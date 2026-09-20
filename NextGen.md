# Conky NextGen

Conky NextGen is a Lua/Cairo widget framework for Conky. It provides:

- standalone, themeable widget files;
- a strict Lua module loader with selectable data profiles;
- Cairo renderers for common dashboard elements;
- Bash fetchers that cache external data under `tmp/`;
- a GTK Designer that reads and writes widget Lua files;
- gettext catalogs, a panel/systray integration, and development tools.

The framework deliberately keeps each widget self-contained. A generated
widget carries its own paths, theme, profile, draw list, groups, views, and
mouse bindings, so it can be copied and customized without a central runtime
configuration.

## Quick start

```bash
git clone git@github.com:molnari811023/conky-nextgen.git ~/.conky
cd ~/.conky

# Populate the cache. This creates tmp/ when needed.
bash sh/fetch_all.sh

# Start a widget.
conky -c clock_cal.conf

# Start the Designer.
python3 sh/designer/main.py
```

`fetch_all.sh` and `fetch_updates.sh` are Bash scripts. Invoke them with
`bash`, not a generic `/bin/sh` wrapper.

For a periodic refresh, use an explicit Bash cron entry:

```cron
0 * * * * /bin/bash /path/to/conky-nextgen/sh/fetch_all.sh && /bin/bash /path/to/conky-nextgen/sh/fetch_updates.sh
```

## Runtime requirements

The exact package names vary by distribution. The runtime needs:

| Component | Required for |
|---|---|
| Conky with Lua/Cairo support | all widgets |
| Lua bindings: `cairo`, `rsvg`, `imlib2`, `lfs`, `dkjson` | framework loader and renderers |
| `curl`, `jq`, `python3` | common fetcher bootstrap |
| ImageMagick (`magick` or `convert`) | map images |
| `ping` | network latency fetcher |
| `playerctl`, `cmus-remote`, `mpc`, or `mocp` | now-playing data, depending on player |
| `gog` | optional Google dashboard data |
| `pacman`, `checkupdates`, `vercmp` | optional Arch update counter |

The project is designed for X11 and Wayland-capable Conky builds. A terminal
test environment without a compositor can emit an ARGB/pseudo-transparency
warning; that is an environment limitation, not a Lua renderer failure.

## Project layout

```text
.
├── *.lua / *.conf          standalone widget bundles
├── debug/                  renderer tests and diagnostics
├── icons/                  weather, moon, wind, and UI assets
├── language/               gettext .po, .mo, and strings.pot files
├── lua/                    engine, renderers, and data accessors
├── panel_systray/          Conky panel and systray helper configuration
├── pkg/                    PKGBUILD, patches, and release package
├── sh/                     fetchers and GTK Designer
├── tools/                  development-only utilities
└── tmp/                    runtime cache; generated and git-ignored
```

Current widget bundles include `clock_cal`, `cpu`, `disk`, `info`, `left`,
`lyrics`, `mem_swap`, `nvidia`, `top`, `weather`, and `widget`. Each `.conf`
selects a sibling `.lua` file through `lua_load`.

`tmp/` is runtime state, not source. Fetchers create and atomically replace
cached JSON and image files there.

## Widget model

A widget Lua file sets paths and data globals, defines a theme and draw list,
loads the engine, then registers groups and views.

```lua
script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"
    .. ";" .. script_dir .. "lua/weather/?.lua"
    .. ";" .. script_dir .. "lua/hardware/?.lua"

JSON_PATH = script_dir .. "tmp/"
draw = {}

THEMES = { theme = { palette = {}, gradients = {}, defaults = {} } }
DEFAULT_THEME = "theme"
MODULE_PROFILE = { "basic" }
_PADDING = 10

require("require")

_GROUPS = {}
_VIEWS = { { name = "main" } }
_MOUSE_ENABLED = true

init_groups(_GROUPS)
```

The matching Conky config normally supplies these hooks:

```lua
lua_load = "widget.lua",
lua_draw_hook_pre = "conky_core_main",
lua_mouse_hook = "conky_on_mouse",
lua_shutdown_hook = "conky_cleanup",
```

### Themes

`THEMES` is owned by the widget, not a global shared config. A theme contains:

- `palette`: named color strings;
- `gradients`: named stop lists;
- `defaults`: renderer defaults applied to matching draw items.

Gradient stops use:

```lua
{ { position, "#RRGGBB", alpha }, ... }
```

For example:

```lua
fg = { { 0, "#3daee9", 1 }, { 1, "#bb9af7", 1 } }
```

### Draw items

Every item is a table added to `draw`. Common fields are `type`, position,
`view`, `group`, `draw_me`, `click`, and `click_view`. String `text` and
`value` fields support Conky templates such as `${cpu}` and Lua expressions
such as `conky_weather_cur_temp()`.

The current dispatcher supports these renderer types:

| Type | Purpose |
|---|---|
| `background` | rectangle, rounded rectangle, border, gradient background |
| `text` | themed and wrapped text |
| `bar` | smooth or block values |
| `graph` | line or filled history graphs |
| `ring` | segmented and polygonal circular values |
| `line` | solid, dashed, or dotted line |
| `image` | PNG/image rendering |
| `svg` | librsvg rendering, clipping, tinting, rotation |
| `clock` | analog clock |
| `calendar` | month grid with week numbers and popup styling |
| `arc` | horizon-style arc drawing |
| `lyrics` | synchronized lyric lines |

The renderers are loaded for every module profile. A profile limits data
modules, not the visual API.

### Views, groups, and conditions

`_VIEWS` defines named views. An item can use a single `view` or a table of
views. `_GROUPS` define visibility groups and their view membership.

