--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 21_hardware_sensors.lua — lm-sensors: CPU/NVMe/WiFi temp, fan speed
function read_sensors_raw()
	return cached("sensors_raw", 2, function()
		return pread("sensors 2>/dev/null")
	end)
end

function conky_cpu_temp()
	return get_sensor_val("Package id 0:%s+%+(%d+%.?%d*)°C")
end
function conky_cpu_core_temp(core)
	return get_sensor_val("Core%s+" .. core .. ":%s+%+(%d+%.?%d*)°C")
end
function conky_nvme_temp()
	return get_sensor_val("Composite:%s+%+(%d+%.?%d*)°C")
end
function conky_wifi_temp()
	return get_sensor_val("iwlwifi_%d+%-virtual%-0.*temp1:%s+%+(%d+%.?%d*)°C")
end
function conky_fan_speed(index)
	return get_sensor_val("fan" .. (index or 1) .. ":%s+(%d+)")
end
--}}}
