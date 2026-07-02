# Conky NextGen Framework

Modular Conky UI framework with Lua engine and Bash backend.

> **The first and only Conky project with full gettext i18n support.**  
> Weblate-compatible, 22 languages ready (hu, en, de, fr, nl, es, pt, it, pl, tr, ja, zh_CN, ru, ro, hr, ar, ko, sv, uk, cs, da, fi), `.pot` template for adding more.  
> Includes a tile-based Mercator map engine, global weather/sensors/hardware, and a Cairo drawing toolkit.

## Architecture

### Lua Modules (`lua/`)

Files are numbered to define load order. Each module registers `conky_*` functions or global tables.

| # | Module | Purpose |
|---|--------|---------|
| 1 | translate | Weather UI translations via `.mo` files. 22 languages ready — see i18n section below |
| 2 | colors | Breeze Dark color palette (`BR` table) |
| 3 | watcher | File change watcher, auto-reloads Conky on edit |
| 4 | weather_core | Weather data loader, sun/moon arcs, icons |
| 5 | weather_current | Current weather accessors |
| 6 | weather_hourly | Hourly forecast accessors |
| 7 | weather_daily | Daily forecast accessors |
| 8 | weather_air | Air quality data accessors |
| 9 | weather_sunmoon | Sun & moon rise/set times |
| 10 | weather_units | Unit labels for weather fields |
| 11 | weather_alerts | MeteoAlarm weather alert parser |
| 12 | spaceweather | NOAA SWPC space weather data |
| 13 | processes | `/proc` process scanner (LPEG-based) |
| 14 | hardware_core | DMI, caching, shell utilities |
| 15 | hardware_battery | Battery health, Bluetooth/UPower devices |
| 16 | hardware_dmi | System vendor, board, BIOS, chassis info |
| 17 | hardware_info | CPU model, NVMe model, install date |
| 18 | hardware_mtp | MTP device detection (KDE/GVFS) |
| 19 | hardware_nvidia | NVIDIA GPU mode & stats via `nvidia-smi` |
| 20 | hardware_network | WiFi, public IP, ping |
| 21 | hardware_sensors | `lm-sensors` CPU/NVMe/WiFi temp, fan speed |
| 22 | hardware_usb | USB mount detection |
| 23 | hardware_processes | Top CPU/memory process views |
| 24 | draw_core | Cairo setup, main draw loop, color helpers |
| 25 | draw_background | Rounded rectangle backgrounds |
| 26 | draw_bar | Progress bars (smooth & block styles) |
| 27 | draw_graph | Time-series graphs (line & fill) |
| 28 | draw_clock | Analog clock |
| 29 | draw_rings | Segmented & smooth ring gauges |
| 30 | hyphen | Hyphenation engine (LibreOffice .dic) |
| 31 | draw_text | Text rendering with word wrap & hyphenation |
| 32 | draw_lines | Lines with dash/dot styles |
| 33 | draw_calendar | Month calendar widget |
| 34 | draw_image | PNG image rendering with crop/tint/rotate |
| 35 | draw_layout | Dynamic layout engine (y-position stacking) |
| 36 | widget | User-defined `draw = {}` and `layout = {}` |
| — | nowplaying | MPRIS now playing info via playerctl (title, artist, album, album art) |

### Internationalization (i18n)

[![Translation status](https://hosted.weblate.org/widget/conky-nextgen/svg-badge.svg)](https://hosted.weblate.org/projects/conky-nextgen/)

Conky NextGen is the **first Conky project with full GNU gettext internationalization**. This isn't a static language switch — it's a real `.po`/`.mo` translation system, identical to what GNOME, KDE, and Weblate use.

- **22 languages shipped**: Hungarian (`hu`), English (`en`), German (`de`), French (`fr`), Dutch (`nl`), Spanish (`es`), Portuguese (`pt`), Italian (`it`), Polish (`pl`), Turkish (`tr`), Japanese (`ja`), Chinese (`zh_CN`), Russian (`ru`), Romanian (`ro`), Croatian (`hr`), Arabic (`ar`), Korean (`ko`), Swedish (`sv`), Ukrainian (`uk`), Czech (`cs`), Danish (`da`), Finnish (`fi`)
- **`.pot` template** ready for any language — copy to `language/xx.po`, translate, compile with `msgfmt`
- **Weblate‑compatible** — can be imported to Weblate for community translations with automatic PRs
- **Zero code changes** to add a language — just add a `.mo` file
- Powered by Lua‑based gettext binding in [`lua/1_translate.lua`](../lua/1_translate.lua)

To add a new language: copy `language/strings.pot` → `language/xx.po`, translate, run `msgfmt language/xx.po -o language/xx.mo`, and set `STRINGS_MO_PATH` in `main.lua`.

### Shell Scripts (`sh/`)

Numbered modules follow the same convention as Lua. Each can be run standalone.

| File | Purpose |
|------|---------|
| `0_common.sh` | Shared helpers (User-Agent, `curl_cmd`, dirs) — sourced by all modules |
| `0_fetch_all.sh` | Master entry point — dispatches to all fetch modules by mode |
| `4_fetch_weather.sh` | Weather, air quality, sun & moon data |
| `11_fetch_alerts.sh` | MeteoAlarm weather alerts |
| `12_fetch_spaceweather.sh` | NOAA SWPC space weather data |
| `13_fetch_maps.sh` | OSM tiles, radar, temperature & wind WMS layers |
| `all_in_one.sh` | Legacy monolith (still works, use modules above for new setups) |
| `updates.sh` | Arch Linux package update checker |

### Config

- `conky.conf` — Conky configuration (window size, update interval, hooks)
- `main.lua` — Entry point, loads modules in order, defines `conky_core_main()`

## Data Flow

1. `conky.conf` loads `main.lua` via `lua_load`
2. `main.lua` requires all modules in numbered order
3. Bash scripts fetch JSON/XML data to `tmp/`
4. `conky_core_main()` (in `24_draw_core.lua`) runs on every Conky update:
   - Checks for file changes (watcher)
   - Loads weather/spaceweather data
   - Iterates `draw[]` items and calls the appropriate draw function
   - Optional: computes `layout[]` for dynamic y-positioning

## Drawing Widgets

Drawing is driven by the `draw` table (defined in `36_widget.lua`). Each entry has a `type` field. The main loop dispatches to the correct draw function based on type.

See the individual draw module docs for examples and variants.

For details on the tile‑based map engine (3×3 Mercator grid, global radar support), see [`docs/sh/fetch_modules.md`](docs/sh/fetch_modules.md).

## Dependencies (Arch Linux)

```
pacman -S --needed conky python3 lua54 lua54-dkjson lua54-filesystem lua54-lpeg lua54-luarocks lua54-luautf8 lua54-system jq curl imagemagick pacman-contrib
```

## Contributing

Contributions are welcome! If you've tried Conky NextGen and have ideas,
found a bug, or want to help, feel free to open an Issue or PR.

I'm actively looking for contributors in these areas:
- New widget types and composite widgets (bar+text, ring+text)
- Multi-distro support (OS detection, package manager detection)
- NVIDIA Prime-Select / hybrid graphics support
- UI polish, bug fixes, performance improvements

Every contribution counts — feedback, ideas, code, or docs.