`draw_me` accepts:

- `true` or `false`;
- a Lua function;
- a Lua expression string containing `()`;
- a Conky template that evaluates to `"1"`.

Invalid Lua expressions are fail-fast: the engine reports the expression and
stops rather than silently hiding the element.

### Mouse actions

Mouse handling is enabled with `_MOUSE_ENABLED = true`. Draw items may carry
a `click` action or a `click_view` target. Global mouse callbacks live in
`lua/mouse_actions.lua`; hit testing and event dispatch live in
`lua/core/mouse.lua`.

## Module profiles

`lua/require.lua` is the strict central loader. It always loads Lua bindings,
core modules, mouse handling, and every draw renderer. It loads data modules
according to `MODULE_PROFILE`.

```lua
-- Backward-compatible single profile
MODULE_PROFILE = "weather"

-- Preferred composable form
MODULE_PROFILE = { "weather", "media", "system" }
```

Available profiles:

| Profile | Data modules |
|---|---|
| `basic` | no extra data modules |
| `weather` | weather, air quality, sun, moon, city, icons, alerts |
| `system` | hardware, battery, DMI, MTP, network, sensors, USB |
| `media` | now playing and song text |
| `panel` | system data used by the panel |
| `google` | Google cache accessors |
| `full` | weather, system, media, and Google |

`full` is exclusive and cannot be combined with another profile. Unknown,
empty, or malformed profile selections fail immediately. Repeated modules
from combined profiles load once.

Older widgets without `MODULE_PROFILE` continue to receive `full`.

## Data semantics and fail-fast behavior

The engine does not use Lua `pcall` guards. Required module dependencies and
invalid renderer expressions stop with an error.

Value accessors make optionality explicit:

| Helper | Meaning |
|---|---|
| `require_num(value, name)` | required numeric value; fails on missing, NaN, or invalid data |
| `require_str(value, name)` | required non-empty string |
| `optional_num(value, default, name)` | default only when data is absent |
| `optional_str(value, default, name)` | default only when data is absent |

Weather, air-quality, and wind-icon values use required accessors so an API
schema mismatch cannot be displayed as a plausible zero. Polar sun/moon
events and fixed Google list slots use explicit optional values where missing
data is a normal state.

## Fetchers

All fetchers are in `sh/`. `common.sh` resolves the project and cache paths,
ensures `curl`, `jq`, and `python3` are present, and provides the shared
User-Agent, HTTP, logging, and URL-encoding helpers.

| File | Responsibility |
|---|---|
| `fetch_all.sh` | dispatcher for all fetch modules |
| `fetch_weather.sh` | city geocoding, Open-Meteo weather/air, MET Norway sun/moon |
| `fetch_alerts.sh` | MeteoAlarm feed for the selected city country |
| `fetch_maps.sh` | OSM, radar, temperature, and wind map composites |
| `fetch_nowplaying.sh` | MPRIS/CMUS/MPD/MOC metadata and cover art |
| `fetch_network.sh` | ping and public IP data |
| `fetch_google.sh` | Gmail, Calendar, Tasks, Contacts, Drive, YouTube, and optional Meet data |
| `fetch_updates.sh` | Arch repository and AUR update counts |
| `gog_open_mail.sh` | open a Gmail thread from its message id |
| `conky_check.sh` | inspect running Conky and Designer process state |

### `fetch_all.sh` modes

```bash
bash sh/fetch_all.sh                 # all fetchers; weather defaults to Vienna
bash sh/fetch_all.sh weather Budapest
bash sh/fetch_all.sh alerts
bash sh/fetch_all.sh map 7
bash sh/fetch_all.sh nowplaying
bash sh/fetch_all.sh network
bash sh/fetch_all.sh google
bash sh/fetch_all.sh "New York"      # city shortcut for weather
```

In `all` mode, weather, alerts, maps, and now-playing run sequentially.
Google, ping, and public-IP fetches then run in parallel. The fetchers write
temporary files first and rename successful results into `tmp/`.

`fetch_updates.sh` is separate from `fetch_all.sh`; it is Arch-specific and
writes `tmp/updates.txt` as `<repo-count> <aur-count>`.

Google fetching is optional. Configure `gog` authentication before enabling a
Google widget; the script supports environment overrides for the account,
keyring settings, result limits, calendar range, and Meet code.

## Designer

The GTK application entry point is:

```bash
python3 sh/designer/main.py
```

The Designer is a generator and editor for self-contained widget Lua files.
It parses existing `draw`, groups, views, themes, mouse settings, weather
settings, and profile selection, then writes the corresponding Lua back.

The property schema in `sh/designer/engine/widget_schema.py` is the single
source of truth for supported renderer types, fields, defaults, editor
controls, and Lua serialization.

Key Designer capabilities:

- add, reorder, edit, and delete draw items;
- edit groups, views, mouse bindings, themes, gradients, and Conky settings;
- choose one or more module profiles from the Profile menu;
- preview live through managed Conky processes;
- generate widget `.lua` and `.conf` files;
- scan available Lua functions for picker data;
- export view captures;
- inspect activity through the developer console.

The Designer writes combined profiles as:

```lua
MODULE_PROFILE = { "weather", "media" }
```

An old widget with a string profile remains readable and is normalized in the
Designer state.

Run its headless regression check with:

```bash
python3 sh/designer/tests/test_widget_schema.py
```

## Panel and systray

`panel_systray/panel.conf` starts the Conky panel and loads
`panel_systray/panel.lua`. The panel bootstraps the standard engine and then
loads `apps`, `tasklist`, and `clock` panel modules.

