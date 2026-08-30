--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
clock_cal.lua — analog clock and calendar widget

Root-level widget layout for the ConkyNextGen system. It computes the
project root (script_dir), extends package.path to the lua/ module
tree, sets JSON_PATH to the tmp/ cache directory, loads the whole
engine with require("require"), declares the THEMES theme and
registers the draw list: a rounded window background, an analog clock
(main view, with seconds hand and ticks) and a month calendar
(view_1). It also declares the view list and a left-click action that
toggles view_1.
]]--

--{{{
-- ## Clock and calendar widget
--
-- Entry-style widget file: bootstraps global paths, theme and engine
-- loading, then registers the background, clock and calendar draw
-- items across the "main" and "view_1" views.
--
-- **Exposed/global functions:**
-- (none defined in this file)
--
-- **Config/globals used:**
-- `script_dir`, `package.path`, `JSON_PATH`, `draw`, `THEMES`,
-- `DEFAULT_THEME`, `_PADDING`, `_GROUPS`, `_VIEWS`, `_MOUSE_ENABLED`
-- `require("require")` — loads all engine modules
-- `init_groups(_GROUPS)` — initializes the item groups
-- `view_toggle("view_1")` — left-click action (defined in mouse_actions.lua)
--}}}

------------------------------------------------------------
-- Global paths / config (formerly settings.lua)
-- script_dir is widget.lua's own directory (the project root)
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

require("require")


--{{{
-- THEMES — Theme definitions (palette, gradients, widget defaults).
-- Lives in widget.lua, before the modules are loaded, so that
-- theme_engine.lua picks it up (THEMES = THEMES or {}).
--
-- THEMES = {
--   theme = {
--     palette   = { key = "#hex", ... },
--     gradients = { name = { stops }, ... },
--     defaults  = {
--       background = { bg, border, border_width },
--       bar        = { fg, bg },
--       graph      = { fg, bg, border, grid_color },
--       ring       = { fg, bg },
--       text       = { color },
--       line       = { fg },
--       clock      = { bg, border, tick/number/hand colors },
--       calendar   = { color_month, color_weekdays, ... },
--     },
--   },
-- }
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
                bg = { { 1, "#222528", 1 } },
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

DEFAULT_THEME = "theme"
_PADDING = 10

draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

draw[#draw + 1] = {
    type = "clock",
    view = "main",
    x = 170,
    y = 170,
    radius = 160,
    show_seconds = true,
    show_ticks = true,
    draw_me = true,
}

draw[#draw + 1] = {
    type = "calendar",
    view = "view_1",
    x = 10,
    y = 10,
    cell_w = 40,
    row_h = 37,
    font = "Mono",
    size = 16,
}


_GROUPS = {
}

_VIEWS = {
    { name = "main" },
    { name = "view_1" },
}

------------------------------------------------------------
-- Mouse event actions (only the non-nil ones are listed)
-- All callbacks receive: function(event)
-- event has: type, x, y, x_abs, y_abs, time,
--            button ("left"/"right"/"middle"/"back"/"forward"),
--            direction ("up"/"down"/"left"/"right"),
--            mods = { shift=bool, control=bool, alt=bool, super=bool,
--                     caps_lock=bool, num_lock=bool }
------------------------------------------------------------

_MOUSE_ENABLED = true
MOUSE_CLICK_LEFT = function() view_toggle("view_1") end


------------------------------------------------------------
-- Bootstrap (formerly init.lua): initialize the item groups.
------------------------------------------------------------
init_groups(_GROUPS)
