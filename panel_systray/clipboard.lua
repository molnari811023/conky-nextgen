--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Compact Clipboard History indicator module (Wayland + X11)
--}}}

CLIP_CFG = {
    enabled   = true,
    icon_size = 18,
    font      = "Sans",
    font_size = 11,
    width     = 42,
    poll_sec  = 2,
    colors = {
        normal = "#fcfcfc",
        empty  = "#a1a9b1",
    },
}

CLIP_STATE = {
    count   = 0,
    top     = "",
    icon    = nil,
    last_ts = 0,
}

local _clip_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

local function pick_clip_icon()
    local names = { "klipper", "edit-paste", "clipboard", "accessories-clipboard" }
    local themes = { XDG_ICON_THEME or "breeze-dark", "breeze-dark", "breeze", "Adwaita", "hicolor" }
    for _, tname in ipairs(themes) do
        for _, n in ipairs(names) do
            local p = icon_resolve(n, CLIP_CFG.icon_size, tname)
            if p then return p end
        end
    end
    return nil
end

local function clip_refresh(force)
    local now = os.time()
    if not force and CLIP_STATE.last_ts > 0 and (now - CLIP_STATE.last_ts < CLIP_CFG.poll_sec) then
        return
    end
    CLIP_STATE.last_ts = now

    local f = io.popen("bash '" .. _clip_dir .. "clip_backend.sh' poll 2>/dev/null")
    if not f then return end
    local line = f:read("*l") or ""
    f:close()

    local cnt, top = line:match("^([^\t]*)\t(.*)$")
    if cnt then
        CLIP_STATE.count = tonumber(cnt) or 0
        CLIP_STATE.top   = top or ""
    end
    if not CLIP_STATE.icon then
        CLIP_STATE.icon = pick_clip_icon()
    end
end

function clip_x_left()
    local panel_w = (conky_window and conky_window.width) or 1920
    local right_edge
    if AUDIO_STATE and AUDIO_STATE.backend ~= "none" and audio_x_left then
        right_edge = audio_x_left() - 6
    elseif BT_STATE and BT_STATE.available and bt_x_left then
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
    return right_edge - CLIP_CFG.width
end

local function clip_visible()
    if not conky_window or not CLIP_CFG.enabled then return false end
    clip_refresh(false)
    return true
end

function clipboard_install()
    if not CLIP_CFG.enabled then return nil end
    clip_refresh(true)

    local toggle_cmd = _clip_dir .. "toggle_clip.sh &"

    draw[#draw + 1] = {
        type         = "background",
        x            = function() return clip_x_left() end,
        y            = 6,
        w            = CLIP_CFG.width,
        h            = 36,
        radius       = 6,
        bg           = { { 1, "#000000", 0 } },
        border_width = 0,
        click        = toggle_cmd,
        rclick       = function()
            clip_refresh(true)
        end,
        draw_me      = clip_visible,
    }

    draw[#draw + 1] = {
        type    = "svg",
        x       = function() return clip_x_left() + 4 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - CLIP_CFG.icon_size) / 2)
        end,
        w       = CLIP_CFG.icon_size,
        h       = CLIP_CFG.icon_size,
        width   = CLIP_CFG.icon_size,
        height  = CLIP_CFG.icon_size,
        path    = function() return CLIP_STATE.icon end,
        draw_me = function()
            return clip_visible() and CLIP_STATE.icon ~= nil
        end,
    }

    draw[#draw + 1] = {
        type    = "text",
        x       = function() return clip_x_left() + CLIP_CFG.icon_size + 6 end,
        y       = function()
            local h = (conky_window and conky_window.height) or 48
            return math.floor((h - CLIP_CFG.font_size) / 2)
        end,
        font    = CLIP_CFG.font,
        size    = CLIP_CFG.font_size,
        color   = { { 1, "#fcfcfc", 1 } },
        text    = function() return tostring(CLIP_STATE.count) end,
        draw_me = clip_visible,
    }

    local text_item = draw[#draw]
    local orig_draw_me = text_item.draw_me
    text_item.draw_me = function()
        if not orig_draw_me() then return false end
        local col = (CLIP_STATE.count > 0) and CLIP_CFG.colors.normal or CLIP_CFG.colors.empty
        text_item.color = { { 1, col, 1 } }
        return true
    end

    return true
end
