--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Compact Bluetooth indicator module (BlueZ bluetoothctl)
--}}}

BT_CFG = {
    enabled   = true,
    icon_size = 18,
    font      = "Sans",
    font_size = 11,
    width     = 42,
    poll_sec  = 4,
    colors = {
        connected = "#3daee9",
        on        = "#fcfcfc",
        off       = "#a1a9b1",
    },
}

BT_STATE = {
    available = false,
    powered   = false,
    count     = 0,
    name      = "",
    icon      = nil,
    last_ts   = 0,
}

local _bt_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

local function pick_bt_icon(powered, count)
    local names
    if not powered then
        names = { "bluetooth-disabled", "bluetooth-offline", "bluetooth" }
    elseif count > 0 then
        names = { "bluetooth-active", "network-bluetooth-activated", "bluetooth" }
    else
        names = { "bluetooth-active", "bluetooth", "network-bluetooth" }
    end

    local themes = { XDG_ICON_THEME or "breeze-dark", "breeze-dark", "breeze", "Adwaita", "hicolor" }
    for _, tname in ipairs(themes) do
        for _, n in ipairs(names) do
            local p = icon_resolve(n, BT_CFG.icon_size, tname)
            if p then return p end
        end
    end
    return nil
end

local function bt_refresh(force)
    local now = os.time()
    if not force and BT_STATE.last_ts > 0 and (now - BT_STATE.last_ts < BT_CFG.poll_sec) then
        return
    end
    BT_STATE.last_ts = now

    local f = io.popen("bash '" .. _bt_dir .. "bt_backend.sh' status 2>/dev/null")
    if not f then return end
    local line = f:read("*l") or ""
    f:close()

    local avail, pwr, cnt, cname = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
    if avail then
        BT_STATE.available = (avail == "1")
        BT_STATE.powered   = (pwr == "1")
        BT_STATE.count     = tonumber(cnt) or 0
        BT_STATE.name      = cname or ""
        BT_STATE.icon      = pick_bt_icon(BT_STATE.powered, BT_STATE.count)
    end
end

function bt_x_left()
    local panel_w = (conky_window and conky_window.width) or 1920
    local right_edge
    if WIFI_STATE and WIFI_STATE.backend ~= "none" and wifi_x_left then
        right_edge = wifi_x_left() - 6
    elseif BATTERY_STATE and BATTERY_STATE.present and battery_x_left then
        right_edge = battery_x_left() - 8
    elseif CLOCK_CFG then
        right_edge = panel_w - (CLOCK_CFG.width or 64) - 8
    else
        right_edge = panel_w - 72
    end
    return right_edge - BT_CFG.width
end

local function bt_color()
    if not BT_STATE.powered then return BT_CFG.colors.off end
    if BT_STATE.count > 0 then return BT_CFG.colors.connected end
    return BT_CFG.colors.on
end

local function bt_visible()
    if not conky_window or not BT_CFG.enabled then return false end
    bt_refresh(false)
    return BT_STATE.available
end

function bluez_install()
    if not BT_CFG.enabled then return nil end
    bt_refresh(true)

    local toggle_cmd = _bt_dir .. "toggle_bt.sh &"

    draw[#draw + 1] = {
        type         = "background",
        x            = function() return bt_x_left() end,
        y            = 6,
        w            = BT_CFG.width,
        h            = 36,
        radius       = 6,
        bg           = { { 1, "#000000", 0 } },
        border_width = 0,
        click        = toggle_cmd,
        rclick       = function()
            os.execute("bash '" .. _bt_dir .. "bt_backend.sh' toggle >/dev/null 2>&1")
            bt_refresh(true)
        end,
        draw_me      = bt_visible,
    }

    draw[#draw + 1] = {
        type    = "svg",
        x       = function() return bt_x_left() + 4 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - BT_CFG.icon_size) / 2)
        end,
        w       = BT_CFG.icon_size,
        h       = BT_CFG.icon_size,
        width   = BT_CFG.icon_size,
        height  = BT_CFG.icon_size,
        path    = function() return BT_STATE.icon end,
        draw_me = function()
            return bt_visible() and BT_STATE.icon ~= nil
        end,
    }

    draw[#draw + 1] = {
        type    = "text",
        x       = function() return bt_x_left() + BT_CFG.icon_size + 6 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - BT_CFG.font_size) / 2)
        end,
        font    = BT_CFG.font,
        size    = BT_CFG.font_size,
        color   = { { 1, "#fcfcfc", 1 } },
        text    = function()
            if not BT_STATE.powered then return "Off" end
            if BT_STATE.count > 0 then return tostring(BT_STATE.count) end
            return ""
        end,
        draw_me = bt_visible,
    }

    local text_item = draw[#draw]
    local orig_draw_me = text_item.draw_me
    text_item.draw_me = function()
        if not orig_draw_me() then return false end
        text_item.color = { { 1, bt_color(), 1 } }
        return true
    end

    return true
end
