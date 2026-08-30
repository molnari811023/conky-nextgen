--[[[
lua/hardware/core.lua — Shared utilities: caching, sysfs readers, DMI access, sensor parsing, and update counters.
]]--
--{{{
-- ## Core Utilities Module
--
-- Provides foundational helpers used by every other hardware module: a
-- time-based cache (`cached`), sysfs/proc file readers (`read_file`,
-- `read_num`), DMI field lookup via `/sys/class/dmi/id/`, raw `sensors`
-- output parsing, a generic `pread` wrapper, and pacman update counters
-- read from a temp file.
--
-- **Exposed/global functions:**
-- - `parse_num(v)` — extracts the first numeric value from a string
-- - `dmi(field)` — reads a DMI field from sysfs (cached)
-- - `get_sensor_val(pattern)` — matches a pattern against raw `sensors` output and returns a number
-- - `get_root_device(map, name)` — walks a parent map to find the root block device
-- - `cached(key, interval, f)` — time-based memoization wrapper
-- - `pread(cmd)` — runs a shell command with a 10 s timeout, returns trimmed output
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

-- Raw output of the `sensors` command, cached for 2 seconds.
local function read_sensors_raw()
	return cached("sensors_raw", 2, function()
		return pread("env LANG=C sensors 2>/dev/null")
	end)
end

function get_sensor_val(pattern)
	local s = read_sensors_raw()
	local v = s:match(pattern)
	return tonumber(v)
end

function get_root_device(map, name)
	local cur = map[name]
	if not cur then
		return nil
	end
	while cur.parent and map[cur.parent] do
		cur = map[cur.parent]
	end
	return cur
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

function pread(cmd)
	local f = io.popen("timeout 10 " .. cmd)
	if not f then
		return ""
	end
	local out = f:read("*a") or ""
	f:close()
	return out:gsub("%s+$", "")
end

-- read_file() is defined in core/utils.lua (loaded before hardware)

local function has_cmd(cmd)
	local f = io.popen("command -v " .. cmd .. " 2>/dev/null")
	if not f then return false end
	local r = f:read("*l")
	f:close()
	return r ~= nil
end

function read_num(path)
	local v = read_file(path)
	return tonumber(v and v:match("(%d+)"))
end

local tmp_dir = os.getenv("HOME") .. "/.conky/tmp/"
local updates_file = tmp_dir .. "updates.txt"

function conky_updates_repo()
	local s = read_file(updates_file)
	local n = tonumber(s:match("^(%d+)"))
	return tostring(n) .. " " .. ((n == 1) and "package" or "packages")
end

function conky_updates_aur()
	local s = read_file(updates_file)
	local n = tonumber(s:match("%s(%d+)$"))
	return tostring(n) .. " " .. ((n == 1) and "package" or "packages")
end
