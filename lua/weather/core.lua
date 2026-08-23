--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/core.lua — Shared weather functions
-- Data loader, time helpers, WMO codes, wind maps, arc helpers.
-- All functions here are global (no conky_ prefix) and used by
-- weather_data.lua, sun.lua, moon.lua, weather_icons.lua, etc.
--}}}

-- ═══ DATA LOADER ═══

local weather_cache_storage = nil
local weather_cache_mtimes = {}
local last_mtime_check = 0

local cached_files = {
	"weather_data.json",
	"airquality.json",
	"sun.json",
	"moon.json",
	"moon_next.json",
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

function read_j(path)
	local f = io.open(path, "r")
	if not f then return {} end
	local c = f:read("*all")
	f:close()
	return json.decode(c) or {}
end

W = W or { weather = {}, air = {}, city = {}, moon = {}, moon_next = {}, sun = {} }

function load_weather_data()
	local now = os.time()
	local diff = now - last_mtime_check
	if not weather_cache_storage or (diff > 5) then
		last_mtime_check = now
		local data = {
			weather   = read_j(JSON_PATH .. "weather_data.json"),
			air       = read_j(JSON_PATH .. "airquality.json"),
			sun       = read_j(JSON_PATH .. "sun.json"),
			moon      = read_j(JSON_PATH .. "moon.json"),
			moon_next = read_j(JSON_PATH .. "moon_next.json"),
			city      = read_j(JSON_PATH .. "city.json"),
		}
		if data then
			weather_cache_storage = data
			W.weather   = data.weather or W.weather
			W.air       = data.air or W.air
			W.city      = data.city or W.city
			W.moon      = data.moon or W.moon
			W.moon_next = data.moon_next or W.moon_next
			W.sun       = data.sun or W.sun
		end
	end
	return weather_cache_storage
end

-- round() is defined in core/utils.lua (loaded before weather)

-- ═══ TIME HELPERS ═══

function fmt_unix(ts)
	if not ts or ts == 0 then return "" end
	return os.date("%H:%M", ts)
end

function iso_to_mins(t)
	if not t then return nil end
	local hh, mm = t:match("T(%d%d):(%d%d)")
	return hh and (tonumber(hh) * 60 + tonumber(mm)) or nil
end

function seconds_to_hour_min(sec)
	if not sec or sec <= 0 then return "0h 00m" end
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	return h .. "h " .. string.format("%02d", m) .. "m"
end

-- ═══ HOUR ALIGNMENT ═══

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

-- ═══ ARC HELPERS ═══

function arc_x(cx, r, p)
	p = tonumber(p) or -1
	if p < 0 then return 0 end
	return round((tonumber(cx) or 0) + (tonumber(r) or 0) * math.cos(math.pi * (1 + p)))
end

function arc_y(cy, r, p)
	p = tonumber(p) or -1
	if p < 0 then return 0 end
	return round((tonumber(cy) or 0) + (tonumber(r) or 0) * math.sin(math.pi * (1 + p)))
end

-- ═══ WMO CODES ═══

WMO_TO_MSGID = {
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

-- ═══ WIND DIRECTION ═══

wind_codes = { "n", "nne", "ne", "ene", "e", "ese", "se", "sse", "s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw" }
dir_keys = { "north", "nne", "ne", "ene", "east", "ese", "se", "sse", "south", "ssw", "sw", "wsw", "west", "wnw", "nw", "nnw" }

function get_wind_dir_code(deg)
	if not deg then return "variable" end
	return wind_codes[math.floor((deg / 22.5) + 0.5) % 16 + 1]
end

function wind_color(s)
	if not s or s <= 0.2 then return "no_wind" end
	if s < 5 then return "green" end
	if s < 15 then return "yellow" end
	return s < 25 and "orange" or "red"
end

-- ═══ MOON PHASE ═══

SYNODIC_MONTH = 29.53058867
MOON_EPOCH = os.time({ year = 2000, month = 1, day = 6, hour = 18, min = 14, sec = 0 })

function moon_phase_fraction()
	return ((os.time() - MOON_EPOCH) / 86400 % SYNODIC_MONTH) / SYNODIC_MONTH
end

MOON_PHASE_TO_MSGID = {
	[0] = "new_moon", [1] = "waxing_crescent", [2] = "first_quarter", [3] = "waxing_gibbous",
	[4] = "full_moon", [5] = "waning_gibbous", [6] = "last_quarter", [7] = "waning_crescent", [8] = "waning_crescent",
}

-- ═══ DAY NAMES ═══

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

-- ═══ GLOBAL ALIASES ═══

conky_load_weather_data = load_weather_data

-- ═══ AUTO-LOAD ═══

if JSON_PATH then
	load_weather_data()
end
