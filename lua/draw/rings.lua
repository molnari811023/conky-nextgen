local RING_DEFAULT = {
	x = 100,
	y = 100,
	radius = 50,
	thickness = 6,
	start_angle = 0,
	end_angle = 360,
	sectors = 6,
	mode = "ring",
	sides = 6,
	max = 100,
	alarm_color = "#FF0000",
	alarm_alpha = 1,
	-- fg, bg: provided by the theme via apply_theme()
}
local function ring_arc_radius(s)
	-- thickness > 2*radius would make the arc radius negative and poison
	-- the cairo context (CAIRO_STATUS_NEGATIVE_COUNT) for the whole frame.
	return math.max(0.5, s.radius - s.thickness / 2)
end
local function ring_auto_compute(s)
	if s.sector_size and s.sector_size > 0 then
		local span = math.abs(s.end_angle - s.start_angle)
		if not (s.sectors and s.sectors > 0) then
			s.sectors = math.max(1, math.floor(span / s.sector_size + 0.5))
		end
		local total_used = s.sectors * s.sector_size
		local remaining = span - total_used
		local gaps = s.sectors
		if span < 360 then
			gaps = s.sectors - 1
		end
		if gaps > 0 then
			s.gap = math.max(0, remaining) / gaps
		else
			s.gap = 0
		end
	else
		s.gap = 0
	end
end
local function get_alarm_color(s)
	return hex_to_rgba(s.alarm_color, s.alarm_alpha)
end
local function move_to_arc_start(cr, cx, cy, r, angle)
	cairo_move_to(cr, cx + r * math.cos(angle), cy + r * math.sin(angle))
end

local function draw_ring_mode(cr, s, dv, ov)
	local rad = math.pi / 180
	local span = math.abs(s.end_angle - s.start_angle)
	local dir = (s.end_angle >= s.start_angle) and 1 or -1
	-- cairo_arc always sweeps in the direction of INCREASING angle; when the
	-- configured span is reversed (end_angle < start_angle) it would draw the
	-- long way around the circle. cairo_arc_negative sweeps the short way.
	local arc_fn = (dir < 0) and cairo_arc_negative or cairo_arc
	local step = span / s.sectors
	local gap = (s.gap or 0) * rad
	local start = s.start_angle * rad
	for i = 1, s.sectors do
		local angle1 = start + dir * (i - 1) * step * rad
		local angle2 = start + dir * i * step * rad - dir * gap
		local t = (i - 1) / s.sectors
		local r, g, b, a = get_color_from_list(s.bg, t)
		cairo_set_source_rgba(cr, r, g, b, a)
		cairo_set_line_width(cr, s.thickness)
		move_to_arc_start(cr, s.x, s.y, ring_arc_radius(s), angle1)
		arc_fn(cr, s.x, s.y, ring_arc_radius(s), angle1, angle2)
		cairo_stroke(cr)
		if i <= dv then
			if ov then
				cairo_set_source_rgba(cr, get_alarm_color(s))
			else
				local r2, g2, b2, a2 = get_color_from_list(s.fg, t)
				cairo_set_source_rgba(cr, r2, g2, b2, a2)
			end
			move_to_arc_start(cr, s.x, s.y, ring_arc_radius(s), angle1)
			arc_fn(cr, s.x, s.y, ring_arc_radius(s), angle1, angle2)
			cairo_stroke(cr)
		end
	end
end
local function draw_smooth_mode(cr, s, pct, ov)
	local rad = math.pi / 180
	local start = s.start_angle * rad
	local endd = s.end_angle * rad
	local frac = pct
	-- see draw_ring_mode: reversed spans must sweep the short way
	local arc_fn = (s.end_angle >= s.start_angle) and cairo_arc or cairo_arc_negative
	local r, g, b, a = get_color_from_list(s.bg, 0)
	cairo_set_source_rgba(cr, r, g, b, a)
	cairo_set_line_width(cr, s.thickness)
	move_to_arc_start(cr, s.x, s.y, ring_arc_radius(s), start)
	arc_fn(cr, s.x, s.y, ring_arc_radius(s), start, endd)
	cairo_stroke(cr)
	if ov then
		cairo_set_source_rgba(cr, get_alarm_color(s))
	else
		local r2, g2, b2, a2 = get_color_from_list(s.fg, frac)
		cairo_set_source_rgba(cr, r2, g2, b2, a2)
	end
	move_to_arc_start(cr, s.x, s.y, ring_arc_radius(s), start)
	arc_fn(cr, s.x, s.y, ring_arc_radius(s), start, start + (endd - start) * frac)
	cairo_stroke(cr)