`panel_systray/panel_systray.conf` is **not** a Conky config. It is the
key/value configuration consumed by the separate systray helper. Do not pass
it to `conky -c`.

## Localization

`language/` contains the active gettext catalog set:

- `strings.pot`: the empty translation template;
- `hu.po`: the maintained reference key set;
- one `.po` and compiled `.mo` catalog for every supported language.

The current template and active catalogs contain the same 758 message IDs.
The English `msgid` remains the intentional final display fallback for a
missing translation.

Compile a catalog with:

```bash
msgfmt --check -o language/en.mo language/en.po
```

Do not run `msgfmt` directly on a `.mo`; it is already a binary catalog.
Inspect it with:

```bash
msgunfmt language/en.mo
```

When adding a message, update `hu.po`, rebuild `strings.pot` from its message
IDs with empty translations, merge that template into the other `.po` files,
then recompile every `.mo`.

## Development tools

Development-only helpers are grouped under `tools/`:

| Tool | Usage |
|---|---|
| `tools/list_functions.lua` | `lua tools/list_functions.lua [lua-directory]` |
| `tools/string_shorten.lua` | `lua tools/string_shorten.lua` |
| `tools/string_measure.conf` | `conky -c tools/string_measure.conf` |
| `tools/lfsdebug.conf` | `conky -c tools/lfsdebug.conf` |

`string_shorten.lua` reports the longest catalog strings and shortening
candidates. `string_measure.lua` measures rendered string widths using a live
Conky Cairo context. Tool reports are generated locally next to the tools and
are not source assets.

## Debug and stress tests

`debug/svg_test.conf` is the focused SVG renderer test.

`debug/extreme_test.conf` starts the renderer stress harness. Select a
renderer with `CONKY_EXTREME_TEST`; each mode creates exactly 500 draw items:

```bash
CONKY_EXTREME_TEST=calendar conky -c debug/extreme_test.conf
CONKY_EXTREME_TEST=image conky -c debug/extreme_test.conf
CONKY_EXTREME_TEST=svg conky -c debug/extreme_test.conf
```

Supported stress modes are `background`, `line`, `text`, `bar`, `graph`,
`ring`, `image`, `svg`, `calendar`, `clock`, `arc`, and `lyrics`.

The 500-item tests are deliberate stress loads, not normal expected desktop
usage. They report memory and render duration so cache growth and renderer
regressions are visible.

## Validation

Use the smallest relevant check after a change:

```bash
# Lua syntax for changed files
luac -p lua/require.lua lua/core/draw_core.lua

# Shell syntax
for script in sh/*.sh; do bash -n "$script"; done

# Designer schema/parser regression suite
python3 sh/designer/tests/test_widget_schema.py

# Translation catalog validation
msgfmt --check -o /dev/null language/hu.po

# Start a representative widget
conky -c weather.conf
```

For terminal-only testing, use a temporary config copy with
`background = false` and `out_to_wayland = false`; do not change the deployed
widget config merely to accommodate a headless environment.

## Adding a renderer or data module

1. Add the renderer under `lua/draw/` or a data accessor under the appropriate
   `lua/` subsystem.
2. Register a renderer in `lua/require.lua` and in the draw dispatch table in
   `lua/core/draw_core.lua`.
3. Extend `widget_schema.py` when it should be editable in the Designer.
4. Add the required data module to an existing or new module profile.
5. Add a focused debug or stress mode when the renderer has non-trivial
   resource behavior.
6. Update translations and this document when the public API changes.

Keep dependencies explicit. Required dependencies should fail at startup;
only data that is semantically optional should use an explicit optional
accessor.

## Complete source reference

This appendix is generated from the current source tree. Function names are
listed exactly as declared by the module; `local` implementation helpers are
intentionally omitted. Each module summary is extracted from its current source
header, so this reference follows the implementation rather than legacy docs.

### Designer renderer schema

The following is the current editable field set from
`sh/designer/engine/widget_schema.py`. Fields are grouped by renderer and
show their Designer defaults when defined.

