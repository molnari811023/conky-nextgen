--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/weather/sun.lua — Conky accessors for sun rise/set, noon/midnight, and arc position

Reads sun data from the global `W.sun` table (loaded from sun.json) and exposes functions for
sunrise/sunset times and azimuths, solar noon/midnight times and elevations, arc coordinates
(for drawing the sun along the sky path), and a visibility check for icons.
]]--

--{{{
-- ## Sun Module
--
-- Surfaces solar ephemeris data to Conky. Rise/set and noon/midnight values are read from
-- `W.sun.properties` and formatted as "HH:MM" times or number elevations. Arc helpers
-- (`conky_sun_x/y`) position the sun icon along a progress arc between sunrise and sunset, and
-- `need_to_draw_sun_icon()` reports whether the sun is currently above the horizon.
--
-- **Exposed/global functions:**
-- - `conky_sun_rise_time()` — sunrise time string
-- - `conky_sun_rise_azimuth()` — sunrise azimuth (degrees)
-- - `conky_sun_set_time()` — sunset time string
-- - `conky_sun_set_azimuth()` — sunset azimuth (degrees)
-- - `conky_sun_noon_time()` — solar noon time string
-- - `conky_sun_noon_elevation()` — solar noon disc-centre elevation
-- - `conky_sun_midnight_time()` — solar midnight time string
-- - `conky_sun_midnight_elevation()` — solar midnight disc-centre elevation
-- - `conky_sun_x(cx, r, size)` — arc x for the sun, centered on size/2
-- - `conky_sun_y(cy, r, size)` — arc y for the sun, centered on size/2
-- - `need_to_draw_sun_icon()` — true if the sun is above the horizon
--
-- **Config/globals used:**
-- `W.sun`, `safe_str()`, `safe_num()`, `iso_to_mins()`, `arc_x()`, `arc_y()`, `round()`,
-- `load_weather_data()`
--}}}

local function fmt_time(t)
	if type(t) ~= "string" or t == "" then return "" end
	local hh, mm = t:match("T(%d%d):(%d%d)")
	return (hh and mm) and (hh .. ":" .. mm) or t
end

local function sun_data()
	return (W.sun or {}).properties or {}
end

--{{{
-- Sun — Rise/Set
--}}}

function conky_sun_rise_time()
	local s = sun_data()
	return fmt_time(safe_str(s.sunrise and s.sunrise.time, "sun_rise_time"))
end

function conky_sun_rise_azimuth()
	local s = sun_data()
	return safe_num(s.sunrise and s.sunrise.azimuth, "sun_rise_az")
end

function conky_sun_set_time()
	local s = sun_data()
	return fmt_time(safe_str(s.sunset and s.sunset.time, "sun_set_time"))
end

function conky_sun_set_azimuth()
	local s = sun_data()
	return safe_num(s.sunset and s.sunset.azimuth, "sun_set_az")
end

--{{{
-- Sun — Noon/Midnight
--}}}

function conky_sun_noon_time()
	local s = sun_data()
	return fmt_time(safe_str(s.solarnoon and s.solarnoon.time, "sun_noon_time"))
end

function conky_sun_noon_elevation()
	local s = sun_data()
	return safe_num(s.solarnoon and s.solarnoon.disc_centre_elevation, "sun_noon_elev")
end

function conky_sun_midnight_time()
	local s = sun_data()
	return fmt_time(safe_str(s.solarmidnight and s.solarmidnight.time, "sun_mid_time"))
end

function conky_sun_midnight_elevation()
	local s = sun_data()
	return safe_num(s.solarmidnight and s.solarmidnight.disc_centre_elevation, "sun_mid_elev")
end

--{{{
-- Sun — Arc position helpers
--}}}

local function sun_progress()
	load_weather_data()
	local s = sun_data()
	local rise = s.sunrise and iso_to_mins(s.sunrise.time)
	local set = s.sunset and iso_to_mins(s.sunset.time)
	if not rise or not set then return nil end
	local now = os.date("*t")
	local now_mins = now.hour * 60 + now.min
	local day_len = set - rise
	if day_len <= 0 then return nil end
	if now_mins < rise then return 0 end
	if now_mins > set then return 1 end
	return (now_mins - rise) / day_len
end

function conky_sun_x(cx, r, size)
	local p = sun_progress()
	if not p then return 0 end
	local off = (tonumber(size) or 0) / 2
	return round(arc_x(cx, r, p) - off)
end

function conky_sun_y(cy, r, size)
	local p = sun_progress()
	if not p then return 0 end
	local off = (tonumber(size) or 0) / 2
	return round(arc_y(cy, r, p) - off)
end

--{{{
-- Sun — Visibility check for draw_me
--}}}

function need_to_draw_sun_icon()
	load_weather_data()
	local s = sun_data()
	local rise = s.sunrise and iso_to_mins(s.sunrise.time)
	local set = s.sunset and iso_to_mins(s.sunset.time)
	if not rise or not set then return false end
	local now = os.date("*t")
	local now_mins = now.hour * 60 + now.min
	return now_mins >= rise and now_mins <= set
end
