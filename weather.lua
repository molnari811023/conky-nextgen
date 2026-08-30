--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
weather.lua — full weather widget (current, hourly, daily forecast)

Root-level widget layout for the ConkyNextGen system. It bootstraps the
script (script_dir, package.path incl. lua/google/, JSON_PATH, icon
globals), clears cached engine modules so a SIGUSR1 hot-reload re-
executes them, loads the engine via require("require"), declares the
THEMES theme and registers three views: "main" (current conditions,
city, temperature, sun/moon arc and icons, humidity, pressure, UV,
sunrise/sunset, moonrise/moonset, moon phase), "view_1" (four hourly
forecast columns) and "view_2" (four daily forecast columns). Tab
backgrounds switch the view and a mouse-leave action returns to main.
]]--

--{{{
-- ## Weather widget
--
-- Full weather display driven by the weather.* lua modules: current
-- conditions, hourly and daily forecast tables and a sun/moon arc.
-- Also exports the conky_weather_update() hook used by lua_hook_exec
-- to refresh weather data and alerts.
--
-- **Exposed/global functions:**
-- - `conky_weather_update()` — refresh hook; calls conky_load_weather_data() and conky_update_alerts()
--
-- **Config/globals used:**
-- `script_dir`, `package.path`, `JSON_PATH`, `ICON_BASE`, `ICON_THEME`,
-- `MOON_ICON_BASE`, `WIND_ICON_BASE`, `draw`, `THEMES`, `DEFAULT_THEME`,
-- `_PADDING`, `_GROUPS`, `_VIEWS`, `_MOUSE_ENABLED`
-- `package.loaded` — cleared for weather/core/draw/hardware/google modules (hot-reload)
-- `switch_view("main")` — mouse-leave action (defined in mouse_actions.lua)
-- `conky_load_weather_data()` / `conky_update_alerts()` — data refresh helpers
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
                fg = { { 1, "#4a4d52", 1 } },
            },
            text = {
                color = { { 1, "#fcfcfc", 1 } },
            },
        },
    },
}

DEFAULT_THEME = "theme"
_PADDING = 10

-- SIGUSR1 hot-reload: clear cached modules so require() re-executes them
for k in pairs(package.loaded) do
	if k:find("^weather%.") or k:find("^core%.") or k:find("^draw%.") or k:find("^hardware%.")
		or k:find("^google%.") or k == "require" or k == "mouse_actions" or k == "nowplaying"
		or k == "draw.hyphen" then
		package.loaded[k] = nil
	end
end
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
    type = "background",
    x = 10,
    y = 10,
    w = 220,
    h = 30,
    radius = 8,
    bg = { { 1, "#1b4155", 0.2 } },
    click_view = "main",
}

draw[#draw + 1] = {
    type = "background",
    x = 240,
    y = 10,
    w = 220,
    h = 30,
    radius = 8,
    bg = { { 1, "#1b4155", 0.2 } },
    click_view = "view_1",
}

draw[#draw + 1] = {
    type = "background",
    x = 470,
    y = 10,
    w = 220,
    h = 30,
    radius = 8,
    bg = { { 1, "#1b4155", 0.2 } },
    click_view = "view_2",
}

draw[#draw + 1] = {
    type = "background",
    view = "main",
    x = 10,
    y = 10,
    w = 220,
    h = 30,
    radius = 8,
    bg = { { 1, "#00aaff", 0.2 } },
    click_view = "main",
}

draw[#draw + 1] = {
    type = "background",
    view = "view_1",
    x = 240,
    y = 10,
    w = 220,
    h = 30,
    radius = 8,
    bg = { { 1, "#00aaff", 0.2 } },
    click_view = "view_1",
}

draw[#draw + 1] = {
    type = "background",
    view = "view_2",
    x = 470,
    y = 10,
    w = 220,
    h = 30,
    radius = 8,
    bg = { { 1, "#00aaff", 0.2 } },
    click_view = "view_2",
}

draw[#draw + 1] = {
    type = "text",
    x = 120,
    y = 15,
    font = "Mono",
    size = 12,
    text = "${lua conky_get_tr current_weather}",
    align = "center",
}

draw[#draw + 1] = {
    type = "text",
    x = 350,
    y = 15,
    font = "Mono",
    size = 12,
    text = "${lua conky_get_tr hourly_forecast}",
    align = "center",
}

draw[#draw + 1] = {
    type = "text",
    x = 580,
    y = 15,
    font = "Mono",
    size = 12,
    text = "${lua conky_get_tr daily_forecast}",
    align = "center",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 245,
    y = 50,
    font = "Mono",
    size = 13,
    weight = "bold",
    text = "${lua conky_city_name}, ${lua conky_city_country}",
    color = { { 1, "#3daee9", 1 } },
}

