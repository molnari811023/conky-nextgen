--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- weather/spaceweather.lua — NOAA SWPC space weather data
-- Kp index, solar wind, Bz, X-ray flux, sunspots, G-scales, aurora, alerts.
-- Optional: comment out the require() in main.lua if not needed.

local sw_cache = nil
local sw_cache_time = 0
local sw_cache_mtimes = {}

local sw_files = {
	kp      = JSON_PATH .. "spaceweather_kp.json",
	wind    = JSON_PATH .. "spaceweather_wind.json",
	mag     = JSON_PATH .. "spaceweather_mag.json",
	xray    = JSON_PATH .. "spaceweather_xray.json",
	scales  = JSON_PATH .. "spaceweather_scales.json",
	sunspot = JSON_PATH .. "spaceweather_sunspot.json",
	alerts  = JSON_PATH .. "spaceweather_alerts.json",
}

local function sw_file_mtime(path)
	local attrs = lfs.attributes(path)
	return attrs and attrs.modification or 0
end

local sw_last_mtime_check = 0

local function sw_json_changed()
	local now = os.time()
	if now - sw_last_mtime_check < 5 then return false end
	sw_last_mtime_check = now
	local changed = false
	for _, path in pairs(sw_files) do
		local m = sw_file_mtime(path)
		if (sw_cache_mtimes[path] or 0) ~= m then
			sw_cache_mtimes[path] = m
			changed = true
		end
	end
	return changed
end

function conky_kp_to_g_scale(kp)
	if type(kp) ~= "number" or kp ~= kp then return "G0" end
	if kp >= 9 then return "G5" end
	if kp >= 8 then return "G4" end
	if kp >= 7 then return "G3" end
	if kp >= 6 then return "G2" end
	if kp >= 5 then return "G1" end
	return "G0"
end

function conky_xray_short_class(flux)
	if type(flux) ~= "number" or flux ~= flux or flux <= 0 then return "--" end
	if flux < 1e-8 then return "A" end
	if flux < 1e-7 then return "B" end
	if flux < 1e-6 then return "C" end
	if flux < 1e-5 then return "M" end
	return "X"
end

function conky_xray_full_class(flux)
	if type(flux) ~= "number" or flux ~= flux or flux <= 0 then return "--" end
	local cls, base
	if flux < 1e-8 then cls = "A"; base = 1e-9
	elseif flux < 1e-7 then cls = "B"; base = 1e-8
	elseif flux < 1e-6 then cls = "C"; base = 1e-7
	elseif flux < 1e-5 then cls = "M"; base = 1e-6
	else cls = "X"; base = 1e-5
	end
	return cls .. string.format("%.1f", flux / base)
end

function conky_aurora_visibility_pct(kp, latitude)
	if type(kp) ~= "number" or type(latitude) ~= "number" then return 0 end
	local abs_lat = math.abs(latitude)
	local auroval_lat = 65 - (kp / 2)
	if kp >= 9 then auroval_lat = 30 end
	local distance = math.abs(abs_lat - auroval_lat)
	local vis = math.max(0, 100 - (distance * 2.5))
	if kp >= 7 and abs_lat >= 40 then vis = math.max(vis, 50) end
	if kp >= 8 and abs_lat >= 35 then vis = math.max(vis, 60) end
	if kp >= 9 and abs_lat >= 30 then vis = math.max(vis, 70) end
	return math.floor(vis + 0.5)
end

local function sw_safe(v)
	if v == nil then return 0 end
	if type(v) == "number" and v ~= v then return 0 end
	return v
end

local function sw_safe_str(v)
	if v == nil then return "" end
	return tostring(v)
end

