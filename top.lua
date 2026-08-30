--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
top.lua — top processes widget (highest CPU / memory usage)

Root-level widget layout for the ConkyNextGen system. It bootstraps the
script (script_dir, package.path, JSON_PATH, icon globals), declares
the THEMES theme, loads the engine via require("require") and regis-
ters a column header plus six rows showing name, PID and percentage
for the busiest processes. The "main" view lists top CPU consumers
(${top ...}) and view_1 lists top memory consumers (${top_mem ...}).
]]--

--{{{
-- ## Top processes widget
--
-- Lists the six most CPU-hungry processes in view "main" and the six
-- most memory-hungry processes in view "view_1", with a left-click
-- action toggling between the two views.
--
-- **Exposed/global functions:**
-- (none defined in this file)
--
-- **Config/globals used:**
-- `script_dir`, `package.path`, `JSON_PATH`, `ICON_BASE`, `ICON_THEME`,
-- `MOON_ICON_BASE`, `WIND_ICON_BASE`, `draw`, `THEMES`, `DEFAULT_THEME`,
-- `_PADDING`, `_GROUPS`, `_VIEWS`, `_MOUSE_ENABLED`
-- `view_toggle("view_1")` — left-click action (defined in mouse_actions.lua)
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
                color = { { 1, "#a1a9b1", 1 } },
            },
            clock = {
                bg = { { 1, "#31363c", 1 } },
                border = { { 1, "#4a4d52", 1 } },
                tick_color = { { 1, "#a1a9b1", 1 } },
                number_color = { { 1, "#fcfcfc", 1 } },
                hour_color = { { 1, "#fcfcfc", 1 } },
                minute_color = { { 1, "#3daee9", 1 } },
                second_color = { { 1, "#f67400", 1 } },
                left_color = { { 1, "#3daee9", 1 } },
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
    type = "text",
    view = "main",
    x = 170,
    y = 10,
    font = "Mono",
    size = 12,
    text = "Top cpu usage",
    align = "center",
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
    x = 30,
    y = 30,
    font = "Mono",
    size = 12,
    text = "Name",
}

draw[#draw + 1] = {
    type = "text",
    x = 315,
    y = 30,
    align = "center",
    font = "Mono",
    size = 12,
    text = "Pid",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 230,
    y = 30,
    align = "center",
    font = "Mono",
    size = 12,
    text = "cpu%",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    x = 220,
    y = 30,
    align = "center",
    font = "Mono",
    size = 12,
    text = "mem",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 10,
    y = 45,
    font = "Mono",
    size = 12,
    text = "1: ${top name 1}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 10,
    y = 60,
    font = "Mono",
    size = 12,
    text = "2: ${top name 2}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 10,
    y = 75,
    font = "Mono",
    size = 12,
    text = "3: ${top name 3}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 10,
    y = 90,
    font = "Mono",
    size = 12,
    text = "4: ${top name 4}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 10,
    y = 105,
    font = "Mono",
    size = 12,
    text = "5: ${top name 5}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 10,
    y = 120,
    font = "Mono",
    size = 12,
    text = "6: ${top name 6}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 280,
    y = 45,
    font = "Mono",
    size = 12,
    text = "${top pid 1}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 280,
    y = 60,
    font = "Mono",
    size = 12,
    text = "${top pid 2}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 280,
    y = 75,
    font = "Mono",
    size = 12,
    text = "${top pid 3}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 280,
    y = 90,
    font = "Mono",
    size = 12,
    text = "${top pid 4}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 280,
    y = 105,
    font = "Mono",
    size = 12,
    text = "${top pid 5}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 280,
    y = 120,
    font = "Mono",
    size = 12,
    text = "${top pid 6}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    x = 170,
    y = 10,
    font = "Mono",
    size = 12,
    text = "Top memory usage",
    align = "center",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    x = 10,
    y = 45,
    font = "Mono",
    size = 12,
    text = "1: ${top_mem name 1}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    x = 10,
    y = 60,
    font = "Mono",
    size = 12,
    text = "2: ${top_mem name 2}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    x = 10,
    y = 75,
    font = "Mono",
    size = 12,
    text = "3: ${top_mem name 3}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    x = 10,
    y = 90,
    font = "Mono",
    size = 12,
    text = "4: ${top_mem name 4}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    x = 10,
    y = 105,
    font = "Mono",
    size = 12,
    text = "5: ${top_mem name 5}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    x = 10,
    y = 120,
    font = "Mono",
    size = 12,
    text = "6: ${top_mem name 6}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 280,
    y = 45,
    font = "Mono",
    size = 12,
    text = "${top_mem pid 1}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 280,
    y = 60,
    font = "Mono",
    size = 12,
    text = "${top_mem pid 2}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 280,
    y = 75,
    font = "Mono",
    size = 12,
    text = "${top_mem pid 3}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 280,
    y = 90,
    font = "Mono",
    size = 12,
    text = "${top_mem pid 4}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 280,
    y = 105,
    font = "Mono",
    size = 12,
    text = "${top_mem pid 5}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 280,
    y = 120,
    font = "Mono",
    size = 12,
    text = "${top_mem pid 6}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 200,
    y = 45,
    font = "Mono",
    size = 12,
    text = "${top_mem mem_res 1}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 200,
    y = 60,
    font = "Mono",
    size = 12,
    text = "${top_mem mem_res 2}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 200,
    y = 75,
    font = "Mono",
    size = 12,
    text = "${top_mem mem_res 3}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 200,
    y = 90,
    font = "Mono",
    size = 12,
    text = "${top_mem mem_res 4}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 200,
    y = 105,
    font = "Mono",
    size = 12,
    text = "${top_mem mem_res 5}",
}

draw[#draw + 1] = {
    type = "text",
    view = "view_1",
    align = "left",
    x = 200,
    y = 120,
    font = "Mono",
    size = 12,
    text = "${top_mem mem_res 6}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 200,
    y = 45,
    font = "Mono",
    size = 12,
    text = "${top cpu 1}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 200,
    y = 60,
    font = "Mono",
    size = 12,
    text = "${top cpu 2}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 200,
    y = 75,
    font = "Mono",
    size = 12,
    text = "${top cpu 3}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 200,
    y = 90,
    font = "Mono",
    size = 12,
    text = "${top cpu 4}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 200,
    y = 105,
    font = "Mono",
    size = 12,
    text = "${top cpu 5}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    align = "left",
    x = 200,
    y = 120,
    font = "Mono",
    size = 12,
    text = "${top cpu 6}",
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
