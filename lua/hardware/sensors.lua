--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/sensors.lua — Hardware sensor readings (CPU, NVMe, WiFi temps and fan speed) via sysfs hwmon.
]]--
--{{{
-- ## Sensors Module
--
-- Discovers sensor paths under `/sys/class/hwmon/` once (cached for 1 hour)
-- and reads millidegree temperature and fan RPM values directly from sysfs
-- (cached for 2 seconds).
--
-- **Exposed/global functions:**
-- - `conky_cpu_temp()` — CPU package temperature in °C
-- - `conky_cpu_core_temp(core)` — temperature of a specific CPU core
-- - `conky_nvme_temp()` — NVMe composite temperature in °C
-- - `conky_wifi_temp()` — WiFi adapter temperature in °C
-- - `conky_fan_speed(index)` — fan RPM for the given fan index (default 1)
--
-- **Config/globals used:**
-- `cached()`, `read_file()`, `read_num()`, `lfs`
--}}}

local function get_hwmon_map()
	return cached("hwmon_map", 3600, function()
		local map = { cores = {}, fans = {} }
		if not lfs or lfs.attributes("/sys/class/hwmon", "mode") ~= "directory" then
			return map
		end
		local entries = {}
		for entry in lfs.dir("/sys/class/hwmon") do
			if entry:match("^hwmon%d+$") then
				entries[#entries + 1] = entry
			end
		end
		table.sort(entries, function(a, b)
			return (tonumber(a:match("%d+")) or 0) < (tonumber(b:match("%d+")) or 0)
		end)
		for _, entry in ipairs(entries) do
			local base = "/sys/class/hwmon/" .. entry .. "/"
			local name = read_file(base .. "name")
			if name == "coretemp" or name == "k10temp" or name == "zenpower" or name == "cpu_thermal" then
				for f in lfs.dir(base) do
					local idx = f:match("^temp(%d+)_input$")
					if idx then
						local label = read_file(base .. "temp" .. idx .. "_label")
						if label:match("^Package id 0") or label:match("^Tctl") or label:match("^Tdie") then
							map.cpu_pkg = base .. f
						else
							local cnum = label:match("^Core%s+(%d+)")
							if cnum then
								map.cores[tonumber(cnum)] = base .. f
							end
						end
					end
				end
				if not map.cpu_pkg and lfs.attributes(base .. "temp1_input", "mode") then
					map.cpu_pkg = base .. "temp1_input"
				end
			elseif name == "nvme" and not map.nvme then
				if lfs.attributes(base .. "temp1_input", "mode") then
					map.nvme = base .. "temp1_input"
				end
			elseif (name:match("^iwlwifi") or name:match("^mt79") or name:match("^ath") or name:match("^rtw")) and not map.wifi then
				if lfs.attributes(base .. "temp1_input", "mode") then
					map.wifi = base .. "temp1_input"
				end
			end
			for f in lfs.dir(base) do
				local fidx = f:match("^fan(%d+)_input$")
				if fidx then
					local n = tonumber(fidx)
					if n and not map.fans[n] then
						map.fans[n] = base .. f
					end
				end
			end
		end
		return map
	end)
end

local function read_temp_sysfs(key, path)
	if not path then return nil end
	return cached(key, 2, function()
		local v = read_num(path)
		if not v then return nil end
		return math.floor((v / 100) + 0.5) / 10
	end)
end

function conky_cpu_temp()
	return read_temp_sysfs("temp_cpu_pkg", get_hwmon_map().cpu_pkg)
end

function conky_cpu_core_temp(core)
	local c = tonumber(core) or 0
	return read_temp_sysfs("temp_cpu_core_" .. c, get_hwmon_map().cores[c])
end

function conky_nvme_temp()
	return read_temp_sysfs("temp_nvme", get_hwmon_map().nvme)
end

function conky_wifi_temp()
	return read_temp_sysfs("temp_wifi", get_hwmon_map().wifi)
end

function conky_fan_speed(index)
	local idx = tonumber(index) or 1
	local path = get_hwmon_map().fans[idx]
	if not path then return nil end
	return cached("fan_speed_" .. idx, 2, function()
		return read_num(path)
	end)
end
