local GH = 50
local GW = 300
local GX = 20
local C = { { 1, "#aaaaaa", 1 } }
local FG = { { 0, "#00ff88", 1 }, { 0.5, "#ffcc00", 1 }, { 1, "#ff0044", 1 } }

local y = 10
draw = {}
local function item(t) t.x = t.x or 10; t.y = y; table.insert(draw, t); end
local function label(t) t.x = 10; t.y = y; t.size = 10; t.color = C; table.insert(draw, t); end

item({ type = "text", text = "Graph — all modes", size = 13, weight = "bold", color = { { 1, "#ffffff", 1 } } }); y = y + 22

label({ type = "text", text = "Line" }); y = y + 12
item({ type = "graph", x = GX, name = "demo_sine", value = conky_demo_sine, width = GW, height = GH, graph_type = "line", max = 100, fg = FG, grid = true }); y = y + GH + 8

label({ type = "text", text = "Fill" }); y = y + 12
item({ type = "graph", x = GX, name = "demo_ramp", key = "demo_ramp", value = conky_demo_ramp, width = GW, height = GH, graph_type = "fill", max = 100, fg = FG, grid = true }); y = y + GH + 8

label({ type = "text", text = "Line + autoscale" }); y = y + 12
item({ type = "graph", x = GX, name = "demo_random", key = "demo_random", value = conky_demo_random, width = GW, height = GH, graph_type = "line", autoscale = true, fg = FG, grid = true }); y = y + GH + 8

label({ type = "text", text = "Fill + grid" }); y = y + 12
item({ type = "graph", x = GX, name = "demo_sine", value = conky_demo_sine, width = GW, height = GH, graph_type = "fill", max = 100, fg = FG, grid = true, grid_steps = 6 }); y = y + GH + 8
