-- BARS
--{{{
BAR_DEFAULT = {
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
	if not draw_allowed(m.draw_me) or not conky_window then
		return 0
	end
	for k, v in pairs(BAR_DEFAULT) do
		if m[k] == nil then
			m[k] = v
		end
	end
	if m.style then
		for k, v in pairs(m.style) do
			m[k] = v
		end
	end
	local raw = conky_parse("${" .. m.name .. (m.arg and " " .. m.arg or "") .. "}")
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
		used = draw_bar_block(cr, m, y, pct)
	else
		used = draw_bar_smooth(cr, m, y, pct)
	end
	cairo_set_matrix(cr, mx)
	return used
end

--}}}