#### `background`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `0` |
| `y` | `int` | `0` |
| `w` | `int` | `0` |
| `h` | `int` | `0` |
| `radius` | `int` | `12` |
| `border_width` | `int` | `2` |
| `bg` | `stops` |  |
| `border` | `stops` |  |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `text`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `20` |
| `y` | `int` | `10` |
| `font` | `font` | `Mono` |
| `size` | `int` | `12` |
| `slant` | `enum` |  |
| `weight` | `enum` |  |
| `align` | `enum` |  |
| `text` | `template` | `New text` |
| `color` | `stops` |  |
| `wrap_width` | `int` |  |
| `wrap_dic` | `path` |  |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `bar`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `50` |
| `y` | `int` | `10` |
| `width` | `int` | `220` |
| `height` | `int` | `12` |
| `value` | `template` | `${cpu}` |
| `max` | `int` | `100` |
| `angle` | `float` |  |
| `mode` | `enum` |  |
| `blocks` | `int` |  |
| `blocks_width` | `int` |  |
| `sides` | `int` |  |
| `fg` | `stops` |  |
| `bg` | `stops` |  |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `graph`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `20` |
| `y` | `int` | `10` |
| `width` | `int` | `360` |
| `height` | `int` | `40` |
| `value` | `template` | `${cpu}` |
| `max` | `int` | `100` |
| `autoscale` | `bool` |  |
| `angle` | `float` |  |
| `key` | `string` |  |
| `graph_type` | `enum` |  |
| `line_width` | `int` |  |
| `border_width` | `int` |  |
| `grid` | `bool` |  |
| `grid_steps` | `int` |  |
| `fg` | `stops` |  |
| `bg` | `stops` |  |
| `border` | `stops` |  |
| `grid_color` | `stops` |  |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `ring`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `200` |
| `y` | `int` | `50` |
| `radius` | `int` | `35` |
| `thickness` | `int` | `8` |
| `value` | `template` | `${cpu}` |
| `max` | `int` | `100` |
| `sectors` | `int` | `6` |
| `mode` | `enum` | `ring` |
| `sides` | `int` | `6` |
| `start_angle` | `float` |  |
| `end_angle` | `float` |  |
| `sector_size` | `float` |  |
| `alarm_color` | `stops` |  |
| `alarm_alpha` | `float` |  |
| `fg` | `stops` |  |
| `bg` | `stops` |  |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `line`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x1` | `int` | `20` |
| `y1` | `int` | `15` |
| `x2` | `int` | `380` |
| `y2` | `int` | `15` |
| `thickness` | `int` | `2` |
| `style_type` | `enum` |  |
| `dash` | `float` |  |
| `dash_on` | `int` |  |
| `dash_off` | `int` |  |
| `dot_on` | `int` |  |
| `dot_off` | `int` |  |
| `fg` | `stops` |  |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `clock`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `200` |
| `y` | `int` | `80` |
| `radius` | `int` | `60` |
| `show_ticks` | `bool` |  |
| `show_numbers` | `bool` |  |
| `show_seconds` | `bool` | `True` |
| `tick_width_hour` | `int` |  |
| `tick_width_minute` | `int` |  |
| `number_size` | `int` |  |
| `number_radius` | `float` |  |
| `hour_hand_width` | `int` |  |
| `minute_hand_width` | `int` |  |
| `second_hand_width` | `int` |  |
| `center_radius` | `int` |  |
| `bg` | `stops` |  |
| `border` | `stops` |  |
| `tick_color` | `stops` |  |
| `number_color` | `stops` |  |
| `hour_color` | `stops` |  |
| `minute_color` | `stops` |  |
| `second_color` | `stops` |  |
| `center_color` | `stops` |  |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `calendar`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `20` |
| `y` | `int` | `10` |
| `cell_w` | `int` | `48` |
| `row_h` | `int` | `22` |
| `font` | `font` | `Mono` |
| `size` | `int` | `10` |
| `weeknum_size` | `int` | `16` |
| `popup_size` | `int` | `17` |
| `color_month` | `stops` |  |
| `color_weekdays` | `stops` |  |
| `color_days` | `stops` |  |
| `color_today` | `stops` |  |
| `color_outside` | `stops` |  |
| `color_weeknums` | `stops` |  |
| `color_popup` | `stops` |  |
| `show_weeknums` | `bool` | `True` |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `image`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `20` |
| `y` | `int` | `10` |
| `width` | `int` | `48` |
| `height` | `int` | `48` |
| `path` | `path` | `` |
| `alpha` | `float` |  |
| `radius` | `int` |  |
| `scale_mode` | `enum` |  |
| `shape` | `string` |  |
| `rotate` | `float` |  |
| `crop` | `string` |  |
| `tint` | `color` |  |
| `tint_alpha` | `float` |  |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `svg`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `20` |
| `y` | `int` | `10` |
| `w` | `int` | `48` |
| `h` | `int` | `48` |
| `path` | `path` | `` |
| `alpha` | `float` |  |
| `radius` | `int` |  |
| `shape` | `string` |  |
| `rotate` | `float` |  |
| `tint` | `color` |  |
| `tint_alpha` | `float` |  |
| `click` | `string` |  |
| `click_view` | `string` |  |

#### `arc`

| Field | Editor kind | Default |
|---|---|---|
| `view` | `string` |  |
| `group` | `string` |  |
| `draw_me` | `draw_me` |  |
| `x` | `int` | `200` |
| `y` | `int` | `80` |
| `radius` | `int` | `80` |
| `segments` | `int` | `20` |
| `arc_color` | `color` | `#a1a9b1` |
| `arc_alpha` | `float` | `0.4` |
| `arc_width` | `int` | `2` |
| `horizon` | `bool` | `True` |
| `horizon_color` | `color` | `#4a4d52` |
| `click` | `string` |  |
| `click_view` | `string` |  |

### Lua runtime modules

#### Core

##### `lua/core/capture.lua`

lua/core/capture.lua — one-shot PNG capture of a view, triggered by a request file

**Exported functions**

- `capture_poll()`
- `capture_finish()`

##### `lua/core/draw_core.lua`

lua/core/draw_core.lua — the main per-frame draw driver: dispatch, view/group gating, layout

**Exported functions**

- `evaluate_draw_me()`
- `draw_allowed()`
- `init_groups()`
- `modify_group_background()`
- `restore_group_background()`
- `compute_group_height()`
- `clear_surface()`
- `conky_core_main()`
- `conky_cleanup()`

##### `lua/core/draw_group.lua`

lua/core/draw_group.lua — group registration and per-group visibility

**Exported functions**

- `register_group()`
- `check_group_visibility()`

##### `lua/core/mouse.lua`

lua/core/mouse.lua — mouse interaction: hit testing, hover tracking, click/scroll actions

**Exported functions**

- `conky_on_mouse()`
- `register_clickable_area()`
- `conky_register_clickable_area()`
- `clear_clickable_areas()`
- `conky_clear_clickable_areas()`

##### `lua/core/theme_engine.lua`

lua/core/theme_engine.lua — theme resolution and per-widget default/color application

**Exported functions**

- `apply_theme()`

##### `lua/core/translate.lua`

lua/core/translate.lua — gettext-style string translation from GNU .mo catalogs

**Exported functions:** module registration or local helpers only.