draw[#draw + 1] = {
    type = "image",
    view = "main",
    x = 15,
    y = 42,
    width = 160,
    height = 160,
    path = function() return conky_icon_current_weather() end,
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 245,
    y = 76,
    font = "Mono",
    size = 42,
    weight = "bold",
    text = "${lua conky_weather_cur_temp}",
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 245,
    y = 112,
    font = "Mono",
    size = 12,
    text = "${lua conky_weather_cur_code_text}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 245,
    y = 128,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr feels_like}: ${lua conky_weather_cur_apparent}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "image",
    view = "main",
    x = 245,
    y = 143,
    width = 28,
    height = 28,
    path = function() return conky_icon_current_wind() end,
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 280,
    y = 149,
    font = "Mono",
    size = 11,
    text = "${lua conky_weather_cur_wind_full}",
}

draw[#draw + 1] = {
    type = "arc",
    view = "main",
    x = 0,
    cx = 560,
    cy = 175,
    r = 118,
    segments = 30,
    arc_color = "#eff0f1",
    arc_alpha = 1,
    arc_width = 2,
    horizon = true,
    horizon_color = "#ffffff",
}

draw[#draw + 1] = {
    type = "image",
    view = "main",
    width = 32,
    height = 32,
    path = ICON_BASE .. ICON_THEME .. "/0d.png",
    x = function() return conky_sun_x(560, 118, 32) end,
    y = function() return conky_sun_y(175, 118, 32) end,
    draw_me = function()
        return need_to_draw_sun_icon()
    end,
}

draw[#draw + 1] = {
    type = "image",
    view = "main",
    width = 32,
    height = 32,
    path = function() return conky_icon_moon() end,
    x = function() return conky_moon_x(560, 118, 32) end,
    y = function() return conky_moon_y(175, 118, 32) end,
    draw_me = function()
        return need_to_draw_moon_icon()
    end,
}

draw[#draw + 1] = {
    type = "line",
    view = "main",
    x1 = 15,
    y1 = 185,
    x2 = 685,
    y2 = 185,
    thickness = 1,
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 15,
    y = 200,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr humidity}: ${lua conky_weather_cur_humidity}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 350,
    y = 200,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr wind_gusts}: ${lua conky_weather_cur_wind_gust}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 15,
    y = 216,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr pressure}: ${lua conky_weather_cur_pressure}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 350,
    y = 216,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr cloud_cover}: ${lua conky_weather_cur_clouds}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 15,
    y = 232,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr uv_index}: ${lua conky_weather_cur_uv}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 350,
    y = 232,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr visibility}: ${lua conky_weather_cur_visibility}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 15,
    y = 248,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr dew_point}: ${lua conky_weather_cur_dewpoint}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 350,
    y = 248,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr precipitation}: ${lua conky_weather_cur_precip}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "line",
    view = "main",
    x1 = 15,
    y1 = 262,
    x2 = 685,
    y2 = 262,
    thickness = 1,
}

