--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Compact Audio volume indicator (PipeWire + PulseAudio auto-detect)
--}}}

AUDIO_CFG = {
    enabled   = true,
    icon_size = 18,
    font      = "Sans",
    font_size = 11,
    width     = 62,
    poll_sec  = 2,
    colors = {
        normal = "#fcfcfc",
        high   = "#3daee9",
        muted  = "#da4453",
    },
}

AUDIO_STATE = {
    backend = "none",
    volume  = 0,
    muted   = false,
    icon    = nil,
    last_ts = 0,
}

local _audio_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

local function pick_audio_icon(vol, muted)
    local names
    if muted or vol <= 0 then
        names = { "audio-volume-muted", "audio-volume-off" }
    elseif vol >= 66 then
        names = { "audio-volume-high", "audio-volume-medium" }
    elseif vol >= 33 then
        names = { "audio-volume-medium", "audio-volume-high" }
    else
        names = { "audio-volume-low", "audio-volume-medium" }
    end

    local themes = { XDG_ICON_THEME or "breeze-dark", "breeze-dark", "breeze", "Adwaita", "hicolor" }
    for _, tname in ipairs(themes) do
        for _, n in ipairs(names) do
            local p = icon_resolve(n, AUDIO_CFG.icon_size, tname)
            if p then return p end
        end
    end
    return nil
end

local function audio_refresh(force)
    local now = os.time()
    if not force and AUDIO_STATE.last_ts > 0 and (now - AUDIO_STATE.last_ts < AUDIO_CFG.poll_sec) then
        return
    end
    AUDIO_STATE.last_ts = now

    local f = io.popen("bash '" .. _audio_dir .. "audio_backend.sh' status 2>/dev/null")
    if not f then return end
    local line = f:read("*l") or ""
    f:close()

    local b, vol, m = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)$")
    if b then
        AUDIO_STATE.backend = b
        AUDIO_STATE.volume  = tonumber(vol) or 0
        AUDIO_STATE.muted   = (m == "1")
        AUDIO_STATE.icon    = pick_audio_icon(AUDIO_STATE.volume, AUDIO_STATE.muted)
    end
end

function audio_x_left()
    local panel_w = (conky_window and conky_window.width) or 1920
    local right_edge
    if BT_STATE and BT_STATE.available and bt_x_left then
        right_edge = bt_x_left() - 6
    elseif WIFI_STATE and WIFI_STATE.backend ~= "none" and wifi_x_left then
        right_edge = wifi_x_left() - 6
    elseif BATTERY_STATE and BATTERY_STATE.present and battery_x_left then
        right_edge = battery_x_left() - 8
    elseif CLOCK_CFG then
        right_edge = panel_w - (CLOCK_CFG.width or 64) - 8
    else
        right_edge = panel_w - 72
    end
    return right_edge - AUDIO_CFG.width
end

local function audio_color()
    if AUDIO_STATE.muted then return AUDIO_CFG.colors.muted end
    if AUDIO_STATE.volume > 100 then return AUDIO_CFG.colors.high end
    return AUDIO_CFG.colors.normal
end

local function audio_visible()
    if not conky_window or not AUDIO_CFG.enabled then return false end
    audio_refresh(false)
    return AUDIO_STATE.backend ~= "none"
end

function audio_install()
    if not AUDIO_CFG.enabled then return nil end
    audio_refresh(true)

    draw[#draw + 1] = {
        type         = "background",
        x            = function() return audio_x_left() end,
        y            = 6,
        w            = AUDIO_CFG.width,
        h            = 36,
        radius       = 6,
        bg           = { { 1, "#000000", 0 } },
        border_width = 0,
        click        = function()
            os.execute("bash '" .. _audio_dir .. "audio_backend.sh' mute >/dev/null 2>&1")
            audio_refresh(true)
        end,
        rclick       = function()
            os.execute("bash '" .. _audio_dir .. "audio_backend.sh' mixer >/dev/null 2>&1 &")
        end,
        scroll_up    = function()
            os.execute("bash '" .. _audio_dir .. "audio_backend.sh' up 5 >/dev/null 2>&1")
            audio_refresh(true)
        end,
        scroll_down  = function()
            os.execute("bash '" .. _audio_dir .. "audio_backend.sh' down 5 >/dev/null 2>&1")
            audio_refresh(true)
        end,
        draw_me      = audio_visible,
    }

    draw[#draw + 1] = {
        type    = "svg",
        x       = function() return audio_x_left() + 4 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - AUDIO_CFG.icon_size) / 2)
        end,
        w       = AUDIO_CFG.icon_size,
        h       = AUDIO_CFG.icon_size,
        width   = AUDIO_CFG.icon_size,
        height  = AUDIO_CFG.icon_size,
        path    = function() return AUDIO_STATE.icon end,
        draw_me = function()
            return audio_visible() and AUDIO_STATE.icon ~= nil
        end,
    }

    draw[#draw + 1] = {
        type    = "text",
        x       = function() return audio_x_left() + AUDIO_CFG.icon_size + 7 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - AUDIO_CFG.font_size) / 2)
        end,
        font    = AUDIO_CFG.font,
        size    = AUDIO_CFG.font_size,
        color   = { { 1, "#fcfcfc", 1 } },
        text    = function()
            if AUDIO_STATE.muted then return "Mute" end
            return string.format("%d%%", AUDIO_STATE.volume)
        end,
        draw_me = audio_visible,
    }

    local text_item = draw[#draw]
    local orig_draw_me = text_item.draw_me
    text_item.draw_me = function()
        if not orig_draw_me() then return false end
        text_item.color = { { 1, audio_color(), 1 } }
        return true
    end

    return true
end
