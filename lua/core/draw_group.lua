--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- core/draw_group.lua — GROUP_STATE handling: toggle, register, visibility, collapse

-- ──────────────────────────────────────────────────────────
-- LAYOUT INDEX CACHE — O(1) group→layout lookup
-- ──────────────────────────────────────────────────────────

GROUP_TO_LAYOUT_IDX = GROUP_TO_LAYOUT_IDX or {}
LAYOUT_WITH_DRAW_ME = LAYOUT_WITH_DRAW_ME or {}

function rebuild_layout_index_cache()
	GROUP_TO_LAYOUT_IDX = {}
	LAYOUT_WITH_DRAW_ME = {}
	if not layout then return end
	for li, entry in ipairs(layout) do
		if entry.group then
			GROUP_TO_LAYOUT_IDX[entry.group] = { index = li, draggable = entry.draggable or false }
		end
		if entry.draw_me ~= nil then
			table.insert(LAYOUT_WITH_DRAW_ME, entry)
		end
	end
end

-- ──────────────────────────────────────────────────────────
-- COLLAPSE — three-state group management
-- ──────────────────────────────────────────────────────────

function is_element_collapsed(el)
	if el.group == nil then return false end
	local gname = el.group:match("^!(.+)$") or el.group
	return GROUP_STATE[gname] == "collapsed"
end

-- ──────────────────────────────────────────────────────────
-- GROUP STATE — toggle, register
-- ──────────────────────────────────────────────────────────

function toggle_group(name)
	if name == "__all_reset__" then
		for g, _ in pairs(GROUP_REGISTRY) do
			GROUP_STATE[g] = "expanded"
		end
		return
	end
	local s = GROUP_STATE[name]
	if s == "collapsed" then
		GROUP_STATE[name] = "expanded"
	elseif s == "expanded" then
		GROUP_STATE[name] = "collapsed"
	else
		GROUP_STATE[name] = "expanded"
	end
end

function register_group(name)
	if GROUP_STATE[name] == nil then
		GROUP_STATE[name] = "expanded"
	end
	GROUP_REGISTRY[name] = true
end

local groups_registered_from_layout = false

function register_groups_from_layout()
	if groups_registered_from_layout then return end
	if not layout then return end
	for _, entry in ipairs(layout) do
		if entry.group then
			register_group(entry.group)
		end
	end
	groups_registered_from_layout = true
	rebuild_layout_index_cache()
end

-- ──────────────────────────────────────────────────────────
-- GROUP VISIBILITY — based on draw_me (pre-filtered list)
-- ──────────────────────────────────────────────────────────

local _last_vis_check = 0

function check_group_visibility()
	local now = os.time()
	if now == _last_vis_check then return end
	_last_vis_check = now
	for _, entry in ipairs(LAYOUT_WITH_DRAW_ME) do
		if entry.group then
			local visible = true
			if type(entry.draw_me) == "function" then
				local ok, r = pcall(entry.draw_me)
				visible = ok and (r == true or r == 1 or r == "1")
			elseif type(entry.draw_me) == "string" then
				visible = conky_parse(entry.draw_me) == "1"
			else
				visible = entry.draw_me == true
			end
			if not visible then
				if GROUP_STATE[entry.group] ~= nil then
					GROUP_HIDDEN_BY_DRAW_ME[entry.group] = GROUP_STATE[entry.group]
					GROUP_STATE[entry.group] = nil
				end
			else
				if GROUP_HIDDEN_BY_DRAW_ME[entry.group] then
					GROUP_STATE[entry.group] = GROUP_HIDDEN_BY_DRAW_ME[entry.group]
					GROUP_HIDDEN_BY_DRAW_ME[entry.group] = nil
				end
			end
		end
	end
end
