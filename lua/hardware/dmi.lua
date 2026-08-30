--[[[
lua/hardware/dmi.lua — Thin wrappers exposing DMI/SMBIOS fields from sysfs to Conky.
]]--
--{{{
-- ## DMI Module
--
-- Exposes individual `/sys/class/dmi/id/` fields as Conky-callable
-- functions. One function per DMI attribute, plus a human-readable
-- chassis type lookup via the `chassis_map` table from core.lua.
--
-- **Exposed/global functions:**
-- - `conky_sys_vendor()` — system vendor string
-- - `conky_product_name()` — product name
-- - `conky_product_family()` — product family
-- - `conky_product_sku()` — product SKU
-- - `conky_board_name()` — motherboard name
-- - `conky_board_vendor()` — motherboard vendor
-- - `conky_board_version()` — motherboard version
-- - `conky_bios_vendor()` — BIOS vendor
-- - `conky_bios_version()` — BIOS version
-- - `conky_bios_date()` — BIOS release date
-- - `conky_bios_release()` — BIOS release identifier
-- - `conky_chassis_vendor()` — chassis vendor
-- - `conky_chassis_type()` — raw chassis type code
-- - `conky_chassis_type_human()` — human-readable chassis type name
--
-- **Config/globals used:**
-- `dmi()` and `chassis_map` (from core.lua)
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
