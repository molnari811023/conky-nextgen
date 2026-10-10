--{{{
--  Conky NextGen Framework (fork)
--  by wim66
--}}}

--{{{
--  visualizer.lua — audio spectrum visualizer, sized like now-playing.
--
--  Data comes from `cava` (raw ASCII mode) via sh/cava_visualizer.sh,
--  which streams continuously in the background (unlike every other
--  fetch script in this project) and keeps only its latest frame in
--  tmp/cava_bars.txt — 12 semicolon-separated values, 0..100.
--
--  Rendering is a single type="spectrum" item (lua/draw/spectrum.lua,
--  a new draw module — see its own header for the full option list).
--  It draws bottom-anchored bars directly (no rotation trick needed,
--  unlike type="bar"), with attack/release easing and an independent
--  falling peak-hold marker per bar, matching a reference conky
--  soundbar example. This file's only job is reading cava's data —
--  all animation/drawing state lives inside the spectrum item itself.
--}}}

script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"

JSON_PATH = script_dir .. "tmp/"

draw = {}

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
        defaults = {
            background = {
                bg = { { 1, "#151d2b", 1 } },
                border = { { 0.00, "#8899EE", 1 }, { 0.50, "#ece5ff", 1 }, { 1.00, "#8899EE", 1 } },
                border_width = 2,
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

------------------------------------------------------------
-- Read tmp/cava_bars.txt once per frame — just the raw values.
-- Attack/release easing and peak-hold now live inside draw_spectrum
-- itself (lua/draw/spectrum.lua); this only needs to hand it the
-- current raw targets.
------------------------------------------------------------
local NUM_BARS = 12
local raw_bars = {}
for i = 1, NUM_BARS do raw_bars[i] = 0 end

local function read_bars()
    local f = io.open(script_dir .. "tmp/cava_bars.txt", "r")
    if not f then return end
    local line = f:read("*l")
    f:close()
    if not line then return end
    local i = 0
    for v in line:gmatch("[^;]+") do
        i = i + 1
        raw_bars[i] = tonumber(v) or raw_bars[i]
        if i >= NUM_BARS then break end
    end
end

draw[#draw + 1] = {
    type = "spectrum",
    x = 10,
    y = 15,
    width = 320,
    height = 85,
    num_bars = NUM_BARS,
    bar_gap = 6,
    bar_corner_radius = 3,
    attack = 0.55,
    release = 0.18,
    peak_hold = true,
    peak_decay = 1.2,
    peak_cap_height = 2,
    color_low = "#3daee9",
    color_mid = "#f2d94d",
    color_high = "#f24d59",
    peak_color = "#ffffff",
    values = function() return raw_bars end,
}

------------------------------------------------------------
-- Start cava (if not already running) once per Conky start. Unlike
-- weather/updates/now-playing's periodic re-trigger, cava is meant to
-- keep streaming continuously — sh/cava_visualizer.sh itself refuses
-- to spawn a second instance (PID-tracked), so calling this every
-- frame is harmless, but a boolean guard avoids the redundant
-- os.execute() call after the first successful start.
------------------------------------------------------------
local cava_started = false

function conky_visualizer_update()
    if not cava_started then
        cava_started = true
        os.execute(script_dir .. "sh/cava_visualizer.sh start >/dev/null 2>&1 &")
    end
    read_bars()
    return ""
end


_GROUPS = {}
_VIEWS = {
    { name = "main" },
}

_MOUSE_ENABLED = false

require("require")
init_groups(_GROUPS)