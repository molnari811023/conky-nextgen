--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/current.lua — Current weather field accessors
-- Reads from W.weather.current (fetched by sh/4_fetch_weather.sh, loaded by weather/core.lua).
-- Each call returns a single field of the "current" weather block. Units
-- are locale-dependent (imperial/metric) — query the matching
-- conky_unit_cur_*() accessor (e.g. conky_unit_cur_temp) for the active
-- unit string. Missing fields → 0.
-- Callable from Conky:
--   conky_weather_current_temp()            → number
--     Air temperature at 2 m, rounded to whole degrees.
--     Unit: conky_unit_cur_temp().
--   conky_weather_current_humidity()        → number
--     Relative humidity (unit: conky_unit_cur_humidity()).
--   conky_weather_current_apparent()        → number
--     Feels-like temperature (unit: conky_unit_cur_apparent()).
--   conky_weather_current_is_day()          → 1|0
--     Whether it is currently daytime.
--   conky_weather_current_precip()          → number
--     Precipitation in the current period
--     (unit: conky_unit_cur_precip()).
--   conky_weather_current_snow()            → number
--     Snowfall in the current period (unit: conky_unit_cur_snow()).
--   conky_weather_current_code()            → number (WMO code)
--     WMO weather code (map with conky_weather_code_text).
--   conky_weather_current_clouds()          → number
--     Total cloud cover percentage
--     (unit: conky_unit_cur_clouds()).
--   conky_weather_current_pressure_msl()    → number
--     Sea-level air pressure
--     (unit: conky_unit_cur_pressure_msl()).
--   conky_weather_current_surface_pressure() → number
--     Pressure at the surface
--     (unit: conky_unit_cur_surface_pressure()).
--   conky_weather_current_visibility()      → number
--     Horizontal visibility
--     (unit: conky_unit_cur_visibility()).
--   conky_weather_current_uv()              → number
--     UV index (unitless).
--   conky_weather_current_radiation()       → number
--     Shortwave solar radiation
--     (unit: conky_unit_cur_radiation()).
--   conky_weather_current_wind_speed()      → number
--     Wind speed (unit: conky_unit_cur_wind_speed()).
--   conky_weather_current_wind_dir()        → number (degrees)
--     Wind direction bearing.
--   conky_weather_current_wind_gust()       → number
--     Wind gust speed (unit: conky_unit_cur_wind_gust()).
--   conky_weather_current_dewpoint()        → number
--     Dew point temperature (unit: conky_unit_cur_dewpoint()).
--   conky_weather_current_precip_prob()     → 0 (not available in current)
--     Always 0: probability is only defined for hourly/daily forecasts.
--}}}

local function cur_data()
	return W.weather.current or {}
end
function conky_weather_current_time()
	return safe_num(cur_data().time, "cur_time")
end
function conky_weather_current_interval()
	return safe_num(cur_data().interval, "cur_interval")
end
function conky_weather_current_temp()
	return conky_round(safe_num(cur_data().temperature_2m, "cur_temp"))
end
function conky_weather_current_humidity()
	return conky_round(safe_num(cur_data().relative_humidity_2m, "cur_humidity"))
end
function conky_weather_current_apparent()
	return conky_round(safe_num(cur_data().apparent_temperature, "cur_apparent"))
end
function conky_weather_current_is_day()
	return safe_num(cur_data().is_day, "cur_is_day")
end
function conky_weather_current_precip()
	return safe_num(cur_data().precipitation, "cur_precip")
end
function conky_weather_current_snow()
	return safe_num(cur_data().snowfall, "cur_snow")
end
function conky_weather_current_code()
	return safe_num(cur_data().weather_code, "cur_code")
end
function conky_weather_current_clouds()
	return conky_round(safe_num(cur_data().cloud_cover, "cur_clouds"))
end
function conky_weather_current_pressure_msl()
	return conky_round(safe_num(cur_data().pressure_msl, "cur_pressure_msl"))
end
function conky_weather_current_surface_pressure()
	return conky_round(safe_num(cur_data().surface_pressure, "cur_pressure_surf"))
end
function conky_weather_current_visibility()
	return conky_round(safe_num(cur_data().visibility, "cur_visibility"))
end
function conky_weather_current_uv()
	return conky_round(safe_num(cur_data().uv_index, "cur_uv"))
end
function conky_weather_current_radiation()
	return conky_round(safe_num(cur_data().direct_radiation, "cur_radiation"))
end
function conky_weather_current_wind_speed()
	return conky_round(safe_num(cur_data().wind_speed_10m, "cur_wind_speed"))
end
function conky_weather_current_wind_dir()
	return safe_num(cur_data().wind_direction_10m, "cur_wind_dir")
end
function conky_weather_current_wind_gust()
	return conky_round(safe_num(cur_data().wind_gusts_10m, "cur_wind_gust"))
end
function conky_weather_current_dewpoint()
	return conky_round(safe_num(cur_data().dew_point_2m, "cur_dewpoint"))
end
function conky_weather_current_precip_prob()
	-- precipitation_probability is only available in hourly data, not current
	return 0
end
