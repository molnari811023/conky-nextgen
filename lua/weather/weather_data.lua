--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/weather_data.lua — Current + Hourly + Daily weather accessors
-- Reads from W.weather (fetched by sh/4_fetch_weather.sh).
-- Uses shared functions from weather/core.lua (read_j, round, get_idx, etc).
--
-- Each function returns VALUE + UNIT concatenated (e.g. "22°C").
-- Special functions (sunrise, sunset, daylight, sunshine) handle their own formatting.
--
-- Naming convention:
--   conky_weather_cur_*    — current conditions (value+unit)
--   conky_weather_hour_*   — hourly forecast (i = 1-24, value+unit)
--   conky_weather_day_*    — daily forecast (i = 1-7, value+unit)
--}}}

--{{{
-- Internal helpers: value+unit merge
--}}}

local function cur_units()
	return W.weather.current_units or {}
end
local function hour_units()
	return W.weather.hourly_units or {}
end
local function day_units()
	return W.weather.daily_units or {}
end

local function fv(val, units, ukey, no_round)
	local v = no_round and val or round(val)
	local u = units[ukey]
	if not u or u == "" then return tostring(v) end
	local sep = u:match("^%a") and " " or ""
	return v .. sep .. u
end

local function cur(field, no_round)
	return fv(safe_num((W.weather.current or {})[field], "cur_" .. field), cur_units(), field, no_round)
end

local function hour(i, field, no_round)
	local arr = (W.weather.hourly or {})[field]
	return fv(safe_num(arr and arr[get_idx(i)], "hour_" .. field), hour_units(), field, no_round)
end

local function day(i, field, no_round)
	local arr = (W.weather.daily or {})[field]
	local idx = tonumber(i) or 1
	return fv(safe_num(arr and arr[idx], "day_" .. field), day_units(), field, no_round)
end

--{{{
-- Current conditions (value+unit)
--}}}

function conky_weather_cur_time()
	return safe_num((W.weather.current or {}).time, "cur_time")
end
function conky_weather_cur_interval()
	return safe_num((W.weather.current or {}).interval, "cur_interval")
end
function conky_weather_cur_temp()
	return cur("temperature_2m")
end
function conky_weather_cur_humidity()
	return cur("relative_humidity_2m")
end
function conky_weather_cur_apparent()
	return cur("apparent_temperature")
end
function conky_weather_cur_is_day()
	return safe_num((W.weather.current or {}).is_day, "cur_is_day")
end
function conky_weather_cur_precip()
	return cur("precipitation", true)
end
function conky_weather_cur_rain()
	return cur("rain", true)
end
function conky_weather_cur_showers()
	return cur("showers", true)
end
function conky_weather_cur_snow()
	return cur("snowfall", true)
end
function conky_weather_cur_code()
	return safe_num((W.weather.current or {}).weather_code, "cur_code")
end
function conky_weather_cur_clouds()
	return cur("cloud_cover")
end
function conky_weather_cur_pressure()
	return cur("pressure_msl")
end
function conky_weather_cur_surface()
	return cur("surface_pressure")
end
function conky_weather_cur_visibility()
	return cur("visibility")
end
function conky_weather_cur_uv()
	return cur("uv_index")
end
function conky_weather_cur_radiation()
	return cur("direct_radiation")
end
function conky_weather_cur_wind_speed()
	return cur("wind_speed_10m")
end
function conky_weather_cur_wind_dir()
	return safe_num((W.weather.current or {}).wind_direction_10m, "cur_wind_dir")
end
function conky_weather_cur_wind_gust()
	return cur("wind_gusts_10m")
end
function conky_weather_cur_dewpoint()
	return cur("dew_point_2m")
end

--{{{
-- Hourly conditions (i = 1-24, value+unit)
--}}}

function conky_weather_hour_time(i)
	local h = (W.weather.hourly or {}).time
	return safe_num(h and h[get_idx(i)], "hour_time")
end
function conky_weather_hour_temp(i)
	return hour(i, "temperature_2m")
end
function conky_weather_hour_humidity(i)
	return hour(i, "relative_humidity_2m")
end
function conky_weather_hour_wind_speed(i)
	return hour(i, "wind_speed_10m")
end
function conky_weather_hour_dewpoint(i)
	return hour(i, "dew_point_2m")
end
function conky_weather_hour_apparent(i)
	return hour(i, "apparent_temperature")
end
function conky_weather_hour_precip_prob(i)
	return hour(i, "precipitation_probability")
end
function conky_weather_hour_precip(i)
	return hour(i, "precipitation", true)
end
function conky_weather_hour_snow(i)
	return hour(i, "snowfall", true)
end
function conky_weather_hour_code(i)
	local h = (W.weather.hourly or {}).weather_code
	return safe_num(h and h[get_idx(i)], "hour_code")
end
function conky_weather_hour_clouds(i)
	return hour(i, "cloud_cover")
end
function conky_weather_hour_pressure(i)
	return hour(i, "pressure_msl")
end
function conky_weather_hour_surface(i)
	return hour(i, "surface_pressure")
