# 6 — weather_hourly.lua

## Purpose
Accessor functions for hourly forecast data. Uses `get_idx(i)` to align to the nearest hour index.

## Dependencies
- `4_weather_core` (for `W`, `conky_round`)

## Functions
All functions take an hour offset `i` (1 = next hour, 2 = 2 hours from now, etc.).

| Function | Returns |
|----------|---------|
| `conky_weather_hour_time(i)` | ISO timestamp |
| `conky_weather_hour_temp(i)` | Temperature |
| `conky_weather_hour_humidity(i)` | Humidity |
| `conky_weather_hour_dewpoint(i)` | Dew point |
| `conky_weather_hour_apparent(i)` | Apparent temperature |
| `conky_weather_hour_precip_prob(i)` | Precipitation probability |
| `conky_weather_hour_precip(i)` | Precipitation (mm) |
| `conky_weather_hour_snow(i)` | Snowfall (cm) |
| `conky_weather_hour_code(i)` | WMO code |
| `conky_weather_hour_clouds(i)` | Cloud cover |
| `conky_weather_hour_pressure_msl(i)` | Pressure |
| `conky_weather_hour_visibility(i)` | Visibility |
| `conky_weather_hour_wind_speed(i)` | Wind speed |
| `conky_weather_hour_wind_dir(i)` | Wind direction |
| `conky_weather_hour_wind_gust(i)` | Wind gust |
| `conky_weather_hour_uv(i)` | UV index |
| `conky_weather_hour_is_day(i)` | Day/night flag |
| `conky_weather_hour_radiation(i)` | Direct radiation |
