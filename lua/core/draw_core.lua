--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- core/draw_core.lua — Cairo init, state, DRAG, Z_INDEX, THEME, helpers, main loop

require("cairo")
local status, cairo_xlib = pcall(require, "cairo_xlib")
if not status then
	cairo_xlib = setmetatable({}, {
		__index = function(_, k)
			return _G[k]
		end,
	})
end

-- ──────────────────────────────────────────────────────────
-- STATE
-- ──────────────────────────────────────────────────────────

GROUP_STATE = GROUP_STATE or {}
GROUP_REGISTRY = GROUP_REGISTRY or {}
GROUP_HIDDEN_BY_DRAW_ME = GROUP_HIDDEN_BY_DRAW_ME or {}
current_view = current_view or "main"
HOVER_VIEW = HOVER_VIEW or nil
MOUSE_INSIDE = false

-- ──────────────────────────────────────────────────────────
-- DRAG STATE — Neovim-style: button state, position tracking
-- ──────────────────────────────────────────────────────────

DRAG = DRAG or {
    active = false,
    source = nil,
    source_idx = nil,
    start_x = 0,
    start_y = 0,
    current_x = 0,
    current_y = 0,
    offset_x = 0,
    offset_y = 0,
    prev_x = 0,
    prev_y = 0,
    did_drag = false,
    drop_target = nil,
}

-- ──────────────────────────────────────────────────────────
-- Z-INDEX — Neovim-style: layer management
-- ──────────────────────────────────────────────────────────

Z_INDEX = Z_INDEX or {}
Z_INDEX.DEFAULT = 0
Z_INDEX.HEADER = 5
Z_INDEX.CONTEXT_MENU = 100
Z_INDEX.TOOLTIP = 200
Z_INDEX.DRAG_OVERLAY = 300

local function get_z_index(item)
    if item and item.z_index then return item.z_index end
    return Z_INDEX.DEFAULT
end

-- ──────────────────────────────────────────────────────────
-- SORTED DRAW CACHE — only re-sort when dirty
-- ──────────────────────────────────────────────────────────

draw_dirty = true
_cached_sorted_draw = nil

function ensure_sorted_draw()
    if not draw then return nil end
    if not draw_dirty and _cached_sorted_draw then
        return _cached_sorted_draw
    end
    local sorted = {}
    for i, item in ipairs(draw) do
        sorted[i] = item
    end
    table.sort(sorted, function(a, b)
        return get_z_index(a) < get_z_index(b)
    end)
    _cached_sorted_draw = sorted
    draw_dirty = false
    return sorted
end

SCROLL = SCROLL or { offset = 0, step = 30, content_height = 1200, window_height = 600 }

THEME = THEME or {}
THEME.view_active = THEME.view_active or { { 1, "#FFFFFF", 1 }, { 1, "#4444FF", 1, "bg" } }
THEME.view_inactive = THEME.view_inactive or { { 1, "#666666", 1 } }
THEME.header_expanded_color = THEME.header_expanded_color or { { 1, "#FFAA00", 1 } }
THEME.header_collapsed_color = THEME.header_collapsed_color or { { 1, "#FF8800", 1 } }
THEME.header_hidden_color = THEME.header_hidden_color or { { 1, "#555555", 1 } }
THEME.header_height = THEME.header_height or 24

-- ──────────────────────────────────────────────────────────
-- DRAG THEME — customizable drag overlay colors
-- ──────────────────────────────────────────────────────────

DRAG_THEME = DRAG_THEME or {}
DRAG_THEME.ghost_fill   = DRAG_THEME.ghost_fill   or { { 1, "#FFFF80", 0.3 } }
DRAG_THEME.ghost_stroke = DRAG_THEME.ghost_stroke or { { 1, "#FFFF00", 0.6 } }
DRAG_THEME.drop_fill    = DRAG_THEME.drop_fill    or { { 1, "#80FF80", 0.15 } }
DRAG_THEME.drop_stroke  = DRAG_THEME.drop_stroke  or { { 1, "#80FF80", 0.4 } }
DRAG_THEME.line_width   = DRAG_THEME.line_width   or 2

