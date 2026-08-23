--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/weather_translations.lua — Translation functions
-- WMO code text, wind direction text, moon phase text.
-- Uses shared functions from weather/core.lua.
--
-- Callable from Conky:
--   conky_weather_code_text(code)  → "Clear sky"
--   conky_wind_direction_text(deg) → "Northwest"
--   conky_moon_phase_text()        → "Full moon"
--}}}

function conky_weather_code_text(code)
	local msgid = WMO_TO_MSGID[tonumber(code) or 0]
	if not msgid then return "WMO " .. (code or 0) end
	return conky_get_tr and conky_get_tr(msgid) or msgid
end

function conky_wind_direction_text(deg)
	if not deg then return conky_get_tr and conky_get_tr("variable") or "variable" end
	local key = dir_keys[math.floor((deg / 22.5) + 0.5) % 16 + 1]
	return conky_get_tr and conky_get_tr(key) or key
end

function conky_moon_phase_text()
	local p = tonumber(conky_moon_phase and conky_moon_phase() or 0) or 0
	local idx = math.floor((p / 12.5) + 0.5)
	local msgid = MOON_PHASE_TO_MSGID[idx > 8 and 8 or idx] or "no_data"
	return conky_get_tr and conky_get_tr(msgid) or msgid
end
