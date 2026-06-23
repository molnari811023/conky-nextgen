# all_in_one.sh

## Purpose
Backend data fetcher. Downloads weather, space weather, alerts, and map tiles.

## Dependencies
- `curl`, `jq`, `python3`, ImageMagick (`magick` or `convert`)

## Usage
```bash
./sh/all_in_one.sh [mode] [arguments]
```

## Modes
| Mode | Arguments | Description |
|------|-----------|-------------|
| `all` | city, zoom | Fetch everything (default) |
| `weather` | city | Weather + air + sun + moon data |
| `space` | — | NOAA space weather data |
| `alerts` | — | MeteoAlarm weather alerts |
| `map` | zoom | OpenStreetMap + radar + temp + wind tiles |

Default city: `Vienna`, default zoom: `7`.

## Output Files (in `tmp/`)
| File | Source |
|------|--------|
| `city.json` | Open-Meteo Geocoding API |
| `weather_data.json` | Open-Meteo Forecast API |
| `airquality.json` | Open-Meteo Air Quality API |
| `sun.json` | MET Norway Sunrise API |
| `moon.json` | MET Norway Moonrise API |
| `spaceweather_*.json` | NOAA SWPC |
| `alerts.xml` | MeteoAlarm Atom feed |
| `osm_big.png`, `temp_big.png`, `rain_big.png`, `wind_big.png` | Map tiles (3×3 grid) |

## First Run
On first run without a TTY, it auto-generates a User-Agent. With a TTY, it prompts for one.
