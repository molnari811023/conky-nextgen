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
------------------------------------------------------------
script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"
    .. ";" .. script_dir .. "lua/weather/?.lua"
    .. ";" .. script_dir .. "lua/hardware/?.lua"

JSON_PATH      = script_dir .. "tmp/"

draw = {}

ICON_BASE      = script_dir .. "icons/"
ICON_THEME     = "default"
MOON_ICON_BASE = script_dir .. "icons/moon/"
WIND_ICON_BASE = script_dir .. "icons/wind/"

--{{{
-- THEMES
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

draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

-- Tab button backgrounds (inactive)
draw[#draw + 1] = {
    type = "background",
    x = 10, y = 10, w = 220, h = 30, radius = 8,
    bg = { { 1, "#1b4155", 0.2 } },
    click_view = "main",
}
draw[#draw + 1] = {
    type = "background",
    x = 240, y = 10, w = 220, h = 30, radius = 8,
    bg = { { 1, "#1b4155", 0.2 } },
    click_view = "view_1",
}
draw[#draw + 1] = {
    type = "background",
    x = 470, y = 10, w = 220, h = 30, radius = 8,
    bg = { { 1, "#1b4155", 0.2 } },
    click_view = "view_2",
}

-- Tab button backgrounds (active highlight)
draw[#draw + 1] = {
    type = "background",
    view = "main",
    x = 10, y = 10, w = 220, h = 30, radius = 8,
    bg = { { 1, "#00aaff", 0.2 } },
    click_view = "main",
}
draw[#draw + 1] = {
    type = "background",
    view = "view_1",
    x = 240, y = 10, w = 220, h = 30, radius = 8,
    bg = { { 1, "#00aaff", 0.2 } },
    click_view = "view_1",
}
draw[#draw + 1] = {
    type = "background",
    view = "view_2",
    x = 470, y = 10, w = 220, h = 30, radius = 8,
    bg = { { 1, "#00aaff", 0.2 } },
    click_view = "view_2",
}

-- Tab labels
draw[#draw + 1] = {
    type = "text",
    x = 120, y = 15,
    font = "Mono", size = 12,
    text = "conky_get_tr(\"current_weather\")",
    align = "center",
}
draw[#draw + 1] = {
    type = "text",
    x = 350, y = 15,
    font = "Mono", size = 12,
    text = "conky_get_tr(\"hourly_forecast\")",
    align = "center",
}
draw[#draw + 1] = {
    type = "text",
    x = 580, y = 15,
    font = "Mono", size = 12,
    text = "conky_get_tr(\"daily_forecast\")",
    align = "center",
}

-- ═══════════════════════════════════════════════
--  VIEW: MAIN — Current Weather (detailed)
-- ═══════════════════════════════════════════════

-- City name + country
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 245, y = 50,
    font = "Mono", size = 13, weight = "bold",
    text = "conky_city_name() .. \", \" .. conky_city_country()",
    color = { { 1, "#3daee9", 1 } },
}

-- Current weather icon (LARGE — left side)
draw[#draw + 1] = {
    type = "image",
    view = "main",
    x = 15, y = 42,
    width = 160, height = 160,
    path = function() return conky_icon_current_weather() end,
}

-- Temperature (big)
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 245, y = 76,
    font = "Mono", size = 42, weight = "bold",
    text = "conky_weather_current_temp() .. conky_unit_cur_temp()",
}

-- Weather description
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 245, y = 112,
    font = "Mono", size = 12,
    text = "conky_weather_code_text(conky_weather_current_code())",
    color = { { 1, "#a1a9b1", 1 } },
}

-- Feels like
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 245, y = 128,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"feels_like\") .. \": \" .. conky_weather_current_apparent() .. conky_unit_cur_apparent()",
    color = { { 1, "#a1a9b1", 1 } },
}

-- Wind icon + speed
draw[#draw + 1] = {
    type = "image",
    view = "main",
    x = 245, y = 143,
    width = 28, height = 28,
    path = function() return conky_icon_current_wind() end,
}
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 280, y = 149,
    font = "Mono", size = 11,
    text = "conky_weather_current_wind_speed() .. \" \" .. conky_unit_cur_wind_speed() .. \" \" .. conky_wind_direction_text(conky_weather_current_wind_dir())",
}

