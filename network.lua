--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
--  network.lua — Widget data (generated/edited by sh/designer/main.py)
--  Loaded directly by Conky (lua_load = 'network.lua'). Structure:
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
-- script_dir is network.lua's own directory (the project root)
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

DEFAULT_THEME = "slot"
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

------------------------------------------------------------
-- Row 1 (y=10): Wifi — interface name + status.
-- color has no function support (only static tables), so "Up"/"Down"
-- are two separate draw items, shown/hidden via draw_me instead of
-- one item with a dynamically computed color.
------------------------------------------------------------
draw[#draw + 1] = {
    type = "text",
    x = 10,
    y = 10,
    font = "Mono",
    size = 12,
    text = "Wifi:",
}

draw[#draw + 1] = {
    type = "text",
    x = 170,
    y = 10,
    font = "Mono",
    size = 12,
    align = "center",
    text = function()
        local iface = conky_wifi_interface()
        return (iface ~= "") and iface or "niet gevonden"
    end,
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 10,
    font = "Mono",
    size = 12,
    align = "right",
    text = "Up",
    color = { { 1, "#27ae60", 1 } },
    draw_me = function() return conky_wifi_active() == 1 end,
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 10,
    font = "Mono",
    size = 12,
    align = "right",
    text = "Down",
    color = { { 1, "#da4453", 1 } },
    draw_me = function() return conky_wifi_active() == 0 end,
}

------------------------------------------------------------
-- Row 2 (y=25): Ethernet — same pattern as the Wifi row above.
------------------------------------------------------------
draw[#draw + 1] = {
    type = "text",
    x = 10,
    y = 25,
    font = "Mono",
    size = 12,
    text = "Ethernet:",
}

draw[#draw + 1] = {
    type = "text",
    x = 170,
    y = 25,
    font = "Mono",
    size = 12,
    align = "center",
    text = function()
        local iface = conky_ethernet_interface()
        return (iface ~= "") and iface or "niet gevonden"
    end,
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 25,
    font = "Mono",
    size = 12,
    align = "right",
    text = "Up",
    color = { { 1, "#27ae60", 1 } },
    draw_me = function() return conky_ethernet_active() == 1 end,
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 25,
    font = "Mono",
    size = 12,
    align = "right",
    text = "Down",
    color = { { 1, "#da4453", 1 } },
    draw_me = function() return conky_ethernet_active() == 0 end,
}

------------------------------------------------------------
-- Row 3 (y=43): current speed, for whichever interface is active
-- (ethernet preferred over wifi when both happen to be up).
------------------------------------------------------------
draw[#draw + 1] = {
    type = "text",
    x = 10,
    y = 43,
    font = "Mono",
    size = 12,
    text = function()
        return "Down: " .. conky_net_downspeed() .. "/s"
    end,
}

draw[#draw + 1] = {
    type = "text",
    x = 330,
    y = 43,
    font = "Mono",
    size = 12,
    align = "right",
    text = function()
        return "Up: " .. conky_net_upspeed() .. "/s"
    end,
}

------------------------------------------------------------
-- Row 4 (y=61-111): speed graphs, same layout as disk.lua's
-- read/write graphs.
--
-- Graph `value` must be either a plain conky-syntax string or a
-- { value = "<unique key>", exec = function() ... end } table (the
-- same shape interpret_name() produces for strings) — a bare Lua
-- function is NOT supported by draw_get_value and, worse, both
-- graphs would collide on the same auto-derived cache key ("").
------------------------------------------------------------
draw[#draw + 1] = {
    type = "graph",
    x = 10,
    y = 61,
    width = 150,
    height = 50,
    value = { value = "net_down_speed", exec = function() return conky_net_downspeedf() end },
    autoscale = true,
    max = 100,
}

draw[#draw + 1] = {
    type = "graph",
    x = 180,
    y = 61,
    width = 150,
    height = 50,
    value = { value = "net_up_speed", exec = function() return conky_net_upspeedf() end },
    autoscale = true,
    max = 100,
}

------------------------------------------------------------
-- Row 5 (y=117): total transferred this session (since this conky
-- instance started — conky's own ${totaldown}/${totalup}), for the
-- same active interface as row 3/4.
------------------------------------------------------------
draw[#draw + 1] = {
    type = "text",
    x = 10,
    y = 117,
    font = "Mono",
    size = 12,
    text = function()
        return "Total Down: " .. conky_net_totaldown()
    end,
}

draw[#draw + 1] = {
    type = "text",
    x = 180,
    y = 117,
    font = "Mono",
    size = 12,
    text = function()
        return "Total Up: " .. conky_net_totalup()
    end,
}


_GROUPS = {
}

_VIEWS = {
    { name = "main" },
}

------------------------------------------------------------
-- Mouse event actions (only the non-nil ones are listed)
------------------------------------------------------------

_MOUSE_ENABLED = true


------------------------------------------------------------
-- Bootstrap (formerly init.lua): initialize the item groups.
------------------------------------------------------------
init_groups(_GROUPS)