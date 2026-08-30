--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/weather/airquality.lua — Air-quality and pollen accessor functions for current and hourly data

Provides conky-callable functions that return value+unit strings for pollutants (PM10, PM2.5, CO,
O3, NO2, SO2, dust) and AQI indices (European, US), plus pollen counts (alder, birch, grass,
mugwort, olive, ragweed). Both current-condition and 24-hourly variants are exposed.
]]--

--{{{
-- ## Air Quality Module
--
-- Reads air-quality and pollen data from the global `W.air` table (loaded from airquality.json).
-- Each exposed function returns a formatted string with the numeric value and its unit merged
-- together (e.g. "12.5 µg/m³").
--
-- **Exposed/global functions:**
-- - `conky_air_cur_pm10()` — current PM10 value+unit
-- - `conky_air_cur_pm25()` — current PM2.5 value+unit
-- - `conky_air_cur_co()` — current carbon monoxide value+unit
-- - `conky_air_cur_o3()` — current ozone value+unit
-- - `conky_air_cur_no2()` — current nitrogen dioxide value+unit
-- - `conky_air_cur_so2()` — current sulphur dioxide value+unit
-- - `conky_air_cur_dust()` — current dust value+unit
-- - `conky_air_cur_eaqi()` — current European AQI value+unit
-- - `conky_air_cur_usaqi()` — current US AQI value+unit
-- - `conky_air_cur_alder()` — current alder pollen value+unit
-- - `conky_air_cur_birch()` — current birch pollen value+unit
-- - `conky_air_cur_grass()` — current grass pollen value+unit
-- - `conky_air_cur_mugwort()` — current mugwort pollen value+unit
-- - `conky_air_cur_olive()` — current olive pollen value+unit
-- - `conky_air_cur_ragweed()` — current ragweed pollen value+unit
-- - `conky_air_hour_pm10(i)` — hourly PM10 for hour i (1–24)
-- - `conky_air_hour_pm25(i)` — hourly PM2.5 for hour i
-- - `conky_air_hour_co(i)` — hourly CO for hour i
-- - `conky_air_hour_o3(i)` — hourly O3 for hour i
-- - `conky_air_hour_no2(i)` — hourly NO2 for hour i
-- - `conky_air_hour_so2(i)` — hourly SO2 for hour i
-- - `conky_air_hour_dust(i)` — hourly dust for hour i
-- - `conky_air_hour_eaqi(i)` — hourly European AQI for hour i
-- - `conky_air_hour_usaqi(i)` — hourly US AQI for hour i
-- - `conky_air_hour_alder(i)` — hourly alder pollen for hour i
-- - `conky_air_hour_birch(i)` — hourly birch pollen for hour i
-- - `conky_air_hour_grass(i)` — hourly grass pollen for hour i
-- - `conky_air_hour_mugwort(i)` — hourly mugwort pollen for hour i
-- - `conky_air_hour_olive(i)` — hourly olive pollen for hour i
-- - `conky_air_hour_ragweed(i)` — hourly ragweed pollen for hour i
--
-- **Config/globals used:**
-- `W.air` (table), `W.air.current`, `W.air.hourly`, `W.air.current_units`, `W.air.hourly_units`,
-- `safe_num()`, `get_idx()`
--}}}

--{{{
-- Helper: raw number from air array
--}}}

local function a_cur(key)
	return safe_num((W.air.current or {})[key])
end

local function a_hour(i, key)
	local d = (W.air.hourly or {})[key]
	return safe_num(d and d[get_idx(i)])
end

local function a_units_cur(key)
	local u = (W.air.current_units or {})[key]
	if not u or u == "" then return "" end
	return u
end

local function a_units_hour(key)
	local u = (W.air.hourly_units or {})[key]
	if not u or u == "" then return "" end
	return u
end

local function af(val, u)
	if not u or u == "" then return tostring(val) end
	local sep = u:match("^%a") and " " or ""
	return val .. sep .. u
