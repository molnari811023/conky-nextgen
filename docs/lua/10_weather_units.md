# 10 — weather_units.lua

## Purpose
Returns unit labels for weather and city data. Dynamically generates `conky_unit_*` accessors from `cur_map`, `hour_map`, `air_cur_map`, `air_hour_map`, and `city_map`.

## Dependencies
- `4_weather_core` (for `cur_map`, `hour_map`, `conky_units_*`)
- `8_weather_air` (for `air_*` helpers)

## Generated Functions

| Pattern | Example |
|---------|---------|
| `conky_unit_cur_<field>` | `conky_unit_cur_temp()` → "°C" |
| `conky_unit_hour_<field>` | `conky_unit_hour_wind_speed()` → "km/h" |
| `conky_unit_air_cur_<field>` | `conky_unit_air_cur_pm10()` → "µg/m³" |
| `conky_unit_air_hour_<field>` | `conky_unit_air_hour_pm25()` → "µg/m³" |
| `conky_city_<field>` | `conky_city_name()` → "Vienna" |

### City Functions
| Function | Description |
|----------|-------------|
| `conky_city_name()` | City name |
| `conky_city_lat()` | Latitude |
| `conky_city_lon()` | Longitude |
| `conky_city_elevation()` | Elevation (m) |
| `conky_city_timezone()` | Timezone string |
| `conky_city_country()` | Country name |
| `conky_city_country_code()` | Country code |
| `conky_city_admin1()` | State/region |
| `conky_city_population()` | Population |
| `conky_city_postcode(i)` | Postcode by index |
| `conky_city_postcode_count()` | Number of postcodes |
