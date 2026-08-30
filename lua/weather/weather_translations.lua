--[[[
lua/weather/weather_translations.lua — Maps weather codes, wind directions, and moon phase to text

Translates WMO weather codes, wind-direction degrees, and moon phase values into localized text
strings using the `conky_get_tr` translation hook (falling back to English message keys).
]]--

--{{{
-- ## Weather Translations Module
--
-- Resolves human-readable (and translatable) descriptors from raw numeric data. WMO codes are
-- mapped through the `WMO_TO_MSGID` table, wind directions through the 16 point `dir_keys`
-- compass, and moon phase percentage to one of the synthesized `MOON_PHASE_TO_MSGID` messages.
-- All values route through `conky_get_tr` for localization and fall back to the message id when
-- no translation function is available.
--
-- **Exposed/global functions:**
-- - `conky_weather_code_text(code)` — translated weather condition text for a WMO code
-- - `conky_wind_direction_text(deg)` — translated compass direction text for degrees
-- - `conky_moon_phase_text()` — translated moon phase text for the current phase
--
-- **Config/globals used:**
-- `WMO_TO_MSGID`, `MOON_PHASE_TO_MSGID`, `dir_keys`, `conky_get_tr()`, `conky_moon_phase()`
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
