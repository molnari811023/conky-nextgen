--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/weather_icons.lua — Icon path builders
-- Generates PNG paths for weather, moon, and wind icons.
-- Uses shared functions from weather/core.lua.
--
-- Callable from Conky:
--   conky_icon_current_weather() → "/path/to/100d.png"
--   conky_icon_hour_weather(i)   → "/path/to/3n.png"
--   conky_icon_day_weather(i)    → "/path/to/61d.png"
--   conky_icon_moon()            → "/path/to/4n.png"
--   conky_icon_current_wind()    → "/path/to/green_ne.png"
--   conky_icon_hour_wind(i)      → "/path/to/yellow_sw.png"
--}}}

--{{{
-- Weather icons (WMO code + day/night)
--}}}

local function weather_icon(code, is_day)
	return ICON_BASE .. ICON_THEME .. "/" .. (code or 0) .. ((is_day == 1) and "d.png" or "n.png")
end

function conky_icon_current_weather()
	return weather_icon(
		conky_weather_cur_code and conky_weather_cur_code(),
		conky_weather_cur_is_day and conky_weather_cur_is_day()
	)
end

function conky_icon_hour_weather(i)
	return weather_icon(
		conky_weather_hour_code and conky_weather_hour_code(i),
		conky_weather_hour_is_day and conky_weather_hour_is_day(i)
	)
end

function conky_icon_day_weather(i)
	return weather_icon(
		conky_weather_day_code and conky_weather_day_code(i),
		1
	)
end

--{{{
-- Moon icon (synodic phase → 0-8 index)
--}}}

function conky_icon_moon()
	local idx = math.floor(moon_phase_fraction() * 8 + 0.5)
	local lat = (W.city and W.city.latitude) or (conky_city_lat and conky_city_lat()) or 47
	return MOON_ICON_BASE .. idx .. (lat < 0 and "s.png" or "n.png")
end

--{{{
-- Wind icons (speed color + direction compass)
--}}}

function conky_icon_current_wind()
	local s = safe_num((W.weather.current or {}).wind_speed_10m, 0)
	if s <= 0.2 then return WIND_ICON_BASE .. "no_wind.png" end
	return WIND_ICON_BASE .. wind_color(s) .. "_" .. get_wind_dir_code(conky_weather_cur_wind_dir and conky_weather_cur_wind_dir()) .. ".png"
end

function conky_icon_hour_wind(i)
	local s = safe_num((W.weather.hourly or {}).wind_speed_10m and (W.weather.hourly or {}).wind_speed_10m[get_idx(i)], 0)
	if s <= 0.2 then return WIND_ICON_BASE .. "no_wind.png" end
	return WIND_ICON_BASE .. wind_color(s) .. "_" .. get_wind_dir_code(conky_weather_hour_wind_dir and conky_weather_hour_wind_dir(i)) .. ".png"
end