-- ─── Sun + Moon arc (right side) ───
draw[#draw + 1] = {
    type = "arc",
    view = "main",
    x = 0,
    cx = 560, cy = 175, r = 130,
    segments = 30,
    progress = "conky_sun_progress()",
    arc_color = "#4a4d52",
    arc_alpha = 0.35,
    arc_width = 1.5,
    icon = script_dir .. "icons/default/0d.png",
    icon_size = 36,
    horizon = true,
    horizon_color = "#4a4d52",
    progress2 = "conky_moon_progress()",
    icon2 = "conky_icon_moon()",
    icon2_size = 32,
}

-- Separator line
draw[#draw + 1] = {
    type = "line",
    view = "main",
    x1 = 15, y1 = 185, x2 = 685, y2 = 185,
    thickness = 1,
}

-- ─── Details grid (2 columns below icon) ───

-- Row 1: Humidity | Wind gusts
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 15, y = 200,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"humidity\") .. \": \" .. conky_weather_current_humidity() .. conky_unit_cur_humidity()",
    color = { { 1, "#a1a9b1", 1 } },
}
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 350, y = 200,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"wind_gusts\") .. \": \" .. conky_weather_current_wind_gust() .. \" \" .. conky_unit_cur_wind_gust()",
    color = { { 1, "#a1a9b1", 1 } },
}

-- Row 2: Pressure | Cloud cover
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 15, y = 216,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"pressure\") .. \": \" .. conky_weather_current_pressure_msl() .. \" \" .. conky_unit_cur_pressure_msl()",
    color = { { 1, "#a1a9b1", 1 } },
}
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 350, y = 216,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"cloud_cover\") .. \": \" .. conky_weather_current_clouds() .. conky_unit_cur_clouds()",
    color = { { 1, "#a1a9b1", 1 } },
}

-- Row 3: UV index | Visibility
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 15, y = 232,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"uv_index\") .. \": \" .. conky_weather_current_uv()",
    color = { { 1, "#a1a9b1", 1 } },
}
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 350, y = 232,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"visibility\") .. \": \" .. conky_weather_current_visibility() .. \" \" .. conky_unit_cur_visibility()",
    color = { { 1, "#a1a9b1", 1 } },
}

-- Row 4: Dew point | Precipitation
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 15, y = 248,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"dew_point\") .. \": \" .. conky_weather_current_dewpoint() .. \" \" .. conky_unit_cur_dewpoint()",
    color = { { 1, "#a1a9b1", 1 } },
}
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 350, y = 248,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"precipitation\") .. \": \" .. conky_weather_current_precip() .. \" \" .. conky_unit_cur_precip()",
    color = { { 1, "#a1a9b1", 1 } },
}

-- Separator line
draw[#draw + 1] = {
    type = "line",
    view = "main",
    x1 = 15, y1 = 262, x2 = 685, y2 = 262,
    thickness = 1,
}

-- Moon icon + phase text
draw[#draw + 1] = {
    type = "image",
    view = "main",
    x = 15, y = 270,
    width = 36, height = 36,
    path = function() return conky_icon_moon() end,
}
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 58, y = 282,
    font = "Mono", size = 10,
    text = "conky_moon_phase_text()",
    color = { { 1, "#a1a9b1", 1 } },
}

-- Sunrise / Sunset
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 200, y = 274,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"sunrise\") .. \": \" .. conky_weather_day_sunrise(1)",
    color = { { 1, "#f67400", 1 } },
}
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 200, y = 290,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"sunset\") .. \": \" .. conky_weather_day_sunset(1)",
    color = { { 1, "#f67400", 1 } },
}

-- Moonrise / Moonset
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 400, y = 274,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"moonrise\") .. \": \" .. conky_moon_rise_time()",
    color = { { 1, "#a1a9b1", 1 } },
}
draw[#draw + 1] = {
    type = "text",
    view = "main",
    x = 400, y = 290,
    font = "Mono", size = 11,
    text = "conky_get_tr(\"moonset\") .. \": \" .. conky_moon_set_time()",
    color = { { 1, "#a1a9b1", 1 } },
}

-- ═══════════════════════════════════════════════
--  VIEW: VIEW_1 — Hourly Forecast (4 hours)
-- ═══════════════════════════════════════════════

