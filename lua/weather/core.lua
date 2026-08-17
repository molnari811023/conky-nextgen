--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/core.lua — Weather data loader, WMO codes, sun/moon arcs, icon paths
-- Reads JSON from tmp/ (fetched by sh/4_fetch_weather.sh and
-- sh/12_fetch_spaceweather.sh; sh/all_in_one.sh combines all fetches).
-- Populates global W table.
-- Also handles wind direction, moon phase, and gradient colors.
-- Callable from Conky:
--   conky_load_weather_data()     — JSON load + cache
--     Load the weather JSON files from tmp/ into the global W table.
--     Called automatically at startup; safe to call again to refresh.
--   conky_round(v)                → number (rounding)
--     Round a number to an integer, tolerating nil/NaN inputs.
--   conky_read_j(path)            → table (JSON decode)
--     Decode a JSON file into a Lua table (with a 5s file cache).
--
-- Weather text:
--   conky_weather_code_text(code)  → string ("Clear sky")
--     Human-readable label for a WMO weather code.
--   conky_wind_direction_text(deg) → string ("Northwest")
--     Cardinal direction name for a wind bearing in degrees.
--   conky_moon_phase_text()        → string ("Full moon")
--     Textual name of the current moon phase.
--
-- Sun/moon icons:
--   conky_icon_current_weather() → "/path/to/100d.png"
--     Icon path for the current weather (day/night suffix).
--   conky_icon_hour_weather(i)   → "/path/to/3n.png"
--     Icon path for the i-th hourly forecast slot.
--   conky_icon_day_weather(i)    → "/path/to/61d.png"
--     Icon path for the i-th daily forecast slot.
--   conky_icon_moon()            → "/path/to/4n.png"
--     Icon path for the current moon phase.
--   conky_icon_current_wind()    → "/path/to/green_ne.png"
--     Wind-direction arrow icon for the current wind.
--   conky_icon_hour_wind(i)      → "/path/to/yellow_sw.png"
--     Wind-direction arrow icon for the i-th hourly slot.
--
-- Sun/moon arc (0-1 position):
--   conky_sun_progress()          → 0.0-1.0
--     Sun's progress along its daily arc (0 = rise, 1 = set).
--   conky_moon_progress()         → 0.0-1.0 (-1 = not visible)
--     Moon's progress along its daily arc; -1 when the moon is not up.
--   conky_sun_arc_x(cx, r)       → number
--     X position of the sun on an arc centered at cx with radius r.
--   conky_sun_arc_y(cy, r)       → number
--     Y position of the sun on an arc centered at cy with radius r.
--   conky_moon_arc_x(cx, r)      → number
--     X position of the moon on its arc.
--   conky_moon_arc_y(cy, r)      → number
--     Y position of the moon on its arc.
--
-- Day names:
--   conky_day_name(offset)       → string ("Monday")
--     Full weekday name for today + offset days.
--   conky_day_name_short(offset) → string ("Mon")
--     Short (3-letter) weekday name for today + offset days.
--
-- Units:
--   conky_units()     → { cur, hour, day, air_cur, air_hour }
--     The full units table (temperature, wind, precipitation…) for the
--     active locale, one entry per forecast group.
--   conky_units_cur() → table
--     Units for the current weather block (the `cur` entry).
--}}}

local weather_cache_storage = nil
local weather_cache_mtimes = {}
local last_mtime_check = 0

local cached_files = {
	"weather_data.json",
	"airquality.json",
	"sun.json",
	"moon.json",
	"city.json"
}

local function file_mtime(path)
	local attrs = lfs.attributes(path)
	return attrs and attrs.modification or 0
end

local function json_changed()
	local changed = false
	for i = 1, #cached_files do
		local path = JSON_PATH .. cached_files[i]
		local m = file_mtime(path)
		if (weather_cache_mtimes[path] or 0) ~= m then
			weather_cache_mtimes[path] = m
			changed = true
		end
	end
	return changed
end

function conky_round(v)
	if not v or type(v) ~= "number" then return 0 end
	return v >= 0 and math.floor(v + 0.5) or math.ceil(v - 0.5)
end

function conky_read_j(path)
	local f = io.open(path, "r")
	if not f then return {} end
	local c = f:read("*all")
	f:close()
	return json.decode(c) or {}
end

W = W or { weather = {}, air = {}, city = {}, moon = {}, sun = {} }

-- Hour-alignment helper, shared by hourly.lua / air.lua.
-- Maps a 1-based hour offset to the real index in the hourly arrays,
-- aligning i=1 to the nearest forecast hour.
local last_idx_check = 0
local cached_start_idx = 1
function get_idx(i)
	local h = W.weather.hourly
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

-- Shared time helper (used by sunmoon.lua / daily.lua).
-- Converts a unix timestamp to "HH:MM" ("" for 0/nil).
function fmt_unix(ts)
	if not ts or ts == 0 then
		return ""
	end
	return os.date("%H:%M", ts)
end

