# 8 — weather_air.lua

## Purpose
Accessor functions for air quality data (current + hourly).

## Dependencies
- `4_weather_core` (for `W`)
- `6_weather_hourly` (for `get_idx`, reused for air hourly indexing)

## Functions (Current)

| Function | Returns |
|----------|---------|
| `conky_air_current_pm10()` | PM10 (µg/m³) |
| `conky_air_current_pm25()` | PM2.5 (µg/m³) |
| `conky_air_current_co()` | Carbon monoxide (µg/m³) |
| `conky_air_current_o3()` | Ozone (µg/m³) |
| `conky_air_current_no2()` | Nitrogen dioxide (µg/m³) |
| `conky_air_current_so2()` | Sulphur dioxide (µg/m³) |
| `conky_air_current_dust()` | Dust (µg/m³) |
| `conky_air_current_eaqi()` | European AQI |
| `conky_air_current_usaqi()` | US AQI |
| `conky_air_current_alder()` | Alder pollen |
| `conky_air_current_birch()` | Birch pollen |
| `conky_air_current_grass()` | Grass pollen |
| `conky_air_current_mugwort()` | Mugwort pollen |
| `conky_air_current_olive()` | Olive pollen |
| `conky_air_current_ragweed()` | Ragweed pollen |

## Functions (Hourly)
Takes index `i` (hour offset). Same fields as current, prefixed `conky_air_hour_*`.
