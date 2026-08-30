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
