--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 29_draw_rings.lua — Ring gauges: segmented or smooth arc mode
local RING_DEFAULT = {
	x = 100,
	y = 100,
	radius = 50,
	thickness = 6,
	start_angle = 0,
	end_angle = 360,
	sectors = 6,
	mode = "ring",
	max = 100,
	alarm_color = 0xFF0000,
	alarm_alpha = 1,
	bg = {
		{ 0.0, "#333333", 1 },
		{ 1.0, "#111111", 1 },
	},
	fg = {
		{ 0.0, "#00FFAA", 1 },
		{ 1.0, "#008866", 1 },
	},
}
local function ring_auto_compute(s)
	if s.sector_size and s.sector_size > 0 and s.sectors then
		local span = math.abs(s.end_angle - s.start_angle)
		local sector_angle = s.sector_size
		local total_used = s.sectors * sector_angle
		local remaining = span - total_used
		if remaining > 0 then
			s.gap = remaining / s.sectors
		else
			s.gap = 0
		end
	elseif s.sector_size and s.sector_size > 0 then
		local span = math.abs(s.end_angle - s.start_angle)
		s.sectors = math.max(1, math.floor(span / s.sector_size + 0.5))
	end
end
local function get_alarm_color(s)
	return hex_to_rgba(s.alarm_color, s.alarm_alpha)
end
local function draw_ring_mode(cr, s, dv, ov)
	local rad = math.pi / 180
	local span = s.end_angle - s.start_angle
	local step = span / s.sectors
	local gap = (s.gap or 0) * rad
	local start = s.start_angle * rad
	for i = 1, s.sectors do
		local angle1 = start + (i - 1) * step * rad
		local angle2 = start + i * step * rad - gap
		local t = (i - 1) / s.sectors
		local r, g, b, a = get_color_from_list(s.bg, t)
		cairo_set_source_rgba(cr, r, g, b, a)
		cairo_set_line_width(cr, s.thickness)
		cairo_arc(cr, s.x, s.y, s.radius - s.thickness / 2, angle1, angle2)
		cairo_stroke(cr)
		if i <= dv then
			if ov then
				cairo_set_source_rgba(cr, get_alarm_color(s))
			else
				local r2, g2, b2, a2 = get_color_from_list(s.fg, t)
				cairo_set_source_rgba(cr, r2, g2, b2, a2)
			end
			cairo_arc(cr, s.x, s.y, s.radius - s.thickness / 2, angle1, angle2)
			cairo_stroke(cr)
		end
	end
end
local function draw_ring_polygon(cr, s, dv, ov)
	local rad = math.pi / 180
	local span = s.end_angle - s.start_angle
	local step = span / s.sectors
	local gap = (s.gap or 0) * rad
	local start = s.start_angle * rad
	local inner_r = s.radius - s.thickness / 2
	local outer_r = s.radius + s.thickness / 2
	local n = s.sides
	for i = 1, s.sectors do
		local angle1 = start + (i - 1) * step * rad
		local angle2 = start + i * step * rad - gap
		local t = (i - 1) / s.sectors
		local r1, g1, b1, a1 = get_color_from_list(s.bg, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		cairo_move_to(cr, s.x + inner_r * math.cos(angle1), s.y + inner_r * math.sin(angle1))
		for j = 1, n - 1 do
			local seg_t = j / n
			local a = angle1 + seg_t * (angle2 - angle1)
			local rr = (j % 2 == 1) and outer_r or inner_r
			cairo_line_to(cr, s.x + rr * math.cos(a), s.y + rr * math.sin(a))
		end
		cairo_line_to(cr, s.x + inner_r * math.cos(angle2), s.y + inner_r * math.sin(angle2))
		cairo_close_path(cr)
		cairo_fill(cr)
		if i <= dv then
			if ov then
				cairo_set_source_rgba(cr, get_alarm_color(s))
			else
				local r2, g2, b2, a2 = get_color_from_list(s.fg, t)
				cairo_set_source_rgba(cr, r2, g2, b2, a2)
			end
			cairo_move_to(cr, s.x + inner_r * math.cos(angle1), s.y + inner_r * math.sin(angle1))
			for j = 1, n - 1 do
				local seg_t = j / n
				local a = angle1 + seg_t * (angle2 - angle1)
				local rr = (j % 2 == 1) and outer_r or inner_r
				cairo_line_to(cr, s.x + rr * math.cos(a), s.y + rr * math.sin(a))
			end
			cairo_line_to(cr, s.x + inner_r * math.cos(angle2), s.y + inner_r * math.sin(angle2))
			cairo_close_path(cr)
			cairo_fill(cr)
		end
	end
end

local function draw_ring_dots(cr, s, dv, ov)
	local rad = math.pi / 180
	local span = s.end_angle - s.start_angle
	local step = span / s.sectors
	local start = s.start_angle * rad
	local dot_r = math.max(1, s.thickness / 2 - 1)
	local ring_r = s.radius - s.thickness / 2
	for i = 1, s.sectors do
		local angle1 = start + (i - 1) * step * rad
		local mid = angle1 + step * rad / 2
		local cx = s.x + ring_r * math.cos(mid)
		local cy = s.y + ring_r * math.sin(mid)
		local t = (i - 1) / s.sectors
		local r1, g1, b1, a1 = get_color_from_list(s.bg, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		cairo_arc(cr, cx, cy, dot_r, 0, 2 * math.pi)
		cairo_fill(cr)
		if i <= dv then
			if ov then
				cairo_set_source_rgba(cr, get_alarm_color(s))
			else
				local r2, g2, b2, a2 = get_color_from_list(s.fg, t)
				cairo_set_source_rgba(cr, r2, g2, b2, a2)
			end
			cairo_arc(cr, cx, cy, dot_r, 0, 2 * math.pi)
			cairo_fill(cr)
		end
	end
end

local function draw_smooth_mode(cr, s, dv, ov)
	local rad = math.pi / 180
	local start = s.start_angle * rad
	local endd = s.end_angle * rad
	local frac = dv / s.sectors
	local r, g, b, a = get_color_from_list(s.bg, 0)
	cairo_set_source_rgba(cr, r, g, b, a)
	cairo_set_line_width(cr, s.thickness)
	cairo_arc(cr, s.x, s.y, s.radius - s.thickness / 2, start, endd)
	cairo_stroke(cr)
	if ov then
		cairo_set_source_rgba(cr, get_alarm_color(s))
	else
		local r2, g2, b2, a2 = get_color_from_list(s.fg, frac)
		cairo_set_source_rgba(cr, r2, g2, b2, a2)
	end
	cairo_arc(cr, s.x, s.y, s.radius - s.thickness / 2, start, start + (endd - start) * frac)
	cairo_stroke(cr)
end
function draw_one_ring(cr, s0)
	if not draw_allowed(s0.draw_me) then
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
	s.sectors = s.sectors or 1
	local raw = conky_parse("${" .. s.name .. (s.arg and " " .. s.arg or "") .. "}")
	local val = tonumber(raw) or 0
	local max = s.max or 100
	local ov = (val > max)
	local pct = math.max(0, math.min(1, val / max))
	local dv = math.floor(pct * s.sectors + 0.5)
	if ov then
		dv = s.sectors
	end
	if s.mode == "smooth" then
		draw_smooth_mode(cr, s, dv, ov)
	elseif s.mode == "dot" then
		draw_ring_dots(cr, s, dv, ov)
	elseif s.sides and s.sides >= 3 then
		draw_ring_polygon(cr, s, dv, ov)
	else
		draw_ring_mode(cr, s, dv, ov)
	end
end

--}}}