##### `lua/core/utils.lua`

lua/core/utils.lua — shared helpers: colors, gradients, numbers, safe access, I/O, name interpretation

**Exported functions**

- `cache_set()`
- `apply_defaults()`
- `hex_to_rgba()`
- `get_color_from_list()`
- `build_gradient_pattern()`
- `rounded_rect_path()`
- `normalize_with_suffix()`
- `format_value()`
- `round()`
- `read_file()`
- `require_num()`
- `require_str()`
- `optional_num()`
- `optional_str()`
- `draw_get_value()`
- `interpret_name()`

#### Renderers

##### `lua/draw/arc.lua`

lua/draw/arc.lua — Draws a segmented semicircular arc gauge via Cairo

**Exported functions**

- `draw_arc()`

##### `lua/draw/background.lua`

lua/draw/background.lua — Draws a rounded-rectangle background panel with gradient fill and border

**Exported functions**

- `draw_background()`

##### `lua/draw/bar.lua`

lua/draw/bar.lua — Draws progress-bar widgets with block, dot, polygon, and smooth styles

**Exported functions**

- `conky_draw_bar_modules()`

##### `lua/draw/calendar.lua`

lua/draw/calendar.lua — Draws a clickable, navigable monthly calendar grid

**Exported functions**

- `draw_calendar()`

##### `lua/draw/clock.lua`

lua/draw/clock.lua — Draws an analogue clock face with hands, ticks, and numbers

**Exported functions**

- `draw_clock()`

##### `lua/draw/graph.lua`

lua/draw/graph.lua — Draws time-series line or area graphs with history buffers

**Exported functions**

- `draw_graph()`

##### `lua/draw/hyphen.lua`

lua/draw/hyphen.lua — TeX-style hyphenation engine for breaking words at soft-hyphen points

**Exported functions**

- `hyphen.load()`
- `hyphen.break_word()`

##### `lua/draw/icon_theme.lua`

lua/draw/icon_theme.lua — Resolves freedesktop icon-theme names to file paths

**Exported functions**

- `icon_resolve()`

##### `lua/draw/image.lua`

lua/draw/image.lua — Draws cached PNG images with cropping, tinting, rotation, and shape clipping

**Exported functions**

- `draw_png()`

##### `lua/draw/lines.lua`

lua/draw/lines.lua — Draws straight lines with solid, dashed, or dotted styles

**Exported functions**

- `draw_line_modules()`

##### `lua/draw/lyrics.lua`

lua/draw/lyrics.lua — synchronized lyrics block renderer (prev/current/next)

**Exported functions**

- `draw_lyrics()`

##### `lua/draw/rings.lua`

lua/draw/rings.lua — Draws circular ring gauges in sector, smooth, dot, or polygon mode

**Exported functions**

- `draw_one_ring()`

##### `lua/draw/svg.lua`

lua/draw/svg.lua — Renders SVG files via librsvg with tinting, rotation, and shape clipping

**Exported functions**

- `draw_svg()`
- `svg_free_all()`

##### `lua/draw/text.lua`

lua/draw/text.lua — Draws styled text with alignment, word-wrapping, and optional hyphenation

**Exported functions**

- `draw_text()`

#### Weather and location data

##### `lua/weather/airquality.lua`

lua/weather/airquality.lua — Air-quality and pollen accessor functions for current and hourly data

**Exported functions**

- `conky_air_cur_pm10()`
- `conky_air_cur_pm25()`
- `conky_air_cur_co()`
- `conky_air_cur_o3()`
- `conky_air_cur_no2()`
- `conky_air_cur_so2()`
- `conky_air_cur_dust()`
- `conky_air_cur_eaqi()`
- `conky_air_cur_usaqi()`
- `conky_air_cur_alder()`
- `conky_air_cur_birch()`
- `conky_air_cur_grass()`
- `conky_air_cur_mugwort()`
- `conky_air_cur_olive()`
- `conky_air_cur_ragweed()`
- `conky_air_hour_pm10()`
- `conky_air_hour_pm25()`
- `conky_air_hour_co()`
- `conky_air_hour_o3()`
- `conky_air_hour_no2()`
- `conky_air_hour_so2()`
- `conky_air_hour_dust()`
- `conky_air_hour_eaqi()`
- `conky_air_hour_usaqi()`
- `conky_air_hour_alder()`
- `conky_air_hour_birch()`
- `conky_air_hour_grass()`
- `conky_air_hour_mugwort()`
- `conky_air_hour_olive()`
- `conky_air_hour_ragweed()`

##### `lua/weather/alerts.lua`

lua/weather/alerts.lua — Parses weather-alert RSS/Atom XML and exposes filtered, cached alert data

**Exported functions**

- `conky_update_alerts()`
- `alerts_count()`
- `alerts_updated()`
- `alert_field()`

##### `lua/weather/city.lua`

lua/weather/city.lua — Conky accessors for the currently selected city metadata

**Exported functions**

- `conky_city_name()`
- `conky_city_country()`
- `conky_city_timezone()`
- `conky_city_admin1()`
- `conky_city_admin2()`
- `conky_city_lat()`
- `conky_city_lon()`
- `conky_city_elevation()`
- `conky_city_population()`
- `conky_city_postcode()`
- `conky_city_postcode_count()`

##### `lua/weather/core.lua`

lua/weather/core.lua — Core data loading, time/math helpers, WMO and wind/moon lookups

**Exported functions**

- `read_j()`
- `load_weather_data()`
- `fmt_unix()`
- `iso_to_mins()`
- `seconds_to_hour_min()`
- `get_idx()`
- `arc_x()`
- `arc_y()`
- `get_wind_dir_code()`
- `wind_color()`
- `moon_phase_fraction()`
- `conky_day_name()`
- `conky_day_name_short()`

