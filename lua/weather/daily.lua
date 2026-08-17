--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/daily.lua — Daily forecast field accessors
-- Reads from W.weather.daily. Index 1 = today. Temperature/pressure units
-- are locale-dependent — query the matching conky_unit_day_*() accessor
-- (e.g. conky_unit_day_temp_max) for the active unit string.
-- Callable from Conky (i = 1-7):
--   conky_weather_day_time(i)         → string ("2024-01-15")
--     Date of the i-th day (ISO format).
--   conky_weather_day_code(i)         → number (WMO code)
--     Dominant WMO weather code for that day.
--   conky_weather_day_temp_max(i)     → number
--     Daytime maximum temperature
--     (unit: conky_unit_day_temp_max()).
--   conky_weather_day_temp_min(i)     → number
--     Night-time minimum temperature
--     (unit: conky_unit_day_temp_min()).
--   conky_weather_day_sunrise(i)      → string ("07:32")
--     Sunrise time as "HH:MM".
--   conky_weather_day_sunset(i)       → string ("16:45")
--     Sunset time as "HH:MM".
--   conky_weather_day_daylight(i)     → number (seconds)
--     Length of daylight in seconds.
--   conky_weather_day_sunshine(i)     → number (seconds)
--     Expected sunshine duration in seconds.
--   conky_weather_day_uv(i)           → number
--     Maximum UV index of the day.
--   conky_weather_day_precip_hours(i) → number (hours)
--     Estimated hours of precipitation.
--}}}

local function daily_data()
	return W.weather.daily or {}
end
function conky_weather_day_time(i)
	local d = daily_data()
	return safe_num(d.time and d.time[i], "day_time")
end
function conky_weather_day_code(i)
	local d = daily_data()
	return safe_num(d.weather_code and d.weather_code[i], "day_code")
end
function conky_weather_day_temp_max(i)
	local d = daily_data()
	return conky_round(safe_num(d.temperature_2m_max and d.temperature_2m_max[i], "day_temp_max"))
end
function conky_weather_day_temp_min(i)
	local d = daily_data()
	return conky_round(safe_num(d.temperature_2m_min and d.temperature_2m_min[i], "day_temp_min"))
end
function conky_weather_day_sunrise(i)
	local d = daily_data()
	return fmt_unix(safe_num(d.sunrise and d.sunrise[i], "day_sunrise"))
end
function conky_weather_day_sunset(i)
	local d = daily_data()
	return fmt_unix(safe_num(d.sunset and d.sunset[i], "day_sunset"))
end
function conky_weather_day_daylight(i)
	local d = daily_data()
	return safe_num(d.daylight_duration and d.daylight_duration[i], "day_daylight")
end
function conky_weather_day_sunshine(i)
	local d = daily_data()
	return safe_num(d.sunshine_duration and d.sunshine_duration[i], "day_sunshine")
end
function conky_weather_day_uv(i)
	local d = daily_data()
	return conky_round(safe_num(d.uv_index_max and d.uv_index_max[i], "day_uv"))
end
function conky_weather_day_precip_hours(i)
	local d = daily_data()
	return safe_num(d.precipitation_hours and d.precipitation_hours[i], "day_precip_hours")
end
