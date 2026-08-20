--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
--  widget.lua — Widget data (generated/edited by sh/designer/main.py)
--  Loaded directly by Conky (lua_load = 'widget.lua'). Structure:
--    Global paths / config (formerly settings.lua)
--    DEFAULT_THEME / _PADDING — global settings
--    draw[#draw + 1] = { ... }        — draw items (background, clock, bar, ...)
--    _GROUPS = { { name, views } }    — item groups (view switching)
--    _VIEWS  = { { name } }           — view definitions
--    MOUSE_*_ACTION = ...             — mouse event callbacks
--    Bootstrap (formerly init.lua)    — loads the modules, inits the groups
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


ICON_BASE      = script_dir .. "icons/"
ICON_THEME     = "default"
MOON_ICON_BASE = script_dir .. "icons/moon/"
WIND_ICON_BASE = script_dir .. "icons/wind/"

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

DEFAULT_THEME = "theme"
_PADDING = 10

require("require")

draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 10,
    y = 10,
    font = "Mono",
    size = 12,
    text = "Cpu: ${cpu}%",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 330,
    y = 10,
    font = "Mono",
    size = 12,
    text = conky_cpu_name(),
    align = "right",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 10,
    y = 25,
    font = "Mono",
    size = 12,
    text = "Temperature:",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 330,
    y = 25,
    font = "Mono",
    size = 12,
    text = conky_cpu_temp() .. "°C",
    align = "right",
}

draw[#draw + 1] = {
    type = "graph",
    view = "main",
    x = 10,
    y = 45,
    width = 320,
    height = 135,
    value = "${cpu}",
    max = 100,
    graph_type = "fill",
    grid = true,
    grid_steps = 5,
    grid_color = { { 1, "#aaaaaa", 1 } },
    autoscale = true,
}

for i = 1, 12 do
    local current_y = 10 + (i - 1) * 15

    draw[#draw + 1] = {
        type = "text",
        x = 10,
        y = current_y,
        font = "Mono",
        size = 12,
        text = "Cpu" .. i .. ": ${cpu cpu" .. i .. "}%",
        view = "view_1",
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = 330,
        y = current_y,
        font = "Mono",
        size = 12,
        text = "${freq " .. i .. "}Mhz",
        align = "right",
    }

    draw[#draw + 1] = {
        type = "bar",
        view = "view_1",
        x = 100,
        y = current_y,
        width = 170,
        height = 12,
        value = "${cpu cpu" .. i .. "}",
        max = 100,
    }
    end


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
