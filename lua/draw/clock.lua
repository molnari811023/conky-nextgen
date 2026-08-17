--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- draw/clock.lua — Analog clock face with hands, ticks, numbers
-- draw_clock(cr, opts) → { x, y, w, h }
--     Draw an analog clock at (x, y) with a configurable radius: minute
--     and hour ticks, numbers around the rim, and hour/minute/second
--     hands plus a center dot. Options toggle ticks/numbers/seconds.
--     Returns the clock's bounding box.
--
-- Parameters:
--   x, y, radius
--   show_ticks, show_numbers, show_seconds
--   tick_width_hour, tick_width_minute, number_size, number_radius
--   hour_hand_width, minute_hand_width, second_hand_width, center_radius
--   bg, border, tick_color, number_color, hour_color, minute_color, second_color, center_color
--
-- Example:
--   draw[#draw+1] = {
--       type = "clock",
--       x = 160, y = 50, radius = 40,
--       show_seconds = true,
--   }

-- Pre-allocated Cairo struct (reused every tick to avoid binding leak)
--}}}

local _clock_ext = cairo_text_extents_t:create()

local CLOCK_DEFAULT = {
	x = 100,
	y = 100,
	radius = 50,
	show_ticks = true,
	show_numbers = true,
	show_seconds = true,
	tick_width_hour = 3,
	tick_width_minute = 1,
	number_size = 14,
	number_radius = 0.75,
	hour_hand_width = 4,
	minute_hand_width = 3,
	second_hand_width = 1,
	center_radius = 4,
	-- bg, border, tick/number/hand colors: provided by the theme via apply_theme()
}
function draw_clock(cr, o)
	if not conky_window then
		return
	end
	local c = {}
	for k, v in pairs(o) do
		c[k] = v
	end
	for k, v in pairs(CLOCK_DEFAULT) do
		if c[k] == nil then
			c[k] = v
		end
	end
	local x, y, r = c.x, c.y, tonumber(c.radius) or 0
	-- Negative/zero radius would poison the cairo context (NEGATIVE_COUNT)
	r = math.max(1, r)
	c.center_radius = math.max(0.5, tonumber(c.center_radius) or 0)
	local h = tonumber(os.date("%I"))
	local m = tonumber(os.date("%M"))
	local s = tonumber(os.date("%S"))
	local sa = (s / 60) * 2 * math.pi
	local ma = (m / 60) * 2 * math.pi
	local ha = ((h % 12) / 12 + m / 720) * 2 * math.pi
	for i = 0, 360, 6 do
		local t = i / 360
		local r1, g1, b1, a1 = get_color_from_list(c.bg, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		local start_a = math.rad(i)
		local end_a = math.rad(i + 6)
		cairo_move_to(cr, x, y)
		cairo_arc(cr, x, y, r, start_a, end_a)
		cairo_fill(cr)
	end
	for i = 0, 360, 6 do
		local t = i / 360
		local r1, g1, b1, a1 = get_color_from_list(c.border, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		local start_a = math.rad(i) - math.pi / 2
		local end_a = math.rad(i + 6) - math.pi / 2
		cairo_set_line_width(cr, 2)
		cairo_arc(cr, x, y, r, start_a, end_a)
		cairo_stroke(cr)
	end
	if c.show_ticks then
		for i = 0, 59 do
			local ang = (i / 60) * 2 * math.pi
			local sin_a = math.sin(ang)
			local cos_a = math.cos(ang)
			local is_hour = (i % 5 == 0)
			local tl = is_hour and 10 or 5
			local tw = is_hour and c.tick_width_hour or c.tick_width_minute
			local t = i / 60
			local r1, g1, b1, a1 = get_color_from_list(c.tick_color, t)
			cairo_set_source_rgba(cr, r1, g1, b1, a1)
			cairo_set_line_width(cr, tw)
			local x1 = x + sin_a * (r - tl)
			local y1 = y - cos_a * (r - tl)
			local x2 = x + sin_a * r
			local y2 = y - cos_a * r
			cairo_move_to(cr, x1, y1)
			cairo_line_to(cr, x2, y2)
			cairo_stroke(cr)
		end
	end
	if c.show_numbers then
		cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
		cairo_set_font_size(cr, c.number_size)
		for i = 1, 12 do
			local ang = (i / 12) * 2 * math.pi
			local sa = math.sin(ang)
			local ca = math.cos(ang)
			local nx = x + sa * (r * c.number_radius)
			local ny = y - ca * (r * c.number_radius)
			local t = i / 12
			local r1, g1, b1, a1 = get_color_from_list(c.number_color, t)
			cairo_set_source_rgba(cr, r1, g1, b1, a1)
			local txt = tostring(i)
			local ext = _clock_ext
			cairo_text_extents(cr, txt, ext)
			cairo_move_to(cr, nx - ext.width / 2, ny + ext.height / 2)
			cairo_show_text(cr, txt)
		end
	end
	local function hand(a, len, th, col)
		cairo_set_line_width(cr, th)
		local t = a / (2 * math.pi)
		local r1, g1, b1, a1 = get_color_from_list(col, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		local ex = x + math.sin(a) * len
		local ey = y - math.cos(a) * len
		cairo_move_to(cr, x, y)
		cairo_line_to(cr, ex, ey)
		cairo_stroke(cr)
	end
	hand(ha, r * 0.5, c.hour_hand_width, c.hour_color)
	hand(ma, r * 0.75, c.minute_hand_width, c.minute_color)
	if c.show_seconds then
		hand(sa, r * 0.9, c.second_hand_width, c.second_color)
	end
	local r1, g1, b1, a1 = get_color_from_list(c.center_color, 0.5)
	cairo_set_source_rgba(cr, r1, g1, b1, a1)
	cairo_arc(cr, x, y, c.center_radius, 0, 2 * math.pi)
	cairo_fill(cr)
	return { x = x - r, y = y - r, w = r * 2, h = r * 2 }
end
