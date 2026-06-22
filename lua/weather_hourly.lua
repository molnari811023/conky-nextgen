function conky_hourly_data()
	return W.weather.hourly or {}
end
local last_idx_check = 0
local cached_start_idx = 1
function get_idx(i)
	local h = conky_hourly_data()
	if not h or not h.time then
		return tonumber(i) or 1
	end
	local now = os.time()
	if now - last_idx_check > 60 then
		for k, t in ipairs(h.time) do
			if t >= (now - 1800) then
				cached_start_idx = k
				break
			end
		end
		last_idx_check = now
	end
	if cached_start_idx < 1 then cached_start_idx = 1 end
	if cached_start_idx > #h.time then cached_start_idx = #h.time end
	return cached_start_idx + (tonumber(i) or 1) - 1
end
function conky_safe_hour(tbl, i)
	return (tbl and tbl[i]) or 0
end
function conky_weather_hour_time(i)
	return conky_safe_hour(conky_hourly_data().time, get_idx(i))
end
function conky_weather_hour_temp(i)
	return conky_round(conky_safe_hour(conky_hourly_data().temperature_2m, get_idx(i)))
end
function conky_weather_hour_humidity(i)
	return conky_round(conky_safe_hour(conky_hourly_data().relative_humidity_2m, get_idx(i)))
end
function conky_weather_hour_dewpoint(i)
	return conky_round(conky_safe_hour(conky_hourly_data().dew_point_2m, get_idx(i)))
end
function conky_weather_hour_apparent(i)
	return conky_round(conky_safe_hour(conky_hourly_data().apparent_temperature, get_idx(i)))
end
function conky_weather_hour_precip_prob(i)
	return conky_round(conky_safe_hour(conky_hourly_data().precipitation_probability, get_idx(i)))
end
function conky_weather_hour_precip(i)
	return conky_safe_hour(conky_hourly_data().precipitation, get_idx(i))
end
function conky_weather_hour_snow(i)
	return conky_safe_hour(conky_hourly_data().snowfall, get_idx(i))
end
function conky_weather_hour_code(i)
	return conky_safe_hour(conky_hourly_data().weather_code, get_idx(i))
end
function conky_weather_hour_clouds(i)
	return conky_round(conky_safe_hour(conky_hourly_data().cloud_cover, get_idx(i)))
end
function conky_weather_hour_pressure_msl(i)
	return conky_round(conky_safe_hour(conky_hourly_data().pressure_msl, get_idx(i)))
end
function conky_weather_hour_surface_pressure(i)
	return conky_round(conky_safe_hour(conky_hourly_data().surface_pressure, get_idx(i)))
end
function conky_weather_hour_visibility(i)
	return conky_round(conky_safe_hour(conky_hourly_data().visibility, get_idx(i)))
end
function conky_weather_hour_wind_speed(i)
	return conky_round(conky_safe_hour(conky_hourly_data().wind_speed_10m, get_idx(i)))
end
function conky_weather_hour_wind_dir(i)
	return conky_safe_hour(conky_hourly_data().wind_direction_10m, get_idx(i))
end
function conky_weather_hour_wind_gust(i)
	return conky_round(conky_safe_hour(conky_hourly_data().wind_gusts_10m, get_idx(i)))
end
function conky_weather_hour_uv(i)
	return conky_round(conky_safe_hour(conky_hourly_data().uv_index, get_idx(i)))
end
function conky_weather_hour_is_day(i)
	return conky_safe_hour(conky_hourly_data().is_day, get_idx(i))
end
function conky_weather_hour_radiation(i)
	return conky_round(conky_safe_hour(conky_hourly_data().direct_radiation, get_idx(i)))
end