draw[#draw + 1] = {
    type = "image",
    view = "main",
    x = 15,
    y = 270,
    width = 36,
    height = 36,
    path = function() return conky_icon_moon() end,
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 58,
    y = 282,
    font = "Mono",
    size = 10,
    text = "${lua conky_moon_phase_text}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 200,
    y = 274,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr sunrise}: ${lua conky_weather_day_sunrise 1}",
    color = { { 1, "#f67400", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 200,
    y = 290,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr sunset}: ${lua conky_weather_day_sunset 1}",
    color = { { 1, "#f67400", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 400,
    y = 274,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr moonrise}: ${lua conky_moon_rise_time}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 400,
    y = 290,
    font = "Mono",
    size = 11,
    text = "${lua conky_get_tr moonset}: ${lua conky_moon_set_time}",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "line",
    view = "view_1",
    x1 = 173,
    y1 = 50,
    x2 = 173,
    y2 = 280,
    thickness = 1,
}

draw[#draw + 1] = {
    type = "line",
    view = "view_1",
    x1 = 338,
    y1 = 50,
    x2 = 338,
    y2 = 280,
    thickness = 1,
}

draw[#draw + 1] = {
    type = "line",
    view = "view_1",
    x1 = 503,
    y1 = 50,
    x2 = 503,
    y2 = 280,
    thickness = 1,
}



-- 4 hourly columns
local h_col_x = { 15, 180, 345, 510 }
for i = 0, 3 do
    local cx = h_col_x[i + 1] + 70

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = cx, y = 52,
        font = "Mono", size = 11,
        text = "${lua conky_weather_hour_time_str " .. (i + 1) .. "}",
        align = "center",
        color = { { 1, "#3daee9", 1 } },
    }

    draw[#draw + 1] = {
        type = "image",
        view = "view_1",
        x = cx - 30, y = 72,
        width = 60, height = 60,
        path = (function(idx) return function() return conky_icon_hour_weather(idx) end end)(i + 1),
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = cx, y = 142,
        font = "Mono", size = 14, weight = "bold",
        text = "${lua conky_weather_hour_temp " .. (i + 1) .. "}",
        align = "center",
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = cx, y = 160,
        font = "Mono", size = 9,
        text = "${lua conky_weather_hour_code_text " .. (i + 1) .. "}",
        align = "center",
        color = { { 1, "#a1a9b1", 1 } },
    }

    draw[#draw + 1] = {
        type = "image",
        view = "view_1",
        x = cx - 22, y = 178,
        width = 44, height = 44,
        path = (function(idx) return function() return conky_icon_hour_wind(idx) end end)(i + 1),
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = cx, y = 232,
        font = "Mono", size = 10,
        text = "${lua conky_get_tr wind_speed}: ${lua conky_weather_hour_wind_speed " .. (i + 1) .. "}",
        align = "center",
        color = { { 1, "#a1a9b1", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = cx, y = 248,
        font = "Mono", size = 10,
        text = "${lua conky_get_tr precipitation}: ${lua conky_weather_hour_precip_icon " .. (i + 1) .. "}",
        align = "center",
        color = { { 1, "#3daee9", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = cx, y = 264,
        font = "Mono", size = 10,
        text = "${lua conky_get_tr humidity}: ${lua conky_weather_hour_humidity " .. (i + 1) .. "}",
        align = "center",
        color = { { 1, "#a1a9b1", 1 } },
    }
end

draw[#draw + 1] = {
    type = "line",
    view = "view_2",
    x1 = 173,
    y1 = 55,
    x2 = 173,
    y2 = 300,
    thickness = 1,
}

draw[#draw + 1] = {
    type = "line",
    view = "view_2",
    x1 = 338,
    y1 = 55,
    x2 = 338,
    y2 = 300,
    thickness = 1,
}

draw[#draw + 1] = {
    type = "line",
    view = "view_2",
    x1 = 503,
    y1 = 55,
    x2 = 503,
    y2 = 300,
    thickness = 1,
}



-- 4 daily columns
local d_col_x = { 15, 180, 345, 510 }
for i = 0, 3 do
    local cx = d_col_x[i + 1] + 70
    local idx = i + 1

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 60,
        font = "Mono", size = 11, weight = "bold",
        text = "${lua conky_day_name_short " .. i .. "}",
        align = "center",
    }

    draw[#draw + 1] = {
        type = "image",
        view = "view_2",
        x = cx - 30, y = 78,
        width = 60, height = 60,
        path = (function(idx) return function() return conky_icon_day_weather(idx) end end)(idx),
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 166,
        font = "Mono", size = 16, weight = "bold",
        text = "${lua conky_weather_day_temp_max " .. idx .. "}",
        align = "center",
        color = { { 1, "#f67400", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 186,
        font = "Mono", size = 13,
        text = "${lua conky_weather_day_temp_min " .. idx .. "}",
        align = "center",
        color = { { 1, "#3daee9", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 206,
        font = "Mono", size = 9,
        text = "${lua conky_weather_day_code_text " .. idx .. "}",
        align = "center",
        color = { { 1, "#a1a9b1", 1 } },
    }

    draw[#draw + 1] = {
        type = "line",
        view = "view_2",
        x1 = d_col_x[i + 1] + 10, y1 = 222, x2 = d_col_x[i + 1] + 130, y2 = 222,
        thickness = 1,
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 238,
        font = "Mono", size = 10,
        text = "${lua conky_get_tr sunrise}: ${lua conky_weather_sunrise " .. idx .. "}",
        align = "center",
        color = { { 1, "#f67400", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 254,
        font = "Mono", size = 10,
        text = "${lua conky_get_tr sunset}: ${lua conky_weather_sunset " .. idx .. "}",
        align = "center",
        color = { { 1, "#f67400", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 270,
        font = "Mono", size = 10,
        text = "${lua conky_get_tr uv_index}: ${lua conky_weather_day_uv_text " .. idx .. "}",
        align = "center",
        color = { { 1, "#a1a9b1", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 286,
        font = "Mono", size = 10,
        text = "${lua conky_get_tr precipitation}: ${lua conky_weather_day_precip_hours_text " .. idx .. "} ${lua conky_get_tr hour_short}",
        align = "center",
        color = { { 1, "#3daee9", 1 } },
    }
end


_GROUPS = {
}

_VIEWS = {
    { name = "main" },
    { name = "view_1" },
    { name = "view_2" },
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
MOUSE_LEAVE_ACTION = function() switch_view("main") end


------------------------------------------------------------
-- Bootstrap (formerly init.lua): initialize the item groups.
------------------------------------------------------------
init_groups(_GROUPS)

------------------------------------------------------------
-- Weather data refresh hook — called via lua_hook_exec in .conf
------------------------------------------------------------
function conky_weather_update()
    conky_load_weather_data()
    conky_update_alerts()
    return ""
end
