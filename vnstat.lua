--{{{ custom_lua
-- vnstat.lua
-- by @wim66
-- August 27, 2026
--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--  Refactored for vnstat support
--}}}
--}}}

script_dir   = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"
    .. ";" .. script_dir .. "lua/weather/?.lua"
    .. ";" .. script_dir .. "lua/hardware/?.lua"

JSON_PATH    = script_dir .. "tmp/"

draw         = {}

ICON_BASE      = script_dir .. "icons/"
ICON_THEME     = "default"
MOON_ICON_BASE = script_dir .. "icons/moon/"
WIND_ICON_BASE = script_dir .. "icons/wind/"

THEMES         = {
    theme = {
        -- primary/secondary/highlight/success live in .gradients only —
        -- resolve_gradient() (lua/core/theme_engine.lua) is what
        -- color = "primary" etc. actually resolve through, and it only
        -- ever looks in THEMES[theme].gradients, never .palette. Having
        -- them in both was dead duplication (the .palette copies were
        -- never consulted by anything).
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
            primary = { { 1, "#E7660B", 1 } },
            secondary = { { 1, "#FAAD3E", 1 } },
            highlight = { { 1, "#DCE142", 1 } },
            success = { { 1, "#42E147", 1 } },
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
        },
    },

    slot = {
        -- primary/secondary/highlight/success live in .gradients only —
        -- resolve_gradient() (lua/core/theme_engine.lua) is what
        -- color = "primary" etc. actually resolve through, and it only
        -- ever looks in THEMES[theme].gradients, never .palette. Having
        -- them in both was dead duplication (the .palette copies were
        -- never consulted by anything).
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
            primary = { { 1, "#E7660B", 1 } },
            secondary = { { 1, "#FAAD3E", 1 } },
            highlight = { { 1, "#DCE142", 1 } },
            success = { { 1, "#42E147", 1 } },
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
        },
    },
}

DEFAULT_THEME  = "slot"
_PADDING       = 10

-- Background box
draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 12,
}

-- Title: VNSTAT
draw[#draw + 1] = {
    type = "text",
    x = 80,
    y = 25,
    font = "Dejavu Sans Mono",
    size = 18,
    weight = "bold",
    text = "VNSTAT",
    color = "primary",
    align = "left",
}

-- Subtitle: network traffic
draw[#draw + 1] = {
    type = "text",
    x = 160,
    y = 25,
    font = "Dejavu Sans Mono",
    size = 12,
    text = "network traffic",
    color = "success",
    align = "left",
}

-- Headers: Down / Up
draw[#draw + 1] = {
    type = "text",
    x = 200,
    y = 45,
    font = "Dejavu Sans Mono",
    size = 11,
    text = "Down",
    color = "highlight",
    align = "right",
}

draw[#draw + 1] = {
    type = "text",
    x = 320,
    y = 45,
    font = "Dejavu Sans Mono",
    size = 11,
    text = "Up",
    color = "highlight",
    align = "right",
}

-- Row Labels & Dynamic Data bindings
-- Reads tmp/vnstat.txt directly in Lua (cheap: one file open per call,
-- no shelling out) instead of each of the 6 values independently
-- re-running sh/vnstat.sh via its own ${execi ...; sed -n 'Np' ...}.
-- The actual fetch is triggered once, in the background, by
-- conky_vnstat_update() below (called once per frame via conky.text,
-- throttled internally) — matching how weather/updates/now-playing
-- already refresh themselves in this project.
local function conky_vnstat_line(n)
    local f = io.open(script_dir .. "tmp/vnstat.txt", "r")
    if not f then return "N/A" end
    local line
    for i = 1, n do
        line = f:read("*l")
        if not line then break end
    end
    f:close()
    return line or "N/A"
end

local labels = { "Today", "Week", "Month" }
local base_y = 65
local step_y = 20

for i, label in ipairs(labels) do
    local y_pos = base_y + (i - 1) * step_y
    local down_line = (i - 1) * 2 + 1
    local up_line = (i - 1) * 2 + 2

    -- Label (Today, Week, Month)
    draw[#draw + 1] = {
        type = "text",
        x = 20,
        y = y_pos,
        font = "Dejavu Sans Mono",
        size = 11,
        text = label,
        color = "highlight",
        align = "left",
    }

    -- Down value
    draw[#draw + 1] = {
        type = "text",
        x = 200,
        y = y_pos,
        font = "Dejavu Sans Mono",
        size = 11,
        text = function() return conky_vnstat_line(down_line) end,
        align = "right",
    }

    -- Up value
    draw[#draw + 1] = {
        type = "text",
        x = 320,
        y = y_pos,
        font = "Dejavu Sans Mono",
        size = 11,
        text = function() return conky_vnstat_line(up_line) end,
        align = "right",
    }
end

------------------------------------------------------------
-- vnstat refresh hook — called via ${lua conky_vnstat_update} in
-- conky.text. Passes conky_active_iface() (lua/hardware/network.lua)
-- so vnstat's numbers always match whichever interface network.conf
-- is currently showing, instead of vnstat.sh guessing independently.
------------------------------------------------------------
local VNSTAT_FETCH_INTERVAL = 300  -- seconds (5 min)
local last_vnstat_fetch = 0

function conky_vnstat_update()
    local now = os.time()
    if now - last_vnstat_fetch > VNSTAT_FETCH_INTERVAL then
        last_vnstat_fetch = now
        local iface = (conky_active_iface and conky_active_iface()) or ""
        os.execute(script_dir .. "sh/vnstat.sh " .. iface .. " >/dev/null 2>&1 &")
    end
    return ""
end

_GROUPS = {}
_VIEWS = {
    { name = "main" },
}

_MOUSE_ENABLED = true

require("require")
init_groups(_GROUPS)