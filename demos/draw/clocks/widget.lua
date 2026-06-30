local CX = 200
local BG = { { 0, "#222222", 1 }, { 1, "#000000", 1 } }
local BD = { { 0, "#ffffff", 1 }, { 1, "#888888", 1 } }
local HW = { { 0, "#ffffff", 1 }, { 1, "#ffffff", 1 } }
local SC = { { 0, "#ff0044", 1 }, { 1, "#aa0022", 1 } }
local C = { { 1, "#aaaaaa", 1 } }

draw = {
	{ type = "text", text = "Clock — larger, stacked", x = 10, y = 10,
	  size = 13, weight = "bold", color = { { 1, "#ffffff", 1 } } },

	-- 1: numbers + seconds
	{ type = "text", text = "Numbers + seconds", x = 10, y = 36, size = 10, color = C },
	{ type = "clock", x = CX, y = 100, radius = 55,
	  show_ticks = true, show_numbers = true, show_seconds = true,
	  bg = BG, border = BD,
	  hour_color = HW, minute_color = HW, second_color = SC },

	-- 2: numbers, no seconds
	{ type = "text", text = "Numbers, no seconds", x = 10, y = 200, size = 10, color = C },
	{ type = "clock", x = CX, y = 260, radius = 55,
	  show_ticks = true, show_numbers = true, show_seconds = false,
	  bg = BG, border = BD,
	  hour_color = HW, minute_color = HW, second_color = SC },

	-- 3: no seconds, no numbers
	{ type = "text", text = "No seconds, no numbers", x = 10, y = 360, size = 10, color = C },
	{ type = "clock", x = CX, y = 420, radius = 55,
	  show_ticks = true, show_numbers = false, show_seconds = false,
	  bg = BG, border = BD,
	  hour_color = HW, minute_color = HW, second_color = SC },
}
