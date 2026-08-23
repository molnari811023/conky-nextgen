--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- hardware/sensors.lua — lm-sensors: CPU/NVMe/WiFi temp, fan speed
-- All values read from `sensors` output (2s cache); 0 when unavailable.
-- Callable from Conky:
--   conky_cpu_temp()          → number (°C)
--     CPU package temperature ("Package id 0") in °C.
--   conky_cpu_core_temp(core) → number (°C, 0-indexed)
--     Temperature of one CPU core, 0-indexed (core 0 = first core).
--   conky_nvme_temp()         → number (°C)
--     NVMe drive temperature from the "Composite" sensor.
--   conky_wifi_temp()         → number (°C)
--     WiFi adapter temperature when the driver exposes it (iwlwifi).
--   conky_fan_speed(index)    → number (RPM, 1-based)
--     Fan speed in RPM for the 1-based fan index (fan1, fan2, …).
--
-- Helper:
--   read_sensors_raw() → string (2s cache) — internal to hardware/core.lua.

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
