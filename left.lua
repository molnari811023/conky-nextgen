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
    group = "info",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 10,
    y = 10,
    font = "Mono",
    size = 12,
    text = conky_get_tr("System"),
    color = { { 1, "#65aacd", 1 } },
    weight = "bold",
}

draw[#draw + 1] = {
    type = "line",
    group = "info",
    x1 = 80,
    y1 = 20,
    x2 = 350,
    y2 = 20,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 10,
    y = 25,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Operating System") .. ":",
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 350,
    y = 25,
    font = "Mono",
    size = 12,
    text = "${execpi 7200 lsb_release -sd |tr -d '\"'}",
    align = "right",
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 10,
    y = 40,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Kernel") .. ":",
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 350,
    y = 40,
    font = "Mono",
    size = 12,
    text = "${kernel}",
    align = "right",
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 10,
    y = 55,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Uptime") ..":",
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 350,
    y = 55,
    font = "Mono",
    size = 12,
    text = conky_uptime_fmt(),
    align = "right",
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 10,
    y = 70,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Desktop session") .. ":",
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 350,
    y = 70,
    font = "Mono",
    size = 12,
    text = "${execpi 3600 echo $DESKTOP_SESSION/$XDG_SESSION_TYPE}",
    align = "right",
}

draw[#draw + 1] = {
    type = "background",
    group = "updates",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

draw[#draw + 1] = {
    type = "text",
    group = "updates",
    x = 10,
    y = 10,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Updates"),
    color = { { 1, "#65aacd", 1 } },
    weight = "bold",
}

draw[#draw + 1] = {
    type = "line",
    group = "updates",
    x1 = 100,
    y1 = 20,
    x2 = 350,
    y2 = 20,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "text",
    group = "updates",
    x = 10,
    y = 25,
    font = "Mono",
    size = 12,
    text = "Repo :",
}

draw[#draw + 1] = {
    type = "text",
    group = "updates",
    x = 350,
    y = 25,
    font = "Mono",
    size = 12,
    text = conky_updates_repo(),
    align = "right",
}

draw[#draw + 1] = {
    type = "text",
    group = "updates",
    x = 10,
    y = 40,
    font = "Mono",
    size = 12,
    text = "Aur:",
}

draw[#draw + 1] = {
    type = "text",
    group = "updates",
    x = 350,
    y = 40,
    font = "Mono",
    size = 12,
    text = conky_updates_aur(),
    align = "right",
}

draw[#draw + 1] = {
    type = "background",
    group = "battery",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

draw[#draw + 1] = {
    type = "text",
    group = "battery",
    x = 10,
    y = 10,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Battery"),
    color = { { 1, "#65aacd", 1 } },
    weight = "bold",
}

draw[#draw + 1] = {
    type = "line",
    group = "battery",
    x1 = 95,
    y1 = 20,
    x2 = 350,
    y2 = 20,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "text",
    group = "battery",
    x = 10,
    y = 25,
    font = "Mono",
    size = 12,
    text = "${lua conky_battery_status}",
}

draw[#draw + 1] = {
    type = "text",
    group = "battery",
    x = 350,
    y = 25,
    font = "Mono",
    size = 12,
    text = "${battery_percent}%",
    align = "right",
}

draw[#draw + 1] = {
    type = "bar",
    group = "battery",
    x = 10,
    y = 40,
    width = 340,
    height = 12,
    value = "${battery_percent}",
    max = 100,
}

draw[#draw + 1] = {
    type = "text",
    group = "battery",
    x = 10,
    y = 60,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Battery Health") .. ":",
}

draw[#draw + 1] = {
    type = "text",
    group = "battery",
    x = 350,
    y = 60,
    font = "Mono",
    size = 12,
    text = "${lua conky_battery_health_data}%",
    align = "right",
}

draw[#draw + 1] = {
    type = "text",
    group = "battery",
    x = 170,
    y = 80,
    font = "Mono",
    size = 12,
    align = "center",
    text = conky_get_tr("Time Remaining") .. ": ${lua conky_battery_time}",
    draw_me = function()
        return conky_battery_status() ~= conky_get_tr("Full")
    end,
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 10,
    y = 85,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Product_name") .. ":",
}

draw[#draw + 1] = {
    type = "text",
    group = "info",
    x = 350,
    y = 85,
    font = "Mono",
    size = 12,
    text = conky_product_name(),
    align = "right",
}

draw[#draw + 1] = {
    type = "background",
    group = "cpu",
    x = 0,
    y = 0,
    w = 0,
    h = 220,
    radius = 12,
    click = function() view_toggle("cpu_full") end,
}

draw[#draw + 1] = {
    type = "text",
    group = "cpu",
    x = 10,
    y = 10,
    w = 340,
    h = 20,
    font = "Mono",
    size = 12,
    text = conky_get_tr("cpu"),
    color = { { 1, "#65aacd", 1 } },
    weight = "bold",
    click = function() view_toggle("cpu_full") end,
}

draw[#draw + 1] = {
    type = "line",
    group = "cpu",
    x1 = 110,
    y1 = 20,
    x2 = 350,
    y2 = 20,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "text",
    group = "cpu",
    view = "main",
    x = 10,
    y = 25,
    font = "Mono",
    size = 12,
    text = conky_get_tr("CPU") .. ": ${cpu}%",
}

draw[#draw + 1] = {
    type = "text",
    group = "cpu",
    view = "main",
    x = 350,
    y = 25,
    font = "Mono",
    size = 12,
    text = "${lua conky_cpu_name}",
    align = "right",
}

draw[#draw + 1] = {
    type = "text",
    group = "cpu",
    view = "main",
    x = 10,
    y = 40,
    font = "Mono",
    size = 12,
    text = conky_get_tr("temperature") .. ":",
}

draw[#draw + 1] = {
    type = "text",
    group = "cpu",
    view = "main",
    x = 350,
    y = 40,
    font = "Mono",
    size = 12,
    text = "${lua conky_cpu_temp}°C",
    align = "right",
}

draw[#draw + 1] = {
    type = "graph",
    group = "cpu",
    view = "main",
    x = 10,
    y = 60,
    width = 340,
    height = 150,
    value = "${cpu}",
    max = 100,
    graph_type = "fill",
    grid = true,
    grid_steps = 5,
    grid_color = { { 1, "#aaaaaa", 1 } },
    autoscale = true,
}

for i = 1, 12 do
    local current_y = 30 + (i - 1) * 15

    draw[#draw + 1] = {
        type = "text",
        group = "cpu",
        x = 10,
        y = current_y,
        font = "Mono",
        size = 12,
        text = "Cpu" .. i .. ": ${cpu cpu" .. i .. "}%",
        view = "cpu_full",
    }

    draw[#draw + 1] = {
        type = "text",
        group = "cpu",
        view = "cpu_full",
        x = 350,
        y = current_y,
        font = "Mono",
        size = 12,
        text = "${freq " .. i .. "}Mhz",
        align = "right",
    }

    draw[#draw + 1] = {
        type = "bar",
        group = "cpu",
        view = "cpu_full",
        x = 100,
        y = current_y,
        width = 190,
        height = 12,
        value = "${cpu cpu" .. i .. "}",
        max = 100,
    }
end

draw[#draw + 1] = {
    type = "background",
    group = "graphics",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 10,
    y = 10,
    w = 340,
    h = 20,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Graphics Card"),
    color = { { 1, "#65aacd", 1 } },
    weight = "bold",
}

draw[#draw + 1] = {
    type = "line",
    group = "graphics",
    x1 = 110,
    y1 = 20,
    x2 = 350,
    y2 = 20,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 170,
    y = 25,
    font = "Mono",
    size = 12,
    text = "${nvidia modelname}",
    align = "center",
    color = { { 1, "#3daee9", 1 } },
}

draw[#draw + 1] = {
    type = "line",
    group = "graphics",
    x1 = 10,
    y1 = 40,
    x2 = 350,
    y2 = 40,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 10,
    y = 52,
    font = "Mono",
    size = 12,
    text = conky_get_tr("GPU Temp") .. ":",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 350,
    y = 52,
    font = "Mono",
    size = 12,
    text = "${nvidia gputemp}°C",
    align = "right",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 10,
    y = 65,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Memory") .. ":",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 170,
    y = 64,
    font = "Mono",
    size = 12,
    text = "${nvidia memused}/${nvidia memmax}",
    align = "center",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 350,
    y = 64,
    font = "Mono",
    size = 12,
    text = "${nvidia memutil}" .. conky_get_tr("% used"),
    align = "right",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "bar",
    group = "graphics",
    x = 10,
    y = 85,
    width = 340,
    height = 10,
    value = "${nvidia memutil}",
    max = 100,
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 10,
    y = 100,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Driver version") .. ":",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 350,
    y = 100,
    font = "Mono",
    size = 12,
    text = "${nvidia driverversion}",
    align = "right",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 10,
    y = 115,
    font = "Mono",
    size = 12,
    text = conky_get_tr("GPU utilization") .. ":",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "text",
    group = "graphics",
    x = 350,
    y = 115,
    font = "Mono",
    size = 12,
    text = "${nvidia gpuutil}%",
    align = "right",
    color = { { 1, "#a1a9b1", 1 } },
}

draw[#draw + 1] = {
    type = "background",
    group = "memory",
    x = 0,
    y = 0,
    w = 0,
    h = 95,
    radius = 12,
}

draw[#draw + 1] = {
    type = "text",
    group = "memory",
    x = 10,
    y = 10,
    w = 340,
    h = 20,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Memory"),
    color = { { 1, "#65aacd", 1 } },
    weight = "bold",
}

draw[#draw + 1] = {
    type = "line",
    group = "memory",
    x1 = 110,
    y1 = 20,
    x2 = 350,
    y2 = 20,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "text",
    group = "memory",
    x = 10,
    y = 25,
    font = "Meslo LGS",
    size = 12,
    text = "Ram:",
}

draw[#draw + 1] = {
    type = "text",
    group = "memory",
    x = 170,
    y = 25,
    font = "Mono",
    size = 12,
    text = "${mem}/${memmax}",
    align = "center",
}

draw[#draw + 1] = {
    type = "text",
    group = "memory",
    x = 350,
    y = 25,
    font = "Mono",
    size = 12,
    text = "${memperc}" .. conky_get_tr("% used"),
    align = "right",
}

draw[#draw + 1] = {
    type = "text",
    group = "memory",
    x = 10,
    y = 60,
    font = "Mono",
    size = 12,
    text = "Swap:",
}

draw[#draw + 1] = {
    type = "text",
    group = "memory",
    x = 170,
    y = 60,
    font = "Mono",
    size = 12,
    text = "${swap}/${swapmax}",
    align = "center",
}

draw[#draw + 1] = {
    type = "text",
    group = "memory",
    x = 350,
    y = 60,
    font = "Mono",
    size = 12,
    text = "${swapperc}" .. conky_get_tr("% used"),
    align = "right",
}

draw[#draw + 1] = {
    type = "bar",
    group = "memory",
    x = 10,
    y = 40,
    width = 340,
    height = 12,
    value = "${memperc}",
    max = 100,
}

draw[#draw + 1] = {
    type = "bar",
    group = "memory",
    x = 10,
    y = 75,
    width = 340,
    height = 12,
    value = "${swapperc}",
    max = 100,
}

draw[#draw + 1] = {
    type = "background",
    group = "disk",
    x = 0,
    y = 0,
    w = 0,
    h = 152,
    radius = 12,
}

draw[#draw + 1] = {
    type = "text",
    group = "disk",
    x = 10,
    y = 10,
    w = 340,
    h = 20,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Disk"),
    color = { { 1, "#65aacd", 1 } },
    weight = "bold",
}

draw[#draw + 1] = {
    type = "line",
    group = "disk",
    x1 = 110,
    y1 = 20,
    x2 = 350,
    y2 = 20,
    thickness = 2,
}

draw[#draw + 1] = {
    type = "text",
    group = "disk",
    x = 10,
    y = 25,
    font = "Mono",
    size = 12,
    text = "${lua conky_nvme_model}",
}

draw[#draw + 1] = {
    type = "text",
    group = "disk",
    x = 350,
    y = 25,
    font = "Mono",
    size = 12,
    align = "right",
    text = "${lua conky_nvme_temp}°C",
}

draw[#draw + 1] = {
    type = "text",
    group = "disk",
    x = 10,
    y = 40,
    font = "Mono",
    size = 12,
    text = "Root:",
}

draw[#draw + 1] = {
    type = "text",
    group = "disk",
    x = 170,
    y = 40,
    font = "Mono",
    size = 12,
    text = "${fs_used}/${fs_size}",
    align = "center",
}

draw[#draw + 1] = {
    type = "text",
    group = "disk",
    x = 350,
    y = 40,
    font = "Mono",
    size = 12,
    text = "${fs_used_perc}" .. conky_get_tr("% used"),
    align = "right",
}

draw[#draw + 1] = {
    type = "bar",
    group = "disk",
    x = 10,
    y = 55,
    width = 340,
    height = 12,
    value = "${fs_used_perc}",
    max = 100,
}



draw[#draw + 1] = {
    type = "text",
    group = "disk",
    x = 10,
    y = 73,
    font = "Mono",
    size = 12,
    text = conky_get_tr("Read") .. ": ${diskio_read}/s",
}

draw[#draw + 1] = {
    type = "text",
    group = "disk",
    x = 350,
    y = 73,
    font = "Mono",
    size = 12,
    align = "right",
    text = conky_get_tr("Write") .. ": ${diskio_write}/s",
}

draw[#draw + 1] = {
    type = "graph",
    group = "disk",
    x = 10,
    y = 93,
    width = 160,
    height = 50,
    value = "${diskio_read}",
    autoscale = true,
    max = 100,
}

draw[#draw + 1] = {
    type = "graph",
    group = "disk",
    x = 190,
    y = 93,
    width = 160,
    height = 50,
    value = "${diskio_write}",
    autoscale = true,
    max = 100,
}

_GROUPS = {
    { name = "info", views = { "main" } },
    { name = "updates", views = { "main" } },
    { name = "battery", views = { "main" } },
    { name = "cpu", views = { "cpu_full" } },
    { name = "graphics", views = { "main" } },
    { name = "memory", views = { "main" } },
    { name = "disk", views = { "main" } },
}

_VIEWS = {
    { name = "main" },
    { name = "cpu_full" },
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
