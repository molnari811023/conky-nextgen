# Fetch modules

## Purpose
Backend data fetchers. Download weather, space weather, alerts, and map tiles into `tmp/`.

## Dependencies
- `curl`, `jq`, `python3`, ImageMagick (`magick` or `convert`)

## Module overview

The monolithic `all_in_one.sh` has been split into numbered modules (matching the Lua convention).

| File | Function | Runs standalone |
|------|----------|-----------------|
| `0_common.sh` | Shared helpers (UA, `curl_cmd`, dirs) — sourced by all modules | sourced only |
| `0_fetch_all.sh` | Master entry point — dispatches by mode | yes |
| `4_fetch_weather.sh` | `fetch_weather` — weather + air + sun + moon | yes |
| `11_fetch_alerts.sh` | `fetch_alerts` — MeteoAlarm XML | yes |
| `12_fetch_spaceweather.sh` | `fetch_spaceweather` — NOAA SWPC | yes |
| `13_fetch_maps.sh` | `fetch_maps` — OSM + radar + temp + wind tiles | yes |
| `fetch_nowplaying.sh` | `fetch_nowplaying` — MPRIS track info + album art via playerctl | yes |
| `all_in_one.sh` | Legacy monolith (still works) | yes |

## Usage (recommended)

```bash
./sh/0_fetch_all.sh [mode] [arguments]
./sh/4_fetch_weather.sh "Budapest"         # standalone weather
./sh/11_fetch_alerts.sh                     # standalone alerts
```

## Modes (`0_fetch_all.sh`)
| Mode | Arguments | Description |
|------|-----------|-------------|
| `all` | city, zoom | Fetch everything (default) |
| `weather` | city | Weather + air + sun + moon data |
| `space` | — | NOAA space weather data |
| `alerts` | — | MeteoAlarm weather alerts |
| `map` | zoom | OpenStreetMap + radar + temp + wind tiles |
| `nowplaying` | — | MPRIS now playing info + album art via playerctl |

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

## 🗺️ Tile Engine (3×3 Mercator Grid)

Conky NextGen includes a real tile‑based map engine, not a static radar image crop. The engine downloads a 3×3 Mercator tile grid around the selected location and stitches it into a single high‑resolution map.

### Why 3×3 tiles?

Most Conky weather widgets download one static radar JPG and crop a fixed region. This works only if the user happens to live exactly in the center of that image.

In reality:

- your city is never in the center of a tile
- radar, cloud and wind layers often extend beyond tile boundaries
- a single tile cannot provide a complete and accurate local view
- zoom levels shift the visible region
- cropping must be based on lat/lon, not fixed pixels

Therefore, NextGen always downloads a 3×3 tile matrix:

```
[ T0 T1 T2 ]
[ T3 T4 T5 ]
[ T6 T7 T8 ]
```

This guarantees:

- full coverage around the user's coordinates
- no missing radar/cloud/wind data
- precise cropping based on Mercator projection
- consistent results at any zoom level
- global support (any country, any location)

### How it works

1. Convert latitude/longitude → tileX/tileY using Mercator projection
2. Download the 3×3 tile grid around the target tile
3. Stitch tiles into a single large map (`magick`)
4. Compute pixel offsets for the exact city position
5. Crop the final region dynamically in Lua (see [`lua/34_draw_image.lua`](../lua/34_draw_image.lua) — `crop {}` table)
6. Render it with Cairo in Conky

### Why this matters

This approach makes Conky NextGen the only Conky framework with:

- global radar support
- accurate geolocation‑based cropping
- zoom‑aware rendering
- consistent visuals regardless of region
- a real map engine instead of static image hacks

Most existing Conky weather widgets use one static radar JPG and crop it. NextGen uses a full tile engine, just like real map applications.
