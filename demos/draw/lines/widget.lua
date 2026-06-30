local C = { { 1, "#aaaaaa", 1 } }

local y = 10
draw = {}
local function item(t) t.x = t.x or 10; t.y = y; table.insert(draw, t); end
local function label(t) t.x = 10; t.y = y; t.size = 10; t.color = C; table.insert(draw, t); end

item({ type = "text", text = "Lines — style variants", size = 13, weight = "bold", color = { { 1, "#ffffff", 1 } } }); y = y + 26

label({ type = "text", text = "Solid" }); y = y + 16
item({ type = "line", x1 = 10, y1 = y + 2, x2 = 300, y2 = y + 2, thickness = 3, style_type = "solid", fg = { { 0, "#66ccff", 1 }, { 1, "#3399cc", 1 } } }); y = y + 24

label({ type = "text", text = "Dashed" }); y = y + 16
item({ type = "line", x1 = 10, y1 = y + 2, x2 = 300, y2 = y + 2, thickness = 3, style_type = "dashed", fg = { { 0, "#ffcc00", 1 }, { 1, "#ff8800", 1 } } }); y = y + 24

label({ type = "text", text = "Dotted" }); y = y + 16
item({ type = "line", x1 = 10, y1 = y + 2, x2 = 300, y2 = y + 2, thickness = 3, style_type = "dotted", fg = { { 0, "#00ff88", 1 }, { 1, "#00aa55", 1 } } }); y = y + 24

label({ type = "text", text = "Thick + angle" }); y = y + 16
item({ type = "line", x1 = 10, y1 = y + 2, x2 = 100, y2 = y + 2, thickness = 6, style_type = "solid", angle = 45, fg = { { 0, "#ff66aa", 1 }, { 1, "#cc3388", 1 } } }); y = y + 24