function conky_load_weather_data()
	local now = os.time()
	if not weather_cache_storage or (now - last_mtime_check > 30) then
		last_mtime_check = now
		if not weather_cache_storage or json_changed() then
			local data = {
				weather = conky_read_j(JSON_PATH .. "weather_data.json"),
				air     = conky_read_j(JSON_PATH .. "airquality.json"),
				sun     = conky_read_j(JSON_PATH .. "sun.json"),
				moon    = conky_read_j(JSON_PATH .. "moon.json"),
				city    = conky_read_j(JSON_PATH .. "city.json"),
			}
			if data then
				weather_cache_storage = data
				W.weather = data.weather or W.weather
				W.air     = data.air or W.air
				W.city    = data.city or W.city
				W.moon    = data.moon or W.moon
				W.sun     = data.sun or W.sun
			end
		end
	end
	return weather_cache_storage
end

function conky_units()
	conky_load_weather_data()
	return {
		cur = W.weather.current_units or {},
		hour = W.weather.hourly_units or {},
		day = W.weather.daily_units or {},
		air_cur = W.air.current_units or {},
		air_hour = W.air.hourly_units or {},
	}
end

function conky_units_cur() return conky_units().cur end
function conky_units_hour() return conky_units().hour end
function conky_units_day() return conky_units().day end
function conky_units_air_cur() return conky_units().air_cur end
function conky_units_air_hour() return conky_units().air_hour end

cur_map = {
	time="time", interval="interval", temp="temperature_2m", humidity="relative_humidity_2m",
	apparent="apparent_temperature", is_day="is_day", precip="precipitation", snow="snowfall",
	code="weather_code", clouds="cloud_cover", pressure_msl="pressure_msl",
	surface_pressure="surface_pressure", wind_speed="wind_speed_10m", wind_dir="wind_direction_10m",
	wind_gust="wind_gusts_10m", dewpoint="dew_point_2m", precip_prob="precipitation_probability",
	visibility="visibility", uv="uv_index", radiation="direct_radiation"
}
hour_map = {
	time="time", temp="temperature_2m", humidity="relative_humidity_2m", dewpoint="dew_point_2m",
	apparent="apparent_temperature", precip_prob="precipitation_probability", precip="precipitation",
	snow="snowfall", code="weather_code", pressure_msl="pressure_msl", surface_pressure="surface_pressure",
	clouds="cloud_cover", visibility="visibility", wind_speed="wind_speed_10m", wind_dir="wind_direction_10m",
	wind_gust="wind_gusts_10m", uv="uv_index", is_day="is_day", radiation="direct_radiation"
}

function conky_day_name(o)
	return os.date("%A", os.time() + (tonumber(o) or 0) * 86400)
end

local short_dayname_cache = {}
local short_dayname_cache_date = 0
function conky_day_name_short(o)
	local d = tonumber(o) or 0
	local now = os.date("*t")
	local today = now.year * 10000 + now.month * 100 + now.day
	if short_dayname_cache_date ~= today then
		short_dayname_cache = {}
		short_dayname_cache_date = today
	end
	if not short_dayname_cache[d] then
		short_dayname_cache[d] = os.date("%a", os.time() + d * 86400)
	end
	return short_dayname_cache[d]
end

local function iso_to_mins(t)
	if not t then return nil end
	local hh, mm = t:match("T(%d%d):(%d%d)")
	return hh and (tonumber(hh) * 60 + tonumber(mm)) or nil
end

function conky_sun_progress()
	conky_load_weather_data()
	local s = (W.sun or {}).properties or {}
	local rise = s.sunrise and iso_to_mins(s.sunrise.time)
	local set = s.sunset and iso_to_mins(s.sunset.time)
	if not rise or not set then return 0.5 end
	local now = os.date("*t")
	local now_mins = now.hour * 60 + now.min
	local day_len = set - rise
	if day_len <= 0 then return 0.5 end
	if now_mins < rise then return 0 end
	if now_mins > set then return 1 end
	return (now_mins - rise) / day_len
end

function conky_moon_progress()
	conky_load_weather_data()
	local m = (W.moon or {}).properties or {}
	local rise = m.moonrise and iso_to_mins(m.moonrise.time)
	local set = m.moonset and iso_to_mins(m.moonset.time)
	if not rise or not set then return -1 end
	local now = os.date("*t")
	local now_mins = now.hour * 60 + now.min
	if rise < set then
		if now_mins < rise or now_mins > set then return -1 end
		return (now_mins - rise) / (set - rise)
	end
	if now_mins >= rise or now_mins <= set then
		local adj_now = now_mins < rise and now_mins + 1440 or now_mins
		return (adj_now - rise) / (set + 1440 - rise)
	end
	return -1
end

local function arc_x(cx, r, p)
	p = tonumber(p) or -1
	if p < 0 then return 0 end
	return conky_round((tonumber(cx) or 0) + (tonumber(r) or 0) * math.cos(math.pi * (1 + p)))
end

local function arc_y(cy, r, p)
	p = tonumber(p) or -1
	if p < 0 then return 0 end
	return conky_round((tonumber(cy) or 0) + (tonumber(r) or 0) * math.sin(math.pi * (1 + p)))
end

