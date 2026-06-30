local FG = { { 0, "#00ff88", 1 }, { 1, "#00ff88", 1 } }
local BG = { { 0, "#333333", 1 }, { 1, "#333333", 1 } }

local FG2 = { { 0.0, "#00ff88", 1 }, { 0.5, "#ffcc00", 1 }, { 1.0, "#ff0044", 1 } }
local BG2 = { { 0.0, "#222222", 1 }, { 1.0, "#111111", 1 } }

local C = { { 1, "#aaaaaa", 1 } }

draw = {
	{ type = "text", text = "Ring demo", x = 10, y = 10,
	  size = 13, weight = "bold", color = { { 1, "#ffffff", 1 } } },

	{ type = "text", text = "Smooth", x = 70, y = 100, size = 10, color = C },
	{ type = "ring", name = "time", arg = "%S", x = 100, y = 135,
	  radius = 50, thickness = 10, mode = "smooth", max = 60, bg = BG, fg = FG },

	{ type = "text", text = "Block (6 sectors, auto gap)", x = 220, y = 100, size = 10, color = C },
	{ type = "ring", name = "time", arg = "%S", x = 280, y = 135,
	  radius = 50, thickness = 10, mode = "ring", sectors = 6, sector_size = 55,
	  max = 60, bg = BG2, fg = FG2 },
}
