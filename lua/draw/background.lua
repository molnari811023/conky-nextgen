--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- draw/background.lua — Rounded rectangles with gradient fill + border
BACKGROUND_DEFAULT = {
	view = nil,
	group = nil,
	click = nil,
	click_view = nil,
	click_toggle = nil,
	hover_view = nil,
	x = 0,
	y = 0,
	w = 0,
	h = 0,
	radius = 20,
	bg = { { 1, "#141618", 1 } },
	border = { { 1, "#4c4e51", 1 } },
	border_width = 2,
}

function draw_background(cr, cfg)
	if not draw_allowed(cfg.view, cfg.group) or not conky_window then
		return
	end
	local c = {}
	for k, v in pairs(BACKGROUND_DEFAULT) do
		c[k] = cfg[k] ~= nil and cfg[k] or v
	end
	local x = c.x
	local y = c.y
	local w = (c.w == 0) and conky_window.width or c.w
	local h = (c.h == 0) and conky_window.height or c.h
	local r = c.radius
	local bw = c.border_width
	local pat_bg = cairo_pattern_create_linear(x, y, x, y + h)
	for _, s in ipairs(c.bg) do
		local pos, col, a = s[1], s[2], s[3]
		local rr, gg, bb, aa = hex_to_rgba(col, a)
		cairo_pattern_add_color_stop_rgba(pat_bg, pos, rr, gg, bb, aa)
	end
	cairo_set_source(cr, pat_bg)
	rounded_rect_path(cr, x, y, w, h, r)
	cairo_fill(cr)
	cairo_pattern_destroy(pat_bg)
	if bw > 0 then
		local inset = bw / 2
		local ix = x + inset
		local iy = y + inset
		local iw = w - bw
		local ih = h - bw
		local ir = math.max(0, r - inset)
		local pat = cairo_pattern_create_linear(x, y, x, y + h)
		for _, s in ipairs(c.border) do
			local pos, col, a = s[1], s[2], s[3]
			local rr, gg, bb, aa = hex_to_rgba(col, a)
			cairo_pattern_add_color_stop_rgba(pat, pos, rr, gg, bb, aa)
		end
		cairo_set_source(cr, pat)
		cairo_set_line_width(cr, bw)
		rounded_rect_path(cr, ix, iy, iw, ih, ir)
		cairo_stroke(cr)
		cairo_pattern_destroy(pat)
	end
	return { x = x, y = y, w = w, h = h }
end

