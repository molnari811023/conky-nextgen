--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Compact battery indicator module for the bottom panel
--}}}
--[[[
battery.lua — battery icon + percentage widget sitting to the left of the panel clock.

Reads battery status via `acpi -b` if available, falling back to
`/sys/class/power_supply/BAT*` when `acpi` is not installed. If the machine
has no battery (e.g. a desktop PC), the widget hides itself automatically.
Clicking the battery widget shows a desktop notification with detailed status.
]]--

BATTERY_CFG = {
    enabled     = true,
    icon_size   = 18,
    font        = "Sans",
    font_size   = 11,
    clock_space = 64,   -- distance from the panel's right edge (leaves room for the clock)
    width       = 62,   -- width reserved for icon + percentage
    poll_sec    = 5,    -- refresh interval in seconds
    colors = {
        normal   = "#fcfcfc",
        charging = "#27ae60",
        low      = "#f67400",
        critical = "#da4453",
    },
}

BATTERY_STATE = {
    present  = false,
    percent  = 100,
    status   = "Unknown",
    raw_info = "",
    icon     = nil,
    last_ts  = 0,
}

local function read_trimmed(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    if not s then return nil end
    return s:match("^%s*(.-)%s*$")
end

local function find_sys_battery()
    if not lfs then return nil end
    local base = "/sys/class/power_supply"
    local mode = lfs.attributes(base, "mode")
    if mode ~= "directory" then return nil end
    for entry in lfs.dir(base) do
        if entry:match("^BAT%d+$") then
            return base .. "/" .. entry
        end
    end
    return nil
end

local function pick_battery_icon(pct, status)
    local step = math.floor((pct + 5) / 10) * 10
    if step < 0 then step = 0 end
    if step > 100 then step = 100 end
    local charging = (status == "Charging")
    local name = string.format("battery-%03d%s", step, charging and "-charging" or "")
    local themes = { XDG_ICON_THEME or "breeze-dark", "breeze-dark", "breeze", "Adwaita", "hicolor" }
    for _, tname in ipairs(themes) do
        local p = icon_resolve(name, BATTERY_CFG.icon_size, tname)
        if p then return p end
    end
    -- Fallback generic battery icon names
    local fallbacks = charging
        and { "battery-good-charging", "battery-full-charging", "battery" }
        or  { "battery-good", "battery-full", "battery" }
    for _, tname in ipairs(themes) do
        for _, fb in ipairs(fallbacks) do
            local p = icon_resolve(fb, BATTERY_CFG.icon_size, tname)
            if p then return p end
        end
    end
    return nil
end

local function battery_refresh()
    local now = os.time()
    if now - BATTERY_STATE.last_ts < BATTERY_CFG.poll_sec and BATTERY_STATE.last_ts > 0 then
        return
    end
    BATTERY_STATE.last_ts = now

    local pct, status, raw = nil, nil, nil

    -- 1. Pure Lua + lfs read from Linux kernel /sys/class/power_supply/BAT* (zero external process)
    local bat_dir = find_sys_battery()
    if bat_dir then
        local cap = tonumber(read_trimmed(bat_dir .. "/capacity") or "")
        local st  = read_trimmed(bat_dir .. "/status") or "Unknown"
        if cap then
            pct = cap
            status = st
            local energy_now = tonumber(read_trimmed(bat_dir .. "/energy_now") or read_trimmed(bat_dir .. "/charge_now") or "")
            local power_now  = tonumber(read_trimmed(bat_dir .. "/power_now")  or read_trimmed(bat_dir .. "/current_now") or "")
            local energy_full = tonumber(read_trimmed(bat_dir .. "/energy_full") or read_trimmed(bat_dir .. "/charge_full") or "")
            local extra = ""
            if power_now and power_now > 0 and energy_now then
                local hrs = (status == "Charging" and energy_full and energy_full > energy_now)
                    and ((energy_full - energy_now) / power_now)
                    or  (energy_now / power_now)
                if hrs > 0 and hrs < 48 then
                    local h = math.floor(hrs)
                    local m = math.floor((hrs - h) * 60)
                    extra = string.format(" (%02d:%02d)", h, m)
                end
            end
            raw = string.format("%s: %d%%%s", status, pct, extra)
        end
    end

    if pct then
        BATTERY_STATE.present  = true
        BATTERY_STATE.percent  = pct
        BATTERY_STATE.status   = status or "Unknown"
        BATTERY_STATE.raw_info = raw or ""
        BATTERY_STATE.icon     = pick_battery_icon(pct, BATTERY_STATE.status)
    else
        BATTERY_STATE.present  = false
    end
end

local function battery_x_left()
    if not conky_window then return 0 end
    return conky_window.width - BATTERY_CFG.clock_space - BATTERY_CFG.width
end

local function battery_color()
    if BATTERY_STATE.status == "Charging" then
        return BATTERY_CFG.colors.charging
    elseif BATTERY_STATE.percent <= 15 then
        return BATTERY_CFG.colors.critical
    elseif BATTERY_STATE.percent <= 30 then
        return BATTERY_CFG.colors.low
    end
    return BATTERY_CFG.colors.normal
end

local function battery_visible()
    if not conky_window or not BATTERY_CFG.enabled then return false end
    battery_refresh()
    return BATTERY_STATE.present
end

function battery_install()
    if not BATTERY_CFG.enabled then return nil end
    battery_refresh()

    local click_fn = function()
        battery_refresh()
        local msg = BATTERY_STATE.raw_info ~= "" and BATTERY_STATE.raw_info
            or string.format("%s (%d%%)", BATTERY_STATE.status, BATTERY_STATE.percent)
        local escaped = msg:gsub("'", "'\\''")
        os.execute("notify-send -a 'Battery' 'Battery' '" .. escaped .. "' >/dev/null 2>&1 &")
    end

    -- Clickable hitbox covering icon + percentage
    draw[#draw + 1] = {
        type         = "background",
        x            = function() return battery_x_left() end,
        y            = 6,
        w            = BATTERY_CFG.width,
        h            = 36,
        radius       = 6,
        bg           = { { 1, "#000000", 0 } },
        border_width = 0,
        click        = click_fn,
        draw_me      = battery_visible,
    }

    -- Battery SVG icon
    draw[#draw + 1] = {
        type    = "svg",
        x       = function() return battery_x_left() + 4 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - BATTERY_CFG.icon_size) / 2)
        end,
        w       = BATTERY_CFG.icon_size,
        h       = BATTERY_CFG.icon_size,
        width   = BATTERY_CFG.icon_size,
        height  = BATTERY_CFG.icon_size,
        path    = function() return BATTERY_STATE.icon end,
        draw_me = function()
            return battery_visible() and BATTERY_STATE.icon ~= nil
        end,
    }

    -- Battery percentage text
    draw[#draw + 1] = {
        type    = "text",
        x       = function() return battery_x_left() + BATTERY_CFG.icon_size + 7 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - BATTERY_CFG.font_size) / 2)
        end,
        font    = BATTERY_CFG.font,
        size    = BATTERY_CFG.font_size,
        color   = { { 1, "#fcfcfc", 1 } },
        text    = function() return string.format("%d%%", BATTERY_STATE.percent) end,
        draw_me = function()
            if not battery_visible() then return false end
            return true
        end,
    }

    -- Keep text color synced on each tick
    local text_item = draw[#draw]
    local orig_draw_me = text_item.draw_me
    text_item.draw_me = function()
        if not orig_draw_me() then return false end
        text_item.color = { { 1, battery_color(), 1 } }
        return true
    end

    return true
end
