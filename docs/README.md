# Conky NextGen Framework

Modular Conky UI framework with Lua engine and Bash backend.

> **The first and only Conky project with full gettext i18n support.**  
> Weblate-compatible, 3 languages ready (hu, en, de), `.pot` template for adding more.  
> Includes a tile-based Mercator map engine, global weather/sensors/hardware, and a Cairo drawing toolkit.

## Architecture

### Lua Modules (`lua/`)

Files are numbered to define load order. Each module registers `conky_*` functions or global tables.

| # | Module | Purpose |
|---|--------|---------|
| 1 | translate | Weather UI translations via `.mo` files. 3 languages ready: **hu**, **en**, **de**. `.pot` template for adding more |
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

### Internationalization (i18n)

[![Translation status](https://hosted.weblate.org/widget/conky-nextgen/svg-badge.svg)](https://hosted.weblate.org/projects/conky-nextgen/)

Conky NextGen is the **first Conky project with full GNU gettext internationalization**. This isn't a static language switch — it's a real `.po`/`.mo` translation system, identical to what GNOME, KDE, and Weblate use.

- **3 languages shipped**: Hungarian (`hu`), English (`en`), German (`de`)
- **`.pot` template** ready for any language — copy to `language/xx.po`, translate, compile with `msgfmt`
- **Weblate‑compatible** — can be imported to Weblate for community translations with automatic PRs
- **Zero code changes** to add a language — just add a `.mo` file
- Powered by Lua‑based gettext binding in [`lua/1_translate.lua`](../lua/1_translate.lua)

To add a new language: copy `language/strings.pot` → `language/xx.po`, translate, run `msgfmt language/xx.po -o language/xx.mo`, and set `STRINGS_MO_PATH` in `main.lua`.

### Shell Scripts (`sh/`)

| File | Purpose |
|------|---------|
| all_in_one.sh | Weather, space weather, alerts, map tile fetcher |
| updates.sh | Arch Linux package update checker |

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

For details on the tile‑based map engine (3×3 Mercator grid, global radar support), see [`docs/sh/all_in_one.md`](docs/sh/all_in_one.md).

## Dependencies (Arch Linux)

```
pacman -S --needed conky python3 lua54 lua54-dkjson lua54-filesystem lua54-lpeg lua54-luarocks lua54-luautf8 lua54-system jq curl imagemagick pacman-contrib
```
