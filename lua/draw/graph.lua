--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- draw/graph.lua — Scrolling time-series graphs (line or fill)
-- OPTIMIZED: bg uses single gradient pattern, fill uses single path + gradient
graph_history = graph_history or {}
local GRAPH_DEFAULT = {
	view = nil,
	group = nil,
	click = nil,
	click_view = nil,
	click_toggle = nil,
	hover_view = nil,
	x = 0,
	y = 0,
	width = 100,
	height = 40,
	max = 100,
	autoscale = false,
	angle = 0,
	graph_type = "line",
	line_width = 2,
	bg = {
		{ 0.0, "#333333", 1 },
		{ 1.0, "#111111", 1 },
	},
	fg = {
		{ 0.0, "#00FFAA", 1 },
		{ 1.0, "#008866", 1 },
	},
	border = {
		{ 0.0, "#FFFFFF", 0.8 },
		{ 1.0, "#FFFFFF", 0.2 },
	},
	border_width = 1,
	grid = false,
	grid_color = { { 0.0, "#FFFFFF", 0.10 } },
	grid_steps = 4,
}

local function build_gradient_pattern(cr, stops, x1, y1, x2, y2)
	local pat = cairo_pattern_create_linear(x1, y1, x2, y2)
	for _, s in ipairs(stops) do
		local p, col, a = s[1], s[2], s[3]
		local r, g, b = hex_to_rgb_components(col)
		cairo_pattern_add_color_stop_rgba(pat, p, r, g, b, a)
	end
	return pat
end

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
	if not draw_allowed(c.view, c.group) then
		return
	end
	if c.style then
		for k, v in pairs(c.style) do
			c[k] = v
		end
	end
	local key = c.key or tostring(c.name or "") .. tostring(c.arg or "")
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
	local x, y, w, h = c.x, c.y, c.width, c.height
	local ang = c.angle or 0
	local mx = cairo_matrix_t:create()
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
		local fg_pat = build_gradient_pattern(cr, c.fg, x, y, x, y + h)
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
