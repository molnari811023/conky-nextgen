local src = debug.getinfo(1, "S").source:gsub("^@", "")
local debug_dir = src:match("^(.*[/\\])") or "./"
script_dir = debug_dir:gsub("[/\\]debug[/\\]?$", "/")

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"
    .. ";" .. script_dir .. "lua/weather/?.lua"
    .. ";" .. script_dir .. "lua/hardware/?.lua"

JSON_PATH = script_dir .. "tmp/"
ICON_BASE = script_dir .. "icons/"
ICON_THEME = "default"
MOON_ICON_BASE = script_dir .. "icons/moon/"
WIND_ICON_BASE = script_dir .. "icons/wind/"

THEMES = {
    theme = {
        defaults = {
            background = {
                bg = { { 1, "#202326", 0.9 } },
                border = { { 1, "#4a4d52", 1 } },
                border_width = 1,
            },
            bar = {
                fg = { { 1, "#3daee9", 1 } },
                bg = { { 1, "#3a3d41", 1 } },
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
            text = { color = { { 1, "#fcfcfc", 1 } } },
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
_PADDING = 0

local COUNT = 500
local COLUMNS = 25
local CELL = 42
local X0, Y0 = 4, 4

local function grid(i)
    return X0 + ((i - 1) % COLUMNS) * CELL,
        Y0 + math.floor((i - 1) / COLUMNS) * CELL
end

local function add_background(i)
    local x, y = grid(i)
    return { type = "background", x = x, y = y, w = 38, h = 38, radius = 4 }
end

local function add_line(i)
    local x, y = grid(i)
    return {
        type = "line", x1 = x, y1 = y, x2 = x + 38, y2 = y + 38,
        thickness = 1 + i % 3, style_type = i % 2 == 0 and "dashed" or "solid",
    }
end

local function add_text(i)
    local x, y = grid(i)
    return {
        type = "text", x = x, y = y + 12, font = "Mono", size = 8,
        text = string.format("T%03d ${cpu}%%", i), wrap_width = 38,
    }
end

local function add_bar(i)
    local x, y = grid(i)
    return {
        type = "bar", x = x, y = y + 12, width = 38, height = 10,
        value = "${cpu}", max = 100, mode = i % 2 == 0 and "smooth" or "block",
    }
end

local function add_graph(i)
    local x, y = grid(i)
    return {
        type = "graph", x = x, y = y, width = 38, height = 32,
        value = "${cpu}", max = 100, key = "extreme_graph_" .. i,
    }
end

local function add_ring(i)
    local x, y = grid(i)
    return {
        type = "ring", x = x + 19, y = y + 19, radius = 16, thickness = 4,
        value = "${cpu}", max = 100, sectors = 6, mode = "ring", sides = 6,
    }
end

local function add_image(i)
    local x, y = grid(i)
    return {
        type = "image", x = x, y = y, width = 38, height = 38,
        path = script_dir .. "icons/default/" .. (i % 2 == 0 and "0d.png" or "61d.png"),
    }
end

local function add_svg(i)
    local x, y = grid(i)
    return {
        type = "svg", x = x, y = y, w = 38, h = 38,
        path = debug_dir .. "extreme_icon.svg", rotate = i % 4 * 90,
    }
end

local function add_calendar(i)
    local x, y = grid(i)
    return {
        type = "calendar", x = x, y = y + 10, cell_w = 8, row_h = 6,
        font = "Mono", size = 5, weeknum_size = 4, popup_size = 5,
        show_weeknums = i % 2 == 0,
    }
end

local function add_clock(i)
    local x, y = grid(i)
    return {
        type = "clock", x = x + 19, y = y + 19, radius = 16,
        show_ticks = true, show_numbers = false, show_seconds = i % 2 == 0,
    }
end

local function add_arc(i)
    local x, y = grid(i)
    return {
        type = "arc", cx = x + 19, cy = y + 30, r = 17, segments = 12,
        arc_color = "#3daee9", arc_alpha = 0.8, arc_width = 2,
        horizon = i % 2 == 0,
    }
end

local function add_lyrics(i)
    local x, y = grid(i)
    return {
        type = "lyrics", x = x, y = y, w = 38, font = "Mono", size = 6,
        prev = 0, next = 0, line_gap = 0, align = "left",
    }
end

local BUILDERS = {
    background = add_background,
    line = add_line,
    text = add_text,
    bar = add_bar,
    graph = add_graph,
    ring = add_ring,
    image = add_image,
    svg = add_svg,
    calendar = add_calendar,
    clock = add_clock,
    arc = add_arc,
    lyrics = add_lyrics,
}

local function proc_status(field)
    local f = io.open("/proc/self/status", "r")
    if not f then return 0 end
    for line in f:lines() do
        local value = line:match("^" .. field .. ":%s+(%d+)")
        if value then
            f:close()
            return tonumber(value)
        end
    end
    f:close()
    return 0
end

local function run(renderer)
    local build = BUILDERS[renderer]
    assert(build, "Unsupported extreme renderer: " .. tostring(renderer))

    draw = {}
    for i = 1, COUNT do
        draw[#draw + 1] = build(i)
    end

    _GROUPS = {}
    _VIEWS = { { name = "main" } }

    require("require")
    init_groups(_GROUPS)

    local original_draw = conky_core_main
    function conky_core_main()
        local started = os.clock()
        original_draw()
        io.write(string.format(
            "[%s x%d | update %s] RSS %.1f MB | render %.1f ms\n",
            renderer, #draw, conky_parse("${updates}"),
            proc_status("VmRSS") / 1024, (os.clock() - started) * 1000
        ))
        io.flush()
    end
end

return { run = run }
