--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/core.lua — Shared utilities: caching, sysfs readers, DMI access, and update counters.
]]--
--{{{
-- ## Core Utilities Module
--
-- Provides foundational helpers used by every other hardware module: a
-- time-based cache (`cached`), sysfs/proc file readers (`read_file`,
-- `read_num`), DMI field lookup via `/sys/class/dmi/id/`, and pacman update
-- counters read from a temp file.
--
-- **Exposed/global functions:**
-- - `parse_num(v)` — extracts the first numeric value from a string
-- - `dmi(field)` — reads a DMI field from sysfs (cached)
-- - `cached(key, interval, f)` — time-based memoization wrapper
-- - `read_num(path)` — reads a file and extracts the first integer
-- - `conky_updates_repo()` — returns the number of pending repo packages
-- - `conky_updates_aur()` — returns the number of pending AUR packages
--
-- **Config/globals used:**
-- `static`, `chassis_map`, `cache`, `read_file()` (defined in core/utils.lua), `lfs`
--}}}

static = {}

function parse_num(v)
	return tonumber((v or ""):match("([%d%.]+)")) or 0
end

chassis_map = {
	["1"] = "Other",
	["2"] = "Unknown",
	["3"] = "Desktop",
	["4"] = "Low Profile Desktop",
	["5"] = "Pizza Box",
	["6"] = "Mini Tower",
	["7"] = "Tower",
	["8"] = "Portable",
	["9"] = "Laptop",
	["10"] = "Notebook",
	["11"] = "Handheld",
	["12"] = "Docking Station",
	["13"] = "All-in-One",
	["14"] = "Sub-Notebook",
	["15"] = "Space-saving",
	["16"] = "Lunch Box",
	["17"] = "Main Server Chassis",
	["18"] = "Expansion Chassis",
	["19"] = "Sub-Chassis",
	["20"] = "Bus Expansion Chassis",
	["21"] = "Peripheral Chassis",
	["22"] = "RAID Chassis",
	["23"] = "Rack Mount Chassis",
	["24"] = "Sealed-case PC",
	["25"] = "Multi-system Chassis",
	["26"] = "Compact PCI",
	["27"] = "Advanced TCA",
	["28"] = "Blade",
	["29"] = "Blade Enclosure",
	["30"] = "Tablet",
	["31"] = "Convertible",
	["32"] = "Detachable",
	["33"] = "IoT Gateway",
	["34"] = "Embedded PC",
	["35"] = "Mini PC",
	["36"] = "Stick PC",
}

function starts_with(str, prefix)
	return str:sub(1, #prefix) == prefix
end

function dmi(field)
	return cached("dmi_" .. field, 999999, function()
		return read_file("/sys/class/dmi/id/" .. field)
	end)
end

cache = cache or {}

function cached(key, interval, f)
	local now = os.time()
	local e = cache[key]
	if e and now - e.time < interval then
		return e.value
	end
	local v = f()
	cache[key] = { time = now, value = v }
	return v
end

-- read_file() is defined in core/utils.lua (loaded before hardware)

function read_num(path)
	local v = read_file(path)
	return tonumber(v and v:match("(%d+)"))
end

local source = debug.getinfo(1, "S").source:sub(2)
local conky_dir = source:match("(.*/)") or "./"
local fallback_updates_file = conky_dir .. "../../tmp/updates.txt"

local function get_updates_file()
	if JSON_PATH and JSON_PATH ~= "" then
		local p = JSON_PATH .. "updates.txt"
		if lfs and lfs.attributes(p, "mode") then
			return p
		end
	end
	if lfs and lfs.attributes(fallback_updates_file, "mode") then
		return fallback_updates_file
	end
	return (os.getenv("HOME") or "/tmp") .. "/.conky/tmp/updates.txt"
end

function conky_updates_repo()
	local s = read_file(get_updates_file())
	local n = tonumber(s and s:match("^(%d+)")) or 0
	return tostring(n) .. " " .. conky_get_tr((n == 1) and "package" or "packages")
end

function conky_updates_aur()
	local s = read_file(get_updates_file())
	local n = tonumber(s and s:match("%s(%d+)$")) or 0
	return tostring(n) .. " " .. conky_get_tr((n == 1) and "package" or "packages")
end
