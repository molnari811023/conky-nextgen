--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lyrics.lua — synchronized lyrics widget

Root-level widget layout for the ConkyNextGen system. Bootstraps the
script, declares the THEMES theme and registers a single
draw.lyrics block item that renders the track header, a configurable
number of dimmed previous lines, the bright current line, dimmed
following lines and a position footer — all word-wrapped to the
widget width. Data comes from tmp/lyrics.json via lua/songtext.lua,
produced by the standalone lyrics_daemon.lua process.
]]--

--{{{
-- ## Synchronized lyrics widget
--
-- **Exposed/global functions:**
-- ${lua conky_lyrics_*} — provider helpers (see lua/songtext.lua)
--
-- **Config/globals used:**
-- `script_dir`, `package.path`, `JSON_PATH`, `draw`, `THEMES`,
-- `DEFAULT_THEME`, `_PADDING`, `_GROUPS`, `_VIEWS`, `_MOUSE_ENABLED`
-- `require("songtext")` — data provider (mtime-cached JSON read)
-- `require("require")` and `init_groups(_GROUPS)` — bootstraps the system
--}}}

------------------------------------------------------------
-- Global paths / config
------------------------------------------------------------
script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"
    .. ";" .. script_dir .. "lua/weather/?.lua"
    .. ";" .. script_dir .. "lua/hardware/?.lua"

JSON_PATH = script_dir .. "tmp/"

draw = {}

--{{{
-- THEMES — Theme definitions (palette, gradients, widget defaults).
--}}}

THEMES = {

    -- ═══ THEME ═══

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
        },
    },
}

DEFAULT_THEME = "theme"
_PADDING = 10

draw[#draw + 1] = {
    -- Only draw while something is playing (draw_me on both items)
    draw_me = function()
        local s = conky_lyrics_status()
        return s ~= "" and s ~= "Stopped"
    end,

    type = "background",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

draw[#draw + 1] = {
    type = "lyrics",
    x = 10,
    y = 10,
    w = 500,
    font = "Mono",
    size = 13,
    prev = 2,
    next = 2,
    align = "center",
    draw_me = function()
        local s = conky_lyrics_status()
        return s ~= "" and s ~= "Stopped"
    end,
}


_GROUPS = {
}

_VIEWS = {
    { name = "main" },
}

_MOUSE_ENABLED = true

------------------------------------------------------------
-- Bootstrap
------------------------------------------------------------
require("require")
init_groups(_GROUPS)