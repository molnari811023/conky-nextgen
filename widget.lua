--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
widget.lua — main entry / loader of the whole ConkyNextGen system

This root file is the system entry point. It computes the project root
(script_dir), extends package.path with the lua/, lua/core/, lua/draw/,
lua/weather/, lua/hardware/ and lua/google/ module directories, sets
JSON_PATH to the tmp/ cache folder and the icon-base globals, declares
the THEMES/DEFAULT_THEME configuration and loads the entire engine by
calling require("require"). It then registers the draw items of the
bundled widget (a small network panel with download/upload speed
graphs using ${lua conky_wifi_downspeed} / ${lua conky_wifi_upspeed}),
defines the lua_hook_exec refresh hook (conky_weather_update) and
boots the renderer via init_groups(_GROUPS).
]]--

--{{{
-- ## Main entry / loader
--
-- Sets up global paths and the module search path, defines the theme
-- configuration and loads every engine module through require("require")
-- before initializing the item groups with init_groups(). Its own draw
-- list configures a network/wifi panel in a single "main" view.
--
-- **Exposed/global functions:**
-- - `conky_weather_update()` — lua_hook_exec refresh hook (weather data + alerts)
--
-- **Config/globals used:**
-- `script_dir`, `package.path`, `JSON_PATH`, `ICON_BASE`, `ICON_THEME`,
-- `MOON_ICON_BASE`, `WIND_ICON_BASE`, `draw`, `THEMES`, `DEFAULT_THEME`,
-- `_PADDING`, `_GROUPS`, `_VIEWS`, `_MOUSE_ENABLED`
-- `require("require")` — central module loader
-- `conky_load_weather_data()` / `conky_update_alerts()` — used by the refresh hook
-- `init_groups(_GROUPS)` — final bootstrap of the renderer
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
    .. ";" .. script_dir .. "lua/google/?.lua"

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
    x = 10,
    y = 10,
    font = "Mono",
    size = 12,
    text = "Wifi",
}

draw[#draw + 1] = {
    type = "line",
    x1 = 50,
    y1 = 20,
    x2 = 330,
    y2 = 20,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "graph",
    x = 10,
    y = 45,
    width = 150,
    height = 40,
    value = "${lua conky_wifi_downspeed}",
    max = 100,
}

draw[#draw + 1] = {
    type = "graph",
    x = 180,
    y = 45,
    width = 150,
    height = 40,
    value = "${lua conky_wifi_upspeed}",
    max = 100,
}

draw[#draw + 1] = {
    type = "text",
    x = 10,
    y = 25,
    font = "Mono",
    size = 12,
    text = "Download:${lua conky_wifi_downspeed}/s",
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 25,
    font = "Mono",
    size = 12,
    text = "Upload:${lua conky_wifi_upspeed}/s",
    align = "right",
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


function conky_weather_update()
    conky_load_weather_data()
    conky_update_alerts()
    return ""
end


------------------------------------------------------------
-- Bootstrap (formerly init.lua): initialize the item groups.
------------------------------------------------------------
init_groups(_GROUPS)
