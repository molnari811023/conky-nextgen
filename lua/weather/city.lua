--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/weather/city.lua — Conky accessors for the currently selected city metadata

Exposes Conky-callable read functions for the first city result stored in the global `W.city`
table: name, country, timezone, administrative divisions, coordinates, elevation, population,
and postal codes.
]]--

--{{{
-- ## City Module
--
-- Reads city metadata from the first entry of `W.city.results` (loaded from city.json) and
-- surfaces it through individually named Conky functions. Required identity and coordinate fields
-- use strict accessors; optional administrative fields use explicit display defaults.
--
-- **Exposed/global functions:**
-- - `conky_city_name()` — required city display name
-- - `conky_city_country()` — country name/code (translated)
-- - `conky_city_timezone()` — IANA timezone string
-- - `conky_city_admin1()` — first administrative division
-- - `conky_city_admin2()` — second administrative division
-- - `conky_city_lat()` — latitude
-- - `conky_city_lon()` — longitude
-- - `conky_city_elevation()` — elevation in metres
-- - `conky_city_population()` — population count
-- - `conky_city_postcode(i)` — i-th postal code
-- - `conky_city_postcode_count()` — number of postal codes
--
-- **Config/globals used:**
-- `W.city`, `require_str()`, `require_num()`, `optional_str()`, `optional_num()`
--}}}

local function city_data()
	return ((W.city or {}).results and W.city.results[1]) or {}
end

--{{{
-- City — String fields
--}}}

function conky_city_name()      return require_str(city_data().name, "city_name") end
function conky_city_country()   return require_str(city_data().country, "city_country") end
function conky_city_timezone()  return require_str(city_data().timezone, "city_timezone") end
function conky_city_admin1()    return optional_str(city_data().admin1, "N/A", "city_admin1") end
function conky_city_admin2()    return optional_str(city_data().admin2, "N/A", "city_admin2") end

--{{{
-- City — Number fields
--}}}

function conky_city_lat()         return require_num(city_data().latitude, "city_lat") end
function conky_city_lon()         return require_num(city_data().longitude, "city_lon") end
function conky_city_elevation()   return optional_num(city_data().elevation, 0, "city_elevation") end
function conky_city_population()  return optional_num(city_data().population, 0, "city_population") end

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