end
function conky_weather_hour_visibility(i)
	return hour(i, "visibility")
end
function conky_weather_hour_wind_speed(i)
	return hour(i, "wind_speed_10m")
end
function conky_weather_hour_wind_dir(i)
	local h = (W.weather.hourly or {}).wind_direction_10m
	return safe_num(h and h[get_idx(i)], "hour_wind_dir")
end
function conky_weather_hour_wind_gust(i)
	return hour(i, "wind_gusts_10m")
end
function conky_weather_hour_uv(i)
	return hour(i, "uv_index")
end
function conky_weather_hour_is_day(i)
	local h = (W.weather.hourly or {}).is_day
	return safe_num(h and h[get_idx(i)], "hour_is_day")
end
function conky_weather_hour_radiation(i)
	return hour(i, "direct_radiation")
end

--{{{
-- Daily (i = 1-7, value+unit)
--}}}

function conky_weather_day_time(i)
	local d = (W.weather.daily or {}).time
	return safe_num(d and d[i], "day_time")
end
function conky_weather_day_code(i)
	local d = (W.weather.daily or {}).weather_code
	return safe_num(d and d[i], "day_code")
end
function conky_weather_day_temp_max(i)
	return day(i, "temperature_2m_max")
end
function conky_weather_day_temp_min(i)
	return day(i, "temperature_2m_min")
end
function conky_weather_day_apparent_max(i)
	return day(i, "apparent_temperature_max")
end
function conky_weather_day_apparent_min(i)
	return day(i, "apparent_temperature_min")
end
function conky_weather_day_sunrise(i)
	local d = (W.weather.daily or {}).sunrise
	local idx = tonumber(i) or 1
	return fmt_unix(safe_num(d and d[idx], "day_sunrise"))
end
function conky_weather_day_sunset(i)
	local d = (W.weather.daily or {}).sunset
	local idx = tonumber(i) or 1
	return fmt_unix(safe_num(d and d[idx], "day_sunset"))
end
function conky_weather_day_daylight(i)
	local d = (W.weather.daily or {}).daylight_duration
	local idx = tonumber(i) or 1
	return seconds_to_hour_min(safe_num(d and d[idx], "day_daylight"))
end
function conky_weather_day_sunshine(i)
	local d = (W.weather.daily or {}).sunshine_duration
	local idx = tonumber(i) or 1
	return seconds_to_hour_min(safe_num(d and d[idx], "day_sunshine"))
end
function conky_weather_day_uv(i)
	return day(i, "uv_index_max")
end
function conky_weather_day_uv_clear(i)
	return day(i, "uv_index_clear_sky_max")
end
function conky_weather_day_precip_sum(i)
	return day(i, "precipitation_sum", true)
end
function conky_weather_day_rain_sum(i)
	return day(i, "rain_sum", true)
end
function conky_weather_day_showers_sum(i)
	return day(i, "showers_sum", true)
end
function conky_weather_day_snow_sum(i)
	return day(i, "snowfall_sum", true)
end
function conky_weather_day_precip_hours(i)
	return day(i, "precipitation_hours", true)
end
function conky_weather_day_precip_prob(i)
	return day(i, "precipitation_probability_max")
end
function conky_weather_day_wind_max(i)
	return day(i, "wind_speed_10m_max")
end
function conky_weather_day_gust_max(i)
	return day(i, "wind_gusts_10m_max")
end
function conky_weather_day_wind_dir(i)
	local d = (W.weather.daily or {}).wind_direction_10m_dominant
	local idx = tonumber(i) or 1
	return safe_num(d and d[idx], "day_wind_dir")
end
function conky_weather_day_radiation(i)
	return day(i, "shortwave_radiation_sum", true)
end
function conky_weather_day_et0(i)
	return day(i, "et0_fao_evapotranspiration", true)
end

--{{{
-- Composed wrappers for ${lua} text fields
--}}}
function conky_weather_cur_code_text()
	return conky_weather_code_text(conky_weather_cur_code())
end
function conky_weather_cur_wind_full()
	return conky_weather_cur_wind_speed() .. " " .. conky_wind_direction_text(conky_weather_cur_wind_dir())
end
function conky_weather_hour_code_text(i)
	return conky_weather_code_text(conky_weather_hour_code(i))
end
function conky_weather_hour_precip_icon(i)
	return conky_weather_hour_precip_prob(i) .. "%"
end
function conky_weather_hour_time_str(i)
	local t = conky_weather_hour_time(i)
	return t and os.date("%H:00", t) or "--"
end
function conky_weather_day_code_text(i)
	return conky_weather_code_text(conky_weather_day_code(i))
end
function conky_weather_sunrise(i)
	return conky_weather_day_sunrise(i)
end
function conky_weather_sunset(i)
	return conky_weather_day_sunset(i)
end
function conky_weather_day_uv_text(i)
	return conky_weather_day_uv(i)
end
function conky_weather_day_precip_hours_text(i)
	local arr = (W.weather.daily or {}).precipitation_hours
	local idx = tonumber(i) or 1
	return tostring(round(safe_num(arr and arr[idx], "day_precip_hours")))
end
