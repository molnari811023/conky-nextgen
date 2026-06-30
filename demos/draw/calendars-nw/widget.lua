local C = { { 1, "#aaaaaa", 1 } }
local CM = { { 0, "#ffffff", 1 }, { 1, "#bbbbbb", 1 } }
local CD = { { 0, "#ffffff", 1 }, { 1, "#cccccc", 1 } }
local CT = { { 0, "#66ccff", 1 }, { 1, "#3399cc", 1 } }
local CO = { { 0, "#550000", 0.6 }, { 1, "#550000", 0.6 } }

draw = {
	-- Calendar 1: with week numbers
	{ type = "text", text = "Calendar — with week numbers", x = 10, y = 10,
	  size = 13, weight = "bold", color = { { 1, "#ffffff", 1 } } },
	{ type = "calendar", x = 20, y = 36, cell_w = 36, row_h = 22,
	  font = "Sans", size = 12, show_weeknums = true,
	  color_month = CM, color_days = CD, color_today = CT, color_outside = CO },

	-- Calendar 2: without week numbers
	{ type = "text", text = "Calendar — no week numbers", x = 10, y = 230,
	  size = 13, weight = "bold", color = { { 1, "#ffffff", 1 } } },
	{ type = "calendar", x = 20, y = 256, cell_w = 42, row_h = 22,
	  font = "Sans", size = 12, show_weeknums = false,
	  color_month = CM, color_days = CD, color_today = CT, color_outside = CO },
}