##### `lua/weather/moon.lua`

lua/weather/moon.lua — Conky accessors for moon rise/set, high/low, phase, and arc position

**Exported functions**

- `conky_moon_rise_time()`
- `conky_moon_rise_azimuth()`
- `conky_moon_set_time()`
- `conky_moon_set_azimuth()`
- `conky_moon_high_time()`
- `conky_moon_high_elevation()`
- `conky_moon_low_time()`
- `conky_moon_low_elevation()`
- `conky_moon_phase()`
- `conky_moon_x()`
- `conky_moon_y()`
- `need_to_draw_moon_icon()`

##### `lua/weather/sun.lua`

lua/weather/sun.lua — Conky accessors for sun rise/set, noon/midnight, and arc position

**Exported functions**

- `conky_sun_rise_time()`
- `conky_sun_rise_azimuth()`
- `conky_sun_set_time()`
- `conky_sun_set_azimuth()`
- `conky_sun_noon_time()`
- `conky_sun_noon_elevation()`
- `conky_sun_midnight_time()`
- `conky_sun_midnight_elevation()`
- `conky_sun_x()`
- `conky_sun_y()`
- `need_to_draw_sun_icon()`

##### `lua/weather/weather_data.lua`

lua/weather/weather_data.lua — Conky accessors for current, hourly, and daily weather values

**Exported functions**

- `conky_weather_cur_time()`
- `conky_weather_cur_interval()`
- `conky_weather_cur_temp()`
- `conky_weather_cur_humidity()`
- `conky_weather_cur_apparent()`
- `conky_weather_cur_is_day()`
- `conky_weather_cur_precip()`
- `conky_weather_cur_rain()`
- `conky_weather_cur_showers()`
- `conky_weather_cur_snow()`
- `conky_weather_cur_code()`
- `conky_weather_cur_clouds()`
- `conky_weather_cur_pressure()`
- `conky_weather_cur_surface()`
- `conky_weather_cur_visibility()`
- `conky_weather_cur_uv()`
- `conky_weather_cur_radiation()`
- `conky_weather_cur_wind_speed()`
- `conky_weather_cur_wind_dir()`
- `conky_weather_cur_wind_gust()`
- `conky_weather_cur_dewpoint()`
- `conky_weather_hour_time()`
- `conky_weather_hour_temp()`
- `conky_weather_hour_humidity()`
- `conky_weather_hour_wind_speed()`
- `conky_weather_hour_dewpoint()`
- `conky_weather_hour_apparent()`
- `conky_weather_hour_precip_prob()`
- `conky_weather_hour_precip()`
- `conky_weather_hour_snow()`
- `conky_weather_hour_code()`
- `conky_weather_hour_clouds()`
- `conky_weather_hour_pressure()`
- `conky_weather_hour_surface()`
- `conky_weather_hour_visibility()`
- `conky_weather_hour_wind_dir()`
- `conky_weather_hour_wind_gust()`
- `conky_weather_hour_uv()`
- `conky_weather_hour_is_day()`
- `conky_weather_hour_radiation()`
- `conky_weather_day_time()`
- `conky_weather_day_code()`
- `conky_weather_day_temp_max()`
- `conky_weather_day_temp_min()`
- `conky_weather_day_apparent_max()`
- `conky_weather_day_apparent_min()`
- `conky_weather_day_sunrise()`
- `conky_weather_day_sunset()`
- `conky_weather_day_daylight()`
- `conky_weather_day_sunshine()`
- `conky_weather_day_uv()`
- `conky_weather_day_uv_clear()`
- `conky_weather_day_precip_sum()`
- `conky_weather_day_rain_sum()`
- `conky_weather_day_showers_sum()`
- `conky_weather_day_snow_sum()`
- `conky_weather_day_precip_hours()`
- `conky_weather_day_precip_prob()`
- `conky_weather_day_wind_max()`
- `conky_weather_day_gust_max()`
- `conky_weather_day_wind_dir()`
- `conky_weather_day_radiation()`
- `conky_weather_day_et0()`
- `conky_weather_cur_code_text()`
- `conky_weather_cur_wind_full()`
- `conky_weather_hour_code_text()`
- `conky_weather_hour_precip_icon()`
- `conky_weather_hour_time_str()`
- `conky_weather_day_code_text()`
- `conky_weather_sunrise()`
- `conky_weather_sunset()`
- `conky_weather_day_uv_text()`
- `conky_weather_day_precip_hours_text()`

##### `lua/weather/weather_icons.lua`

lua/weather/weather_icons.lua — Computes icon file paths for weather, moon, and wind states

**Exported functions**

- `conky_icon_current_weather()`
- `conky_icon_hour_weather()`
- `conky_icon_day_weather()`
- `conky_icon_moon()`
- `conky_icon_current_wind()`
- `conky_icon_hour_wind()`
- `conky_icon_img_line()`
- `conky_icon_img_current_weather()`
- `conky_icon_img_hour_weather()`
- `conky_icon_img_day_weather()`
- `conky_icon_img_moon()`
- `conky_icon_img_current_wind()`
- `conky_icon_img_hour_wind()`

##### `lua/weather/weather_translations.lua`

lua/weather/weather_translations.lua — Maps weather codes, wind directions, and moon phase to text

**Exported functions**

- `conky_weather_code_text()`
- `conky_wind_direction_text()`
- `conky_moon_phase_text()`

#### Hardware data

##### `lua/hardware/battery.lua`

lua/hardware/battery.lua — Battery and external-device charge monitoring via sysfs, UPower, and BlueZ/D-Bus.

