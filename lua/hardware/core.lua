--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- hardware/core.lua — Core utilities: DMI, cache, shell calls, NVIDIA XML
-- Shared by all 15-23 hardware modules. Provides pread(), cached(), dmi().

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

function get_sensor_val(pattern)
	local s = read_sensors_raw()
	local v = s:match(pattern)
	return tonumber(v) or 0
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

function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return ""
	end
	local out = f:read("*a") or ""
	f:close()
	return out:gsub("%s+$", "")
end

function has_cmd(cmd)
	local f = io.popen("command -v " .. cmd .. " 2>/dev/null")
	if not f then return false end
	local r = f:read("*l")
	f:close()
	return r ~= nil
end

function read_num(path)
	local v = read_file(path)
	return tonumber(v and v:match("(%d+)")) or 0
end

local source = debug.getinfo(1, "S").source:sub(2)
local conky_dir = source:match("(.*/)") or "./"
local tmp_dir = conky_dir .. "../tmp/"
local updates_file = tmp_dir .. "updates.txt"

function conky_updates_repo()
	local s = read_file(updates_file)
	local n = tonumber(s:match("^(%d+)") or 0)
	return tostring(n) .. " " .. ((n == 1) and "package" or "packages")
end

function conky_updates_aur()
	local s = read_file(updates_file)
	local n = tonumber(s:match("%s(%d+)$") or 0)
	return tostring(n) .. " " .. ((n == 1) and "package" or "packages")
end