function conky_sun_arc_x(cx, r) return arc_x(cx, r, conky_sun_progress()) end
function conky_sun_arc_y(cy, r) return arc_y(cy, r, conky_sun_progress()) end
function conky_moon_arc_x(cx, r) return arc_x(cx, r, conky_moon_progress()) end
function conky_moon_arc_y(cy, r) return arc_y(cy, r, conky_moon_progress()) end

local function weather_icon(code, is_day)
	return ICON_BASE .. ICON_THEME .. "/" .. (code or 0) .. ((is_day == 1) and "d.png" or "n.png")
end

function conky_icon_current_weather()
	return weather_icon(
		conky_weather_current_code and conky_weather_current_code(),
		conky_weather_current_is_day and conky_weather_current_is_day()
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

local SYNODIC_MONTH = 29.53058867
local EPOCH = os.time({ year = 2000, month = 1, day = 6, hour = 18, min = 14, sec = 0 })

local function moon_phase_fraction()
	return ((os.time() - EPOCH) / 86400 % SYNODIC_MONTH) / SYNODIC_MONTH
end

function conky_icon_moon()
	local idx = math.floor(moon_phase_fraction() * 8 + 0.5)
	local lat = (W.city and W.city.latitude) or (conky_city_lat and conky_city_lat()) or 47
	return MOON_ICON_BASE .. idx .. (lat < 0 and "s.png" or "n.png")
end

local WMO_TO_MSGID = {
	[0] = "clear_sky", [1] = "mainly_clear", [2] = "partly_cloudy", [3] = "overcast",
	[45] = "fog", [48] = "depositing_rime_fog", [51] = "light_drizzle", [53] = "moderate_drizzle",
	[55] = "dense_drizzle", [56] = "light_freezing_drizzle", [57] = "dense_freezing_drizzle",
	[61] = "slight_rain", [63] = "moderate_rain", [65] = "heavy_rain", [66] = "light_freezing_rain",
	[67] = "heavy_freezing_rain", [71] = "slight_snowfall", [73] = "moderate_snowfall",
	[75] = "heavy_snowfall", [77] = "snow_grains", [80] = "slight_rain_showers",
	[81] = "moderate_rain_showers", [82] = "violent_rain_showers", [85] = "slight_snow_showers",
	[86] = "heavy_snow_showers", [95] = "thunderstorm", [96] = "thunderstorm_with_slight_hail",
	[99] = "thunderstorm_with_heavy_hail",
}

function conky_weather_code_text(code)
	local msgid = WMO_TO_MSGID[tonumber(code) or 0]
	if not msgid then return "WMO " .. (code or 0) end
	return conky_get_tr and conky_get_tr(msgid) or msgid
end

local wind_codes = { "n", "nne", "ne", "ene", "e", "ese", "se", "sse", "s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw" }
local function get_wind_dir_code(deg)
	if not deg then return "variable" end
	return wind_codes[math.floor((deg / 22.5) + 0.5) % 16 + 1]
end

local dir_keys = { "north", "nne", "ne", "ene", "east", "ese", "se", "sse", "south", "ssw", "sw", "wsw", "west", "wnw", "nw", "nnw" }
function conky_wind_direction_text(deg)
	if not deg then return conky_get_tr and conky_get_tr("variable") or "variable" end
	local key = dir_keys[math.floor((deg / 22.5) + 0.5) % 16 + 1]
	return conky_get_tr and conky_get_tr(key) or key
end

local function wind_color(s)
	if not s or s <= 0.2 then return "no_wind" end
	if s < 5 then return "green" end
	if s < 15 then return "yellow" end
	return s < 25 and "orange" or "red"
end

function conky_icon_current_wind()
	local s = conky_weather_current_wind_speed and conky_weather_current_wind_speed() or 0
	if s <= 0.2 then return WIND_ICON_BASE .. "no_wind.png" end
	return WIND_ICON_BASE .. wind_color(s) .. "_" .. get_wind_dir_code(conky_weather_current_wind_dir and conky_weather_current_wind_dir()) .. ".png"
end

function conky_icon_hour_wind(i)
	local s = conky_weather_hour_wind_speed and conky_weather_hour_wind_speed(i) or 0
	if s <= 0.2 then return WIND_ICON_BASE .. "no_wind.png" end
	return WIND_ICON_BASE .. wind_color(s) .. "_" .. get_wind_dir_code(conky_weather_hour_wind_dir and conky_weather_hour_wind_dir(i)) .. ".png"
end

local MOON_PHASE_TO_MSGID = {
	[0] = "new_moon", [1] = "waxing_crescent", [2] = "first_quarter", [3] = "waxing_gibbous",
	[4] = "full_moon", [5] = "waning_gibbous", [6] = "last_quarter", [7] = "waning_crescent", [8] = "waning_crescent",
}

function conky_moon_phase_text()
	local p = tonumber(conky_moon_phase and conky_moon_phase() or 0) or 0
	local idx = math.floor((p / 12.5) + 0.5)
	local msgid = MOON_PHASE_TO_MSGID[idx > 8 and 8 or idx] or "no_data"
	return conky_get_tr and conky_get_tr(msgid) or msgid
end

if JSON_PATH then
	conky_load_weather_data()
end
