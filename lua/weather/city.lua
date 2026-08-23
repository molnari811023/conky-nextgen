--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- weather/city.lua — City metadata accessors
-- Reads from W.city (fetched by sh/4_fetch_weather.sh).
-- Uses shared functions from weather/core.lua.
--
-- Callable from Conky:
--   conky_city_name()       → "Budapest"
--   conky_city_lat()        → 47.49
--   conky_city_lon()        → 19.04
--   conky_city_country()    → "Hungary"
--   conky_city_timezone()   → "Europe/Budapest"
--   conky_city_population() → number
--   conky_city_admin1()     → "Budapest"
--   conky_city_admin2()     → ""
--   conky_city_elevation()  → 102
--   conky_city_postcode(i)  → "1011"
--   conky_city_postcode_count() → number
--}}}

local function city_data()
	return ((W.city or {}).results and W.city.results[1]) or {}
end

--{{{
-- City — String fields
--}}}

function conky_city_name()      local c = city_data() return c.name or "Unknown City" end
function conky_city_country()   return safe_str(city_data().country, "city_country") end
function conky_city_timezone()  return safe_str(city_data().timezone, "city_timezone") end
function conky_city_admin1()    return safe_str(city_data().admin1, "city_admin1") end
function conky_city_admin2()    return safe_str(city_data().admin2, "city_admin2") end

--{{{
-- City — Number fields
--}}}

function conky_city_lat()         return safe_num(city_data().latitude, "city_lat") end
function conky_city_lon()         return safe_num(city_data().longitude, "city_lon") end
function conky_city_elevation()   return safe_num(city_data().elevation, "city_elevation") end
function conky_city_population()  return safe_num(city_data().population, "city_population") end

--{{{
-- City — Postcodes
--}}}

function conky_city_postcode(i)
	local c = city_data()
	return c.postcodes and c.postcodes[i]
end

function conky_city_postcode_count()
	local c = city_data()
	return (c.postcodes and #c.postcodes) or 0
end
