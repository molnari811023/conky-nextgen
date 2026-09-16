--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/draw/calendar.lua — Draws a clickable, navigable monthly calendar grid

The calendar is computed from Lua's os.date at draw time. Today's date is
highlighted. The month/year title is split into two clickable halves: the
left opens a 4×4 year popup, the right a 3×4 month popup (both tiled on the
whole window). Day cells are clickable (selects the date), a separator line
with week numbers and weekday headers are drawn like the original calendar.
Clicks that hit no calendar element fall through to the widget's global
click handler (e.g. back to the clock view).

**Exposed/global functions:**
- `draw_calendar(cr, opts)` — Draws the calendar and returns `{x, y, w, h}`.

**Config/globals used:**
- `conky_window` — checked for early-exit guard; popups tile its size.
- `draw_text()` — renders all text elements.
- `draw_line_modules()` — draws the separator line beneath the month title.
- `register_clickable_area()` / `clear_clickable_areas()` — Cairo-free click areas.
]]--

CALENDAR_DEFAULT = {
	x = 300,
	y = 15,
	cell_w = 40,
	row_h = 30,
	font = "Noto Sans",
	size = 18,
	show_weeknums = true,
	weeknum_size = 16,
	popup_size = 17,
	-- color_month, color_weekdays, color_days, color_today,
	-- color_outside, color_weeknums: provided by the theme via apply_theme()
	color_popup = { { 1, "#a9b1d6", 1 } },
}

-- navigation state (module-level, shared by all calendar instances of the widget)
local nav_y = os.date("*t").year
local nav_m = os.date("*t").month
local popup = nil
local year_base = nav_y

local ext_box = cairo_text_extents_t:create()

local function measure_text(cr, font, size, weight, txt)
	cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL, (weight == "bold") and CAIRO_FONT_WEIGHT_BOLD or CAIRO_FONT_WEIGHT_NORMAL)
	cairo_set_font_size(cr, size)
	cairo_text_extents(cr, txt, ext_box)
	return ext_box.width
end

local function get_calendar_data()
	local today = os.date("*t").day
	local y0, mo = nav_y, nav_m
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

	-- drop stale areas from previous frames / other views
	clear_clickable_areas()

	local x, y, cw, rh = c.x, c.y, c.cell_w, c.row_h
	local cd = get_calendar_data()
	local mn = os.date("%Y %B", os.time({ year = nav_y, month = nav_m, day = 1 }))
	local half_cols = c.show_weeknums and 4 or 3.5
	local center_x = x + cw * half_cols
	local weekcol = c.show_weeknums and cw or 0

	local function reg(xp, yp, wp, hp, action)
		register_clickable_area(xp, yp, wp, hp, action)
	end

	-- month/year title: clickable halves (left = year popup, right = month popup)
	local tw = measure_text(cr, c.font, c.size + 8, "bold", mn)
	local title_top = y - 16
	reg(center_x - tw / 2, title_top, tw / 2, 26, function() popup = "year"; year_base = nav_y end)
	reg(center_x, title_top, tw / 2, 26, function() popup = "month" end)

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

	-- weekday headers hidden while a popup covers the grid
	if not popup then
		for i = 0, 6 do
			local wd = os.date("%a", os.time({ year = 2000, month = 1, day = 3 + i }))
			draw_text(cr, {
				text = wd,
				x = x + weekcol + i * cw + cw / 2,
				y = y + rh * 1.8,
				align = "center",
				font = c.font,
				size = c.size,
				color = c.color_weekdays,
			})
		end
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

	if popup == "month" or popup == "year" then
		-- full-window popup grid: month = 3×4, year = 4×4, items centred on slots
		local win_w = conky_window.width
		local win_h = conky_window.height
		local coln = (popup == "month") and 3 or 4
		local slotw = win_w / coln
		local pop_top = y + rh * 1.2
		local sloth = (win_h - pop_top) / 4
		for row = 0, 3 do
			for col = 0, coln - 1 do
				local label
				local action
				if popup == "month" then
					local i = row * coln + col + 1
					label = os.date("%b", os.time({ year = 2000, month = i, day = 1 }))
					action = function()
						nav_m = i
						popup = nil
					end
				else
					local yr = year_base - 7 + row * 4 + col
					label = tostring(yr)
					action = function()
						nav_y = yr
						popup = nil
					end
				end
				draw_text(cr, {
					text = label,
					x = slotw * col + slotw / 2,
					y = pop_top + sloth * row + sloth / 2,
					align = "center",
					font = c.font,
					size = c.popup_size,
					color = c.color_popup,
				})
				reg(slotw * col, pop_top + sloth * row, slotw, sloth, action)
			end
		end
	else
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
					size = c.weeknum_size,
					color = c.color_weeknums,
				})
			end
			local tdate = os.date("*t")
			local is_today = inside and yw == tdate.year and mw == tdate.month and dw == tdate.day
			local colr = is_today and c.color_today or (inside and c.color_days or c.color_outside)
			local weight = is_today and "bold" or "normal"
			draw_text(cr, {
				text = tostring(dw),
				x = x + weekcol + col * cw + cw / 2,
				y = y + rh * (row + 3),
				align = "center",
				font = c.font,
				size = c.size,
				color = colr,
				weight = weight,
			})
			reg(x + weekcol + col * cw, y + rh * (row + 3), cw, rh, function()
				nav_y = yw
				nav_m = mw
				popup = nil
			end)
		end
	end

	return { x = c.x, y = c.y, w = (c.show_weeknums and c.cell_w or 0) + 7 * c.cell_w, h = c.row_h * 8 }
end