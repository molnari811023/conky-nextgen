--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/draw/calendar.lua — Draws a monthly calendar grid with weekday headers and week numbers

The calendar is computed entirely from Lua's os.date at draw time, so it
always reflects the current month. Today's date is highlighted.
]]--

--{{{
-- ## Calendar
--
-- Renders a full monthly calendar: a centred month/year title, abbreviated
-- weekday headers, an optional ISO week-number column, and a 6×7 grid of day
-- cells. Days outside the current month are drawn in a muted colour; today is
-- bold and highlighted.
--
-- **Exposed/global functions:**
-- - `draw_calendar(cr, opts)` — Draws a monthly calendar grid and returns `{x, y, w, h}`.
--
-- **Config/globals used:**
-- - `conky_window` — checked for early-exit guard.
-- - `draw_text()` — renders all text elements (title, weekdays, day numbers, week numbers).
-- - `draw_line_modules()` — draws the separator line beneath the month title.
--}}}

CALENDAR_DEFAULT = {
	x = 300,
	y = 15,
	cell_w = 40,
	row_h = 30,
	font = "Noto Sans",
	size = 18,
	show_weeknums = true,
	-- color_month, color_weekdays, color_days, color_today,
	-- color_outside, color_weeknums: provided by the theme via apply_theme()
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
	local function cell_date(i)
		-- Grid cell 0 = the Monday of the week that contains day 1.
		-- Returns { year, month, day, inside } for the date in cell i.
		local offset = i - cd.first_wday + 1
		local year, month, day, inside
		if offset < 1 then
			inside = false
			day = cd.prev_days + offset
			month = cd.month - 1
			year = cd.year
			if month == 0 then
				month = 12
				year = year - 1
			end
		elseif offset > cd.days_in_month then
			inside = false
			day = offset - cd.days_in_month
			month = cd.month + 1
			year = cd.year
			if month == 13 then
				month = 1
				year = year + 1
			end
		else
			inside = true
			day = offset
			month = cd.month
			year = cd.year
		end
		return year, month, day, inside
	end
	for i = 0, 41 do
		local row = math.floor(i / 7)
		local col = i % 7
		local yw, mw, dw, inside = cell_date(i)
		if c.show_weeknums and col == 0 then
			-- Week number of the row = ISO week of its Monday (cell date),
			-- so partial first/last rows get one too.
			draw_text(cr, {
				text = os.date("%V", os.time({ year = yw, month = mw, day = dw })),
				x = x + cw / 2,
				y = y + rh * (row + 3),
				align = "center",
				font = c.font,
				size = c.size,
				color = c.color_weeknums,
			})
		end
		local colr = (inside and dw == cd.today) and c.color_today or (inside and c.color_days or c.color_outside)
		local weight = (inside and dw == cd.today) and "bold" or "normal"
		draw_text(cr, {
			text = tostring(dw),
			x = x + (c.show_weeknums and cw or 0) + col * cw + cw / 2,
			y = y + rh * (row + 3),
			align = "center",
			font = c.font,
			size = c.size,
			color = colr,
			weight = weight,
		})
	end
	return { x = c.x, y = c.y, w = (c.show_weeknums and c.cell_w or 0) + 7 * c.cell_w, h = c.row_h * 8 }
end
