--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/hourly.lua — Hourly forecast field accessors
-- Uses get_idx(i) to align to the nearest hour. Reads from W.weather.hourly.
-- Temperature/pressure/precip/wind units are locale-dependent — query the
-- matching conky_unit_hour_*() accessor (e.g. conky_unit_hour_temp) for
-- the active unit string.
-- Callable from Conky (i = 1-24, from nearest hour):
--   conky_weather_hour_time(i)         → string (ISO time)
--     Timestamp of the i-th hour slot.
--   conky_weather_hour_temp(i)         → number
--     Air temperature at 2 m (unit: conky_unit_hour_temp()).
--   conky_weather_hour_humidity(i)     → number
--     Relative humidity (unit: conky_unit_hour_humidity()).
--   conky_weather_hour_dewpoint(i)     → number
--     Dew point temperature (unit: conky_unit_hour_dewpoint()).
--   conky_weather_hour_apparent(i)     → number
--     Feels-like temperature (unit: conky_unit_hour_apparent()).
--   conky_weather_hour_precip_prob(i)  → number
--     Precipitation probability for that hour (unitless).
--   conky_weather_hour_precip(i)       → number
--     Expected precipitation amount (unit: conky_unit_hour_precip()).
--   conky_weather_hour_snow(i)         → number
--     Expected snowfall amount (unit: conky_unit_hour_snow()).
--   conky_weather_hour_code(i)         → number (WMO code)
--     WMO weather code for the hour.
--   conky_weather_hour_clouds(i)       → number
--     Cloud cover percentage (unit: conky_unit_hour_clouds()).
--   conky_weather_hour_pressure_msl(i) → number
--     Sea-level air pressure (unit: conky_unit_hour_pressure_msl()).
--   conky_weather_hour_surface_pressure(i) → number
--     Surface pressure (unit: conky_unit_hour_surface_pressure()).
--   conky_weather_hour_visibility(i)   → number
--     Visibility (unit: conky_unit_hour_visibility()).
--   conky_weather_hour_wind_speed(i)   → number
--     Wind speed (unit: conky_unit_hour_wind_speed()).
--   conky_weather_hour_wind_dir(i)     → number (degrees)
--     Wind direction bearing.
--   conky_weather_hour_wind_gust(i)    → number
--     Wind gust speed (unit: conky_unit_hour_wind_gust()).
--   conky_weather_hour_uv(i)           → number
--     UV index (unitless).
--   conky_weather_hour_is_day(i)       → 1|0
--     Whether that hour is daytime.
--   conky_weather_hour_radiation(i)    → number
--     Shortwave solar radiation (unit: conky_unit_hour_radiation()).
--
-- Time alignment is done via get_idx(i) (defined in weather.core).
--}}}

local function hourly_data()
	return W.weather.hourly or {}
end
function conky_weather_hour_time(i)
	return safe_num(hourly_data().time and hourly_data().time[get_idx(i)], "hour_time")
end
function conky_weather_hour_temp(i)
	return conky_round(safe_num(hourly_data().temperature_2m and hourly_data().temperature_2m[get_idx(i)], "hour_temp"))
end
function conky_weather_hour_humidity(i)
	return conky_round(safe_num(hourly_data().relative_humidity_2m and hourly_data().relative_humidity_2m[get_idx(i)], "hour_humidity"))
end
function conky_weather_hour_dewpoint(i)
	return conky_round(safe_num(hourly_data().dew_point_2m and hourly_data().dew_point_2m[get_idx(i)], "hour_dewpoint"))
end
function conky_weather_hour_apparent(i)
	return conky_round(safe_num(hourly_data().apparent_temperature and hourly_data().apparent_temperature[get_idx(i)], "hour_apparent"))
end
function conky_weather_hour_precip_prob(i)
	return conky_round(safe_num(hourly_data().precipitation_probability and hourly_data().precipitation_probability[get_idx(i)], "hour_precip_prob"))
end
function conky_weather_hour_precip(i)
	return safe_num(hourly_data().precipitation and hourly_data().precipitation[get_idx(i)], "hour_precip")
end
function conky_weather_hour_snow(i)
	return safe_num(hourly_data().snowfall and hourly_data().snowfall[get_idx(i)], "hour_snow")
end
function conky_weather_hour_code(i)
	return safe_num(hourly_data().weather_code and hourly_data().weather_code[get_idx(i)], "hour_code")
end
function conky_weather_hour_clouds(i)
	return conky_round(safe_num(hourly_data().cloud_cover and hourly_data().cloud_cover[get_idx(i)], "hour_clouds"))
end
function conky_weather_hour_pressure_msl(i)
	return conky_round(safe_num(hourly_data().pressure_msl and hourly_data().pressure_msl[get_idx(i)], "hour_pressure"))
end
function conky_weather_hour_surface_pressure(i)
	return conky_round(safe_num(hourly_data().surface_pressure and hourly_data().surface_pressure[get_idx(i)], "hour_surface_pressure"))
end
function conky_weather_hour_visibility(i)
	return conky_round(safe_num(hourly_data().visibility and hourly_data().visibility[get_idx(i)], "hour_visibility"))
end
function conky_weather_hour_wind_speed(i)
	return conky_round(safe_num(hourly_data().wind_speed_10m and hourly_data().wind_speed_10m[get_idx(i)], "hour_wind_speed"))
end
function conky_weather_hour_wind_dir(i)
	return safe_num(hourly_data().wind_direction_10m and hourly_data().wind_direction_10m[get_idx(i)], "hour_wind_dir")
end
function conky_weather_hour_wind_gust(i)
	return conky_round(safe_num(hourly_data().wind_gusts_10m and hourly_data().wind_gusts_10m[get_idx(i)], "hour_wind_gust"))
end
function conky_weather_hour_uv(i)
	return conky_round(safe_num(hourly_data().uv_index and hourly_data().uv_index[get_idx(i)], "hour_uv"))
end
function conky_weather_hour_is_day(i)
	return safe_num(hourly_data().is_day and hourly_data().is_day[get_idx(i)], "hour_is_day")
end
function conky_weather_hour_radiation(i)
	return conky_round(safe_num(hourly_data().direct_radiation and hourly_data().direct_radiation[get_idx(i)], "hour_radiation"))
end
