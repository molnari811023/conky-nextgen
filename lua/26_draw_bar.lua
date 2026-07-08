--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 26_draw_bar.lua — Progress bars: smooth or block style, gradient colors
BAR_DEFAULT = {
	draw_me = true,
	view = nil,
	group = nil,
	click = nil,
	click_view = nil,
	click_toggle = nil,
	x = 0,
	width = 100,
	height = 10,
	max = 100,
	angle = 0,
	bg = {
		{ 0.0, "#333333", 1 },
		{ 1.0, "#111111", 1 },
	},
	fg = {
		{ 0.0, "#00FF00", 1 },
		{ 1.0, "#009900", 1 },
	},
}

function draw_bar_block(cr, m, y, pct)
	local c, h, w = m.blocks, m.height, m.width
	if c < 2 then
		return h + 4
	end
	local bw = h
	local gap = (w - c * bw) / (c - 1)
	local f = math.floor(c * pct)
	for i = 1, c do
		local bx = m.x + (i - 1) * (bw + gap)
		local t = i / c
		local r1, g1, b1, a1 = get_color_from_list(m.bg, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		cairo_rectangle(cr, bx, y, bw, h)
		cairo_fill(cr)
		if i <= f then
			local r2, g2, b2, a2 = get_color_from_list(m.fg, t)
			cairo_set_source_rgba(cr, r2, g2, b2, a2)
			cairo_rectangle(cr, bx, y, bw, h)
			cairo_fill(cr)
		end
	end
	return h + 4
end

function draw_bar_polygon(cr, m, y, pct)
	local c, h, w, n = m.blocks, m.height, m.width, m.sides
	if c < 2 then
		return h + 4
	end
	local bw = h
	local gap = (w - c * bw) / (c - 1)
	local f = math.floor(c * pct)
	local r = h / 2
	local step_angle = 2 * math.pi / n
	local start_angle = -math.pi / 2
	local cx0 = m.x + bw / 2
	for i = 1, c do
		local cx = cx0 + (i - 1) * (bw + gap)
		local cy = y + h / 2
		local t = i / c
		local r1, g1, b1, a1 = get_color_from_list(m.bg, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		cairo_move_to(cr, cx + r * math.cos(start_angle), cy + r * math.sin(start_angle))
		for k = 1, n - 1 do
			local a = start_angle + k * step_angle
			cairo_line_to(cr, cx + r * math.cos(a), cy + r * math.sin(a))
		end
		cairo_close_path(cr)
		cairo_fill(cr)
		if i <= f then
			local r2, g2, b2, a2 = get_color_from_list(m.fg, t)
			cairo_set_source_rgba(cr, r2, g2, b2, a2)
			cairo_move_to(cr, cx + r * math.cos(start_angle), cy + r * math.sin(start_angle))
			for k = 1, n - 1 do
				local a = start_angle + k * step_angle
				cairo_line_to(cr, cx + r * math.cos(a), cy + r * math.sin(a))
			end
			cairo_close_path(cr)
			cairo_fill(cr)
		end
	end
	return h + 4
end

function draw_bar_dots(cr, m, y, pct)
	local c, h, w = m.blocks, m.height, m.width
	if c < 2 then
		return h + 4
	end
	local bw = h
	local gap = (w - c * bw) / (c - 1)
	local f = math.floor(c * pct)
	local r = h / 2 - 1
	for i = 1, c do
		local cx = m.x + (i - 1) * (bw + gap) + bw / 2
		local cy = y + h / 2
		local t = i / c
		local r1, g1, b1, a1 = get_color_from_list(m.bg, t)
		cairo_set_source_rgba(cr, r1, g1, b1, a1)
		cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
		cairo_fill(cr)
		if i <= f then
			local r2, g2, b2, a2 = get_color_from_list(m.fg, t)
			cairo_set_source_rgba(cr, r2, g2, b2, a2)
			cairo_arc(cr, cx, cy, r, 0, 2 * math.pi)
			cairo_fill(cr)
		end
	end
	return h + 4
end

function draw_bar_smooth(cr, m, y, pct)
	for i = 0, m.width - 1 do
		local t = i / m.width
		local r, g, b, a = get_color_from_list(m.bg, t)
		cairo_set_source_rgba(cr, r, g, b, a)
		cairo_rectangle(cr, m.x + i, y, 1, m.height)
		cairo_fill(cr)
	end
	local f = m.width * pct
	for i = 0, f - 1 do
		local t = i / m.width
		local r, g, b, a = get_color_from_list(m.fg, t)
		cairo_set_source_rgba(cr, r, g, b, a)
		cairo_rectangle(cr, m.x + i, y, 1, m.height)
		cairo_fill(cr)
	end
	return m.height + 4
end

function draw_bar_modules(cr, m, y)
	if not conky_window then
		return
	end
	for k, v in pairs(BAR_DEFAULT) do
		if m[k] == nil then
			m[k] = v
		end
	end
	if not draw_allowed(m.draw_me, m.view, m.group) then
		return
	end
	if m.style then
		for k, v in pairs(m.style) do
			m[k] = v
		end
	end
	local raw = draw_get_value(m)
	local val = normalize_with_suffix(raw)
	local pct = math.max(0, math.min(1, val / m.max))
	local a = m.angle or 0
	local mx = cairo_matrix_t:create()
	cairo_get_matrix(cr, mx)
	if a ~= 0 then
		local cx = m.x + m.width / 2
		local cy = y + m.height / 2
		cairo_translate(cr, cx, cy)
		cairo_rotate(cr, math.rad(a))
		cairo_translate(cr, -cx, -cy)
	end
	local used
	if m.blocks ~= nil then
		if m.mode == "dot" then
			used = draw_bar_dots(cr, m, y, pct)
		elseif m.sides and m.sides >= 3 then
			used = draw_bar_polygon(cr, m, y, pct)
		else
			used = draw_bar_block(cr, m, y, pct)
		end
	else
		used = draw_bar_smooth(cr, m, y, pct)
	end
	cairo_set_matrix(cr, mx)
	return { x = m.x, y = y, w = m.width, h = m.height }
end