end
local function ring_slot_center_angle(s, i)
	local rad = math.pi / 180
	local span = math.abs(s.end_angle - s.start_angle)
	local dir = (s.end_angle >= s.start_angle) and 1 or -1
	local step = span / s.sectors
	local start = s.start_angle * rad
	return start + dir * (i - 0.5) * step * rad
end
local function draw_ring_dots(cr, s, dv, ov)
	local r = math.max(1, s.thickness / 2 - 1)
	local rr = ring_arc_radius(s)
	for i = 1, s.sectors do
		local a = ring_slot_center_angle(s, i)
		local cx = s.x + rr * math.cos(a)
		local cy = s.y + rr * math.sin(a)
		local t = (i - 1) / s.sectors
		local r1, g1, b1, a1 = get_color_from_list(s.bg, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
		cairo_fill(cr)
		if i <= dv then
			if ov then
				cairo_set_source_rgba(cr, get_alarm_color(s))
			else
				local r2, g2, b2, a2 = get_color_from_list(s.fg, t)
				cairo_set_source_rgba(cr, r2, g2, b2, a2)
			end
			cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
			cairo_fill(cr)
		end
	end
end
local function draw_ring_polygon(cr, s, dv, ov)
	local rr = ring_arc_radius(s)
	local n = s.sides or 6
	if n < 3 then
		n = 3
	end
	local r = math.max(1, s.thickness / 2 - 1)
	local step_angle = 2 * math.pi / n
	local start_angle = -math.pi / 2
	for i = 1, s.sectors do
		local a = ring_slot_center_angle(s, i)
		local cx = s.x + rr * math.cos(a)
		local cy = s.y + rr * math.sin(a)
		local t = (i - 1) / s.sectors
		local r1, g1, b1, a1 = get_color_from_list(s.bg, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		cairo_move_to(cr, cx + r * math.cos(start_angle), cy + r * math.sin(start_angle))
		for k = 1, n - 1 do
			local aa = start_angle + k * step_angle
			cairo_line_to(cr, cx + r * math.cos(aa), cy + r * math.sin(aa))
		end
		cairo_close_path(cr)
		cairo_fill(cr)
		if i <= dv then
			if ov then
				cairo_set_source_rgba(cr, get_alarm_color(s))
			else
				local r2, g2, b2, a2 = get_color_from_list(s.fg, t)
				cairo_set_source_rgba(cr, r2, g2, b2, a2)
			end
			cairo_move_to(cr, cx + r * math.cos(start_angle), cy + r * math.sin(start_angle))
			for k = 1, n - 1 do
				local aa = start_angle + k * step_angle
				cairo_line_to(cr, cx + r * math.cos(aa), cy + r * math.sin(aa))
			end
			cairo_close_path(cr)
			cairo_fill(cr)
		end
	end
end
function draw_one_ring(cr, s0)
	if not conky_window then
		return
	end

	local s = {}
	for k, v in pairs(RING_DEFAULT) do
		s[k] = v
	end
	for k, v in pairs(s0) do
		s[k] = v
	end
	ring_auto_compute(s)
	if not (s.sectors and s.sectors > 0) then
		s.sectors = 1
	end
	local raw = draw_get_value(s)
	local val = normalize_with_suffix(raw)
	local max = s.max or 100
	local ov = (val > max)
	if max == 0 then
		max = 1
	end
	local pct = math.max(0, math.min(1, val / max))
	local dv = math.floor(pct * s.sectors + 0.5)
	if ov then
		dv = s.sectors
	end
	if s.mode == "smooth" then
		draw_smooth_mode(cr, s, pct, ov)
	elseif s.mode == "dot" then
		draw_ring_dots(cr, s, dv, ov)
	elseif s.mode == "polygon" then
		draw_ring_polygon(cr, s, dv, ov)
	else
		draw_ring_mode(cr, s, dv, ov)
	end
	return { x = s.x - s.radius, y = s.y - s.radius, w = s.radius * 2, h = s.radius * 2 }
end