**Exported functions**

- `conky_battery_health_data()`
- `conky_battery_status()`
- `conky_battery_time()`
- `conky_headset_info()`
- `conky_mouse_info()`
- `conky_external_battery_list()`
- `conky_external_battery_count()`
- `conky_external_battery_name()`
- `conky_external_battery_charge()`

##### `lua/hardware/core.lua`

lua/hardware/core.lua — Shared utilities: caching, sysfs readers, DMI access, sensor parsing, and update counters.

**Exported functions**

- `parse_num()`
- `starts_with()`
- `dmi()`
- `get_sensor_val()`
- `get_root_device()`
- `cached()`
- `pread()`
- `read_num()`
- `conky_updates_repo()`
- `conky_updates_aur()`

##### `lua/hardware/dmi.lua`

lua/hardware/dmi.lua — Thin wrappers exposing DMI/SMBIOS fields from sysfs to Conky.

**Exported functions**

- `conky_sys_vendor()`
- `conky_product_name()`
- `conky_product_family()`
- `conky_product_sku()`
- `conky_board_name()`
- `conky_board_vendor()`
- `conky_board_version()`
- `conky_bios_vendor()`
- `conky_bios_version()`
- `conky_bios_date()`
- `conky_bios_release()`
- `conky_chassis_vendor()`
- `conky_chassis_type()`
- `conky_chassis_type_human()`

##### `lua/hardware/info.lua`

lua/hardware/info.lua — Hardware identification: CPU model, NVMe model, and OS install date.

**Exported functions**

- `conky_cpu_name()`
- `conky_nvme_model()`
- `conky_install_date()`
- `conky_uptime_fmt()`

##### `lua/hardware/mtp.lua`

lua/hardware/mtp.lua — MTP device detection and storage usage via KDE kmtpd or GVFS.

**Exported functions**

- `conky_mtp_data()`
- `conky_mtp_count()`
- `conky_mtp_perc()`

##### `lua/hardware/network.lua`

lua/hardware/network.lua — WiFi status, public IP info, ping metrics, and wireless accessors for Conky.

**Exported functions**

- `conky_wifi_interface()`
- `conky_wifi_active()`
- `conky_public_ip()`
- `conky_public_city()`
- `conky_public_country()`
- `conky_ping_avg()`
- `conky_ping_jitter()`
- `conky_wifi_ap()`
- `conky_wifi_bitrate()`
- `conky_wifi_ip()`
- `conky_wifi_channel()`
- `conky_wifi_essid()`
- `conky_wifi_freq()`
- `conky_wifi_downspeed()`
- `conky_wifi_downspeedf()`
- `conky_wifi_upspeed()`
- `conky_wifi_upspeedf()`
- `conky_wifi_v6addrs()`
- `conky_wifi_link_qual()`
- `conky_wifi_link_qual_max()`
- `conky_wifi_link_qual_perc()`
- `conky_wifi_mode()`

##### `lua/hardware/sensors.lua`

lua/hardware/sensors.lua — Hardware sensor readings (CPU, NVMe, WiFi temps and fan speed) via lm_sensors.

**Exported functions**

- `conky_cpu_temp()`
- `conky_cpu_core_temp()`
- `conky_nvme_temp()`
- `conky_wifi_temp()`
- `conky_fan_speed()`

##### `lua/hardware/usb.lua`

lua/hardware/usb.lua — Mounted USB block device detection and enumeration via lsblk.

**Exported functions**

- `conky_usb_list()`
- `conky_has_usb()`
- `conky_usb_count()`
- `conky_usb_name()`
- `conky_usb_mount()`

#### Google data

##### `lua/google/core.lua`

lua/google/core.lua — loads Google JSON data files into a global `G` table and exposes helpers for labels, senders, and dates

**Exported functions**

- `G.populate()`
- `load_google_data()`
- `google_label_text()`
- `google_msg_label()`
- `google_label_is_system()`
- `google_sender_name()`
- `google_date_str()`

##### `lua/google/data.lua`

lua/google/data.lua — Google data accessors for the Conky widget layer.

**Exported functions**

- `conky_google_unread_count()`
- `conky_google_gmail_count()`
- `conky_google_gmail_subject()`
- `conky_google_gmail_from()`
- `conky_google_gmail_date()`
- `conky_google_gmail_label()`
- `conky_google_gmail_id()`
- `conky_google_gmail_is_unread()`
- `conky_google_calendar_count()`
- `conky_google_calendar_summary()`
- `conky_google_calendar_start()`
- `conky_google_calendar_end()`
- `conky_google_calendar_location()`
- `conky_google_calendar_hangout()`
- `conky_google_tasks_count()`
- `conky_google_tasks_title()`
- `conky_google_tasks_due()`
- `conky_google_tasks_status()`
- `conky_google_tasks_list_title()`
- `conky_google_contacts_count()`
- `conky_google_contacts_name()`
- `conky_google_contacts_phone()`
- `conky_google_drive_count()`
- `conky_google_drive_filesize()`
- `conky_google_drive_name()`
- `conky_google_drive_doctype()`
- `conky_google_youtube_count()`
- `conky_google_youtube_title()`
- `conky_google_meet_count()`

#### Top-level Lua modules

##### `lua/apps.lua`

