--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- core/draw_context.lua — Context menu: state, actions, draw, hit test

-- ──────────────────────────────────────────────────────────
-- CONTEXT MENU — right-click menu for groups
-- ──────────────────────────────────────────────────────────

CONTEXT_MENU_ACTIONS = {
	{
		key = "ctx_collapse",
		label = function() return get_tr("ctx_collapse") end,
		action = function(g) GROUP_STATE[g] = "collapsed" end,
	},
	{
		key = "ctx_expand",
		label = function() return get_tr("ctx_expand") end,
		action = function(g) GROUP_STATE[g] = "expanded" end,
	},
	{
		key = "ctx_hide",
		label = function() return get_tr("ctx_hide") end,
		action = function(g) GROUP_STATE[g] = nil end,
	},
	{
		key = "ctx_restore_all",
		label = function() return get_tr("ctx_restore_all") end,
		action = function()
			for name, _ in pairs(GROUP_REGISTRY) do
				GROUP_STATE[name] = "expanded"
			end
		end,
	},
}

CONTEX_MENU = CONTEX_MENU or { visible = false, x = 0, y = 0, group = nil, text = nil }
CONTEX_MENU_H = 28
CONTEX_MENU_W = 160
CONTEX_MENU_PAD = 8

function open_context_menu(ex, ey, group_name)
	CONTEX_MENU.visible = true
	CONTEX_MENU.x = ex
	CONTEX_MENU.y = ey
	CONTEX_MENU.group = group_name
end

function close_context_menu()
	CONTEX_MENU.visible = false
	CONTEX_MENU.group = nil
	CONTEX_MENU.text = nil
end

function get_visible_menu_actions()
	local actions = {}
	if CONTEX_MENU.text and copy_to_clipboard then
		table.insert(actions, {
			key = "ctx_copy",
			label = function() return get_tr("ctx_copy") end,
			action = function()
				copy_to_clipboard(CONTEX_MENU.text)
			end,
		})
	end
	if CONTEX_MENU.group then
		local state = GROUP_STATE[CONTEX_MENU.group]
		local has_header = HEADER_REGISTRY[CONTEX_MENU.group] or false
		for _, a in ipairs(CONTEXT_MENU_ACTIONS) do
			if a.key == "ctx_collapse" and state ~= "collapsed" and has_header then
				table.insert(actions, a)
			elseif a.key == "ctx_expand" and state ~= "expanded" and has_header then
				table.insert(actions, a)
			elseif a.key == "ctx_hide" and state ~= nil then
				table.insert(actions, a)
			elseif a.key == "ctx_restore_all" then
				table.insert(actions, a)
			end
		end
	else
		table.insert(actions, CONTEXT_MENU_ACTIONS[#CONTEXT_MENU_ACTIONS])
	end
	return actions
end

function draw_context_menu(cr)
	if not CONTEX_MENU.visible then return end
	local x, y = CONTEX_MENU.x, CONTEX_MENU.y
	local h = CONTEX_MENU_H
	local w = CONTEX_MENU_W
	local pad = CONTEX_MENU_PAD

	local actions = get_visible_menu_actions()

	cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
	cairo_set_line_width(cr, 1)

	local total_h = #actions * (h + pad) + pad

	rounded_rect_path(cr, x, y, w, total_h, 6)
	cairo_set_source_rgba(cr, 0.1, 0.1, 0.14, 0.95)
	cairo_fill_preserve(cr)
	cairo_set_source_rgba(cr, 0.35, 0.35, 0.4, 1)
	cairo_stroke(cr)

	for i, entry in ipairs(actions) do
		local ey = y + pad + (i - 1) * (h + pad)
		rounded_rect_path(cr, x + 6, ey, w - 12, h, 4)
		cairo_set_source_rgba(cr, 0.25, 0.25, 0.3, 1)
		cairo_fill(cr)

		cairo_set_source_rgba(cr, 1, 1, 1, 0.9)
		cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
		cairo_set_font_size(cr, 11)
		cairo_move_to(cr, x + 16, ey + h * 0.65)
		local label_text = type(entry.label) == "function" and entry.label() or entry.label
		cairo_show_text(cr, label_text)
	end

	cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
end