function conky_load_spaceweather()
	local now = os.time()
	if not sw_cache or (now - sw_cache_time > 300) or sw_json_changed() then
		local ok, data = pcall(function()
			local raw = {
				kp      = conky_read_j(sw_files.kp),
				wind    = conky_read_j(sw_files.wind),
				mag     = conky_read_j(sw_files.mag),
				xray    = conky_read_j(sw_files.xray),
				scales  = conky_read_j(sw_files.scales),
				sunspot = conky_read_j(sw_files.sunspot),
				alerts  = conky_read_j(sw_files.alerts),
			}

			if type(raw.xray) == "table" and #raw.xray > 100 then
				local n = #raw.xray
				local t = {}
				for i = n - 99, n do t[#t + 1] = raw.xray[i] end
				raw.xray = t
			end
			if type(raw.sunspot) == "table" and #raw.sunspot > 10 then
				local n = #raw.sunspot
				local t = {}
				for i = n - 9, n do t[#t + 1] = raw.sunspot[i] end
				raw.sunspot = t
			end

			local kp_latest = {}
			if type(raw.kp) == "table" and #raw.kp > 0 then
				local last = raw.kp[#raw.kp]
				kp_latest = {
					value   = sw_safe(last.kp),
					scale   = sw_safe(last.noaa_scale),
					status  = sw_safe_str(last.observed),
					time    = sw_safe_str(last.time_tag),
				}
			end

			local wind_speed = 0
			if type(raw.wind) == "table" and raw.wind.proton_speed then
				wind_speed = sw_safe(raw.wind.proton_speed)
			end

			local bz = 0
			if type(raw.mag) == "table" and raw.mag.bz_gsm then
				bz = sw_safe(raw.mag.bz_gsm)
			end

			local xray_flux = 0
			if type(raw.xray) == "table" then
				for i = #raw.xray, 1, -1 do
					local e = raw.xray[i]
					if type(e) == "table" and e.energy and e.energy:find("0.1") and e.flux then
						xray_flux = sw_safe(e.flux)
						break
					end
				end
				if xray_flux == 0 and #raw.xray > 0 then
					local last = raw.xray[#raw.xray]
					xray_flux = last and sw_safe(last.flux) or 0
				end
			end

			local scales = {}
			if type(raw.scales) == "table" then
				for _, v in pairs(raw.scales) do
					if type(v) == "table" and v.DateStamp then
						table.insert(scales, v)
					end
				end
				table.sort(scales, function(a, b)
					return (a.DateStamp or "") < (b.DateStamp or "")
				end)
			end

			local sunspot_nr = 0
			if type(raw.sunspot) == "table" and #raw.sunspot > 0 then
				local last = raw.sunspot[#raw.sunspot]
				sunspot_nr = last and (sw_safe(last.sunspot) or sw_safe(last.SUNSPOT) or 0) or 0
			end

			local space_weather_alerts = {}
			if type(raw.alerts) == "table" then
				for _, a in ipairs(raw.alerts) do
					if type(a) == "table" and a.message then
						table.insert(space_weather_alerts, {
							message    = sw_safe_str(a.message),
							issue_time = sw_safe_str(a.issue_time),
							severity   = sw_safe_str(a.severity),
						})
					end
				end
			end

			SW = {
				kp       = raw.kp,
				wind     = raw.wind,
				mag      = raw.mag,
				xray     = raw.xray,
				scales   = raw.scales,
				sunspot  = raw.sunspot,
				alerts   = raw.alerts,
				kp_latest = kp_latest,
				wind_speed = wind_speed,
				bz       = bz,
				xray_flux = xray_flux,
				xray_class = conky_xray_short_class(xray_flux),
				xray_full  = conky_xray_full_class(xray_flux),
				g_scale    = kp_latest.scale or conky_kp_to_g_scale(kp_latest.value),
				sunspot_nr = sunspot_nr,
				scales_forecast = scales,
				sw_alerts = space_weather_alerts,
			}
			return SW
		end)
		if ok and data then
			sw_cache = data
			sw_cache_time = now
		end
	end
	return sw_cache
end

function conky_sw_kp()
	local d = conky_load_spaceweather()
	return d and d.kp_latest.value or 0
end

function conky_sw_kp_status()
	local d = conky_load_spaceweather()
	return d and d.kp_latest.status or ""
end

function conky_sw_g_scale()
	local d = conky_load_spaceweather()
	return d and d.g_scale or "G0"
end

function conky_sw_wind_speed()
	local d = conky_load_spaceweather()
	return d and d.wind_speed or 0
end

function conky_sw_bz()
	local d = conky_load_spaceweather()
	return d and d.bz or 0
end

function conky_sw_xray_flux()
	local d = conky_load_spaceweather()
	return d and d.xray_flux or 0
end

function conky_sw_xray_class()
	local d = conky_load_spaceweather()
	return d and d.xray_class or "--"
end

function conky_sw_xray_full()
	local d = conky_load_spaceweather()
	return d and d.xray_full or "--"
end

function conky_sw_sunspot()
	local d = conky_load_spaceweather()
	return d and d.sunspot_nr or 0
end

function conky_sw_aurora_pct()
	local d = conky_load_spaceweather()
	if not d then return 0 end
	return conky_aurora_visibility_pct(d.kp_latest.value, conky_city_lat() or 47.5)
end

function conky_sw_alerts_count()
	local d = conky_load_spaceweather()
	return d and #(d.sw_alerts) or 0
end

function conky_sw_alert_message(i)
	local d = conky_load_spaceweather()
	if not d or not d.sw_alerts then return "" end
	local a = d.sw_alerts[i]
	return a and a.message or ""
end

function conky_sw_alert_severity(i)
	local d = conky_load_spaceweather()
	if not d or not d.sw_alerts then return "" end
	local a = d.sw_alerts[i]
	return a and a.severity or ""
end

function conky_sw_summary()
	local d = conky_load_spaceweather()
	if not d then return "--" end
	local parts = {}
	local kpv = (d.kp_latest and d.kp_latest.value) and tonumber(d.kp_latest.value) or 0
	table.insert(parts, "Kp " .. string.format("%.1f", kpv))
	table.insert(parts, d.g_scale or "--")
	local ws = tonumber(d.wind_speed) or 0
	table.insert(parts, math.floor(ws + 0.5) .. " km/s")
	local bz = tonumber(d.bz) or 0
	if bz >= 0 then
		table.insert(parts, "Bz +" .. string.format("%.1f", bz) .. " nT")
	else
		table.insert(parts, "Bz " .. string.format("%.1f", bz) .. " nT")
	end
	if d.xray_full and d.xray_full ~= "--" then
		table.insert(parts, d.xray_full)
	end
	return table.concat(parts, " ")
end

if JSON_PATH then
	conky_load_spaceweather()
end

return true
