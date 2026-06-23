--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 4_weather_core.lua — Weather data loader, WMO codes, sun/moon arcs, icon paths
-- Reads JSON from tmp/ (fetched by sh/all_in_one.sh). Populates global W table.
-- Also handles wind direction, moon phase, and gradient colors.

local weather_cache_storage = nil
local weather_cache_time = 0
local weather_cache_mtimes = {}
local function file_mtime(path)
	local attrs = lfs.attributes(path)
	return attrs and attrs.modification or 0
end
local function get_day_name(d)
	d = d or 0
	local t = os.date("*t", os.time() + d * 86400)
	return os.date("%A", os.time(t))
end
local function get_next_hours(n)
	local h = os.date("*t").hour
	local out = {}
	for i = 1, n do
		out[i] = string.format("%02d:00", (h + i) % 24)
	end
	return out
end
local function json_changed()
	local files = {
		JSON_PATH .. "weather_data.json",
		JSON_PATH .. "airquality.json",
		JSON_PATH .. "sun.json",
		JSON_PATH .. "moon.json",
		JSON_PATH .. "city.json",
	}
	local changed = false
	for _, path in ipairs(files) do
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
	if v >= 0 then
		return math.floor(v + 0.5)
	else
		return math.ceil(v - 0.5)
	end
end
function conky_read_j(path)
	local f = io.open(path, "r")
	if not f then
		return {}
	end
	local c = f:read("*all")
	f:close()
	local ok, r = pcall(json.decode, c)
	return ok and r or {}
end
function conky_load_weather_data()
	local now = os.time()
	if not weather_cache_storage or (now - weather_cache_time > 300) or json_changed() then
		local ok, data = pcall(function()
			local weather = conky_read_j(JSON_PATH .. "weather_data.json")
			local air     = conky_read_j(JSON_PATH .. "airquality.json")
			local sun_j   = conky_read_j(JSON_PATH .. "sun.json")
			local moon_j  = conky_read_j(JSON_PATH .. "moon.json")
			local city_j  = conky_read_j(JSON_PATH .. "city.json")
			return {
				weather = weather,
				air     = air,
				sun     = sun_j,
				moon    = moon_j,
				city    = city_j,
				cur_a   = (air and air.current) or {},
			}
		end)
		if ok and data then
			weather_cache_storage = data
			weather_cache_time = now
		end
	end
	return weather_cache_storage
end
function conky_update_weather()
	conky_load_weather_data()
	conky_update_alerts()
end
function conky_units()
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
local function get_day_entry(tbl, i)
	if type(tbl) ~= "table" then
		return {}
	end
	return tbl[i] or tbl[1] or {}
end
function conky_day_name(o)
	local d = tonumber(o) or 0
	return os.date("%A", os.time() + d * 86400)
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
	if not hh then return nil end
	return tonumber(hh) * 60 + tonumber(mm)
end
function conky_sun_progress()
	local s = conky_sun_data()
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
	local m = conky_moon_data()
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
		local adj_now = now_mins
		if now_mins < rise then adj_now = now_mins + 1440 end
		return (adj_now - rise) / (set + 1440 - rise)
	end
	return -1
end
local function arc_x(cx, r, p)
	if p < 0 then return nil end
	return conky_round(cx + r * math.cos(math.pi * (1 + p)))
end
local function arc_y(cy, r, p)
	if p < 0 then return nil end
	return conky_round(cy + r * math.sin(math.pi * (1 + p)))
end
function conky_sun_arc_x(cx, r)
	return arc_x(cx, r, conky_sun_progress())
end
function conky_sun_arc_y(cy, r)
	return arc_y(cy, r, conky_sun_progress())
end
function conky_moon_arc_x(cx, r)
	return arc_x(cx, r, conky_moon_progress())
end
function conky_moon_arc_y(cy, r)
	return arc_y(cy, r, conky_moon_progress())
end

local function weather_icon(code, is_day)
	local dn = (is_day == 1) and "d" or "n"
	return ICON_BASE .. ICON_THEME .. "/" .. tostring(code) .. dn .. ".png"
end
function conky_icon_current_weather()
	return weather_icon(conky_weather_current_code(), conky_weather_current_is_day())
end
function conky_icon_hour_weather(i)
	return weather_icon(conky_weather_hour_code(i), conky_weather_hour_is_day(i))
end
function conky_icon_day_weather(i)
	return weather_icon(conky_weather_day_code(i), 1)
