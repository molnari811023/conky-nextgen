--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
--  clock_cal_2.lua — Widget data (generated/edited by sh/designer/main.py)
--  Loaded directly by Conky (lua_load = 'clock_cal_2.lua'). Compact
--  clock + calendar side by side in a single view (unlike clock_cal.lua,
--  which shows a large clock and a large calendar as two view-toggled
--  screens). Structure:
--    Global paths / config (formerly settings.lua)
--    DEFAULT_THEME / _PADDING — global settings
--    draw[#draw + 1] = { ... }        — draw items (background, clock, calendar)
--    _GROUPS = { { name, views } }    — item groups (view switching)
--    _VIEWS  = { { name } }           — view definitions
--    Bootstrap (formerly init.lua)    — loads the modules, inits the groups
--}}}

------------------------------------------------------------
-- Global paths / config (formerly settings.lua)
-- script_dir is clock_cal_2.lua's own directory (the project root)
------------------------------------------------------------
script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"

JSON_PATH      = script_dir .. "tmp/"

draw = {}

require("require")

--{{{
-- THEMES — same palette/defaults as clock_cal.lua, so this widget
-- matches the rest of the desktop (and the other clock/calendar view).
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
                bg = { { 1, "#2f384a", 1 } },
                border = { { 1, "#8899EE", 1 } },
                tick_color = { { 1, "#ece5ff", 1 } },
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

draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

------------------------------------------------------------
-- Analog clock — left half.
------------------------------------------------------------
draw[#draw + 1] = {
    type = "clock",
    view = "main",
    x = 80,
    y = 90,
    radius = 70,
    show_ticks = true,
    show_numbers = true,
    show_seconds = true,
}

------------------------------------------------------------
-- Month calendar with week numbers — right half.
-- draw_calendar always draws the month title at (size + 8), so a
-- too-small cell_w/size makes the title dominate the tiny grid below
-- it. Sized here so the grid and its title are back in proportion,
-- and the total grid width (8 * cell_w, incl. the week-number column)
-- plus x fits inside the widget instead of clipping the last column.
------------------------------------------------------------
draw[#draw + 1] = {
    type = "calendar",
    view = "main",
    x = 154,
    y = 8,
    cell_w = 23,
    row_h = 19,
    font = "Mono",
    size = 10,
    show_weeknums = true,
}


_GROUPS = {
}

_VIEWS = {
    { name = "main" },
}

------------------------------------------------------------
-- Mouse event actions
------------------------------------------------------------

_MOUSE_ENABLED = false


------------------------------------------------------------
-- Bootstrap (formerly init.lua): initialize the item groups.
------------------------------------------------------------
init_groups(_GROUPS)