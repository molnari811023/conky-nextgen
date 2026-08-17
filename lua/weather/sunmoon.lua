--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/sunmoon.lua — Sun & moon rise/set times, moon phase
-- Reads from W.sun and W.moon.
-- Callable from Conky (Moon):
--   conky_moon_rise_time()        → string ("05:32")
--     Today's moonrise time as "HH:MM".
--   conky_moon_rise_azimuth()     → number (degrees)
--     Azimuth of the moonrise point.
--   conky_moon_set_time()         → string ("15:45")
--     Moonset time as "HH:MM".
--   conky_moon_set_azimuth()      → number (degrees)
--     Azimuth of the moonset point.
--   conky_moon_high_time()        → string ("10:30")
--     Time of the moon's highest point.
--   conky_moon_high_elevation()   → number (degrees)
--     Elevation of the moon at its highest point.
--   conky_moon_low_time()         → string ("22:15")
--     Time of the moon's lowest point.
--   conky_moon_low_elevation()    → number (degrees)
--     Elevation of the moon at its lowest point.
--   conky_moon_phase()            → number (0-100)
--     Moon phase as a percentage (0 = new, 50 = full, 100 = new again).
--
-- Callable from Conky (Sun):
--   conky_sun_rise_time()         → string ("07:32")
--     Sunrise time as "HH:MM".
--   conky_sun_rise_azimuth()      → number (degrees)
--     Azimuth of the sunrise point.
--   conky_sun_set_time()          → string ("16:45")
--     Sunset time as "HH:MM".
--   conky_sun_set_azimuth()       → number (degrees)
--     Azimuth of the sunset point.
--   conky_sun_noon_time()         → string ("12:08")
--     Solar noon time.
--   conky_sun_noon_elevation()    → number (degrees)
--     Sun elevation at solar noon.
--   conky_sun_midnight_time()     → string ("00:12")
--     Solar midnight time.
--   conky_sun_midnight_elevation() → number (degrees)
--     Sun elevation at solar midnight.
--
-- Helper:
--   fmt_unix(ts) → "HH:MM" (unix timestamp → time), defined in weather.core.
--}}}

local function fmt_time(t)
	if type(t) ~= "string" or t == "" then
		return ""
	end
	local hh, mm = t:match("T(%d%d):(%d%d)")
	return (hh and mm) and (hh .. ":" .. mm) or t
end
local function moon_data()
	return W.moon.properties or {}
end
function conky_moon_rise_time()
	local m = moon_data()
	return fmt_time(safe_str(m.moonrise and m.moonrise.time, "moon_rise_time"))
end
function conky_moon_rise_azimuth()
	local m = moon_data()
	return safe_num(m.moonrise and m.moonrise.azimuth, "moon_rise_az")
end
function conky_moon_set_time()
	local m = moon_data()
	return fmt_time(safe_str(m.moonset and m.moonset.time, "moon_set_time"))
end
function conky_moon_set_azimuth()
	local m = moon_data()
	return safe_num(m.moonset and m.moonset.azimuth, "moon_set_az")
end
function conky_moon_high_time()
	local m = moon_data()
	return fmt_time(safe_str(m.high_moon and m.high_moon.time, "moon_high_time"))
end
function conky_moon_high_elevation()
	local m = moon_data()
	return safe_num(m.high_moon and m.high_moon.disc_centre_elevation, "moon_high_elev")
end
function conky_moon_low_time()
	local m = moon_data()
	return fmt_time(safe_str(m.low_moon and m.low_moon.time, "moon_low_time"))
end
function conky_moon_low_elevation()
	local m = moon_data()
	return safe_num(m.low_moon and m.low_moon.disc_centre_elevation, "moon_low_elev")
end
function conky_moon_phase()
	local m = moon_data()
	local deg = tonumber(safe_num(m.moonphase, "moon_phase")) or 0
	return ((deg % 360) / 360) * 100
end
local function sun_data()
	return W.sun.properties or {}
end
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
