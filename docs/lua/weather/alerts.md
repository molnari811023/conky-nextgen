# 11 — weather_alerts.lua

## Purpose
Parses MeteoAlarm XML weather alerts. Supports both SAX (via lxp) and regex-based parsing as fallback.

## Dependencies
- `4_weather_core` (for `conky_read_j`, JSON_PATH)

## Functions
| Function | Description |
|----------|-------------|
| `load_alerts()` | Load/cache alert data (2 min TTL) |
| `conky_update_alerts()` | Force reload alerts |
| `alerts_count()` | Number of active alerts |
| `alert_field(i, field)` | Get alert field (event, severity, certainty, area, onset, expires, title, color). Fields `severity`, `color`, `certainty` are translated via `get_tr()`. |
| `alerts_updated()` | Feed-level `<updated>` timestamp string |

## Data
- Source: `https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-<country>`
- Matches alerts by city name or admin1 region
- Returns top 3 by severity
- Severity colors: red, orange, yellow