-- ──────────────────────────────────────────────────────────
-- THEME HELPERS
-- ──────────────────────────────────────────────────────────

function btn_color(view_name)
	return function()
		return (current_view == view_name) and THEME.view_active or THEME.view_inactive
	end
end

function arrow(name)
	return function()
		local s = GROUP_STATE[name]
		if s == "expanded" then return "▼ " .. name end
		if s == "collapsed" then return "▶ " .. name end
		return "• " .. name .. " (hidden)"
	end
end

function arrow_color(name)
	return function()
		local s = GROUP_STATE[name]
		if s == "expanded" then return THEME.header_expanded_color end
		if s == "collapsed" then return THEME.header_collapsed_color end
		return THEME.header_hidden_color
	end
end

-- ──────────────────────────────────────────────────────────
-- HELPERS — drawing, numbers, colors
-- ──────────────────────────────────────────────────────────

function rounded_rect_path(cr, x, y, w, h, r)
	cairo_new_sub_path(cr)
	cairo_arc(cr, x + w - r, y + r, r, -math.pi / 2, 0)
	cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi / 2)
	cairo_arc(cr, x + r, y + h - r, r, math.pi / 2, math.pi)
	cairo_arc(cr, x + r, y + r, r, math.pi, 3 * math.pi / 2)
	cairo_close_path(cr)
end

function draw_allowed(view, group)
	if view ~= nil then
		if view ~= current_view and view ~= HOVER_VIEW then
			return false
		end
	end
	if group ~= nil and view == nil and current_view ~= "main" then
		return false
	end
	if group ~= nil then
		local gname = group:match("^!(.+)$") or group
		local invert = group ~= gname
		local visible = GROUP_STATE[gname] ~= nil
		if (invert and visible) or (not invert and not visible) then
			return false
		end
	end
	return true
end

function normalize_number(v)
	if v == nil then
		return 0
	end
	if type(v) == "number" then
		return v
	end
	if type(v) == "table" then
		return 0
	end
	local s = tostring(v):gsub(",", ".")
	local n = tonumber(s:match("([%d%.]+)"))
	return n or 0
end

function normalize_with_suffix(raw)
	if not raw then
		return 0
	end
	local s = tostring(raw):lower():gsub("%s+", "")
	local num = normalize_number(s)
	local suf = s:match("([kmg])$")
	if suf == "k" then
		return num * 1024
	end
	if suf == "m" then
		return num * 1024 ^ 2
	end
	if suf == "g" then
		return num * 1024 ^ 3
	end
	return num
end

function hex_to_rgba(hex, alpha)
	hex = tostring(hex):gsub("#", "")
	local r = tonumber(hex:sub(1, 2), 16) / 255
	local g = tonumber(hex:sub(3, 4), 16) / 255
	local b = tonumber(hex:sub(5, 6), 16) / 255
	return r, g, b, alpha or 1
end

local _hex_cache = {}
function hex_to_rgb_components(col)
	local cached = _hex_cache[col]
	if cached then
		return cached[1], cached[2], cached[3]
	end
	local val = col
	if type(col) == "string" then
		val = tonumber(col:gsub("#", ""), 16)
	end
	local r = ((val >> 16) & 0xFF) / 255
	local g = ((val >> 8) & 0xFF) / 255
	local b = (val & 0xFF) / 255
	_hex_cache[col] = { r, g, b }
	return r, g, b
end

