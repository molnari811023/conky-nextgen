# 7 — weather_daily.lua

## Purpose
Accessor functions for daily forecast data.

## Dependencies
- `4_weather_core` (for `W`, `conky_round`)

## Functions
All functions take a day offset `i` (1 = today, 2 = tomorrow, etc.).

| Function | Returns |
|----------|---------|
| `conky_weather_day_time(i)` | ISO timestamp |
| `conky_weather_day_code(i)` | WMO weather code |
| `conky_weather_day_temp_max(i)` | Max temperature |
| `conky_weather_day_temp_min(i)` | Min temperature |
| `conky_weather_day_sunrise(i)` | Sunrise time (HH:MM) |
| `conky_weather_day_sunset(i)` | Sunset time (HH:MM) |
| `conky_weather_day_daylight(i)` | Daylight duration (s) |
| `conky_weather_day_sunshine(i)` | Sunshine duration (s) |
| `conky_weather_day_uv(i)` | UV index max |
| `conky_weather_day_precip_hours(i)` | Precipitation hours |
