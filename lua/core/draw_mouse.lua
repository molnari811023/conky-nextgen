--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- core/draw_mouse.lua — Mouse event handler: button_down/up, scroll, move, drag, enter/leave

-- ──────────────────────────────────────────────────────────
-- MOUSE ENTER/LEAVE — overridable
-- ──────────────────────────────────────────────────────────

on_mouse_enter = on_mouse_enter or function()
	MOUSE_INSIDE = true
end

on_mouse_leave = on_mouse_leave or function()
	if hover_idx > 0 then
		HOVER_VIEW = nil
	end
	if previous_hover_toggle then
		GROUP_STATE[previous_hover_toggle] = "collapsed"
		previous_hover_toggle = nil
	end
	hover_idx = 0
	MOUSE_INSIDE = false
	SCROLL.offset = 0
	if DRAG.active then
		DRAG.active = false
		DRAG.source = nil
		DRAG.source_idx = nil
		DRAG.drop_target = nil
		DRAG.did_drag = false
	end
end

-- ──────────────────────────────────────────────────────────
-- MOUSE HANDLER — separated hit testing
-- ──────────────────────────────────────────────────────────

function conky_on_mouse(event)
	if not event then return true end

	local ex = tonumber(event.x) or 0
	local ey = tonumber(event.y) or 0

	if event.type == "button_down" then
		-- right-click → text copy + context menu
		if event.button == "right" then
			local found_text = nil
			local found_group = nil
			for i = #text_registry, 1, -1 do
				local t = text_registry[i]
				if ex >= t.x and ex <= t.x + t.w and ey >= t.y and ey <= t.y + t.h then
					found_text = t.text
					break
				end
			end
			if found_text then
				if copy_to_clipboard then
					pcall(copy_to_clipboard, found_text)
				end
			end
			for i = #group_hit_registry, 1, -1 do
				local e = group_hit_registry[i]
				local tg = e.target_group or e.group
				if tg and ex >= e.x and ex <= e.x + e.w and ey >= e.y and ey <= e.y + e.h then
					found_group = tg
					break
				end
			end
			if not found_group then
				for i = #click_registry, 1, -1 do
					local e = click_registry[i]
					local tg = e.target_group or e.group
					if tg and ex >= e.x and ex <= e.x + e.w and ey >= e.y and ey <= e.y + e.h then
						found_group = tg
						break
					end
				end
			end
			open_context_menu(ex, ey, found_group)
			CONTEX_MENU.text = found_text
			return true
		end

		-- context menu click → execute + close
		if CONTEX_MENU.visible then
			local cx, cy = CONTEX_MENU.x, CONTEX_MENU.y
			local actions = get_visible_menu_actions()
			for i, entry in ipairs(actions) do
				local ey2 = cy + CONTEX_MENU_PAD + (i - 1) * (CONTEX_MENU_H + CONTEX_MENU_PAD)
				if ex >= cx and ex <= cx + CONTEX_MENU_W and ey >= ey2 and ey <= ey2 + CONTEX_MENU_H then
					if CONTEX_MENU.group then
						entry.action(CONTEX_MENU.group)
					else
						entry.action()
					end
					close_context_menu()
					return true
				end
			end
			close_context_menu()
		end

		-- DRAG START — left-click, no context menu, on draggable element
		if event.button == "left" then
			for i = #group_hit_registry, 1, -1 do
				local e = group_hit_registry[i]
				if e.draggable and e.layout_index
					and ex >= e.x and ex <= e.x + e.w
					and ey >= e.y and ey <= e.y + e.h then
					DRAG.active = true
					DRAG.source = {
						group = e.group,
						name = layout[e.layout_index] and layout[e.layout_index].name,
						x = e.x, y = e.y, w = e.w, h = e.h,
					}
					DRAG.source_idx = e.layout_index
					DRAG.start_x = ex
					DRAG.start_y = ey
					DRAG.current_x = ex
					DRAG.current_y = ey
					DRAG.offset_x = ex - e.x
					DRAG.offset_y = ey - e.y
					DRAG.prev_x = ex
					DRAG.prev_y = ey
					DRAG.did_drag = false
					DRAG.drop_target = nil
					return true
				end
			end
		end

		-- CLICK TARGETS ONLY (not scroll, not hover)
		for i = #click_registry, 1, -1 do
			local e = click_registry[i]
			local is_click_target = e.click or e.click_view or e.click_toggle or e.clipboard
			if is_click_target and ex >= e.x and ex <= e.x + e.w and ey >= e.y and ey <= e.y + e.h then
				if e.click_view then
					CLICK_ACTIONS["view"](e)
				elseif e.click_toggle then
					CLICK_ACTIONS["toggle"](e)
				elseif e.clipboard then
					CLICK_ACTIONS["clipboard"](e)
				elseif e.click then
					CLICK_ACTIONS["command"](e)
				end
				break
			end
		end

	elseif event.type == "mouse_scroll" then
		local direction = event.direction
		for i = #click_registry, 1, -1 do
			local e = click_registry[i]
			local is_scroll_target = e.scroll_up_action or e.scroll_down_action
			if is_scroll_target and ex >= e.x and ex <= e.x + e.w and ey >= e.y and ey <= e.y + e.h then
				if direction == "up" and e.scroll_up_action then
					execute_scroll_action(e.scroll_up_action)
					return true
				elseif direction == "down" and e.scroll_down_action then
					execute_scroll_action(e.scroll_down_action)
					return true
				end
			end
		end

	elseif event.type == "mouse_move" then
		if DRAG.active then
			local dx = ex - DRAG.prev_x
			local dy = ey - DRAG.prev_y
			if math.abs(dx) > 2 or math.abs(dy) > 2 then
				DRAG.did_drag = true
			end
			DRAG.current_x = ex
			DRAG.current_y = ey
			DRAG.prev_x = ex
			DRAG.prev_y = ey

			DRAG.drop_target = nil
			if layout and DRAG.source_idx then
				for i, box in ipairs(layout) do
					if i ~= DRAG.source_idx and box.name then
						local ty = _G["y_start_" .. box.name]
						local tx = _G["x_start_" .. box.name]
						local th = _G["height_" .. box.name]
						if ty and tx and th then
							if ex >= tx and ex <= tx + 300
								and ey >= ty and ey <= ty + th then
								DRAG.drop_target = i
								break
							end
						end
					end
				end
			end
			return true
		end

		local found = false
		for i = #click_registry, 1, -1 do
			local e = click_registry[i]
			local is_hover_target = e.mouse_hover_view or e.mouse_hover_toggle
			if is_hover_target and ex >= e.x and ex <= e.x + e.w and ey >= e.y and ey <= e.y + e.h then
				if e.mouse_hover_view then
					if HOVER_VIEW ~= e.mouse_hover_view then
						HOVER_VIEW = e.mouse_hover_view
					end
					hover_idx = i
					found = true
					break
				elseif e.mouse_hover_toggle then
					if hover_idx ~= i then
						if previous_hover_toggle and previous_hover_toggle ~= e.mouse_hover_toggle then
							GROUP_STATE[previous_hover_toggle] = "collapsed"
						end
						toggle_group(e.mouse_hover_toggle)
						previous_hover_toggle = e.mouse_hover_toggle
						hover_idx = i
						found = true
						break
					end
				end
			end
		end
		if not found and hover_idx > 0 then
			HOVER_VIEW = nil
			if previous_hover_toggle then
				GROUP_STATE[previous_hover_toggle] = "collapsed"
				previous_hover_toggle = nil
			end
			hover_idx = 0
		end

	elseif event.type == "button_up" then
		if DRAG.active then
			if DRAG.did_drag and DRAG.drop_target and layout then
				local source = table.remove(layout, DRAG.source_idx)
				if source then
					table.insert(layout, DRAG.drop_target, source)
				end
				if rebuild_layout_index_cache then
					rebuild_layout_index_cache()
				end
				if draw_dirty ~= nil then
					draw_dirty = true
				end
			end
			DRAG.active = false
			DRAG.source = nil
			DRAG.source_idx = nil
			DRAG.drop_target = nil
			DRAG.did_drag = false
			return true
		end

	elseif event.type == "mouse_enter" then
		on_mouse_enter()

	elseif event.type == "mouse_leave" then
		on_mouse_leave()
	end

	return true
end
