# 12 — spaceweather.lua

## Purpose
NOAA SWPC space weather data: Kp index, solar wind, magnetic field Bz, X-ray flux, sunspot number, G-scales, aurora visibility, and alerts.

## Dependencies
- `4_weather_core` (for `conky_read_j`, JSON_PATH, `conky_city_lat`)

## Globals
| Name | Description |
|------|-------------|
| `SW` | Space weather data table |

## Functions
| Function | Description |
|----------|-------------|
| `conky_load_spaceweather()` | Load/cache space weather data |
| `conky_update_spaceweather()` | Force reload |
| `conky_sw_kp()` | Current Kp index |
| `conky_sw_kp_status()` | Kp observation status |
| `conky_sw_g_scale()` | NOAA G-scale (G0–G5) |
| `conky_sw_wind_speed()` | Solar wind speed (km/s) |
| `conky_sw_bz()` | Bz component (nT) |
| `conky_sw_xray_flux()` | X-ray flux |
| `conky_sw_xray_class()` | X-ray class (A/B/C/M/X) |
| `conky_sw_xray_full()` | Full X-ray class (e.g. "M3.2") |
| `conky_sw_sunspot()` | Sunspot number |
| `conky_sw_aurora_pct()` | Aurora visibility percentage |
| `conky_sw_alerts_count()` | Number of space weather alerts |
| `conky_sw_alert_message(i)` | Alert message text |
| `conky_sw_alert_severity(i)` | Alert severity |
| `conky_sw_summary()` | One-line summary |

## Utilities
| Function | Description |
|----------|-------------|
| `conky_kp_to_g_scale(kp)` | Convert Kp to G-scale |
| `conky_xray_short_class(flux)` | Short X-ray class |
| `conky_xray_full_class(flux)` | Full X-ray class |
| `conky_aurora_visibility_pct(kp, lat)` | Aurora visibility calculation |