[[[

**Exported functions**

- `apps_list()`
- `apps_find()`
- `apps_by_wmclass()`
- `apps_clear_cache()`

##### `lua/lyrics.lua`

lyrics.lua — synchronized lyrics widget

**Exported functions:** module registration or local helpers only.

##### `lua/lyrics_daemon.lua`

lyrics_daemon.lua — pure-Lua lyrics fetcher + synchronizer (standalone)

**Exported functions:** module registration or local helpers only.

##### `lua/mouse_actions.lua`

mouse_actions.lua — view-switching and hover helpers (support module)

**Exported functions**

- `switch_view()`
- `view_toggle()`
- `on_hover_group()`
- `on_leave_group()`

##### `lua/nowplaying.lua`

nowplaying.lua — "now playing" media data provider (support module)

**Exported functions**

- `conky_nowplaying_player()`
- `conky_nowplaying_title()`
- `conky_nowplaying_artist()`
- `conky_nowplaying_album()`
- `conky_nowplaying_status()`
- `conky_nowplaying_art_path()`

##### `lua/require.lua`

require.lua — central module loader for the ConkyNextGen engine

**Exported functions:** module registration or local helpers only.

##### `lua/songtext.lua`

songtext.lua — synchronized lyrics data provider (support module)

**Exported functions**

- `conky_lyrics_status()`
- `conky_lyrics_title()`
- `conky_lyrics_artist()`
- `conky_lyrics_current()`
- `conky_lyrics_prev()`
- `conky_lyrics_next()`
- `conky_lyrics_position()`
- `conky_lyrics_position_ms()`
- `conky_lyrics_total()`
- `conky_lyrics_index()`
- `conky_lyrics_synced()`

#### Panel modules

##### `panel_systray/clock.lua`

clock.lua — digital clock text widget for the bottom panel

**Exported functions**

- `clock_install()`

##### `panel_systray/panel.lua`

panel.lua — bottom panel widget: full-width bar hosting the systray

**Exported functions:** module registration or local helpers only.

##### `panel_systray/tasklist.lua`

tasklist.lua — taskbar for the bottom panel: open windows as icon+title slots

**Exported functions**

- `tasklist_update()`
- `tasklist_paint()`
- `TLW()`
- `slot_state()`
- `slot_icon()`
- `slot_title()`
- `TL_CLICK_STR()`
- `tasklist_install()`

### Shell backend reference

#### `sh/common.sh`

!/bin/bash

**Shell functions**

- `log()`
- `require_cmds()`
- `curl_cmd()`
- `urlencode()`

#### `sh/conky_check.sh`

!/usr/bin/env bash

**Shell functions:** script entry point only.

#### `sh/fetch_alerts.sh`

!/bin/bash

**Shell functions**

- `fetch_alerts()`

#### `sh/fetch_all.sh`

!/bin/bash

**Shell functions:** script entry point only.

#### `sh/fetch_google.sh`

!/bin/bash

**Shell functions**

- `require_gog()`
- `gog_emit()`
- `fetch_google_gmail()`
- `fetch_google_calendar()`
- `fetch_google_tasks()`
- `fetch_google_contacts()`
- `fetch_google_drive()`
- `fetch_google_youtube()`
- `fetch_google_meet()`
- `fetch_google()`

#### `sh/fetch_maps.sh`

!/bin/bash

**Shell functions**

- `fetch_maps()`

#### `sh/fetch_network.sh`

!/bin/bash

**Shell functions**

- `fetch_ping()`
- `fetch_ipinfo()`

#### `sh/fetch_nowplaying.sh`

!/bin/bash

**Shell functions**

- `fetch_nowplaying()`

#### `sh/fetch_updates.sh`

!/bin/bash

**Shell functions**

- `require_cmds()`

#### `sh/fetch_weather.sh`

!/bin/bash

**Shell functions**

- `fetch_weather()`

#### `sh/gog_open_mail.sh`

!/bin/bash

**Shell functions**

- `open_gmail_thread()`

### Development tools and Designer modules

#### `tools/lfsdebug.lua`

local tool_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

#### `tools/list_functions.lua`

tools/list_functions.lua

#### `tools/string_measure.lua`

tools/string_measure.lua — measurer: which language produces the longest string?

#### `tools/string_shorten.lua`

tools/string_shorten.lua — ahol rövidíteni lehet a fordításokban?

#### `sh/designer/__init__.py`

NextGen Designer — GTK3 visual editor for widget.lua.

#### `sh/designer/color_picker.py`

Custom color picker button with screen eyedropper support.

#### `sh/designer/constants.py`

Lua template constants, theme data, and helper functions.

#### `sh/designer/lua_helpers.py`

Lua code generation helpers for draw items, groups, views, mouse actions.

#### `sh/designer/main.py`

NextGen Designer — GTK3 visual editor for widget.lua.

#### `sh/designer/update_checker.py`

GitHub update checker for the NextGen Designer.

#### `sh/designer/utils.py`

Path resolution, window state, and small utility functions.

#### `sh/designer/engine/__init__.py`

Engine core — pure-Python logic (no GTK dependency).

#### `sh/designer/engine/activity_log.py`

In-memory error/activity log for the designer GUI.

#### `sh/designer/engine/gradient_gen.py`

gradient_gen.py — Standalone gradient / palette generator (no Lua writes).

#### `sh/designer/engine/lua_data.py`

List the project's conky_* Lua functions for the designer's function picker.

#### `sh/designer/engine/lua_parser.py`

Lua table parser — parses widget.lua draw[] entries into Python dicts.

#### `sh/designer/engine/theme_engine.py`

Theme engine — Python reimplementation of Lua theme_engine.lua

#### `sh/designer/engine/theme_writer.py`

theme_writer.py — Serialize the THEMES dict into the inline THEMES = {...}

#### `sh/designer/engine/widget_schema.py`

PropertySpec metadata for designer widgets.

#### `sh/designer/tests/test_widget_schema.py`

Headless parity + integrity tests for engine.widget_schema.
