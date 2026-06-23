--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 9_weather_sunmoon.lua — Sun & moon rise/set times, moon phase
-- Reads from W.sun and W.moon.

local function fmt_time(t)
	if type(t) ~= "string" or t == "" then
		return ""
	end
	local hh, mm = t:match("T(%d%d):(%d%d)")
	return (hh and mm) and (hh .. ":" .. mm) or t
end
function fmt_unix(ts)
	if not ts or ts == 0 then
		return ""
	end
	return os.date("%H:%M", ts)
end
function conky_moon_data()
	return W.moon.properties or {}
end
function conky_moon_rise_time()
	local m = conky_moon_data()
	return fmt_time(conky_safe_moon(m.moonrise and m.moonrise.time))
end
function conky_moon_rise_azimuth()
	local m = conky_moon_data()
	return conky_safe_moon(m.moonrise and m.moonrise.azimuth)
end
function conky_moon_set_time()
	local m = conky_moon_data()
	return fmt_time(conky_safe_moon(m.moonset and m.moonset.time))
end
function conky_moon_set_azimuth()
	local m = conky_moon_data()
	return conky_safe_moon(m.moonset and m.moonset.azimuth)
end
function conky_moon_high_time()
	local m = conky_moon_data()
	return fmt_time(conky_safe_moon(m.high_moon and m.high_moon.time))
end
function conky_moon_high_elevation()
	local m = conky_moon_data()
	return conky_safe_moon(m.high_moon and m.high_moon.disc_centre_elevation)
end
function conky_moon_low_time()
	local m = conky_moon_data()
	return fmt_time(conky_safe_moon(m.low_moon and m.low_moon.time))
end
function conky_moon_low_elevation()
	local m = conky_moon_data()
	return conky_safe_moon(m.low_moon and m.low_moon.disc_centre_elevation)
end
function conky_safe_moon(v)
	return v or 0
end
function conky_moon_phase()
	local m = conky_moon_data()
	return conky_safe_moon(m.moonphase)
end
function conky_safe_sun(v)
	return v or 0
end
function conky_sun_data()
	return W.sun.properties or {}
end
function conky_sun_rise_time()
	local s = conky_sun_data()
	return fmt_time(conky_safe_sun(s.sunrise and s.sunrise.time))
end
function conky_sun_rise_azimuth()
	local s = conky_sun_data()
	return conky_safe_sun(s.sunrise and s.sunrise.azimuth)
end
function conky_sun_set_time()
	local s = conky_sun_data()
	return fmt_time(conky_safe_sun(s.sunset and s.sunset.time))
end
function conky_sun_set_azimuth()
	local s = conky_sun_data()
	return conky_safe_sun(s.sunset and s.sunset.azimuth)
end
function conky_sun_noon_time()
	local s = conky_sun_data()
	return fmt_time(conky_safe_sun(s.solarnoon and s.solarnoon.time))
end
function conky_sun_noon_elevation()
	local s = conky_sun_data()
	return conky_safe_sun(s.solarnoon and s.solarnoon.disc_centre_elevation)
end
function conky_sun_midnight_time()
	local s = conky_sun_data()
	return fmt_time(conky_safe_sun(s.solarmidnight and s.solarmidnight.time))
end
function conky_sun_midnight_elevation()
	local s = conky_sun_data()
	return conky_safe_sun(s.solarmidnight and s.solarmidnight.disc_centre_elevation)
end
