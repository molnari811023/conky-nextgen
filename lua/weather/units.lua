--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- weather/units.lua — Unit labels for weather + city fields
-- Dynamically generates conky_unit_* and conky_city_* accessors.

local function make_getter(units_fn, safe_fn, field)
	return function() return safe_fn(units_fn()[field]) end
end
for k,v in pairs(cur_map) do
	_G["conky_unit_cur_"..k] = make_getter(conky_units_cur, conky_safe_cur, v)
end
for k,v in pairs(hour_map) do
	_G["conky_unit_hour_"..k] = function() return conky_safe_hour(conky_units_hour()[v], 1) end
end
function conky_unit_day_time()
	return conky_units_day().time or conky_unit_cur_time()
end
function conky_unit_day_code()
	return conky_units_day().weather_code or conky_unit_cur_code()
end
function conky_unit_day_temp_max()
	return conky_units_day().temperature_2m_max or conky_unit_cur_temp()
end
function conky_unit_day_temp_min()
	return conky_units_day().temperature_2m_min or conky_unit_cur_temp()
end
function conky_unit_day_sunrise()
	return conky_units_day().sunrise or "unixtime"
end
function conky_unit_day_sunset()
	return conky_units_day().sunset or "unixtime"
end
function conky_unit_day_daylight()
	return conky_units_day().daylight_duration or "s"
end
function conky_unit_day_sunshine()
	return conky_units_day().sunshine_duration or "s"
end
function conky_unit_day_uv()
	return conky_units_day().uv_index_max or ""
end
function conky_unit_day_precip_hours()
	return conky_units_day().precipitation_hours or "h"
end
air_cur_map = {
	time="time", interval="interval", pm10="pm10", pm25="pm2_5", co="carbon_monoxide",
	o3="ozone", dust="dust", no2="nitrogen_dioxide", so2="sulphur_dioxide", eaqi="european_aqi",
	usaqi="us_aqi", alder="alder_pollen", birch="birch_pollen", grass="grass_pollen",
	mugwort="mugwort_pollen", olive="olive_pollen", ragweed="ragweed_pollen"
}
for k,v in pairs(air_cur_map) do
	_G["conky_unit_air_cur_"..k] = function() return conky_safe_air(conky_units_air_cur()[v]) end
end
air_hour_map = {
	time="time", pm10="pm10", pm25="pm2_5", co="carbon_monoxide", o3="ozone", dust="dust",
	no2="nitrogen_dioxide", so2="sulphur_dioxide", eaqi="european_aqi", usaqi="us_aqi",
	alder="alder_pollen", birch="birch_pollen", grass="grass_pollen", mugwort="mugwort_pollen",
	olive="olive_pollen", ragweed="ragweed_pollen"
}
for k,v in pairs(air_hour_map) do
	_G["conky_unit_air_hour_"..k] = function() return conky_safe_air(conky_units_air_hour()[v]) end
end
function conky_safe_city(v) return v or 0 end
function conky_city_data() return (W.city.results and W.city.results[1]) or {} end
function conky_city_name() local c = conky_city_data() return c and c.name or "Unknown City" end

city_map = {
	lat="latitude", lon="longitude", elevation="elevation", timezone="timezone",
	country="country", country_code="country_code", admin1="admin1", admin2="admin2",
	population="population", id="id", country_id="country_id", admin1_id="admin1_id",
	admin2_id="admin2_id"
}
for k,v in pairs(city_map) do
	_G["conky_city_"..k] = function() return conky_safe_city(conky_city_data()[v]) end
end

function conky_city_postcode(i)
	local c = conky_city_data()
	return (c.postcodes and conky_safe_city(c.postcodes[i])) or ""
end
function conky_city_postcode_count()
	local c = conky_city_data()
	return (c.postcodes and #c.postcodes) or 0
end