end
local SYNODIC_MONTH = 29.53058867
local EPOCH = os.time({ year = 2000, month = 1, day = 6, hour = 18, min = 14, sec = 0 })
local function moon_phase_fraction()
	local age = (os.time() - EPOCH) / 86400
	return (age % SYNODIC_MONTH) / SYNODIC_MONTH
end
local function moon_icon_index()
	local f = moon_phase_fraction()
	return math.floor(f * 8 + 0.5)
end
function conky_icon_moon()
	local idx = moon_icon_index()
	local hemi = conky_city_lat() and conky_city_lat() < 0 and "s" or "n"
	return MOON_ICON_BASE .. idx .. hemi .. ".png"
end
local WMO_TO_MSGID = {
	[0] = "clear_sky",
	[1] = "mainly_clear",
	[2] = "partly_cloudy",
	[3] = "overcast",
	[45] = "fog",
	[48] = "depositing_rime_fog",
	[51] = "light_drizzle",
	[53] = "moderate_drizzle",
	[55] = "dense_drizzle",
	[56] = "light_freezing_drizzle",
	[57] = "dense_freezing_drizzle",
	[61] = "slight_rain",
	[63] = "moderate_rain",
	[65] = "heavy_rain",
	[66] = "light_freezing_rain",
	[67] = "heavy_freezing_rain",
	[71] = "slight_snowfall",
	[73] = "moderate_snowfall",
	[75] = "heavy_snowfall",
	[77] = "snow_grains",
	[80] = "slight_rain_showers",
	[81] = "moderate_rain_showers",
	[82] = "violent_rain_showers",
	[85] = "slight_snow_showers",
	[86] = "heavy_snow_showers",
	[95] = "thunderstorm",
	[96] = "thunderstorm_with_slight_hail",
	[99] = "thunderstorm_with_heavy_hail",
}
function conky_weather_code_text(code)
	code = tonumber(code) or 0
	local msgid = WMO_TO_MSGID[code]
	if not msgid then
		return "WMO " .. code
	end
	return get_tr(msgid)
end
local function get_wind_dir_code(deg)
	if not deg then return "variable" end
	local codes = { "n", "nne", "ne", "ene", "e", "ese", "se", "sse", "s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw" }
	local idx = math.floor((deg / 22.5) + 0.5) % 16
	return codes[idx + 1]
end
function conky_wind_direction_text(deg)
	if not deg then return get_tr("variable") end
	local dir_keys = { "north", "nne", "ne", "ene", "east", "ese", "se", "sse", "south", "ssw", "sw", "wsw", "west",
		"wnw", "nw", "nnw" }
	local idx = math.floor((deg / 22.5) + 0.5) % 16
	return get_tr(dir_keys[idx + 1])
end
local function wind_color(s)
	if not s or s <= 0.2 then
		return "no_wind"
	elseif s < 5 then
		return "green"
	elseif s < 15 then
		return "yellow"
	elseif s < 25 then
		return "orange"
	else
		return "red"
	end
end
function conky_icon_current_wind()
	local s = conky_weather_current_wind_speed()
	local d = get_wind_dir_code(conky_weather_current_wind_dir())
	local c = wind_color(s)
	if c == "no_wind" then
		return WIND_ICON_BASE .. "no_wind.png"
	end
	return WIND_ICON_BASE .. c .. "_" .. d .. ".png"
end
function conky_icon_hour_wind(i)
	local s = conky_weather_hour_wind_speed(i)
	local d = get_wind_dir_code(conky_weather_hour_wind_dir(i))
	local c = wind_color(s)
	if c == "no_wind" then
		return WIND_ICON_BASE .. "no_wind.png"
	end
	return WIND_ICON_BASE .. c .. "_" .. d .. ".png"
end
local MOON_PHASE_TO_MSGID = {
	[0] = "new_moon",
	[1] = "waxing_crescent",
	[2] = "first_quarter",
	[3] = "waxing_gibbous",
	[4] = "full_moon",
	[5] = "waning_gibbous",
	[6] = "last_quarter",
	[7] = "waning_crescent",
	[8] = "waning_crescent",
}
function conky_moon_phase_text()
	local p = tonumber(conky_moon_phase()) or 0
	local idx = math.floor((p / 12.5) + 0.5)
	local msgid = MOON_PHASE_TO_MSGID[idx > 8 and 8 or idx]
	return get_tr(msgid or "no_data")
end

local function init_globals()
	local data = conky_load_weather_data()
	if data then
		W = {
			weather = data.weather or {},
			air = data.air or {},
			city = data.city or {},
			moon = data.moon or {},
			sun = data.sun or {},
		}
	end
end

if JSON_PATH then
	init_globals()
end
