local C = { { 1, "#aaaaaa", 1 } }

local y = 10
draw = {}
local function item(t) t.x = t.x or 10; t.y = y; table.insert(draw, t); end
local function label(t) t.x = 10; t.y = y; t.size = 10; t.color = C; table.insert(draw, t); end

item({ type = "text", text = "Text — alignment & font variants", size = 13, weight = "bold", color = { { 1, "#ffffff", 1 } } }); y = y + 26

label({ type = "text", text = "Left align (Sans 14)" }); y = y + 16
item({ type = "text", text = "Left aligned text", font = "Sans", size = 14, align = "left", color = { { 1, "#ffffff", 1 } } }); y = y + 24

label({ type = "text", text = "Center align (Sans 14)" }); y = y + 16
item({ type = "text", text = "Centered text", x = "center", font = "Sans", size = 14, align = "center", color = { { 1, "#ffffff", 1 } } }); y = y + 24

label({ type = "text", text = "Right align (Sans 14)" }); y = y + 16
item({ type = "text", text = "Right aligned text", x = 350, font = "Sans", size = 14, align = "right", color = { { 1, "#ffffff", 1 } } }); y = y + 24

label({ type = "text", text = "Bold Monospace 16" }); y = y + 16
item({ type = "text", text = "Bold Monospace", font = "Monospace", size = 16, weight = "bold", color = { { 1, "#00ff88", 1 } } }); y = y + 28

label({ type = "text", text = "Italic Serif 15" }); y = y + 16
item({ type = "text", text = "Italic Serif", font = "Serif", size = 15, slant = "italic", color = { { 1, "#ffcc00", 1 } } }); y = y + 28

label({ type = "text", text = "Wrap width 200 (Sans 12)" }); y = y + 16
item({ type = "text", text = "This is a long sentence that wraps at two hundred pixels width to show text wrapping", font = "Sans", size = 12, wrap_width = 200, color = { { 1, "#88ccff", 1 } } }); y = y + 24