-- Vertical separator lines (between columns)
draw[#draw + 1] = {
    type = "line",
    view = "view_1",
    x1 = 173, y1 = 50, x2 = 173, y2 = 280,
    thickness = 1,
}
draw[#draw + 1] = {
    type = "line",
    view = "view_1",
    x1 = 338, y1 = 50, x2 = 338, y2 = 280,
    thickness = 1,
}
draw[#draw + 1] = {
    type = "line",
    view = "view_1",
    x1 = 503, y1 = 50, x2 = 503, y2 = 280,
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
        text = "conky_weather_hour_time(" .. (i + 1) .. ") and os.date(\"%H:00\", conky_weather_hour_time(" .. (i + 1) .. ")) or \"--\"",
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
        text = "conky_weather_hour_temp(" .. (i + 1) .. ") .. conky_unit_hour_temp()",
        align = "center",
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = cx, y = 160,
        font = "Mono", size = 9,
        text = "conky_weather_code_text(conky_weather_hour_code(" .. (i + 1) .. "))",
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
        text = "conky_weather_hour_wind_speed(" .. (i + 1) .. ") .. \" \" .. conky_unit_hour_wind_speed()",
        align = "center",
        color = { { 1, "#a1a9b1", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = cx, y = 248,
        font = "Mono", size = 10,
        text = "\"💧 \" .. conky_weather_hour_precip_prob(" .. (i + 1) .. ") .. \"%\"",
        align = "center",
        color = { { 1, "#3daee9", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_1",
        x = cx, y = 264,
        font = "Mono", size = 10,
        text = "conky_weather_hour_humidity(" .. (i + 1) .. ") .. conky_unit_hour_humidity()",
        align = "center",
        color = { { 1, "#a1a9b1", 1 } },
    }
end

-- ═══════════════════════════════════════════════
--  VIEW: VIEW_2 — Daily Forecast (4 days)
-- ═══════════════════════════════════════════════

-- Vertical separator lines (between columns)
draw[#draw + 1] = {
    type = "line",
    view = "view_2",
    x1 = 173, y1 = 55, x2 = 173, y2 = 300,
    thickness = 1,
}
draw[#draw + 1] = {
    type = "line",
    view = "view_2",
    x1 = 338, y1 = 55, x2 = 338, y2 = 300,
    thickness = 1,
}
draw[#draw + 1] = {
    type = "line",
    view = "view_2",
    x1 = 503, y1 = 55, x2 = 503, y2 = 300,
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
        text = "conky_day_name_short(" .. i .. ")",
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
        text = "conky_weather_day_temp_max(" .. idx .. ") .. conky_unit_day_temp_max()",
        align = "center",
        color = { { 1, "#f67400", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 186,
        font = "Mono", size = 13,
        text = "conky_weather_day_temp_min(" .. idx .. ") .. conky_unit_day_temp_min()",
        align = "center",
        color = { { 1, "#3daee9", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 206,
        font = "Mono", size = 9,
        text = "conky_weather_code_text(conky_weather_day_code(" .. idx .. "))",
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
        text = "conky_get_tr(\"sunrise\") .. \": \" .. conky_weather_day_sunrise(" .. idx .. ")",
        align = "center",
        color = { { 1, "#f67400", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 254,
        font = "Mono", size = 10,
        text = "conky_get_tr(\"sunset\") .. \": \" .. conky_weather_day_sunset(" .. idx .. ")",
        align = "center",
        color = { { 1, "#f67400", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 270,
        font = "Mono", size = 10,
        text = "conky_get_tr(\"uv_index\") .. \": \" .. conky_weather_day_uv(" .. idx .. ")",
        align = "center",
        color = { { 1, "#a1a9b1", 1 } },
    }

    draw[#draw + 1] = {
        type = "text",
        view = "view_2",
        x = cx, y = 286,
        font = "Mono", size = 10,
        text = "conky_get_tr(\"precipitation_hours\") .. \": \" .. conky_weather_day_precip_hours(" .. idx .. ") .. \" \" .. conky_get_tr(\"hour_short\")",
        align = "center",
        color = { { 1, "#3daee9", 1 } },
    }
end

-- ═══ GROUPS / VIEWS ═══

_GROUPS = {}

_VIEWS = {
    { name = "main" },
    { name = "view_1" },
    { name = "view_2" },
}

_MOUSE_ENABLED = true
MOUSE_LEAVE_ACTION = function() switch_view("main") end

require("require")
init_groups(_GROUPS)
