# Conky NextGen Framework

Modular Conky UI framework with Lua engine and Bash backend.

> **The first and only Conky project with full gettext i18n support.**  
> Weblate-compatible, 22 languages ready (hu, en, de, fr, nl, es, pt, it, pl, tr, ja, zh_CN, ru, ro, hr, ar, ko, sv, uk, cs, da, fi), `.pot` template for adding more.  
> Includes a tile-based Mercator map engine, global weather/sensors/hardware, and a Cairo drawing toolkit.

## Architecture

### Lua Modules (`lua/`)

Modules are organized into folders by responsibility. Loading order is defined in `main.lua`.

#### Core (`lua/core/`)

| Module | Purpose |
|--------|---------|
| `translate` | Weather UI translations via `.mo` files. 22 languages ready |
| `colors` | Breeze Dark color palette (`BR` table) |
| `clipboard` | Clipboard provider detection and copy function |
| `draw_core` | Cairo setup, main draw loop `conky_core_main()`, state, helpers |
| `draw_input` | Input registration, click/scroll actions, `build_draw()` |
| `draw_group` | GROUP_STATE toggle, register, visibility, collapse |
| `draw_context` | Right-click context menu |
| `draw_mouse` | Mouse event handler, drag-and-drop, hover |

#### Draw Types (`lua/draw/`)

| Module | Purpose |
|--------|---------|
| `background` | Rounded rectangle backgrounds |
| `bar` | Progress bars (smooth & block styles) |
| `graph` | Time-series graphs (line & fill) |
| `clock` | Analog clock |
| `rings` | Segmented & smooth ring gauges |
| `hyphen` | Hyphenation engine (LibreOffice .dic) |
| `text` | Text rendering with word wrap & hyphenation |
| `lines` | Lines with dash/dot styles |
| `calendar` | Month calendar widget |
| `image` | PNG image rendering with crop/tint/rotate |
| `svg` | SVG vector icon rendering via librsvg |
| `layout` | Dynamic layout engine (y-position stacking) |
| `widget` | User-defined `draw = {}` and `layout = {}` with interactive fields |

#### Weather (`lua/weather/`)

| Module | Purpose |
|--------|---------|
| `core` | Weather data loader, sun/moon arcs, icons |
| `current` | Current weather accessors |
| `hourly` | Hourly forecast accessors |
| `daily` | Daily forecast accessors |
| `air` | Air quality data accessors |
| `sunmoon` | Sun & moon rise/set times |
| `units` | Unit labels for weather fields |
| `alerts` | MeteoAlarm weather alert parser |
| `spaceweather` | NOAA SWPC space weather data |

#### Hardware (`lua/hardware/`)

| Module | Purpose |
|--------|---------|
| `core` | DMI, caching, shell utilities |
| `processes` | `/proc` process scanner (LPEG-based) |
| `battery` | Battery health, Bluetooth/UPower devices |
| `dmi` | System vendor, board, BIOS, chassis info |
| `info` | CPU model, NVMe model, install date |
| `mtp` | MTP device detection (KDE/GVFS) |
| `mtp` | MTP device detection |
| `network` | WiFi, public IP, ping |
| `sensors` | `lm-sensors` CPU/NVMe/WiFi temp, fan speed |
| `usb` | USB mount detection |
| `processes_extra` | Top CPU/memory process views |

#### Root (`lua/`)

| File | Purpose |
|------|---------|
| `draw_layout` | `DynamicLayout.compute()` — layout box positioning |
| `widget` | User-defined `raw_elements`, `layout[]`, `THEME`, `SCROLL` |
| `nowplaying` | MPRIS now playing info via playerctl |

### Input System

The framework supports full mouse interaction via Conky's `lua_mouse_hook`:

