--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/air.lua — Air quality accessors (current + hourly)
-- Reads from W.air. Covers PM, gases, pollen, and AQI indices.
-- Pollutant/gas units are locale-dependent — query the matching
-- conky_unit_air_cur_*() / conky_unit_air_hour_*() accessor (e.g.
-- conky_unit_air_cur_pm10) for the active unit string. Missing fields → 0.
-- Callable from Conky (current):
--   conky_air_current_pm10()   → number
--     Current PM10 concentration (unit: conky_unit_air_cur_pm10()).
--   conky_air_current_pm25()   → number
--     Current PM2.5 concentration (unit: conky_unit_air_cur_pm25()).
--   conky_air_current_co()     → number
--     Carbon monoxide level (unit: conky_unit_air_cur_co()).
--   conky_air_current_o3()     → number
--     Ozone level (unit: conky_unit_air_cur_o3()).
--   conky_air_current_no2()    → number
--     Nitrogen dioxide level (unit: conky_unit_air_cur_no2()).
--   conky_air_current_so2()    → number
--     Sulphur dioxide level (unit: conky_unit_air_cur_so2()).
--   conky_air_current_dust()   → number
--     Dust/coarse fraction (unit: conky_unit_air_cur_dust()).
--   conky_air_current_eaqi()   → number
--     European AQI index (unitless).
--   conky_air_current_usaqi()  → number
--     US AQI index (unitless).
--   conky_air_current_alder()  → number
--     Current alder pollen level (unit: conky_unit_air_cur_alder()).
--   conky_air_current_birch()  → number
--     Current birch pollen level (unit: conky_unit_air_cur_birch()).
--   conky_air_current_grass()  → number
--     Current grass pollen level (unit: conky_unit_air_cur_grass()).
--   conky_air_current_mugwort() → number
--     Current mugwort pollen level (unit: conky_unit_air_cur_mugwort()).
--   conky_air_current_olive()  → number
--     Current olive pollen level (unit: conky_unit_air_cur_olive()).
--   conky_air_current_ragweed() → number
--     Current ragweed pollen level (unit: conky_unit_air_cur_ragweed()).
--
-- Callable from Conky (hourly, i = 1-24):
--   conky_air_hour_pm10(i)     → number
--     Hourly PM10 concentration for the i-th slot
--     (unit: conky_unit_air_hour_pm10()).
--   conky_air_hour_pm25(i)     → number
--     Hourly PM2.5 concentration for the i-th slot
--     (unit: conky_unit_air_hour_pm25()).
--   conky_air_hour_co(i)       → number
--     Hourly carbon monoxide level (unit: conky_unit_air_hour_co()).
--   conky_air_hour_o3(i)       → number
--     Hourly ozone level (unit: conky_unit_air_hour_o3()).
--   conky_air_hour_no2(i)      → number
--     Hourly nitrogen dioxide level (unit: conky_unit_air_hour_no2()).
--   conky_air_hour_so2(i)      → number
--     Hourly sulphur dioxide level (unit: conky_unit_air_hour_so2()).
--   conky_air_hour_dust(i)     → number
--     Hourly dust level.
--   conky_air_hour_eaqi(i)     → number
--     Hourly European AQI index (unitless).
--   conky_air_hour_usaqi(i)    → number
--     Hourly US AQI index (unitless).

local function cur_air_data()
	return W.air.current or {}
end
function conky_air_current_pm10()
	return safe_num(cur_air_data().pm10)
end
function conky_air_current_pm25()
	return safe_num(cur_air_data().pm2_5)
end
function conky_air_current_co()
	return safe_num(cur_air_data().carbon_monoxide)
end
function conky_air_current_o3()
	return safe_num(cur_air_data().ozone)
end
function conky_air_current_no2()
	return safe_num(cur_air_data().nitrogen_dioxide)
end
function conky_air_current_so2()
	return safe_num(cur_air_data().sulphur_dioxide)
end
function conky_air_current_dust()
	return safe_num(cur_air_data().dust)
end
function conky_air_current_eaqi()
	return safe_num(cur_air_data().european_aqi)
end
function conky_air_current_usaqi()
	return safe_num(cur_air_data().us_aqi)
end
function conky_air_current_alder()
	return safe_num(cur_air_data().alder_pollen)
end
function conky_air_current_birch()
	return safe_num(cur_air_data().birch_pollen)
end
function conky_air_current_grass()
	return safe_num(cur_air_data().grass_pollen)
end
function conky_air_current_mugwort()
	return safe_num(cur_air_data().mugwort_pollen)
end
function conky_air_current_olive()
	return safe_num(cur_air_data().olive_pollen)
end
function conky_air_current_ragweed()
	return safe_num(cur_air_data().ragweed_pollen)
end
local function air_hourly_data()
	return W.air.hourly or {}
end
function conky_air_hour_pm10(i)
	local d = air_hourly_data()
	return safe_num(d.pm10 and d.pm10[get_idx(i)], "air_hour_pm10")
end
function conky_air_hour_pm25(i)
	local d = air_hourly_data()
	return safe_num(d.pm2_5 and d.pm2_5[get_idx(i)], "air_hour_pm25")
end
function conky_air_hour_co(i)
	local d = air_hourly_data()
	return safe_num(d.carbon_monoxide and d.carbon_monoxide[get_idx(i)], "air_hour_co")
end
function conky_air_hour_o3(i)
	local d = air_hourly_data()
	return safe_num(d.ozone and d.ozone[get_idx(i)], "air_hour_o3")
end
function conky_air_hour_no2(i)
	local d = air_hourly_data()
	return safe_num(d.nitrogen_dioxide and d.nitrogen_dioxide[get_idx(i)], "air_hour_no2")
end
function conky_air_hour_so2(i)
	local d = air_hourly_data()
	return safe_num(d.sulphur_dioxide and d.sulphur_dioxide[get_idx(i)], "air_hour_so2")
end
function conky_air_hour_dust(i)
	local d = air_hourly_data()
	return safe_num(d.dust and d.dust[get_idx(i)], "air_hour_dust")
end
function conky_air_hour_eaqi(i)
	local d = air_hourly_data()
	return safe_num(d.european_aqi and d.european_aqi[get_idx(i)], "air_hour_eaqi")
end
function conky_air_hour_usaqi(i)
	local d = air_hourly_data()
	return safe_num(d.us_aqi and d.us_aqi[get_idx(i)], "air_hour_usaqi")
end
