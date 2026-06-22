--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
]]

-- translate.lua — shared .mo loader and get_tr()
-- Load before weather.lua / spaceweather.lua in standalone mode
-- In production, Conky provides get_tr() natively via STRINGS_MO_PATH


local mo_strings = {}
local function load_mo(path)
	local f = io.open(path, "rb")
	if not f then return end
	local data = f:read("*all")
	f:close()
	local magic = data:byte(1) | (data:byte(2) << 8) | (data:byte(3) << 16) | (data:byte(4) << 24)
	if magic ~= 0x950412de then return end
	local num   = data:byte(9) | (data:byte(10) << 8) | (data:byte(11) << 16) | (data:byte(12) << 24)
	local o_off = data:byte(13) | (data:byte(14) << 8) | (data:byte(15) << 16) | (data:byte(16) << 24)
	local t_off = data:byte(17) | (data:byte(18) << 8) | (data:byte(19) << 16) | (data:byte(20) << 24)
	for i = 0, num - 1 do
		local base = o_off + i * 8
		local o_len = data:byte(base+1) | (data:byte(base+2) << 8) | (data:byte(base+3) << 16) | (data:byte(base+4) << 24)
		local o_pos = data:byte(base+5) | (data:byte(base+6) << 8) | (data:byte(base+7) << 16) | (data:byte(base+8) << 24)
		local key = data:sub(o_pos+1, o_pos + o_len)
		base = t_off + i * 8
		local t_len = data:byte(base+1) | (data:byte(base+2) << 8) | (data:byte(base+3) << 16) | (data:byte(base+4) << 24)
		local t_pos = data:byte(base+5) | (data:byte(base+6) << 8) | (data:byte(base+7) << 16) | (data:byte(base+8) << 24)
		mo_strings[key] = data:sub(t_pos+1, t_pos + t_len)
	end
end

if STRINGS_MO_PATH then
	load_mo(STRINGS_MO_PATH)
end

if not get_tr then
	function get_tr(msgid)
		return mo_strings[msgid] or msgid or ""
	end
end

return true
