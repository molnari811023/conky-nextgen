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
-- surfaces it through individually named Conky functions. String fields go through `safe_str`
-- for translation or fallback handling; numeric fields go through `safe_num`.
--
-- **Exposed/global functions:**
-- - `conky_city_name()` — city display name (defaults to "Unknown City")
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
-- `W.city`, `safe_str()`, `safe_num()`
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
