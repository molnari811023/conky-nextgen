# 5 — weather_current.lua

## Purpose
Accessor functions for current weather data from `W.weather.current`.

## Dependencies
- `4_weather_core` (for `W`, `conky_round`)

## Functions

| Function | Returns |
|----------|---------|
| `conky_weather_current_time()` | ISO timestamp |
| `conky_weather_current_temp()` | Temperature (°C) |
| `conky_weather_current_humidity()` | Relative humidity (%) |
| `conky_weather_current_apparent()` | Apparent temperature |
| `conky_weather_current_is_day()` | 1 = day, 0 = night |
| `conky_weather_current_precip()` | Precipitation (mm) |
| `conky_weather_current_snow()` | Snowfall (cm) |
| `conky_weather_current_code()` | WMO weather code |
| `conky_weather_current_clouds()` | Cloud cover (%) |
| `conky_weather_current_pressure_msl()` | Pressure (hPa) |
| `conky_weather_current_visibility()` | Visibility (m) |
| `conky_weather_current_uv()` | UV index |
| `conky_weather_current_radiation()` | Direct radiation (W/m²) |
| `conky_weather_current_wind_speed()` | Wind speed (km/h) |
| `conky_weather_current_wind_dir()` | Wind direction (degrees) |
| `conky_weather_current_wind_gust()` | Wind gust (km/h) |
| `conky_weather_current_dewpoint()` | Dew point (°C) |
| `conky_weather_current_precip_prob()` | Precipitation probability (%) |
