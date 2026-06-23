--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 16_hardware_dmi.lua — System vendor, product, board, BIOS, chassis
function conky_sys_vendor()
	return dmi("sys_vendor")
end
function conky_product_name()
	return dmi("product_name")
end
function conky_product_family()
	return dmi("product_family")
end
function conky_product_sku()
	return dmi("product_sku")
end
function conky_board_name()
	return dmi("board_name")
end
function conky_board_vendor()
	return dmi("board_vendor")
end
function conky_board_version()
	return dmi("board_version")
end
function conky_bios_vendor()
	return dmi("bios_vendor")
end
function conky_bios_version()
	return dmi("bios_version")
end
function conky_bios_date()
	return dmi("bios_date")
end
function conky_bios_release()
	return dmi("bios_release")
end
function conky_chassis_vendor()
	return dmi("chassis_vendor")
end
function conky_chassis_type()
	return dmi("chassis_type")
end

function conky_chassis_type_human()
	local code = dmi("chassis_type")
	return chassis_map[code] or ("Unknown (" .. code .. ")")
end
--}}}
