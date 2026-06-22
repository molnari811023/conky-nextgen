-- LINES
--{{{
local LINE_DEFAULT = {
	x1 = 0,
	y1 = 0,
	x2 = 100,
	y2 = 0,
	thickness = 2,
	angle = 0,
	style_type = "solid",
	dash_on = 4,
	dash_off = 4,
	dot_on = 1,
	dot_off = 3,
	fg = {
		{ 0.0, 0xFFFFFF, 1 },
		{ 1.0, 0xAAAAAA, 1 },
	},
}
function draw_line_modules(cr, m)
	if not draw_allowed(m.draw_me) or not conky_window then
		return
	end
	local cfg = {}
	for k, v in pairs(LINE_DEFAULT) do
		cfg[k] = v
	end
	for k, v in pairs(m) do
		cfg[k] = v
	end
	if type(cfg.fg) ~= "table" or #cfg.fg == 0 then
		cfg.fg = LINE_DEFAULT.fg
	end
	local x1, y1 = cfg.x1, cfg.y1
	local x2, y2 = cfg.x2, cfg.y2
	local mx = cairo_matrix_t:create()
	cairo_get_matrix(cr, mx)
	if cfg.angle ~= 0 then
		local cx = (x1 + x2) / 2
		local cy = (y1 + y2) / 2
		cairo_translate(cr, cx, cy)
		cairo_rotate(cr, math.rad(cfg.angle))
		cairo_translate(cr, -cx, -cy)
	end
	cairo_set_line_width(cr, cfg.thickness)
	if cfg.style_type == "dashed" then
		cairo_set_dash(cr, { cfg.dash_on, cfg.dash_off }, 2, 0)
	elseif cfg.style_type == "dotted" then
		cairo_set_dash(cr, { cfg.dot_on, cfg.dot_off }, 2, 0)
	else
		cairo_set_dash(cr, {}, 0, 0)
	end
	local pat = cairo_pattern_create_linear(x1, y1, x2, y2)
	for _, stop in ipairs(cfg.fg) do
		local pos, col, a = stop[1], stop[2], stop[3]
		local r, g, b, aa = hex_to_rgba(col, a)
		cairo_pattern_add_color_stop_rgba(pat, pos, r, g, b, aa)
	end
	cairo_set_source(cr, pat)
	cairo_move_to(cr, x1, y1)
	cairo_line_to(cr, x2, y2)
	cairo_stroke(cr)
	cairo_pattern_destroy(pat)
	cairo_set_matrix(cr, mx)
end

--}}}
