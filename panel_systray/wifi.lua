--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Compact Wi-Fi indicator module (nmcli + iwd auto-detect)
--}}}

WIFI_CFG = {
    enabled     = true,
    icon_size   = 18,
    font        = "Sans",
    font_size   = 11,
    width       = 64,
    poll_sec    = 3,
    colors = {
        connected = "#27ae60",
        weak      = "#f67400",
        offline   = "#a1a9b1",
        off       = "#da4453",
    },
}

WIFI_STATE = {
    backend   = "none",
    powered   = false,
    connected = false,
    ssid      = "",
    signal    = 0,
    ip        = "",
    dev       = "",
    icon      = nil,
    last_ts   = 0,
}

local _wifi_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

local function pick_wifi_icon(powered, connected, sig)
    local names
    if not powered then
        names = { "network-wireless-disabled", "network-wireless-offline", "network-wireless-disconnected" }
    elseif not connected then
        names = { "network-wireless-disconnected", "network-wireless-offline", "network-wireless-signal-none" }
    elseif sig >= 75 then
        names = { "network-wireless-signal-excellent", "network-wireless-connected-100", "network-wireless" }
    elseif sig >= 50 then
        names = { "network-wireless-signal-good", "network-wireless-connected-75", "network-wireless" }
    elseif sig >= 25 then
        names = { "network-wireless-signal-ok", "network-wireless-connected-50", "network-wireless" }
    else
        names = { "network-wireless-signal-weak", "network-wireless-connected-25", "network-wireless" }
    end

    local themes = { XDG_ICON_THEME or "breeze-dark", "breeze-dark", "breeze", "Adwaita", "hicolor" }
    for _, tname in ipairs(themes) do
        for _, n in ipairs(names) do
            local p = icon_resolve(n, WIFI_CFG.icon_size, tname)
            if p then return p end
        end
    end
    return nil
end

local function wifi_refresh(force)
    local now = os.time()
    if not force and WIFI_STATE.last_ts > 0 and (now - WIFI_STATE.last_ts < WIFI_CFG.poll_sec) then
        return
    end
    WIFI_STATE.last_ts = now

    local f = io.popen("bash '" .. _wifi_dir .. "wifi_backend.sh' status 2>/dev/null")
    if not f then return end
    local line = f:read("*l") or ""
    f:close()

    local b, pwr, conn, ssid, sig, ip, dev = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
    if b then
        WIFI_STATE.backend   = b
        WIFI_STATE.powered   = (pwr == "1")
        WIFI_STATE.connected = (conn == "1")
        WIFI_STATE.ssid      = ssid or ""
        WIFI_STATE.signal    = tonumber(sig) or 0
        WIFI_STATE.ip        = ip or ""
        WIFI_STATE.dev       = dev or ""
        WIFI_STATE.icon      = pick_wifi_icon(WIFI_STATE.powered, WIFI_STATE.connected, WIFI_STATE.signal)
    end
end

function wifi_x_left()
    local panel_w = (conky_window and conky_window.width) or 1920
    local right_edge
    if BATTERY_STATE and BATTERY_STATE.present and BATTERY_CFG then
        right_edge = panel_w - BATTERY_CFG.clock_space - BATTERY_CFG.width - 8
    elseif CLOCK_CFG then
        right_edge = panel_w - (CLOCK_CFG.width or 64) - 8
    else
        right_edge = panel_w - 72
    end
    return right_edge - WIFI_CFG.width
end

local function wifi_color()
    if not WIFI_STATE.powered then return WIFI_CFG.colors.off end
    if not WIFI_STATE.connected then return WIFI_CFG.colors.offline end
    if WIFI_STATE.signal < 35 then return WIFI_CFG.colors.weak end
    return WIFI_CFG.colors.connected
end

local function wifi_visible()
    if not conky_window or not WIFI_CFG.enabled then return false end
    wifi_refresh(false)
    return WIFI_STATE.backend ~= "none"
end

function wifi_install()
    if not WIFI_CFG.enabled then return nil end
    wifi_refresh(true)

    local toggle_cmd = _wifi_dir .. "toggle_wifi.sh &"

    draw[#draw + 1] = {
        type         = "background",
        x            = function() return wifi_x_left() end,
        y            = 6,
        w            = WIFI_CFG.width,
        h            = 36,
        radius       = 6,
        bg           = { { 1, "#000000", 0 } },
        border_width = 0,
        click        = toggle_cmd,
        rclick       = function()
            os.execute("bash '" .. _wifi_dir .. "wifi_backend.sh' scan >/dev/null 2>&1 &")
            wifi_refresh(true)
        end,
        draw_me      = wifi_visible,
    }

    draw[#draw + 1] = {
        type    = "svg",
        x       = function() return wifi_x_left() + 4 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - WIFI_CFG.icon_size) / 2)
        end,
        w       = WIFI_CFG.icon_size,
        h       = WIFI_CFG.icon_size,
        width   = WIFI_CFG.icon_size,
        height  = WIFI_CFG.icon_size,
        path    = function() return WIFI_STATE.icon end,
        draw_me = function()
            return wifi_visible() and WIFI_STATE.icon ~= nil
        end,
    }

    draw[#draw + 1] = {
        type    = "text",
        x       = function() return wifi_x_left() + WIFI_CFG.icon_size + 7 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - WIFI_CFG.font_size) / 2)
        end,
        font    = WIFI_CFG.font,
        size    = WIFI_CFG.font_size,
        color   = { { 1, "#fcfcfc", 1 } },
        text    = function()
            if not WIFI_STATE.powered then return "Off" end
            if not WIFI_STATE.connected then return "--" end
            return string.format("%d%%", WIFI_STATE.signal)
        end,
        draw_me = wifi_visible,
    }

    local text_item = draw[#draw]
    local orig_draw_me = text_item.draw_me
    text_item.draw_me = function()
        if not orig_draw_me() then return false end
        text_item.color = { { 1, wifi_color(), 1 } }
        return true
    end

    return true
end
