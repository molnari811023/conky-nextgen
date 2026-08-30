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
