--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 27_draw_graph.lua — Scrolling time-series graphs (line or fill)
graph_history = graph_history or {}
local GRAPH_DEFAULT = {
	draw_me = true,
	view = nil,
	group = nil,
	click = nil,
	click_view = nil,
	click_toggle = nil,
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
	if not draw_allowed(c.draw_me, c.view, c.group) then
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
	local raw = draw_get_value(c)
	local val = normalize_with_suffix(raw)
	table.remove(graph_history[key], 1)
	table.insert(graph_history[key], val)
	local maxv = c.max
	if c.autoscale then
		maxv = 1
		for _, v in ipairs(graph_history[key]) do
			if v > maxv then
				maxv = v
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
	for i = 0, w - 1 do
		local t = i / w
		local r, g, b, a = get_color_from_list(c.bg, t)
		cairo_set_source_rgba(cr, r, g, b, a)
		cairo_rectangle(cr, x + i, y, 1, h)
		cairo_fill(cr)
	end
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
			local v1 = graph_history[key][i] / maxv
			local v2 = graph_history[key][i + 1] / maxv
			local t = v2
			local r, g, b, a = get_color_from_list(c.fg, t)
			cairo_set_source_rgba(cr, r, g, b, a)
			cairo_move_to(cr, x + i, y + h - v1 * h)
			cairo_line_to(cr, x + i + 1, y + h - v2 * h)
			cairo_stroke(cr)
		end
	end
	if c.graph_type == "fill" then
		for i = 1, w do
			local v = graph_history[key][i] / maxv
			local bh = v * h
			for yy = 0, bh do
				local t = yy / h
				local r, g, b, a = get_color_from_list(c.fg, t)
				cairo_set_source_rgba(cr, r, g, b, a)
				cairo_rectangle(cr, x + i, y + h - yy, 1, 1)
				cairo_fill(cr)
			end
		end
	end
	local pat = cairo_pattern_create_linear(x, y, x + w, y)
	for _, s in ipairs(c.border) do
		local p, col, a = s[1], s[2], s[3]
		local r, g, b = hex_to_rgb_components(col)
		cairo_pattern_add_color_stop_rgba(pat, p, r, g, b, a)
	end
	cairo_set_source(cr, pat)
	cairo_pattern_destroy(pat)
	cairo_set_line_width(cr, c.border_width)
	cairo_rectangle(cr, x, y, w, h)
	cairo_stroke(cr)
	cairo_set_matrix(cr, mx)
	return { x = c.x, y = c.y, w = c.width, h = c.height }
end

