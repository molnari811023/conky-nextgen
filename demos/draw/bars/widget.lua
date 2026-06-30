local L = 10
local BX = 10
local BW = 340
local BH = 18
local G = 30
local C = { { 1, "#aaaaaa", 1 } }
local FG = { { 0, "#00ff88", 1 }, { 0.5, "#ffcc00", 1 }, { 1, "#ff0044", 1 } }

local y = 10
draw = {}
local function item(t) t.x = t.x or L; t.y = y; table.insert(draw, t); end
local function label(t) t.x = L; t.y = y; t.size = 10; t.color = C; table.insert(draw, t); end

item({ type = "text", text = "Bar — all modes", size = 13, weight = "bold", color = { { 1, "#ffffff", 1 } } }); y = y + 22

label({ type = "text", text = "Smooth" }); y = y + 14
item({ type = "bar", x = BX, name = "demo_sine", value = conky_demo_sine, width = BW, height = BH, max = 100, fg = FG }); y = y + G

label({ type = "text", text = "Block (12 blocks)" }); y = y + 14
item({ type = "bar", x = BX, name = "demo_sine", value = conky_demo_sine, width = BW, height = BH, blocks = 12, max = 100, fg = FG }); y = y + G

label({ type = "text", text = "Dot (15 blocks)" }); y = y + 14
item({ type = "bar", x = BX, name = "demo_sine", value = conky_demo_sine, width = BW, height = BH, blocks = 15, mode = "dot", max = 100, fg = FG }); y = y + G

label({ type = "text", text = "Triangle (sides=3)" }); y = y + 14
item({ type = "bar", x = BX, name = "demo_sine", value = conky_demo_sine, width = BW, height = BH, blocks = 12, sides = 3, max = 100, fg = FG }); y = y + G

label({ type = "text", text = "Square (sides=4)" }); y = y + 14
item({ type = "bar", x = BX, name = "demo_sine", value = conky_demo_sine, width = BW, height = BH, blocks = 12, sides = 4, max = 100, fg = FG }); y = y + G

label({ type = "text", text = "Pentagon (sides=5)" }); y = y + 14
item({ type = "bar", x = BX, name = "demo_sine", value = conky_demo_sine, width = BW, height = BH, blocks = 12, sides = 5, max = 100, fg = FG }); y = y + G

label({ type = "text", text = "Hexagon (sides=6)" }); y = y + 14
item({ type = "bar", x = BX, name = "demo_sine", value = conky_demo_sine, width = BW, height = BH, blocks = 12, sides = 6, max = 100, fg = FG }); y = y + G

label({ type = "text", text = "Octagon (sides=8)" }); y = y + 14
item({ type = "bar", x = BX, name = "demo_sine", value = conky_demo_sine, width = BW, height = BH, blocks = 12, sides = 8, max = 100, fg = FG }); y = y + G
