--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- weather/current.lua — Current weather field accessors
-- Reads from W.weather.current (populated by 4_weather_core).

function conky_safe_cur(v)
	return v or 0
end
function conky_cur_data()
	return W.weather.current or {}
end
function conky_weather_current_time()
	return conky_safe_cur(conky_cur_data().time)
end
function conky_weather_current_interval()
	return conky_safe_cur(conky_cur_data().interval)
end
function conky_weather_current_temp()
	return conky_round(conky_safe_cur(conky_cur_data().temperature_2m))
end
function conky_weather_current_humidity()
	return conky_round(conky_safe_cur(conky_cur_data().relative_humidity_2m))
end
function conky_weather_current_apparent()
	return conky_round(conky_safe_cur(conky_cur_data().apparent_temperature))
end
function conky_weather_current_is_day()
	return conky_safe_cur(conky_cur_data().is_day)
end
function conky_weather_current_precip()
	return conky_safe_cur(conky_cur_data().precipitation)
end
function conky_weather_current_snow()
	return conky_safe_cur(conky_cur_data().snowfall)
end
function conky_weather_current_code()
	return conky_safe_cur(conky_cur_data().weather_code)
end
function conky_weather_current_clouds()
	return conky_round(conky_safe_cur(conky_cur_data().cloud_cover))
end
function conky_weather_current_pressure_msl()
	return conky_round(conky_safe_cur(conky_cur_data().pressure_msl))
end
function conky_weather_current_surface_pressure()
	return conky_round(conky_safe_cur(conky_cur_data().surface_pressure))
end
function conky_weather_current_visibility()
	return conky_round(conky_safe_cur(conky_cur_data().visibility))
end
function conky_weather_current_uv()
	return conky_round(conky_safe_cur(conky_cur_data().uv_index))
end
function conky_weather_current_radiation()
	return conky_round(conky_safe_cur(conky_cur_data().direct_radiation))
end
function conky_weather_current_wind_speed()
	return conky_round(conky_safe_cur(conky_cur_data().wind_speed_10m))
end
function conky_weather_current_wind_dir()
	return conky_safe_cur(conky_cur_data().wind_direction_10m)
end
function conky_weather_current_wind_gust()
	return conky_round(conky_safe_cur(conky_cur_data().wind_gusts_10m))
end
function conky_weather_current_dewpoint()
	return conky_round(conky_safe_cur(conky_cur_data().dew_point_2m))
end
function conky_weather_current_precip_prob()
	return conky_round(conky_safe_cur(conky_cur_data().precipitation_probability))
end
