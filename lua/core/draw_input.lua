--[[
  Conky NextGen Framework — core/draw_input.lua
  Input registration, click/scroll actions, clickable overlay, build_draw
--]]

-- ──────────────────────────────────────────────────────────
-- REGISTRY VARIABLES
-- ──────────────────────────────────────────────────────────

click_registry = click_registry or {}
text_registry = text_registry or {}
group_hit_registry = group_hit_registry or {}
HEADER_REGISTRY = HEADER_REGISTRY or {}
hover_idx = hover_idx or 0
previous_hover_toggle = previous_hover_toggle or nil

-- ──────────────────────────────────────────────────────────
-- INPUT KEYS — single source of truth
-- ──────────────────────────────────────────────────────────

INPUT_KEYS = {
	"click", "click_view", "click_toggle", "clipboard",
	"scroll_up_action", "scroll_down_action",
	"mouse_hover_view", "mouse_hover_toggle", "hover_view",
}

-- ──────────────────────────────────────────────────────────
-- CLICK ACTIONS — extensible
-- ──────────────────────────────────────────────────────────

CLICK_ACTIONS = {}

CLICK_ACTIONS["view"] = function(e)
	current_view = e.click_view
end

CLICK_ACTIONS["toggle"] = function(e)
	toggle_group(e.click_toggle)
end

CLICK_ACTIONS["command"] = function(e)
	os.execute(e.click .. " &")
end

CLICK_ACTIONS["clipboard"] = function(e)
	local text = e.clipboard
	if type(text) == "function" then
		local ok, result = pcall(text)
		if ok then text = result end
	end
	if text and copy_to_clipboard then
		copy_to_clipboard(tostring(text))
	end
end

-- ──────────────────────────────────────────────────────────
-- SCROLL ACTIONS — extensible
-- ──────────────────────────────────────────────────────────

SCROLL_ACTIONS = {}

SCROLL_ACTIONS["view"] = function(arg1, arg2)
	if arg1 ~= "next" and arg1 ~= "prev" then
		current_view = arg1
	end
end

SCROLL_ACTIONS["group"] = function(arg1, arg2)
	if arg1 and arg2 == "expand" then
		GROUP_STATE[arg1] = "expanded"
	elseif arg1 and arg2 == "collapse" then
		GROUP_STATE[arg1] = "collapsed"
	elseif arg1 then
		toggle_group(arg1)
	end
end

SCROLL_ACTIONS["command"] = function(arg1, arg2)
	os.execute(arg1 .. " &")
end

SCROLL_ACTIONS["scroll"] = function(arg1, arg2)
	local step = SCROLL.step or 30
	local max_offset = math.max(0, (SCROLL.content_height or 800) - (SCROLL.window_height or 400))
	if arg1 == "up" then
		SCROLL.offset = math.max(0, SCROLL.offset - step)
	elseif arg1 == "down" then
		SCROLL.offset = math.min(max_offset, SCROLL.offset + step)
	end
end

function parse_scroll_action(action)
	if not action then return end
	local cmd, arg1, arg2 = action:match("^([^:]+):([^:]+):?(.*)$")
	if not cmd then cmd = action end
	return cmd, arg1, arg2
end

function execute_scroll_action(action)
	if not action then return end
	local cmd, arg1, arg2 = parse_scroll_action(action)
	if SCROLL_ACTIONS[cmd] then
		SCROLL_ACTIONS[cmd](arg1, arg2)
	end
end

-- ──────────────────────────────────────────────────────────
-- CLICKABLE OVERLAY GENERATOR
-- ──────────────────────────────────────────────────────────

function clickable(item)
	local overlay = {
		type = "input_overlay",
		x = item.x, y = item.y, w = item.w, h = item.h,
		fixed = item.fixed,
		view = item.view, group = item.group,
		target_group = item.target_group,
	}
	for _, key in ipairs(INPUT_KEYS) do
		if item[key] ~= nil then
			overlay[key] = item[key]
		end
	end
	return overlay
end

-- ──────────────────────────────────────────────────────────
-- INPUT REGISTRATION
-- ──────────────────────────────────────────────────────────

function register_input(item, bounds)
	if not item._has_input then return end
	local b = bounds or {}

	table.insert(click_registry, {
		x = b.x or item.x or 0,
		y = b.y or item.y or 0,
		w = b.w or item.w or 0,
		h = b.h or item.h or 0,
		click = item.click,
		click_view = item.click_view,
		click_toggle = item.click_toggle,
		clipboard = item.clipboard,
		scroll_up_action = item.scroll_up_action,
		scroll_down_action = item.scroll_down_action,
		mouse_hover_view = item.mouse_hover_view or item.hover_view,
		mouse_hover_toggle = item.mouse_hover_toggle,
		fixed = item.fixed,
		target_group = item.target_group,
	})
end

-- ──────────────────────────────────────────────────────────
-- CONKY MOUSE STATUS — debug info
-- ──────────────────────────────────────────────────────────

function conky_mouse_status()
	local s = "view: " .. tostring(current_view)
	if hover_idx and hover_idx > 0 and click_registry[hover_idx] then
		s = s .. "  hover: " .. tostring(hover_idx)
	end
	return s
end

-- ──────────────────────────────────────────────────────────
-- BUILD DRAW — raw_elements → draw + clickable overlay
-- ──────────────────────────────────────────────────────────

function build_draw(raw_elements)
	draw = {}
	for _, elem in ipairs(raw_elements) do
		table.insert(draw, elem)
		local has_input = false
		for _, key in ipairs(INPUT_KEYS) do
			if elem[key] ~= nil then
				has_input = true
				break
			end
		end
		elem._has_input = has_input
		if has_input then
			table.insert(draw, clickable(elem))
		end
	end
end
