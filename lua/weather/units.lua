--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/units.lua — Unit labels for weather + city fields
-- Dynamically generates conky_unit_* and conky_city_* accessors.
-- Auto-generated (from cur_map):
--   conky_unit_cur_temp, conky_unit_cur_humidity, conky_unit_cur_wind_speed, etc.
--   conky_unit_hour_temp, conky_unit_hour_humidity, etc.
--   conky_unit_day_temp_max, conky_unit_day_sunrise, etc.
--   conky_unit_air_cur_pm10, conky_unit_air_hour_pm25, etc.
--
-- City fields:
--   conky_city_name()       → string ("Budapest")
--     Name of the forecast city.
--   conky_city_lat()        → number (47.49)
--     Latitude of the forecast city.
--   conky_city_lon()        → number (19.04)
--     Longitude of the forecast city.
--   conky_city_country()    → string ("Hungary")
--     Country name of the forecast city.
--   conky_city_timezone()   → string ("Europe/Budapest")
--     IANA timezone of the forecast city.
--   conky_city_population() → number
--     Population of the forecast city.
--   conky_city_postcode(i)  → string
--     Postal code of the city from the geocoding result (index 1 = main).

-- ═══ Unitless fields (no unit getter needed) ═══
--}}}

local unitless_keys = {
	is_day = true, uv_index = true, precipitation_probability = true,
	time = true, interval = true,
}

local function make_getter(units_fn, field)
	return function() return safe_str(units_fn()[field], "unit_" .. field) end
end
for k,v in pairs(cur_map) do
	if not unitless_keys[v] then
		_G["conky_unit_cur_"..k] = make_getter(conky_units_cur, v)
	end
end
for k,v in pairs(hour_map) do
	if not unitless_keys[v] then
		_G["conky_unit_hour_"..k] = function() return safe_str(conky_units_hour()[v], "unit_hour_" .. v) end
	end
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
	_G["conky_unit_air_cur_"..k] = function() return safe_str(conky_units_air_cur()[v], "unit_air_cur_" .. v) end
end
air_hour_map = {
	time="time", pm10="pm10", pm25="pm2_5", co="carbon_monoxide", o3="ozone", dust="dust",
	no2="nitrogen_dioxide", so2="sulphur_dioxide", eaqi="european_aqi", usaqi="us_aqi",
	alder="alder_pollen", birch="birch_pollen", grass="grass_pollen", mugwort="mugwort_pollen",
	olive="olive_pollen", ragweed="ragweed_pollen"
}
for k,v in pairs(air_hour_map) do
	_G["conky_unit_air_hour_"..k] = function() return safe_str(conky_units_air_hour()[v], "unit_air_hour_" .. v) end
end
local function city_data() return (W.city.results and W.city.results[1]) or {} end
function conky_city_name() local c = city_data() return c and c.name or "Unknown City" end

city_num_map = {
	lat="latitude", lon="longitude", elevation="elevation",
	population="population", id="id", country_id="country_id",
	admin1_id="admin1_id", admin2_id="admin2_id"
}
city_str_map = {
	timezone="timezone", country="country", country_code="country_code",
	admin1="admin1", admin2="admin2"
}
for k,v in pairs(city_num_map) do
	_G["conky_city_"..k] = function() return safe_num(city_data()[v], "city_" .. v) end
end
for k,v in pairs(city_str_map) do
	_G["conky_city_"..k] = function() return safe_str(city_data()[v], "city_" .. v) end
end

function conky_city_postcode(i)
	local c = city_data()
	return c.postcodes and c.postcodes[i] or ""
end
function conky_city_postcode_count()
	local c = city_data()
	return (c.postcodes and #c.postcodes) or 0
end
