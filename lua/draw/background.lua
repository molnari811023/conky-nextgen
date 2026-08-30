--[[[
lua/draw/background.lua — Draws a rounded-rectangle background panel with gradient fill and border

Defaults adapt to the conky window size or a group's computed height when
explicit dimensions are not supplied.
]]--

--{{{
-- ## Background
--
-- Fills a rounded rectangle with a vertical gradient, then optionally strokes
-- an inset border with its own gradient. Dimensions fall back to the conky
-- window size or a group offset when zero.
--
-- **Exposed/global functions:**
-- - `draw_background(cr, cfg)` — Draws a rounded rectangle background with gradient fill and optional border; returns `{x, y, w, h}`.
--
-- **Config/globals used:**
-- - `BACKGROUND_DEFAULT` — global table of default background parameters.
-- - `conky_window` — window dimensions used as fallback for w/h.
-- - `GROUP_OFFSETS` — looked up when `cfg.group` is set to determine height.
-- - `build_gradient_pattern()` — creates a Cairo linear gradient from a color-stop list.
-- - `rounded_rect_path()` — adds a rounded rectangle path to the Cairo context.
--}}}

BACKGROUND_DEFAULT = {
	x = 0,
	y = 0,
	w = 0,
	h = 0,
	radius = 20,
	border_width = 2,
	-- bg, border: provided by the theme via apply_theme()
}

function draw_background(cr, cfg)
	if not conky_window then
		return
	end
	local c = {}
	for k, v in pairs(cfg) do c[k] = v end
	for k, v in pairs(BACKGROUND_DEFAULT) do
		if c[k] == nil then c[k] = v end
	end
	local x = c.x
	local y = c.y
	local w = (c.w == 0) and conky_window.width or c.w
	local gh = (c.group and GROUP_OFFSETS[c.group]) and GROUP_OFFSETS[c.group].height or 0
	local h = (c.h == 0) and (gh > 0 and gh or conky_window.height) or c.h
	local r = c.radius
	local bw = c.border_width
	local pat_bg = build_gradient_pattern(cr, c.bg, x, y, x, y + h)
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
		local pat = build_gradient_pattern(cr, c.border, x, y, x, y + h)
		cairo_set_source(cr, pat)
		cairo_set_line_width(cr, bw)
		rounded_rect_path(cr, ix, iy, iw, ih, ir)
		cairo_stroke(cr)
		cairo_pattern_destroy(pat)
	end
	return { x = x, y = y, w = w, h = h }
end
