--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- hardware/core.lua — Core utilities: DMI, cache, shell calls, NVIDIA XML
-- Shared by all hardware modules (battery, dmi, info, mtp, network,
-- sensors, usb). Provides pread(), cached(), dmi().
-- Callable from Conky:
--   conky_updates_repo()  → "5 packages"
--     Number of pending package updates from the distro repos, as a
--     human-readable string (e.g. "5 packages"). Fetched in the
--     background by sh/ and cached. Use in a text widget.
--   conky_updates_aur()   → "3 packages"
--     Pending AUR updates, same format as conky_updates_repo().
--
-- Helper functions (used by hardware modules):
--   cached(key, interval, f)  → cached value (TTL-based)
--   pread(cmd)                → string (shell output, timeout 10s)
--   read_file(path)           → string
--   read_num(path)            → number
--   has_cmd(cmd)              → bool
--   dmi(field)                → string (/sys/class/dmi/id/)
--   parse_num(v)              → number
--   starts_with(str, prefix)  → bool
--   get_sensor_val(pattern)   → number
--     Extract a number from the output of `sensors` matching the given
--     Lua pattern (e.g. "Package id 0:%s+%+(%d+%.?%d*)°C"). Used by
--     hardware/sensors.lua; returns 0 when no match is found.
--   get_root_device(map, name) → table
--     Find a device entry by name inside the lsblk JSON map; returns the
--     entry table or nil. Used by hardware/usb.lua.
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
		return pread("sensors 2>/dev/null")
	end)
end

function get_sensor_val(pattern)
	local s = read_sensors_raw()
	local v = s:match(pattern)
	if not v then return "N/A" end
	return tostring(tonumber(v) or "N/A")
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

local source = debug.getinfo(1, "S").source:sub(2)
local conky_dir = source:match("(.*/)") or "./"
local tmp_dir = conky_dir .. "../tmp/"
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
