--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- draw/calendar.lua — Month calendar grid with week numbers
CALENDAR_DEFAULT = {
	view = nil,
	group = nil,
	click = nil,
	click_view = nil,
	click_toggle = nil,
	hover_view = nil,
	x = 300,
	y = 15,
	cell_w = 40,
	row_h = 30,
	font = "Noto Sans",
	size = 18,
	show_weeknums = true,
	color_month = {
		{ 0.0, "#ffffff", 1 },
		{ 1.0, "#bbbbbb", 1 },
	},
	color_weekdays = {
		{ 0.0, "#dddddd", 1 },
		{ 1.0, "#aaaaaa", 1 },
	},
	color_days = {
		{ 0.0, "#ffffff", 1 },
		{ 1.0, "#cccccc", 1 },
	},
	color_today = {
		{ 0.0, "#66ccff", 1 },
		{ 1.0, "#3399cc", 1 },
	},
	color_outside = {
		{ 0.0, "#550000", 0.7 },
		{ 1.0, "#550000", 0.7 },
	},
	color_weeknums = {
		{ 0.0, "#ffcc66", 1 },
		{ 1.0, "#cc9933", 1 },
	},
}
local function get_calendar_data()
	local now = os.date("*t")
	local y0, mo, today = now.year, now.month, now.day
	local first = os.time({ year = y0, month = mo, day = 1 })
	local wday = tonumber(os.date("%w", first))
	if wday == 0 then
		wday = 7
	end
	wday = wday - 1
	local dim = os.date("*t", os.time({ year = y0, month = mo + 1, day = 0 })).day
	local prev_dim = os.date("*t", os.time({ year = y0, month = mo, day = 0 })).day
	return {
		year = y0,
		month = mo,
		today = today,
		first_wday = wday,
		days_in_month = dim,
		prev_days = prev_dim,
	}
end
function draw_calendar(cr, opts)
	if not conky_window then
		return
	end
	local c = {}
	for k, v in pairs(CALENDAR_DEFAULT) do
		c[k] = v
	end
	for k, v in pairs(opts) do
		c[k] = v
	end
	if not draw_allowed(c.view, c.group) then
		return
	end
	local x, y, cw, rh = c.x, c.y, c.cell_w, c.row_h
	local cd = get_calendar_data()
	local mn = os.date("%Y %B")
	local half_cols = c.show_weeknums and 4 or 3.5
	local center_x = x + cw * half_cols
	draw_text(cr, {
		text = mn,
		x = center_x,
		y = y,
		align = "center",
		font = c.font,
		size = c.size + 8,
		weight = "bold",
		color = c.color_month,
	})
	draw_line_modules(cr, {
		x1 = x,
		y1 = y + rh,
		x2 = x + cw * (c.show_weeknums and 8 or 7),
		y2 = y + rh,
		thickness = 1,
		style_type = "solid",
		fg = c.color_weekdays,
	})
	for i = 0, 6 do
		local wd = os.date("%a", os.time({ year = 2000, month = 1, day = 3 + i }))
		draw_text(cr, {
			text = wd,
			x = x + (c.show_weeknums and cw or 0) + i * cw + cw / 2,
			y = y + rh * 1.8,
			align = "center",
			font = c.font,
			size = c.size,
			color = c.color_weekdays,
		})
	end
	local row = 0
	local col = 0
	for i = 1, cd.first_wday do
		col = col + 1
	end
	local prev_start = cd.prev_days - cd.first_wday + 1
	for i = 1, cd.first_wday do
		local idx = i - 1
		draw_text(cr, {
			text = tostring(prev_start + idx),
			x = x + (c.show_weeknums and cw or 0) + idx * cw + cw / 2,
			y = y + rh * 3,
			align = "center",
			font = c.font,
			size = c.size,
			color = c.color_outside,
		})
	end
	for d = 1, cd.days_in_month do
		if col == 7 then
			col = 0
			row = row + 1
		end
		if c.show_weeknums and col == 0 then
			local tw = os.time({ year = cd.year, month = cd.month, day = d })
			draw_text(cr, {
				text = os.date("%V", tw),
				x = x + cw / 2,
				y = y + rh * (row + 3),
				align = "center",
				font = c.font,
				size = c.size,
				color = c.color_weeknums,
			})
		end
		local colr = (d == cd.today) and c.color_today or c.color_days
		draw_text(cr, {
			text = tostring(d),
			x = x + (c.show_weeknums and cw or 0) + col * cw + cw / 2,
			y = y + rh * (row + 3),
			align = "center",
			font = c.font,
			size = c.size,
			color = colr,
			weight = (d == cd.today) and "bold" or "normal",
		})
		col = col + 1
	end
	local tc, cc, nd = 42, row * 7 + col, 1
	while cc < tc do
		if col == 7 then
			col = 0
			row = row + 1
		end
		draw_text(cr, {
			text = tostring(nd),
			x = x + (c.show_weeknums and cw or 0) + col * cw + cw / 2,
			y = y + rh * (row + 3),
			align = "center",
			font = c.font,
			size = c.size,
			color = c.color_outside,
		})
		nd = nd + 1
		col = col + 1
		cc = cc + 1
	end
	return { x = c.x, y = c.y, w = (c.show_weeknums and c.cell_w or 0) + 7 * c.cell_w, h = c.row_h * 8 }
end

