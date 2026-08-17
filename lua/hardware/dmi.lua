--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- hardware/dmi.lua — System vendor, product, board, BIOS, chassis
-- All values read from /sys/class/dmi/id/* and cached. Straight-forward
-- field accessors — pick whichever string you want to display.
-- Callable from Conky:
--   conky_sys_vendor()         → string ("ASUSTeK")
--     System manufacturer from DMI (sys_vendor).
--   conky_product_name()       → string ("ZenBook")
--     Product/model name of the machine (product_name).
--   conky_product_family()     → string
--     Product family name, e.g. "ZenBook" (may be empty).
--   conky_product_sku()        → string
--     Product SKU identifier as set by the vendor.
--   conky_board_name()         → string ("X550ZK")
--     Motherboard model name (board_name).
--   conky_board_vendor()       → string
--     Motherboard manufacturer (board_vendor).
--   conky_board_version()      → string
--     Motherboard version string (board_version).
--   conky_bios_vendor()        → string ("American Megatrends")
--     BIOS/UEFI vendor (bios_vendor).
--   conky_bios_version()       → string
--     BIOS version string (bios_version).
--   conky_bios_date()          → string ("03/15/2019")
--     BIOS release date in the vendor's DMI format (bios_date).
--   conky_bios_release()       → string
--     BIOS release version (bios_release).
--   conky_chassis_vendor()     → string
--     Chassis manufacturer (chassis_vendor).
--   conky_chassis_type()       → string ("10" = Notebook)
--     Raw numeric chassis type code from DMI (chassis_type).
--   conky_chassis_type_human() → string ("Notebook")
--     Human-readable name for the chassis type code, e.g. "Notebook".
--}}}

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
