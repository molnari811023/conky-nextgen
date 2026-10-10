--{{{ custom_lua
-- music.lua
-- by @wim66
-- August 27, 2026
--{{{

--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
--  music.lua — Widget data (generated/edited by sh/designer/main.py)
--  Loaded directly by Conky (lua_load = 'music.lua'). Shows the
--  currently playing track via conky_nowplaying_*() (lua/nowplaying.lua).
--}}}

------------------------------------------------------------
-- Global paths / config (formerly settings.lua)
-- script_dir is music.lua's own directory (the project root)
------------------------------------------------------------
script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"
    .. ";" .. script_dir .. "lua/weather/?.lua"
    .. ";" .. script_dir .. "lua/hardware/?.lua"

-- JSON_PATH is always needed (weather, hardware/network, nowplaying data)
JSON_PATH      = script_dir .. "tmp/"

draw = {}

ICON_BASE      = script_dir .. "icons/"
ICON_THEME     = "default"
MOON_ICON_BASE = script_dir .. "icons/moon/"
WIND_ICON_BASE = script_dir .. "icons/wind/"

--{{{
-- THEMES — same palette as the other NextGen widgets, kept identical
-- so music.conf matches the rest of the desktop at a glance.
--}}}
THEMES = {

    theme = {

        palette = {
            bg_dark = "#202326",
            bg_mid = "#292c30",
            bg_light = "#31363c",
            fg = "#fcfcfc",
            fg_dim = "#a1a9b1",
            blue = "#3daee9",
            green = "#27ae60",
            yellow = "#f67400",
            red = "#da4453",
        },

        gradients = {
            text_value = { { 1, "#27ae60", 1 } },
            bar_cpu = { { 1, "#3daee9", 1 } },
            border_subtle = { { 1, "#a1a9b1", 0.6 } },
        },

        defaults = {
            background = {
                bg = { { 1, "#202326", 0.9 } },
                border = { { 1, "#4a4d52", 1 } },
                border_width = 2,
            },
            bar = {
                fg = { { 1, "#3daee9", 1 } },
                bg = { { 1, "#3a3d41", 1 } },
            },
            line = {
                fg = { { 1, "#a1a9b1", 1 } },
            },
            graph = {
                fg = { { 1, "#3daee9", 1 } },
                bg = { { 1, "#3a3d41", 1 } },
                border = { { 1, "#4a4d52", 1 } },
                grid_color = { { 1, "#31363c", 1 } },
            },
            ring = {
                fg = { { 1, "#3daee9", 1 } },
                bg = { { 1, "#3a3d41", 1 } },
            },
            text = {
                color = { { 1, "#fcfcfc", 1 } },
            },
            clock = {
                bg = { { 1, "#31363c", 1 } },
                border = { { 1, "#4a4d52", 1 } },
                tick_color = { { 1, "#a1a9b1", 1 } },
                number_color = { { 1, "#fcfcfc", 1 } },
                hour_color = { { 1, "#fcfcfc", 1 } },
                minute_color = { { 1, "#3daee9", 1 } },
                second_color = { { 1, "#f67400", 1 } },
                center_color = { { 1, "#3daee9", 1 } },
            },
            calendar = {
                color_month = { { 1, "#fcfcfc", 1 } },
                color_weekdays = { { 1, "#a1a9b1", 1 } },
                color_days = { { 1, "#a1a9b1", 1 } },
                color_today = { { 1, "#3daee9", 1 } },
                color_outside = { { 1, "#4a4d52", 1 } },
                color_weeknums = { { 1, "#3daee9", 1 } },
            },
        },
    },

    slot = {

        palette = {
            bg_dark = "#202326",
            bg_mid = "#292c30",
            bg_light = "#31363c",
            fg = "#fcfcfc",
            fg_dim = "#a1a9b1",
            blue = "#3daee9",
            green = "#27ae60",
            yellow = "#f67400",
            red = "#da4453",
        },

        defaults = {
            background = {
                bg = { { 1, "#151d2b", 1 } },
                border = { { 0.00, "#8899EE", 1 }, { 0.50, "#ece5ff", 1 }, { 1.00, "#8899EE", 1 } },
                border_width = 2,
            },
            bar = {
                fg = { { 1, "#3daee9", 1 } },
                bg = { { 1, "#3a3d41", 1 } },
            },
            line = {
                fg = { { 1, "#a1a9b1", 1 } },
            },
            graph = {
                fg = { { 1, "#3daee9", 1 } },
                bg = { { 1, "#3a3d41", 1 } },
                border = { { 1, "#4a4d52", 1 } },
                grid_color = { { 1, "#31363c", 1 } },
            },
            ring = {
                fg = { { 1, "#3daee9", 1 } },
                bg = { { 1, "#3a3d41", 1 } },
            },
            text = {
                color = { { 1, "#fcfcfc", 1 } },
            },
            clock = {
                bg = { { 1, "#31363c", 1 } },
                border = { { 1, "#4a4d52", 1 } },
                tick_color = { { 1, "#a1a9b1", 1 } },
                number_color = { { 1, "#fcfcfc", 1 } },
                hour_color = { { 1, "#fcfcfc", 1 } },
                minute_color = { { 1, "#3daee9", 1 } },
                second_color = { { 1, "#f67400", 1 } },
                center_color = { { 1, "#3daee9", 1 } },
            },
            calendar = {
                color_month = { { 1, "#fcfcfc", 1 } },
                color_weekdays = { { 1, "#a1a9b1", 1 } },
                color_days = { { 1, "#a1a9b1", 1 } },
                color_today = { { 1, "#3daee9", 1 } },
                color_outside = { { 1, "#4a4d52", 1 } },
                color_weeknums = { { 1, "#3daee9", 1 } },
            },
        },
    },
}

DEFAULT_THEME = "slot"
_PADDING = 10

------------------------------------------------------------
-- Now Playing — draw items
-- Data comes from lua/nowplaying.lua (conky_nowplaying_*), already
-- wired into the central loader via require.lua ("EXTRAS" section).
------------------------------------------------------------

local STATUS_SYMBOL = {
    Playing = "\226\150\182",  -- ▶
    Paused  = "\226\143\184",  -- ⏸
    Stopped = "\226\150\160",  -- ■
}

local function np_has_track()
    local ok, t = pcall(conky_nowplaying_title)
    return ok and t ~= nil and t ~= ""
end

-- Helper: Splits a string into lines based on a maximum character limit per line
local function wrap_text(str, max_len)
    if not str then return "", "" end
    if string.len(str) <= max_len then
        return str, ""
    end
    -- Zoek naar een spatie om netjes op af te breken rond de limiet
    local breakpoint = max_len
    for i = max_len, 1, -1 do
        if string.sub(str, i, i) == " " then
            breakpoint = i
            break
        end
    end
    local line1 = string.sub(str, 1, breakpoint)
    local line2 = string.sub(str, breakpoint + 1)
    -- Trim leading space from line 2
    line2 = line2:match("^%s*(.-)$")
    return line1, line2
end

draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

-- Album art
draw[#draw + 1] = {
    type = "image",
    x = 10,
    y = 10,
    width = 100,
    height = 100,
    path = function() return conky_nowplaying_art_path() end,
    draw_me = function()
        return np_has_track() and conky_nowplaying_art_path() ~= nil
    end,
}

-- Player + playback status
draw[#draw + 1] = {
    type = "text",
    x = 120,
    y = 12,
    font = "Mono",
    size = 10,
    text = function()
        if not np_has_track() then return "" end
        local status = conky_nowplaying_status() or "Stopped"
        local symbol = STATUS_SYMBOL[status] or STATUS_SYMBOL.Stopped
        local player = conky_nowplaying_player() or ""
        return symbol .. "  " .. player
    end,
    color = { { 1, "#3daee9", 1 } },
}

-- Track title - Line 1
draw[#draw + 1] = {
    type = "text",
    x = 120,
    y = 32,
    font = "Mono",
    size = 13,
    text = function()
        if not np_has_track() then return "Niets aan het afspelen" end
        local title = conky_nowplaying_title() or ""
        local l1, _ = wrap_text(title, 26) -- Pas de 26 aan als het breder/smalder moet
        return l1
    end,
    color = { { 1, "#fcfcfc", 1 } },
}

-- Track title - Line 2 (Alleen getoond als de titel lang genoeg is)
draw[#draw + 1] = {
    type = "text",
    x = 120,
    y = 48,
    font = "Mono",
    size = 13,
    text = function()
        if not np_has_track() then return "" end
        local title = conky_nowplaying_title() or ""
        local _, l2 = wrap_text(title, 26)
        return l2
    end,
    draw_me = function()
        if not np_has_track() then return false end
        local title = conky_nowplaying_title() or ""
        local _, l2 = wrap_text(title, 26)
        return l2 ~= ""
    end,
    color = { { 1, "#fcfcfc", 1 } },
}

-- Artist (schuift automatisch mee omlaag als regel 2 actief is)
draw[#draw + 1] = {
    type = "text",
    x = 120,
    y = function()
        if not np_has_track() then return 54 end
        local title = conky_nowplaying_title() or ""
        local _, l2 = wrap_text(title, 26)
        return (l2 ~= "") and 66 or 54
    end,
    font = "Mono",
    size = 11,
    text = function()
        if not np_has_track() then return "" end
        return conky_nowplaying_artist() or ""
    end,
    color = { { 1, "#a1a9b1", 1 } },
}

-- Album (schuift eveneens mee omlaag)
draw[#draw + 1] = {
    type = "text",
    x = 120,
    y = function()
        if not np_has_track() then return 72 end
        local title = conky_nowplaying_title() or ""
        local _, l2 = wrap_text(title, 26)
        return (l2 ~= "") and 84 or 72
    end,
    font = "Mono",
    size = 10,
    text = function()
        if not np_has_track() then return "" end
        return conky_nowplaying_album() or ""
    end,
    color = { { 1, "#a1a9b1", 1 } },
}


_GROUPS = {
}

_VIEWS = {
    { name = "main" },
}

------------------------------------------------------------
-- Mouse event actions
------------------------------------------------------------
_MOUSE_ENABLED = true

MOUSE_CLICK_LEFT = function()
    os.execute("playerctl play-pause &")
end

MOUSE_CLICK_RIGHT = function()
    os.execute("playerctl next &")
end

------------------------------------------------------------
-- Now-playing refresh hook — called via ${lua conky_music_update}
-- in conky.text. Uses script_dir (portable, no hardcoded path) so
-- it works regardless of user, clone location, or launcher cwd.
------------------------------------------------------------
local MUSIC_FETCH_INTERVAL = 5  -- seconds
local last_music_fetch = 0

function conky_music_update()
    local now = os.time()
    if now - last_music_fetch > MUSIC_FETCH_INTERVAL then
        last_music_fetch = now
        os.execute(script_dir .. "sh/0_fetch_all.sh nowplaying >/dev/null 2>&1 &")
    end
    return ""
end

require("require")
init_groups(_GROUPS)