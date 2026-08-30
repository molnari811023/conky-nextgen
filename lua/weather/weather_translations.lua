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
