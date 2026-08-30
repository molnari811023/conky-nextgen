--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
nvidia.lua — NVIDIA GPU monitoring widget

Root-level widget layout for the ConkyNextGen system. It bootstraps the
script (script_dir, package.path, JSON_PATH), loads the engine via
require("require") early, declares the THEMES theme and icon globals,
and registers draw items: a rounded background, GPU model, temperature,
memory usage bar, driver version and GPU utilization.
]]--

--{{{
-- ## NVIDIA GPU widget
--
-- Monitors GPU model, temperature, memory usage, utilization and driver
-- version in a single "main" view using the ${nvidia ...} conky
-- variables (modelname, gputemp, memused, memmax, memutil,
-- driverversion, gpuutil).
--
-- **Exposed/global functions:**
-- (none defined in this file)
--
-- **Config/globals used:**
-- `script_dir`, `package.path`, `JSON_PATH`, `ICON_BASE`, `ICON_THEME`,
-- `MOON_ICON_BASE`, `WIND_ICON_BASE`, `draw`, `THEMES`, `DEFAULT_THEME`,
-- `_PADDING`, `_GROUPS`, `_VIEWS`, `_MOUSE_ENABLED`
-- `require("require")` and `init_groups(_GROUPS)` — bootstraps the system
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
            text = {
                color = { { 1, "#fcfcfc", 1 } },
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
    type = "text",
    x = 170,
    y = 10,
    font = "Mono",
    size = 12,
    text = "${nvidia modelname}",
    align = "center",
    color = { { 1, "#3daee9", 1 } },
}

draw[#draw + 1] = {
    type = "line",
    x1 = 10,
    y1 = 25,
    x2 = 330,
    y2 = 25,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "text",
    x = 10,
    y = 37,
    font = "Mono",
    size = 12,
    text = "Gpu temp:",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 37,
    font = "Mono",
    size = 12,
    text = "${nvidia gputemp}°C",
    align = "right",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    x = 10,
    y = 50,
    font = "Mono",
    size = 12,
    text = "Memory:",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    x = 170,
    y = 49,
    font = "Mono",
    size = 12,
    text = "${nvidia memused}/${nvidia memmax}",
    align = "center",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 49,
    font = "Mono",
    size = 12,
    text = "${nvidia memutil}% used",
    align = "right",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "bar",
    x = 10,
    y = 70,
    width = 320,
    height = 10,
    value = "${nvidia memutil}",
    max = 100,
}

draw[#draw + 1] = {
    type = "text",
    x = 10,
    y = 85,
    font = "Mono",
    size = 12,
    text = "Driver version:",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 85,
    font = "Mono",
    size = 12,
    text = "${nvidia driverversion}",
    align = "right",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    x = 10,
    y = 100,
    font = "Mono",
    size = 12,
    text = "GPU utilization:",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 100,
    font = "Mono",
    size = 12,
    text = "${nvidia gpuutil}%",
    align = "right",
    color = { { 1, "#a1a9b1", 1 } },
}


_GROUPS = {
}

_VIEWS = {
    { name = "main" },
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


------------------------------------------------------------
-- Bootstrap (formerly init.lua): initialize the item groups.
------------------------------------------------------------
init_groups(_GROUPS)
