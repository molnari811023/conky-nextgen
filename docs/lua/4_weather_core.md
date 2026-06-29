# 4 — weather_core.lua

## Purpose
Core weather module. Loads and caches weather/air/sun/moon/city JSON data from `tmp/`. Provides data access helpers, icon paths, and sun/moon arc calculations.

## Dependencies
- `1_translate` (for WMO code translations)
- `3_watcher` (for file change detection)
- JSON files in `tmp/` (fetched by `sh/4_fetch_weather.sh` or `sh/0_fetch_all.sh`)

## Globals
| Name | Description |
|------|-------------|
| `W` | Global weather data table: `W.weather`, `W.air`, `W.city`, `W.moon`, `W.sun` |
| `cur_map` | Short → API field name mapping for current weather |
| `hour_map` | Short → API field name mapping for hourly weather |

## Key Functions
| Function | Description |
|----------|-------------|
| `conky_load_weather_data()` | Load/cache weather JSON files (5 min TTL) |
| `conky_update_weather()` | Reload weather + alerts |
| `conky_round(v)` | Round number |
| `conky_read_j(path)` | Read & decode JSON file |
| `conky_weather_code_text(code)` | Translate WMO code to text via `get_tr()` |
| `conky_wind_direction_text(deg)` | Translate wind degrees to direction name |
| `conky_sun_progress()` | 0–1 daytime progress |
| `conky_moon_progress()` | 0–1 moon visibility progress |
| `conky_sun_arc_x(cx, r)` | X position of sun on arc |
| `conky_sun_arc_y(cy, r)` | Y position of sun on arc |
| `conky_moon_arc_x(cx, r)` | X position of moon on arc |
| `conky_moon_arc_y(cy, r)` | Y position of moon on arc |
| `conky_icon_current_weather()` | Path to current weather icon PNG |
| `conky_icon_hour_weather(i)` | Path to hourly weather icon |
| `conky_icon_day_weather(i)` | Path to daily weather icon |
| `conky_icon_moon()` | Path to moon phase icon |
| `conky_icon_current_wind()` | Path to wind icon |
| `conky_icon_hour_wind(i)` | Path to hourly wind icon |
| `conky_moon_phase_text()` | Translated moon phase name |
| `conky_day_name(o)` | Day name from offset |
| `conky_day_name_short(o)` | Short day name (cached) |
| `conky_units()` | All unit labels |
