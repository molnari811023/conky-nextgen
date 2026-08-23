--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/moon.lua — Moon data accessors
-- Reads from W.moon (fetched by sh/4_fetch_weather.sh).
-- Uses shared functions from weather/core.lua.
--
-- Callable from Conky:
--   conky_moon_rise_time()        → "HH:MM"
--   conky_moon_rise_azimuth()     → degrees
--   conky_moon_set_time()         → "HH:MM"
--   conky_moon_set_azimuth()      → degrees
--   conky_moon_high_time()        → "HH:MM"
--   conky_moon_high_elevation()   → degrees
--   conky_moon_low_time()         → "HH:MM"
--   conky_moon_low_elevation()    → degrees
--   conky_moon_phase()            → 0-100%
--   need_to_draw_moon_icon()      → bool (for draw_me guard)
--}}}

local function fmt_time(t)
	if type(t) ~= "string" or t == "" then return "" end
	local hh, mm = t:match("T(%d%d):(%d%d)")
	return (hh and mm) and (hh .. ":" .. mm) or t
end

local function moon_data()
	return (W.moon or {}).properties or {}
end

--{{{
-- Moon — Rise/Set
--}}}

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

--{{{
-- Moon — High/Low
--}}}

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

--{{{
-- Moon — Phase (0-100%)
--}}}

function conky_moon_phase()
	local m = moon_data()
	local deg = tonumber(safe_num(m.moonphase, "moon_phase")) or 0
	return ((deg % 360) / 360) * 100
end

--{{{
-- Moon — Arc position helpers
--}}}

local function moon_progress()
	load_weather_data()
	local m = moon_data()
	local rise = m.moonrise and iso_to_mins(m.moonrise.time)
	local set = m.moonset and iso_to_mins(m.moonset.time)
	if not rise or not set then return nil end
	local now = os.date("*t")
	local now_mins = now.hour * 60 + now.min
	if rise < set then
		if now_mins >= rise and now_mins <= set then
			return (now_mins - rise) / (set - rise)
		end
		return nil
	end
	if now_mins >= rise or now_mins <= set then
		local adj_now = now_mins < rise and now_mins + 1440 or now_mins
		return (adj_now - rise) / (set + 1440 - rise)
	end
	return nil
end

function conky_moon_x(cx, r, size)
	local p = moon_progress()
	if not p then return 0 end
	local off = (tonumber(size) or 0) / 2
	return round(arc_x(cx, r, p) - off)
end

function conky_moon_y(cy, r, size)
	local p = moon_progress()
	if not p then return 0 end
	local off = (tonumber(size) or 0) / 2
	return round(arc_y(cy, r, p) - off)
end

--{{{
-- Moon — Visibility check for draw_me
--}}}

function need_to_draw_moon_icon()
	load_weather_data()
	local m = moon_data()
	local rise = m.moonrise and iso_to_mins(m.moonrise.time)
	local set = m.moonset and iso_to_mins(m.moonset.time)
	if not rise or not set then return false end
	local now = os.date("*t")
	local now_mins = now.hour * 60 + now.min
	if rise < set then
		return now_mins >= rise and now_mins <= set
	end
	return now_mins >= rise or now_mins <= set
end
