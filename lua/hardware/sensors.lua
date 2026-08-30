--[[[
lua/hardware/sensors.lua — Hardware sensor readings (CPU, NVMe, WiFi temps and fan speed) via lm_sensors.
]]--
--{{{
-- ## Sensors Module
--
-- Thin wrappers around `get_sensor_val()` that match specific `sensors`
-- output patterns to return individual temperature or fan speed values.
-- All raw sensor data is cached for 2 seconds by core.lua.
--
-- **Exposed/global functions:**
-- - `conky_cpu_temp()` — CPU package temperature in °C
-- - `conky_cpu_core_temp(core)` — temperature of a specific CPU core
-- - `conky_nvme_temp()` — NVMe composite temperature in °C
-- - `conky_wifi_temp()` — Intel WiFi adapter temperature in °C
-- - `conky_fan_speed(index)` — fan RPM for the given fan index (default 1)
--
-- **Config/globals used:**
-- `get_sensor_val()` (from core.lua)
--}}}

function conky_cpu_temp()
	return get_sensor_val("Package id 0:%s+%+(%d+%.?%d*)%s*C")
end
function conky_cpu_core_temp(core)
	return get_sensor_val("Core%s+" .. core .. ":%s+%+(%d+%.?%d*)%s*C")
end
function conky_nvme_temp()
	return get_sensor_val("Composite:%s+%+(%d+%.?%d*)%s*C")
end
function conky_wifi_temp()
	return get_sensor_val("iwlwifi_%d+%-virtual%-0.*temp1:%s+%+(%d+%.?%d*)%s*C")
end
function conky_fan_speed(index)
	return get_sensor_val("fan" .. (index or 1) .. ":%s+(%d+)")
end
