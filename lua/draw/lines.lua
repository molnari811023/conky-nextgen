--[[[
lua/draw/lines.lua — Draws straight lines with solid, dashed, or dotted styles

Supports gradient colour along the line direction via build_gradient_pattern.
Dash parameters are clamped to non-negative values to protect the Cairo context.
]]--

--{{{
-- ## Lines
--
-- Renders a straight line between two endpoints using Cairo. The line style
-- can be solid, dashed, or dotted, with configurable dash/gap and dot/gap
-- lengths. A gradient pattern can be applied along the line axis. The dash
-- state is explicitly reset after drawing to prevent leakage to later elements.
--
-- **Exposed/global functions:**
-- - `draw_line_modules(cr, m)` — Draws a styled line between two points and returns its bounding box `{x, y, w, h}`.
--
-- **Config/globals used:**
-- - `conky_window` — checked for early-exit guard.
-- - `build_gradient_pattern()` — creates a Cairo linear gradient from a color-stop list.
--}}}

local LINE_DEFAULT = {
	x1 = 0,
	y1 = 0,
	x2 = 100,
	y2 = 0,
	thickness = 2,
	style_type = "solid",
	dash_on = 4,
	dash_off = 4,
	dot_on = 1,
	dot_off = 3,
	-- fg: provided by the theme via apply_theme()
}
function draw_line_modules(cr, m)
	if not conky_window then
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
		cfg.fg = { { 1, "#565f89", 1 } }
	end
	local x1, y1 = cfg.x1, cfg.y1
	local x2, y2 = cfg.x2, cfg.y2
	-- The core adds the group's Y offset to item.y; apply it to the
	-- endpoints so line points are relative to the group's top.
	local gy = tonumber(cfg.y) or 0
	if gy ~= 0 then
		y1 = y1 + gy
		y2 = y2 + gy
	end
	-- Negative dash values would poison the cairo context (NEGATIVE_COUNT);
	-- coerce in case theme/config passes strings.
	local dash_on = math.max(0, tonumber(cfg.dash_on) or 0)
	local dash_off = math.max(0, tonumber(cfg.dash_off) or 0)
	local dot_on = math.max(0, tonumber(cfg.dot_on) or 0)
	local dot_off = math.max(0, tonumber(cfg.dot_off) or 0)
	cairo_set_line_width(cr, math.max(1, tonumber(cfg.thickness) or 2))
	if cfg.style_type == "dashed" and dash_on > 0 then
		cairo_set_dash(cr, { dash_on, dash_off }, 2, 0)
	elseif cfg.style_type == "dotted" and dot_on > 0 then
		cairo_set_dash(cr, { dot_on, dot_off }, 2, 0)
	else
		cairo_set_dash(cr, {}, 0, 0)
	end
	local pat = build_gradient_pattern(cr, cfg.fg, x1, y1, x2, y2)
	cairo_set_source(cr, pat)
	cairo_move_to(cr, x1, y1)
	cairo_line_to(cr, x2, y2)
	cairo_stroke(cr)
	cairo_pattern_destroy(pat)
	-- Reset the dash so it does not leak onto later stroke-based elements
	-- (rings, graph borders, clock ticks) drawn in the same frame.
	cairo_set_dash(cr, {}, 0, 0)
	return { x = math.min(x1, x2), y = math.min(y1, y2), w = math.abs(x2 - x1), h = math.abs(y2 - y1) }
end
