--[[[
lua/draw/graph.lua — Draws time-series line or area graphs with history buffers

Each unique graph key maintains a rolling history ring-buffer that persists
across frames in the global `graph_history` table.
]]--

--{{{
-- ## Graph
--
-- Renders a scrolling time-series graph as either a line or a filled area.
-- The current value is appended to a width-sized ring buffer each frame; older
-- samples scroll left. An optional grid, border, and rotation are supported.
-- Autoscale mode adjusts the Y maximum to 110 % of the peak observed value.
--
-- **Exposed/global functions:**
-- - `draw_graph(cr, m)` — Draws a time-series graph and returns `{x, y, w, h}`.
--
-- **Config/globals used:**
-- - `graph_history` — global table storing per-key history ring buffers.
-- - `conky_window` — checked for early-exit guard.
-- - `draw_get_value()` — fetches the numeric value to graph.
-- - `normalize_with_suffix()` — parses human-readable suffixes.
-- - `get_color_from_list()` — resolves gradient color-stop lists to RGBA.
-- - `build_gradient_pattern()` — creates Cairo linear gradient patterns.
--}}}

local _graph_mx = cairo_matrix_t:create()

graph_history = graph_history or {}
local GRAPH_DEFAULT = {
	x = 0,
	y = 0,
	width = 100,
	height = 40,
	max = 100,
	autoscale = false,
	angle = 0,
	graph_type = "line",
	line_width = 2,
	border_width = 1,
	grid = false,
	grid_steps = 4,
	-- fg, bg, border, grid_color: provided by the theme via apply_theme()
}



function draw_graph(cr, m)
	if not conky_window then
		return
	end
	local c = {}
	for k, v in pairs(GRAPH_DEFAULT) do
		c[k] = v
	end
	for k, v in pairs(m) do
		c[k] = v
	end

	if c.style then
		for k, v in pairs(c.style) do
			c[k] = v
		end
	end

	-- Numeric coercion: theme/config values may arrive as strings
	-- (e.g. width = "240"), which would crash numeric loops/compare.
	c.width = tonumber(c.width) or GRAPH_DEFAULT.width
	c.height = tonumber(c.height) or GRAPH_DEFAULT.height
	c.grid_steps = tonumber(c.grid_steps) or GRAPH_DEFAULT.grid_steps
	c.max = tonumber(c.max) or GRAPH_DEFAULT.max
	c.line_width = tonumber(c.line_width) or GRAPH_DEFAULT.line_width

	local key = c.key
	if not key then
		if c.name then
			key = tostring(c.name) .. tostring(c.arg or "")
		elseif type(c.value) == "table" then
			key = c.value.value
		elseif type(c.value) == "string" then
			key = c.value
		else
			key = ""
		end
	end
	if not graph_history[key] or #graph_history[key] ~= c.width then
		graph_history[key] = {}
		for i = 1, c.width do
			graph_history[key][i] = 0
		end
	end
	local hist = graph_history[key]
	local raw = draw_get_value(c)
	local val = normalize_with_suffix(raw)
	table.remove(hist, 1)
	hist[#hist + 1] = val
	local maxv = c.max
	if c.autoscale then
		maxv = 1
		for i = 1, #hist do
			if hist[i] > maxv then
				maxv = hist[i]
			end
		end
		maxv = maxv * 1.1
	end
	if not (maxv and maxv > 0) then
		maxv = 1
	end
	local x, y, w, h = c.x, c.y, c.width, c.height
	local ang = c.angle or 0
	local mx = _graph_mx
	cairo_get_matrix(cr, mx)
	if ang ~= 0 then
		local cx = x + w / 2
		local cy = y + h / 2
		cairo_translate(cr, cx, cy)
		cairo_rotate(cr, math.rad(ang))
		cairo_translate(cr, -cx, -cy)
	end

	-- BG: single gradient pattern + one fill (was O(w) individual calls)
	local bg_pat = build_gradient_pattern(cr, c.bg, x, y, x + w, y)
	cairo_set_source(cr, bg_pat)
	cairo_rectangle(cr, x, y, w, h)
	cairo_fill(cr)
	cairo_pattern_destroy(bg_pat)

	if c.grid then
		local r, g, b, a = get_color_from_list(c.grid_color, 0)
		cairo_set_source_rgba(cr, r, g, b, a)
		cairo_set_line_width(cr, 1)
		local steps = c.grid_steps
		if not (steps and steps > 1) then
			steps = 1
		end
		for i = 1, steps - 1 do
			local gy = y + (h / steps) * i
			cairo_move_to(cr, x, gy)
			cairo_line_to(cr, x + w, gy)
			cairo_stroke(cr)
		end
	end

	if c.graph_type == "line" then
		cairo_set_line_width(cr, c.line_width)
		for i = 1, w - 1 do
			local v1 = hist[i] / maxv
			local v2 = hist[i + 1] / maxv
			local r, g, b, a = get_color_from_list(c.fg, v2)
			cairo_set_source_rgba(cr, r, g, b, a)
			cairo_move_to(cr, x + i, y + h - v1 * h)
			cairo_line_to(cr, x + i + 1, y + h - v2 * h)
			cairo_stroke(cr)
		end
	end

	if c.graph_type == "fill" then
		-- Single path: bottom-left → each column top → bottom-right → close
		cairo_move_to(cr, x, y + h)
		for i = 1, w do
			local v = hist[i] / maxv
			cairo_line_to(cr, x + i, y + h - v * h)
		end
		cairo_line_to(cr, x + w, y + h)
		cairo_close_path(cr)
		-- Vertical gradient fill (was O(w×h) individual pixel fills)
		local fg_pat = build_gradient_pattern(cr, c.fg, x, y + h, x, y)
		cairo_set_source(cr, fg_pat)
		cairo_fill(cr)
		cairo_pattern_destroy(fg_pat)
	end

	-- Border
	local border_pat = build_gradient_pattern(cr, c.border, x, y, x + w, y)
	cairo_set_source(cr, border_pat)
	cairo_set_line_width(cr, c.border_width)
	cairo_rectangle(cr, x, y, w, h)
	cairo_stroke(cr)
	cairo_pattern_destroy(border_pat)

	cairo_set_matrix(cr, mx)
	return { x = c.x, y = c.y, w = c.width, h = c.height }
end