function get_color_from_list(stops, t)
	if #stops == 1 then
		local _, col, a = stops[1][1], stops[1][2], stops[1][3]
		local r, g, b = hex_to_rgb_components(col)
		return r, g, b, a
	end
	for i = 1, #stops - 1 do
		local p1, col1, a1 = stops[i][1], stops[i][2], stops[i][3]
		local p2, col2, a2 = stops[i + 1][1], stops[i + 1][2], stops[i + 1][3]
		if t >= p1 and t <= p2 then
			local k = (t - p1) / (p2 - p1)
			local r1, g1, b1 = hex_to_rgb_components(col1)
			local r2, g2, b2 = hex_to_rgb_components(col2)
			local r = r1 + (r2 - r1) * k
			local g = g1 + (g2 - g1) * k
			local b = b1 + (b2 - b1) * k
			local a = a1 + (a2 - a1) * k
			return r, g, b, a
		end
	end
	local _, col, a = stops[#stops][1], stops[#stops][2], stops[#stops][3]
	local r, g, b = hex_to_rgb_components(col)
	return r, g, b, a
end

function draw_get_value(m)
	if m.value ~= nil then
		if type(m.value) == "function" then
			local ok, v = pcall(m.value)
			if ok then return tostring(v) end
			return "0"
		end
		return tostring(m.value)
	end
	return conky_parse("${" .. m.name .. (m.arg and " " .. m.arg or "") .. "}")
end

-- ──────────────────────────────────────────────────────────
-- DRAW HOOKS — overridable
-- ──────────────────────────────────────────────────────────

on_draw_start = on_draw_start or function() end
on_draw_end = on_draw_end or function() end

-- ──────────────────────────────────────────────────────────
-- MAIN LOOP
-- ──────────────────────────────────────────────────────────

local RESOLVE_KEYS = { "x", "y", "w", "h", "width", "height", "radius", "text", "color", "path" }
local DRAW_DISPATCH = nil

local function clear_table(t)
	for k in pairs(t) do t[k] = nil end
end

local _bounds = { x = 0, y = 0, w = 0, h = 0 }

function conky_core_main()
	if not conky_window then
		return
	end

	conky_load_weather_data()
	conky_update_alerts()

	local updates = tonumber(conky_parse("${updates}")) or 0
	if updates < 3 then
		return
	end

	if raw_elements and not draw then
		build_draw(raw_elements)
	end

	click_registry = click_registry or {}
	text_registry = text_registry or {}
	group_hit_registry = group_hit_registry or {}
	HEADER_REGISTRY = HEADER_REGISTRY or {}
	clear_table(click_registry)
	clear_table(text_registry)
	clear_table(group_hit_registry)
	clear_table(HEADER_REGISTRY)
	hover_idx = 0

	local cs
	local own_surface = false
	if conky_surface then
		cs = conky_surface()
	else
		cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
		own_surface = true
	end
	local cr = cairo_create(cs)

	if layout and #layout > 0 then
		register_groups_from_layout()
		check_group_visibility()
		DynamicLayout.compute(layout, 0, {
			max_height = conky_window.height,
			column_width = 300,
			column_gap = 20,
			start_x = 0,
		})
	end

	cairo_translate(cr, 0, -SCROLL.offset)
	on_draw_start(cr)

	if draw then
		if not DRAW_DISPATCH then
			DRAW_DISPATCH = {
				background = draw_background,
				line = draw_line_modules,
				text = draw_text,
				bar = function(cr, item) return draw_bar_modules(cr, item, item.y) end,
				ring = draw_one_ring,
				image = draw_png,
				svg = draw_svg,
				graph = draw_graph,
				calendar = draw_calendar,
				clock = draw_clock,
			}
		end
		local draw_list = ensure_sorted_draw() or draw
		for _, item in ipairs(draw_list) do
			if item.draw_me ~= nil then
				local ok, visible = pcall(item.draw_me)
				if ok and not visible then goto continue end
			end
			if draw_allowed(item.view, item.group) then
				local layout_box_offset_x = 0
				local layout_box_offset_y = 0
				if item.layout_box and _G["x_start_" .. item.layout_box] then
					layout_box_offset_x = _G["x_start_" .. item.layout_box] or 0
					layout_box_offset_y = _G["y_start_" .. item.layout_box] or 0
				end

				if not (item.collapse and is_element_collapsed(item)) then
				local restore
				for _, k in ipairs(RESOLVE_KEYS) do
					if type(item[k]) == "function" then
						restore = restore or {}
						restore[k] = item[k]
						item[k] = item[k]()
					end
				end

			local rx = (item.x or 0) + layout_box_offset_x
			local ry = (item.y or 0) + layout_box_offset_y
			local rw = item.w or 0
			local rh = item.h or 0

			_bounds.x = rx
			_bounds.y = ry - (item.fixed and 0 or SCROLL.offset)
			_bounds.w = rw
			_bounds.h = rh

			if not is_element_collapsed(item) then
				register_input(item, _bounds)
				end

				if item.id and item.id:match("^h_") and item.group and item.click_toggle then
					HEADER_REGISTRY[item.group] = true
				end

				if item.group and not is_element_collapsed(item) then
					local entry = GROUP_TO_LAYOUT_IDX[item.group]
					local layout_idx = entry and entry.index
					local draggable = entry and entry.draggable or false
					table.insert(group_hit_registry, {
						x = rx, y = ry, w = rw, h = rh,
						group = item.group,
						target_group = item.target_group,
						layout_index = layout_idx,
						draggable = draggable,
					})
				end

				if item.type ~= "input_overlay" then
					if item.type == "text" and item.text then
						local txt = item.text
						if type(txt) == "function" then
							local ok, r = pcall(txt)
							if ok then txt = r end
						end
						if txt and type(txt) == "string" and txt ~= "" then
							table.insert(text_registry, {
								x = rx, y = ry, w = rw, h = rh,
								text = txt,
								group = item.group,
								target_group = item.target_group,
							})
						end
					end

				local fn = DRAW_DISPATCH[item.type]
					if fn then
						local ox, oy, ow, oh = item.x, item.y, item.w, item.h
						item.x, item.y, item.w, item.h = rx, ry, rw, rh
						pcall(fn, cr, item)
						item.x, item.y, item.w, item.h = ox, oy, ow, oh
					end
				end

				if restore then
					for k, v in pairs(restore) do
						item[k] = v
					end
				end
			end
			end
			::continue::
		end
	end

	-- ═══ FLOATING LAYER STACK — Neovim-style layer management ═══
	cairo_save(cr)
	cairo_translate(cr, 0, SCROLL.offset)

	if DRAG.active or CONTEX_MENU.visible then
		local floating = {}

		if DRAG.active and DRAG.source and DRAG.did_drag then
		table.insert(floating, {
			z_index = Z_INDEX.DRAG_OVERLAY,
			draw = function(cr)
				local gf = DRAG_THEME.ghost_fill[1]
				local gs = DRAG_THEME.ghost_stroke[1]
				local df = DRAG_THEME.drop_fill[1]
				local ds = DRAG_THEME.drop_stroke[1]
				local lw = DRAG_THEME.line_width
				cairo_set_source_rgba(cr, hex_to_rgba(gf[2], gf[3]))
				cairo_rectangle(cr,
					DRAG.current_x - DRAG.offset_x,
					DRAG.current_y - DRAG.offset_y,
					DRAG.source.w, DRAG.source.h)
				cairo_fill(cr)
				cairo_set_source_rgba(cr, hex_to_rgba(gs[2], gs[3]))
				cairo_set_line_width(cr, lw)
				cairo_rectangle(cr,
					DRAG.current_x - DRAG.offset_x,
					DRAG.current_y - DRAG.offset_y,
					DRAG.source.w, DRAG.source.h)
				cairo_stroke(cr)
				if DRAG.drop_target and layout then
					local box = layout[DRAG.drop_target]
					if box and box.name then
						local ty = _G["y_start_" .. box.name]
						local tx = _G["x_start_" .. box.name]
						local th = _G["height_" .. box.name]
						if ty and tx and th then
							cairo_set_source_rgba(cr, hex_to_rgba(df[2], df[3]))
							cairo_rectangle(cr, tx, ty, 300, th)
							cairo_fill(cr)
							cairo_set_source_rgba(cr, hex_to_rgba(ds[2], ds[3]))
							cairo_set_line_width(cr, lw)
							cairo_rectangle(cr, tx, ty, 300, th)
							cairo_stroke(cr)
						end
					end
				end
			end,
		})
	end

	if CONTEX_MENU.visible then
		table.insert(floating, {
			z_index = Z_INDEX.CONTEXT_MENU,
			draw = function(cr)
				draw_context_menu(cr)
			end,
		})
	end

	table.sort(floating, function(a, b)
		return a.z_index < b.z_index
	end)

	for _, layer in ipairs(floating) do
		layer.draw(cr)
	end
	end

	cairo_restore(cr)

	on_draw_end(cr)
	cairo_destroy(cr)
	if own_surface then
		cairo_surface_destroy(cs)
	end
end