| Feature | Description |
|---------|-------------|
| **Click actions** | `click` (shell cmd), `click_view` (switch view), `click_toggle` (toggle group), `clipboard` (copy text) |
| **Scroll actions** | `scroll_up_action`, `scroll_down_action` — format: `"command:arg1:arg2"` |
| **Hover** | `mouse_hover_view` (switch view on hover), `mouse_hover_toggle` (expand group on hover) |
| **Right-click** | Context menu with collapse/expand/hide/restore + text copy |
| **Drag-and-drop** | Rearrange groups by dragging (Neovim-inspired, `draggable = true` in layout) |
| **Z-index** | Layer ordering: DEFAULT(0) → HEADER(5) → CONTEXT_MENU(100) → TOOLTIP(200) → DRAG_OVERLAY(300) |

### Group System

Three-state model for collapsible sections:

| State | Visible | Description |
|-------|---------|-------------|
| `nil` | No | Hidden (context menu "Hide") |
| `"collapsed"` | Header only | Arrow click collapses content |
| `"expanded"` | Full | Default state |

Groups are defined in `layout[]` and toggled via header arrows or context menu.

### Internationalization (i18n)

[![Translation status](https://hosted.weblate.org/widget/conky-nextgen/svg-badge.svg)](https://hosted.weblate.org/projects/conky-nextgen/)

- **22 languages shipped**: Hungarian, English, German, French, Dutch, Spanish, Portuguese, Italian, Polish, Turkish, Japanese, Chinese, Russian, Romanian, Croatian, Arabic, Korean, Swedish, Ukrainian, Czech, Danish, Finnish
- **`.pot` template** ready for any language — copy to `language/xx.po`, translate, compile with `msgfmt`
- **Weblate-compatible** — can be imported to Weblate for community translations
- **Zero code changes** to add a language — just add a `.mo` file
- Powered by Lua-based gettext binding in `lua/core/translate.lua`

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
- `main.lua` — Entry point, loads modules in order via `require()`

## Data Flow

1. `conky.conf` loads `main.lua` via `lua_load`
2. `main.lua` requires all modules in dependency order (core → weather → hardware → draw)
3. Bash scripts fetch JSON/XML data to `tmp/`
4. `conky_core_main()` (in `lua/core/draw_core.lua`) runs on every Conky update:
   - Loads weather/spaceweather data
   - Computes layout (if `layout[]` table exists)
   - Iterates `draw[]` items and calls the appropriate draw function
   - Renders floating layers (context menu, drag overlay)
5. `conky_on_mouse()` (in `lua/core/draw_mouse.lua`) handles all mouse events

## Drawing Widgets

Drawing is driven by the `draw` table (built from `raw_elements` in `lua/widget.lua`). Each entry has a `type` field. The main loop dispatches to the correct draw function based on type.

See the individual draw module docs for examples and variants.

For details on the tile-based map engine (3×3 Mercator grid, global radar support), see [`docs/sh/fetch_modules.md`](docs/sh/fetch_modules.md).

## Performance (Extreme Stress Test)

The NextGen Engine produced ~6% CPU and 0.2% RAM usage with 434 simultaneous,
overlapping draw elements (text, bar, line, ring, graph, clock, calendar, image, background)
in a 400×1040 px window.

This test does not model a real-world use case — it demonstrates the engine's scalability
and stability under extreme load. A typical Conky config uses 10–20 widgets.

## Dependencies (Arch Linux)

```
pacman -S --needed conky-mng python3 lua lua-dkjson lua-filesystem lua-lpeg lua-luarocks lua-luautf8 lua-system jq curl imagemagick pacman-contrib
```

**Note**: Interactive features (click, view switching, group toggle, drag-and-drop) require the custom `conky-mng` package with `BUILD_MOUSE_EVENTS=ON`. See [docs/pkg/conky-mng.md](pkg/conky-mng.md).

The official Arch `conky` package (1.22.3) does not support mouse events. Build the custom package from `pkg/PKGBUILD` in this repository.

## Contributing

Contributions are welcome! If you've tried Conky NextGen and have ideas,
found a bug, or want to help, feel free to open an Issue or PR.

I'm actively looking for contributors in these areas:
- New widget types and composite widgets (bar+text, ring+text)
- Multi-distro support (OS detection, package manager detection)
- NVIDIA Prime-Select / hybrid graphics support
- UI polish, bug fixes, performance improvements

Every contribution counts — feedback, ideas, code, or docs.
