--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/weather/weather_icons.lua — Computes icon file paths for weather, moon, and wind states

Builds the full file path to the icon image representing the current/hourly/daily weather (WMO
code + day/night variant), the moon phase (synodic index + hemisphere suffix), and wind
conditions (speed color + compass direction).
]]--

--{{{
-- ## Weather Icons Module
--
-- Constructs icon image paths used by the Conky ${image} templates. Weather icons are named by
-- WMO code plus a "d"/"n" day/night suffix under `ICON_BASE`/`ICON_THEME`. The moon icon uses
-- the computed synodic phase (0–8) plus a hemisphere suffix derived from latitude. Wind icons
-- combine a speed color with the compass direction code; calm conditions use a "no_wind" icon.
--
-- **Exposed/global functions:**
-- - `conky_icon_current_weather()` — current conditions icon path
-- - `conky_icon_hour_weather(i)` — hourly conditions icon path
-- - `conky_icon_day_weather(i)` — daily conditions icon path (always day variant)
-- - `conky_icon_moon()` — moon phase icon path
-- - `conky_icon_current_wind()` — current wind icon path
-- - `conky_icon_hour_wind(i)` — hourly wind icon path
-- - `conky_icon_img_line(path, x, y, w, h)` — generic ${image} template line
-- - `conky_icon_img_*_weather/wind/moon(x, y, w, h)` — ${image} template lines
--   ready for Conky ${lua_parse} / conky_parse() injection (Cairo-free icons).
--
-- **Config/globals used:**
-- `ICON_BASE`, `ICON_THEME`, `MOON_ICON_BASE`, `WIND_ICON_BASE`, `W.weather`, `W.city`,
-- `require_num()`, `moon_phase_fraction()`, `wind_color()`, `get_wind_dir_code()`, `get_idx()`,
-- and the `conky_weather_*` / `conky_city_lat` accessors
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
	local s = require_num((W.weather.current or {}).wind_speed_10m, "cur_wind_speed")
	if s <= 0.2 then return WIND_ICON_BASE .. "no_wind.png" end
	return WIND_ICON_BASE .. wind_color(s) .. "_" .. get_wind_dir_code(conky_weather_cur_wind_dir and conky_weather_cur_wind_dir()) .. ".png"
end

function conky_icon_hour_wind(i)
	local s = require_num((W.weather.hourly or {}).wind_speed_10m and (W.weather.hourly or {}).wind_speed_10m[get_idx(i)], "hour_wind_speed")
	if s <= 0.2 then return WIND_ICON_BASE .. "no_wind.png" end
	return WIND_ICON_BASE .. wind_color(s) .. "_" .. get_wind_dir_code(conky_weather_hour_wind_dir and conky_weather_hour_wind_dir(i)) .. ".png"
end

--{{{
-- Image template lines (Cairo-free ${image} injection)
--
-- Build a full Conky ${image} template line for a resolved icon path. The
-- `-n` (no-cache) flag makes Conky re-read the PNG from disk on every update,
-- so a freshly rendered icon file is picked up immediately. These lines are
-- meant to be injected via `${lua_parse}` in conky.text or `conky_parse()`
-- from inside a Lua hook.
--}}}

local function image_line(path, x, y, w, h)
	return "${image " .. path .. " -p " .. x .. "," .. y .. " -s " .. w .. "x" .. h .. " -n}"
end

function conky_icon_img_line(path, x, y, w, h)
	return image_line(path, x, y, w, h)
end

function conky_icon_img_current_weather(x, y, w, h)
	return image_line(conky_icon_current_weather(), x, y, w, h)
end

function conky_icon_img_hour_weather(i, x, y, w, h)
	return image_line(conky_icon_hour_weather(i), x, y, w, h)
end

function conky_icon_img_day_weather(i, x, y, w, h)
	return image_line(conky_icon_day_weather(i), x, y, w, h)
end

function conky_icon_img_moon(x, y, w, h)
	return image_line(conky_icon_moon(), x, y, w, h)
end

function conky_icon_img_current_wind(x, y, w, h)
	return image_line(conky_icon_current_wind(), x, y, w, h)
end

function conky_icon_img_hour_wind(i, x, y, w, h)
	return image_line(conky_icon_hour_wind(i), x, y, w, h)
end