end

--{{{
-- Air — Current (value+unit merged)
--}}}

function conky_air_cur_pm10()     return af(a_cur("pm10"), a_units_cur("pm10")) end
function conky_air_cur_pm25()     return af(a_cur("pm2_5"), a_units_cur("pm2_5")) end
function conky_air_cur_co()       return af(a_cur("carbon_monoxide"), a_units_cur("carbon_monoxide")) end
function conky_air_cur_o3()       return af(a_cur("ozone"), a_units_cur("ozone")) end
function conky_air_cur_no2()      return af(a_cur("nitrogen_dioxide"), a_units_cur("nitrogen_dioxide")) end
function conky_air_cur_so2()      return af(a_cur("sulphur_dioxide"), a_units_cur("sulphur_dioxide")) end
function conky_air_cur_dust()     return af(a_cur("dust"), a_units_cur("dust")) end
function conky_air_cur_eaqi()     return af(a_cur("european_aqi"), a_units_cur("european_aqi")) end
function conky_air_cur_usaqi()    return af(a_cur("us_aqi"), a_units_cur("us_aqi")) end
function conky_air_cur_alder()    return af(a_cur("alder_pollen"), a_units_cur("alder_pollen")) end
function conky_air_cur_birch()    return af(a_cur("birch_pollen"), a_units_cur("birch_pollen")) end
function conky_air_cur_grass()    return af(a_cur("grass_pollen"), a_units_cur("grass_pollen")) end
function conky_air_cur_mugwort()  return af(a_cur("mugwort_pollen"), a_units_cur("mugwort_pollen")) end
function conky_air_cur_olive()    return af(a_cur("olive_pollen"), a_units_cur("olive_pollen")) end
function conky_air_cur_ragweed()  return af(a_cur("ragweed_pollen"), a_units_cur("ragweed_pollen")) end

--{{{
-- Air — Hourly (value+unit merged, i = 1-24)
--}}}

function conky_air_hour_pm10(i)     return af(a_hour(i, "pm10"), a_units_hour("pm10")) end
function conky_air_hour_pm25(i)     return af(a_hour(i, "pm2_5"), a_units_hour("pm2_5")) end
function conky_air_hour_co(i)       return af(a_hour(i, "carbon_monoxide"), a_units_hour("carbon_monoxide")) end
function conky_air_hour_o3(i)       return af(a_hour(i, "ozone"), a_units_hour("ozone")) end
function conky_air_hour_no2(i)      return af(a_hour(i, "nitrogen_dioxide"), a_units_hour("nitrogen_dioxide")) end
function conky_air_hour_so2(i)      return af(a_hour(i, "sulphur_dioxide"), a_units_hour("sulphur_dioxide")) end
function conky_air_hour_dust(i)     return af(a_hour(i, "dust"), a_units_hour("dust")) end
function conky_air_hour_eaqi(i)     return af(a_hour(i, "european_aqi"), a_units_hour("european_aqi")) end
function conky_air_hour_usaqi(i)    return af(a_hour(i, "us_aqi"), a_units_hour("us_aqi")) end
function conky_air_hour_alder(i)    return af(a_hour(i, "alder_pollen"), a_units_hour("alder_pollen")) end
function conky_air_hour_birch(i)    return af(a_hour(i, "birch_pollen"), a_units_hour("birch_pollen")) end
function conky_air_hour_grass(i)    return af(a_hour(i, "grass_pollen"), a_units_hour("grass_pollen")) end
function conky_air_hour_mugwort(i)  return af(a_hour(i, "mugwort_pollen"), a_units_hour("mugwort_pollen")) end
function conky_air_hour_olive(i)    return af(a_hour(i, "olive_pollen"), a_units_hour("olive_pollen")) end
function conky_air_hour_ragweed(i)  return af(a_hour(i, "ragweed_pollen"), a_units_hour("ragweed_pollen")) end
