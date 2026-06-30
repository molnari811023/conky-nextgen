local C = { { 1, "#aaaaaa", 1 } }

draw = {
	{ type = "text", text = "Background — border, square, gradient", x = 10, y = 10,
	  size = 13, weight = "bold", color = { { 1, "#ffffff", 1 } } },

	-- 1: rounded with border
	{ type = "text", text = "Rounded + border", x = 10, y = 36, size = 10, color = C },
	{ type = "background", x = 10, y = 52, w = 300, h = 40, radius = 10,
	  bg = { { 1, "#2a2d30", 1 } },
	  border = { { 1, "#4c4e51", 1 } }, border_width = 2 },

	-- 2: square with border
	{ type = "text", text = "Square + border", x = 10, y = 110, size = 10, color = C },
	{ type = "background", x = 10, y = 126, w = 300, h = 40, radius = 0,
	  bg = { { 1, "#2a2d30", 1 } },
	  border = { { 1, "#66ccff", 1 } }, border_width = 2 },

	-- 3: gradient
	{ type = "text", text = "Gradient fill", x = 10, y = 184, size = 10, color = C },
	{ type = "background", x = 10, y = 200, w = 300, h = 40, radius = 8,
	  bg = { { 0, "#1a2332", 1 }, { 1, "#2a1a2a", 1 } },
	  border = { { 0, "#66ccff", 1 }, { 1, "#ff66aa", 1 } }, border_width = 2 },
}
