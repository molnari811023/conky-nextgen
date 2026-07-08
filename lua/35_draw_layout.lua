--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 35_draw_layout.lua — Dynamic y-position layout engine
-- Computes y_start_<name> and height_<name> globals from layout[].
DynamicLayout = DynamicLayout or {}

local PADDING = 7

local function eval(v)
	if type(v) == "function" then
		return v()
	end
	return v
end

function DynamicLayout.compute(list, start_y)
	if not list then
		return
	end
	
	_G.y_end_dynamic = start_y or 0
	local y = start_y or 0
	
	for _, box in ipairs(list) do
		local name = box.name
		local enabled = box.enabled
		local view = box.view
		local group = box.group
		
		if draw_allowed(enabled, view, group) and name then
			local h = eval(box.height) or 0
			_G["y_start_" .. name] = y
			_G["height_" .. name] = h
			y = y + h + PADDING
			_G.y_end_dynamic = y
		end
	end
end