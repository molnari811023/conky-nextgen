# NextGen — Table of Contents

- What is NextGen?
- What can I do with it?
- Installation / Requirements
- The Designer (vs. manual editing, quick start, main window, tabs, properties, preview, save, console)
- Project Structure (layout, runtime/designer/shell/lua files, icons, tmp, config files, loading order)
- Colors & Gradients
- Themes: Understanding, Palette, Gradients, Defaults, Creating your own
- Conky Configuration, Conky Variables
- Troubleshooting (designer, preview, widgets, weather)
- Configuration Reference / Environment Variables
- Shell backend (sh/): data flow, dependencies, each module
- Lua engine (lua/): dependencies, views & groups, each module
- Glossary

## What is NextGen?

**Conky NextGen** is a modular Conky UI framework: a Lua engine (Cairo drawing) with a Bash backend (data fetching). Configuration lives in a single `widget.lua`; the runtime loads the framework from there.

### Layout

- `widget.lua` — theme block (THEMES) + the `draw` list of widgets
- `lua/` — framework modules; documented in [Lua engine](#lua-engine-lua)
- `sh/` — Bash/Python fetchers (weather, network, now playing, updates…)

### Hooks

- `conky_core_main()` — draw hook (`lua_draw_hook_pre`): renders the `draw` list, applies THEMES, evaluates views/groups/draw_me.
- `conky_cleanup()` — shutdown hook.
- `conky_on_mouse()` — mouse hook (`lua_mouse_hook`).

## What can I do with it?

- Build desktop panels with **bars, graphs, rings, analog clocks, calendars, images and SVG** widgets.
- Show **live system data**: CPU, memory, sensors, network, battery, storage.
- Show **rich weather data**: current conditions, hourly/daily forecasts, air quality, alerts, sun & moon, space weather.
- Switch between **views** and highlight **groups** with mouse events (click → view).
- Use **themes**: a palette + gradient names + per-widget defaults fill every color automatically.
- Edit it all visually in the **Designer** without hand-writing Lua.

## Installation

1.  Clone or copy the project into `~/.conky/`.
2.  Install Conky (with Cairo + Xft) and the framework's runtime dependencies (see Requirements).
3.  Make the fetchers executable: `chmod +x sh/*.sh`.
4.  Run sh/0_fetch_all.sh once to populate `tmp/` with the cached JSON data.
5.  Start Conky with the generated config, or open the Designer to adjust everything first.

## Requirements

- **Conky 1.24.x** with Cairo, Xft, X11 (tested with **1.24.3‑pre**, stable Lua 5.5 C bindings and working mouse hooks).
- **Lua** for the framework itself; required modules: `lua-dkjson`, `lua-expat`, `lua-filesystem`, `lua-luautf8`; `librsvg` for SVG widgets. Optional: `lua-lpeg` (speeds up dkjson's JSON decoding).
- **Python 3** + **PyGObject (GTK3)** for the Designer.
- **Bash** + `curl`/`jq` for the data fetchers.
- **playerctl** for now-playing data.
- **lm-sensors** for hardware sensor readings (CPU/NVMe temperatures, fan speeds, WiFi adapter temperature).
- Optional: `kio-extras` (MTP under KDE Plasma), XDG icon themes (icons).

## Colors & Gradients

Color fields are **gradient stop lists**: `{ { 0.0, "#RRGGBB", 1 }, { 1.0, "#RRGGBB", 1 } }`. A single-color field still needs the nested list. Instead of writing stops by hand you can reference a *gradient name* from the theme (`fg = "bar_cpu"`).

If the theme defines a default for a widget type, missing color fields are filled from it at render time.

## Understanding Themes

A **theme** is a named table in the global `THEMES` block of `widget.lua`:

``` code
THEMES = {
  theme = {
    palette   = { bg_dark = "#202326", fg = "#fcfcfc", ... },
    gradients = { bar_cpu = { { 1, "#3daee9", 1 } }, ... },
    defaults  = { bar = { fg = ..., bg = ... }, ... },
  },
}
```

The engine keeps `THEMES` global and merges the block from `widget.lua` (`THEMES = THEMES or {}`), so the definitions are picked up when the modules load. `DEFAULT_THEME` (default `"theme"`) selects the active theme when an item does not set its own `theme` field.

The resolution pipeline in `apply_theme(item)`:
1. **Color resolution** — every color field (`fg`, `bg`, `border`, `color`, `grid_color`) that is a *string* is treated as a gradient name and replaced by the matching stops from `theme.gradients`. Unresolved names are kept as-is.
2. **Defaults fill** — for each missing field on the widget, the value from `theme.defaults[item.type]` is copied in. Explicit widget values always win.

The Designer mirrors this logic in `engine/theme_engine.py`. You can switch themes at runtime from the Designer's Theme tab, which edits the same block.

## Palette

The palette maps semantic color names to hex values, e.g. `bg_dark = "#202326"`. Stops that reference a palette name resolve through it, and the Theme tab lets you tune every entry live. The palette entries are the building blocks that the gradients then point to.

## Gradients

Named gradient stop lists, e.g. `bar_cpu = { { 1, "#3daee9", 1 } }`. A color field can reference one by name: `fg = "bar_cpu"`. This is how the default theme keeps bars/rings/graphs consistently colored — the renderer resolves the name to the stop list at draw time.

Each stop is `{ pos, "#RRGGBB", alpha }` where `pos` runs from 0 to 1. Interpolation between stops uses OKLab for perceptually even color transitions (`get_color_from_list()`).

## Defaults

Per-widget-type default properties. When a widget is missing a field that the theme defines for its type, the renderer fills it in — so a plain `type = "bar"` still looks right:

``` code
defaults = {
  bar  = { height = 12, fg = "bar_cpu", bg = "bg" },
  ring = { radius = 35, thickness = 8 },
},
```

## Creating your own Theme

1.  Copy the `theme` block inside `THEMES`, rename it (e.g. `darkblue`).
2.  Adjust palette colors and add your own gradients.
3.  Add/override per-widget defaults.
4.  Set `DEFAULT_THEME = "darkblue"` (either in the THEMES block or before the modules load).

You can switch themes at runtime from the Designer's Theme tab, which edits the same block. Widgets can also opt out per item with `theme = "other_theme"`.

## Conky Configuration

The Designer's Conky tab writes the `conky.config` table of the generated `.conf`: window type, alignment, gaps, update interval and font. `lua_load = 'widget.lua'` plus the `lua_draw_hook_pre`/`lua_mouse_hook`/`lua_shutdown_hook` wiring is what makes the framework run.

## Conky Variables

Widgets embed standard Conky templates directly in `value`/`text`/`draw_me`: `${cpu}`, `${mem}`, `${fs_used /}`, `${uptime}`… The Designer previews the layout in the **real, running Conky**, so values always match runtime.

## Designer Problems

- **widget.lua doesn't load** — read the Developer Console (View menu); the parse error line is reported. Fix by hand, then File → Reload.
- **Values not saved** — press Enter to apply a property edit; invalid numbers are rejected.
- **Item missing from list** — the Items tab is filtered by the current view; a widget without `view` belongs to all views.

## Preview Problems

- Nothing appears — press **Conky → Run** (left column) to start the live
  preview; the window needs ~3 updates (~3 s) before the first draw.
- Wrong size — set W/H/Pad on the Conky tab to your target screen size.
- A `w`/`h` = 0 widget may show nothing until content defines a size
  (background with h=0 sizes to content).
- The preview is the real Conky; if a value is empty, check the JSON cache in
  `tmp/` and the Developer Console (it tails the conky log).

## Widget Problems

- Color fields are stop lists: `{ { 0.0, "#RRGGBB", 1 } }` — a single-color field still needs the nested list.
- `alarm_color` is a stop list too; plain hex is coerced.
- Ring/bar full scale — `max` protects against NaN (max≤0 → 1); set max to a sane value like 100 for `${cpu}`.
- Non-numeric x/y are kept as comments (`-- x = 'auto' skipped`); use real numbers for predictable layout.

## Weather Problems

- Empty values — the fetchers run in the background; check `tmp/` JSON files and run `sh/0_fetch_all.sh` once.
- Wrong units — use `conky_unit_cur_*()` / `_hour_*` / `_day_*` accessors; they follow the locale, don't hardcode °C.

## Configuration Reference

Key settings written by the Designer into the generated `.conf`:

| Setting                | Meaning                                  |
|------------------------|------------------------------------------|
| `lua_load`             | widget.lua — the framework entry.        |
| `lua_draw_hook_pre`    | conky_core_main — renders the draw list. |
| `lua_mouse_hook`       | conky_on_mouse — mouse events.           |
| `minimum_width/height` | Canvas size (W/H from the toolbar).      |
| `update_interval`      | Conky refresh interval (s).              |

## The Designer

The Designer is a GTK3 visual editor for the Conky NextGen framework. It edits
`widget.lua` (the widget data + bootstrap file) through a GUI, renders a live
PNG preview of the layout, and on Save also writes the `.conf` and `.png`
files that Conky Manager expects.

```bash
python3 ~/.conky/sh/designer/main.py
conky -c ~/.conky/widget.conf
```

### Designer vs. manual editing

The Designer is a GTK3 visual editor for `widget.lua`. It groups widgets by
`group`, filters them by the current `view`, and writes back the same file —
the framework modules in `lua/` are never touched.

**Designer**

- Point-and-click property editing with a live preview.
- Guaranteed valid output (values are validated before they are applied).
- Gradient editor, theme tab, view/group management built in.

**Manual**

- Full control over every value and expression.
- Easier to diff in version control.
- Requires knowing the framework's conventions.

Both are interchangeable: the file format is the same either way, so you can
hand-edit and then File → Reload to bring the changes back into the designer.

### Quick start

1. Start the designer from the project root:
   `python3 ~/.conky/sh/designer/main.py` — an empty canvas opens with the
   live PNG preview on the left and the editor tabs on the right.
2. Create your first widget: on the **Items** tab press **Add Item**, pick a
   type (e.g. **Bar**), a group if you have one, and a count, then **Add**.
3. The item appears in the list. Select it and press **Edit Props** (or
   double-click the row) to open the property editor.
4. Set `value` to `${cpu}`, `max` to `100`, and give it a `width`/`height`.
   Press **Enter** to apply each change.
5. Watch the live preview on the left; it re-renders automatically. The
   **Render View** button re-renders immediately, the **View:** dropdown
   switches which view you edit/preview, and **Pad:** sets the `_PADDING`
   spacing around the layout.
6. Set the canvas size in the **Conky** tab (`minimum_width` /
   `minimum_height`) — this is what the preview renders to.
7. **File → Save** writes `widget.lua` plus the sibling `.conf` and `.png`.
8. Start Conky with the generated config to see it live:
   `conky -c ~/.conky/widget.conf`.

#### Position & size

Every widget has an `x`/`y` position in px. Size fields depend on the type:
`width`/`height` for bars/graphs/images, `radius`/`thickness` for rings,
`w`/`h` for backgrounds and SVG. Non-numeric x/y values (e.g. `x = "auto"`)
are preserved in the file as comments and skipped by the editor.

### How the Designer finds the project

The designer can live anywhere and still point at a conky-nextgen checkout.
The project root is resolved in this order:

1. `--conky-dir <path>` command line flag
2. `CONKY_NEXTGEN_DIR` environment variable
3. `conky_dir = /path` in `~/.config/conky-designer.conf`
4. default: the in-tree layout (`sh/designer/` is 3 levels below the root)

The window state (size/maximized) is remembered in
`~/.config/conky-designer-state.json`.

### Main window

The window is split in two:

- **Left: live preview.** A `View:` dropdown, a `Render View` button and a
  `Pad:` spin (the `_PADDING` global — spacing added around the layout).
  Below is the rendered PNG of the current view, re-rendered automatically
  ~200 ms after every change.
- **Right: menu bar + notebook of 8 tabs** (Items, Groups, Views, Mouse,
  Gradient, Theme, Conky, Weather & Icons) and the status bar at the bottom.

#### Menu bar

**File**

| Item | Action |
|---|---|
| New (empty) | Confirms, then replaces the editor with an empty `widget.lua` template. Nothing is written until you press Save. |
| Save | Generates and writes the current layout (see *What Save writes* below). |
| Open... | File chooser starting in the project root. Validates the file (must parse and contain draw items/groups/views, with a warning otherwise), copies it to the work file and loads it. |
| Save As... | Saves the layout to a chosen path, then treats it as the new current file. |
| Reload | Re-reads `widget.lua` from disk (or the legacy `main.lua`) discarding unsaved edits (asks first). |
| Show the code | Writes the current in-memory layout to the work file and opens it in the default editor (`xdg-open`). |
| Quit | Same as closing the window (prompts if there are unsaved changes). |

**View**

- `Developer Console...` — live log of render/conky/lua activity (see below).

**Help**

- `Conky Manual` — converts `/usr/share/man/man1/conky.1.gz` to HTML and opens it.
- `NextGen Handbook` — converts `NextGen.md` to HTML and opens it (always fresh).
- `About` — opens the project page on GitHub.

The generated manual/handbook HTML files land in `/tmp/conky-designer-help/`
(never inside the conky tree) and get a built-in search box that highlights
matches with prev/next navigation.

### The tabs

#### 1. Items

Manages the `draw` list. Columns: **Group**, **Type**, **Value** (short
summary: text content for text widgets, value expression for bar/ring/graph,
filename for image/svg, size for background, endpoints for line).

The list is always filtered to the current view (see the preview's `View:`
dropdown) and sorted by group. This mirrors what the Lua engine actually
draws (`_items_for_view` applies the same rules as `draw_allowed`).

Buttons:

- **Add Item** — dialog with *Type* (background, text, bar, graph, ring,
  line, clock, calendar, image, svg), *Group* and *Count*. Each additional
  widget is stacked directly below the previous one (non-overlapping) using
  the widget's inferred height.
- **Delete** — removes the selected item.
- **Edit Props** — opens the Properties window for the selected item
  (double-clicking a row does the same).

#### 2. Groups

Groups bundle items and drive view switching. The list shows **Name** and
the **Views** the group belongs to. Selecting a group shows its properties
below the list:

- `name`
- `views` (comma-separated view names)
- `draw_me` — group-level conditional drawing: `— none —`, `true (always
  draw)`, `false (never draw)` or `custom…` (a conky `${...}` template or a
  Lua expression; the `ƒx` button opens the project function picker).

The name and views rows commit on **Enter**. Deleting a group clears the
`group` field of every item that referenced it (asks first).

#### 3. Views

Views are named layouts. The list shows **Name** and the groups assigned to
that view.

- **Add View** — name dialog (default `view_N`, must be unique).
- **Delete View** — removes the view and strips its references from all
  items and groups (asks first and reports how many items/groups were
  affected).
- Renaming a view renames it everywhere: the view's own name plus every item
  `view` field and every group `views` list that referenced the old name
  (duplicate names are rejected).

#### 4. Mouse

Configures the `MOUSE_*_ACTION` callbacks of the framework. The **Mouse
actions** check button enables/disables the whole block (`_MOUSE_ENABLED`).

Each of the ~22 events (Enter/Leave, hover, all scroll directions with
Ctrl/Shift/Alt, left/right/middle/back/forward click, Ctrl/Shift/Alt+click)
has a dropdown:

- `— (none)` — no action (`nil`).
- every function defined in `lua/mouse_actions.lua` (parsed automatically).
- `switch_view (<view>)` / `view_toggle (<view>)` — one entry per view, e.g.
  `function() switch_view("main") end`.

An existing custom value is kept as an extra entry so nothing is lost when a
file is reloaded. Only non-nil actions are written to the Lua output.

#### 5. Gradient

A standalone gradient/shades lab — it does **not** write to Lua files, it
produces text you paste elsewhere.

- **Stops** — add `+ Stop` rows (position 0.0–1.0, `#RRGGBB`, alpha), remove
  per stop. `Mode:` (linear/smooth/dot/banded/…) and `Steps:` (2–64) change
  the interpolation preview.
- **Shades** — pick a base color and a step count (`Db:`) to generate
  lightening/darkening shades.
- Outputs: a read-only `Output` field in the THEMES block gradient format,
  plus three copy buttons — `Copy Lua stops`, `Copy hex palette`,
  `Copy shades`. The swatches render live.

#### 6. Theme

Edits the single theme (`"theme"`), whose state is kept in memory and only
written to `widget.lua` on **Save**. It has three sub-tabs:

- **Palette** — `+ Palette color` adds a named color (`key` entry + color
  picker). Palette colors can be referenced from gradient/default fields.
  Rows can be renamed (Enter) or removed.
- **Gradients** — `+ Gradient` adds a named gradient to the left list.
  Selecting one opens a stops editor in the right pane (stops rows with
  position / color / alpha, `+ Stop`, preview swatch). Rename and delete via
  the list.
- **Defaults** — `+ Widget type` adds a per-widget-type default set. For the
  selected type you can `+ field` rows (key entry + value entry). These
  defaults are applied to widgets that don't specify their own value, and
  they let the property editor skip writing values that already equal the
  theme default.

#### 7. Conky

Conky window settings that are emitted as a **.conf** file (the Conky
Manager triplet), **not** stored in the Lua:

- `gap_x`, `gap_y` — leave empty for `auto` (value omitted, Conky decides).
- `alignment` — the 9 position combos.
- `own_window_hints` — default `below,sticky,skip_taskbar,skip_pager`.
- `minimum_width` / `minimum_height` — also drive the preview canvas size.

Changing the size re-renders the preview. When opening a file, the sibling
`.conf` (if present) is parsed back into these fields.

#### 8. Weather & Icons

- **Use weather** check button — enables writing the weather icon block.
- **Weather icon set** — `default`, `metno`, `weathermap`, `wmo`.
- **Icon theme (XDG)** — any installed icon theme (listed dynamically); empty
  means "not written".

The `JSON_PATH` block is always written (hardware/network and nowplaying
read it too); the weather icon lines are only written when weather is
enabled, and the icon theme line only when one is chosen.

### Properties window

Opened via **Edit Props** or double-click. Editing applies live to the
in-memory item; closing the window saves. The title shows
`Properties — <type> [<index>]`.

Properties come from the per-widget schema in
`engine/widget_schema.py`, grouped by section headers (e.g. *Appearance*,
*Colors*, *Geometry*). Conditional visibility: a `bar` widget only shows
`blocks` for block/dot/polygon mode and `sides` for polygon mode.

Editor widgets depend on the property kind:

| Kind | Editor |
|---|---|
| int / float | spin button |
| bool | check button |
| enum | combo box |
| string / font / color | text entry (Enter commits) |
| template / text / value | entry + `ƒx` button → project `conky_*` function picker |
| path | entry + `…` button → file chooser |
| code | multi-line text view (commits on focus-out) |
| stops | entry + `Edit…` → gradient stops editor |
| draw_me | `— none / true / false / custom` combo + entry + `ƒx` |

The `ƒx` picker lists all `conky_*` functions of the project (from
`lua_data.list_conky_functions()`) with their call signature, arguments and
source file, has a live search box, and inserts the call at the cursor.

A field that exactly matches the theme default for that widget type is
labelled `(theme)` and is skipped on save (keeps the Lua file small).
`+ Prop` adds an arbitrary extra key/value pair.

### Live editing / preview

There is no separate renderer anymore: the designer edits **the live
`widget.lua`** directly. Every committed edit is written atomically (diff-
guarded, so identical writes are skipped) and the running Conky picks it up —
through its own inotify reload on Wayland, or a full restart on X11 where a
reload makes the window disappear.

**X11 ghost-clearing.** While managing the preview on X11, the designer does
not launch the deployed `.conf`: it writes a temporary preview `.conf` into
`WORK_DIR` that appends `live_clear.lua` to the `lua_load` line (after the
widget file) and spawns Conky with that instead. `live_clear.lua` overrides
the no-op `clear_surface(cr)` hook of `draw_core.lua` so every frame starts
by wiping the surface (`CAIRO_OPERATOR_CLEAR`) — otherwise moved or shrunk
items would leave permanent ghost pixels on the ARGB window. The deployed
`.conf` never references the helper, so the fix is active only while the
designer is managing its preview. On exit the designer kills its own preview
and re-spawns the widget with the plain `.conf` (and deletes the preview
file); on Wayland no helper is used at all, because the compositor already
clears the buffer.

- Left column has the **Conky Run / Stop / Restart** buttons plus an **Export
  PNGs** button and a live `conky: running/stopped` state label.
- The 2 s watchdog restarts the preview conky if it dies while managed.
- Ownership is per `.conf` (scanned via `/proc/<pid>/cmdline`), so the
  designer never kills a conky that runs a different theme, even across
  designer restarts.
- Errors land in the Developer Console (`[LUA-ERR]` / `[CONKY-ERR]` from the
  conky log).

### What Save writes

Save (or Save As) does three things:

1. **`<name>.lua`** — the full generated Lua: config/bootstrap block, weather
   and XDG blocks, the serialized THEMES, `DEFAULT_THEME`, `_PADDING`, every
   `draw[...]` item, `_GROUPS`, `_VIEWS`, the `MOUSE_*` block.
2. **`<name>.conf`** — Conky Manager triplet config that references the Lua
   (`lua_load = '<name>.lua'`, `lua_draw_hook_pre = 'conky_core_main'`,
   `lua_mouse_hook = 'conky_on_mouse'`,
   `lua_shutdown_hook = 'conky_cleanup'`). The `.conf` is only rewritten when
   its content changes (a same-content write would still reload/break conky).
3. **`<name>.png`** (+ `<name>_<view>.png` for every extra view) — exported
   via the running conky's own surface (`lua/core/capture.lua`), so it works
   on Wayland where no screenshot tool can grab the window.

The default save path is `<project>/widget.lua`. Writes are atomic (temp
file + rename). The status bar reports `Saved <file> (+ .conf, .png)`.

### Developer Console

Opened from **View → Developer Console...**. Tails the managed conky's
stderr/stdout log (1 s poll) followed by timestamped activity-log entries, so
Lua parse errors and conky warnings appear live, with a `Clear` button.

### Workflow notes

- Everything you edit lives in memory; **Save** writes it to disk. Reload /
  Open / New / Quit all warn if there are unsaved changes (dirty tracking).
- The work file and the theme snapshot live in a unique temp dir
  (`/tmp/conky_designer_*`) so two designer instances never race on the same
  file. It is removed on quit.
- A non-numeric `gap_x`/`gap_y` in the Conky tab is skipped in the `.conf`
  with a comment instead of breaking it.
- The `gradient` banding rule from the README applies: two colors too close
  together produce visible bands in Cairo — the Gradient tab is a quick way
  to check contrast before pasting stops into a widget.


## Project Structure

Everything in `~/.conky/` — what each file and folder does, what reads and
writes what, and how the pieces connect into the finished widget.

### Directory layout

```
~/.conky/
├── widget.lua / *.lua          # widget data (designer-generated)
├── widget.conf / *.conf        # Conky config (designer-generated)
├── widget.png / *.png          # preview icons (designer-generated)
├── require.lua                 # Lua module loader
├── nd.svg                      # app icon
├── conky.kwinrule              # KWin window rule
├── nextgen-designer.desktop    # desktop launcher
├── list_functions.lua          # developer tool
├── lua/                        # Lua engine (draw + data accessors)
│   ├── core/                   #   main loop, mouse, themes, i18n, utils
│   ├── draw/                   #   Cairo widget renderers
│   ├── hardware/               #   system info accessors
│   ├── weather/                #   weather/air/alerts/spaceweather accessors
│   ├── require.lua             #   module loader
│   ├── nowplaying.lua          #   MPRIS player accessors
│   └── mouse_actions.lua       #   user-defined mouse callbacks
├── sh/                         # Bash backend (data fetchers)
│   ├── 0_common.sh             #   shared bootstrap
│   ├── 0_fetch_all.sh          #   master dispatcher
│   ├── 4_fetch_weather.sh      #   weather + air + sun/moon
│   ├── 11_fetch_alerts.sh      #   MeteoAlarm
│   ├── 12_fetch_spaceweather.sh#   NOAA space weather
│   ├── 13_fetch_maps.sh        #   map/radar/satellite tiles
│   ├── fetch_network.sh        #   ping + public IP
│   ├── fetch_nowplaying.sh     #   now playing + album art
│   ├── updates.sh              #   Arch repo + AUR update counts
│   ├── all_in_one.sh           #   monolithic fetcher (no sourcing)
│   └── designer/               #   GTK3 visual editor app
├── icons/                      # weather/icon theme PNGs
├── language/                   # gettext .po/.mo (22 languages)
├── debug/                      # standalone test/debug scripts
├── pkg/                        # Arch PKGBUILD + built package
├── tmp/                        # runtime data cache (fetcher output)
├── README.md                   # quick-start + overview
└── NextGen.md                  # full framework documentation
```

### Runtime files

Designer-generated widget bundles. Each `<name>` has a `.lua` (widget data +
bootstrap), `.conf` (Conky Manager triplet), and `.png` (preview icon).

| File | Contents |
|---|---|
| `widget.lua` | The main widget file (created by the designer on Save). Config/bootstrap block, `THEMES`, `DEFAULT_THEME`, `_PADDING`, `draw[]` items, `_GROUPS`, `_VIEWS`, `MOUSE_*` actions. Loaded by Conky via `lua_load`. |
| `<name>.conf` | `conky.config` referencing `<name>.lua`: `lua_draw_hook_pre = 'conky_core_main'`, `lua_mouse_hook = 'conky_on_mouse'`, `lua_shutdown_hook = 'conky_cleanup'`, plus window geometry. |
| `<name>.png` | Preview PNG of the main view (plus `<name>_<view>.png` per extra view). |
| `clock_cal.lua` | Example bundle: a clock (main view) + calendar (calendar view), click toggles views via `MOUSE_CLICK_LEFT = view_toggle("calendar")`. |
| `mem_swap.lua` | Example bundle: memory/swap labels + two bars in one panel. |

### Designer files

`sh/designer/` — the GTK3 visual editor (see The Designer section).

| File | Purpose |
|---|---|
| `main.py` | The editor application (`DesignerWindow`): live Conky preview (Run/Stop/Restart + watchdog) + 8 tabs (Items, Groups, Views, Mouse, Gradient, Theme, Conky, Weather & Icons), properties window, Developer Console, Help. Parses/writes `widget.lua`, generates `.conf`, exports PNGs via the running conky. |
| `engine/lua_parser.py` | `widget.lua` → Python: `draw[]`, `_GROUPS`, `_VIEWS`, `_PADDING`, settings, `THEMES`. |
| `engine/widget_schema.py` | Single source of truth for widget types, property fields, defaults, editor kinds. |
| `engine/lua_data.py` | `list_conky_functions()` for the function picker (static scan of the project's Lua). |
| `engine/gradient_gen.py` | Gradient/shades math for the Gradient tab. |
| `engine/theme_engine.py` | Python mirror of Lua `theme_engine.lua`. |
| `engine/theme_writer.py` | Serializes `THEMES` back to the Lua `THEMES = {...}` block. |
| `engine/activity_log.py` | Thread-safe log feeding the Developer Console. |
| `tests/test_widget_schema.py` | Headless schema/parity tests (`python3 tests/test_widget_schema.py`). |
| `icons/` | Designer window icons. |
| `ui/`, `data/` | Placeholder packages (future home of UI helpers / static data). |

### Shell backend files

`sh/` — the read-only *data producer*. Fetch modules download remote data and
write it into `tmp/`; the Lua modules only ever read those cached files.

| File | What it fetches / does | Writes to `tmp/` |
|---|---|---|
| `0_common.sh` | Shared bootstrap: resolves dirs, sets `$UA`, enforces `curl`/`jq`/`python3`, defines `log`, `require_cmds`, `curl_cmd`, `urlencode`. | — (writes `~/.config/conky-nextgen/user_agent.txt`) |
| `0_fetch_all.sh` | Master dispatcher: sources the modules and runs them by mode (`all`, `weather`, `space`, `alerts`, `map`, `nowplaying`, `network`, or a city name). | — (delegates) |
| `4_fetch_weather.sh` | `fetch_weather(city)` — Open-Meteo geocoding + forecast + air quality, MET Norway sun/moon. | `city.json`, `weather_data.json`, `airquality.json`, `sun.json`, `moon.json` |
| `11_fetch_alerts.sh` | `fetch_alerts()` — MeteoAlarm Atom feed for the country from `city.json`. | `alerts.xml` |
| `12_fetch_spaceweather.sh` | `fetch_spaceweather()` — 8 NOAA SWPC JSON feeds. | `spaceweather_{kp,wind,mag,xray,scales,sunspot,aurora,alerts}.json` |
| `13_fetch_maps.sh` | `fetch_maps(zoom)` — 3×3 tile grid from OSM, RainViewer radar, Environment Canada GDPS (temp/wind), stitched with ImageMagick. | `osm_big.png`, `rain_big.png`, `temp_big.png`, `wind_big.png` |
| `fetch_network.sh` | `fetch_ping()` (ping 1.1.1.1) + `fetch_ipinfo()` (ipinfo.io). | `network_ping.json`, `network_ip.json` |
| `fetch_nowplaying.sh` | `fetch_nowplaying()` — playerctl/CMUS/MPD/MOC + album art (change-cached). | `nowplaying.json`, `album_art.png` |
| `updates.sh` | Standalone (does not source `0_common.sh`): `checkupdates` + AUR RPC, counts with `vercmp`. | `updates.txt` (`"<repo> <aur>"`) |
| `all_in_one.sh` | Monolithic copy of weather/space/alerts/maps fetchers in one script (no sourcing). | same as above |

### Lua engine files

`lua/` — the drawing engine and data accessors. Loaded by `require.lua` in a
strict dependency order (core → weather → hardware → nowplaying → draw).

| File | Purpose |
|---|---|
| `lua/require.lua` | Loads the C bindings (`cairo`, `rsvg`, `imlib2`, `lfs`, `json`) and every framework module. |
| `lua/nowplaying.lua` | `conky_nowplaying_*` accessors reading `tmp/nowplaying.json` (mtime-cached). |
| `lua/mouse_actions.lua` | User callbacks: `switch_view(v)`, `view_toggle(v)`, hover highlight handlers. |

#### `lua/core/`

| File | Purpose |
|---|---|
| `draw_core.lua` | Main loop / draw hook `conky_core_main`: evaluates `draw_me`, filters by view/group, applies theme, auto-interprets strings, adds group offsets, dispatches to draw modules; overridable no-op `clear_surface(cr)` hook right after the cairo context is created (the designer's X11 preview overrides it to clear the surface between moves); `conky_cleanup` frees SVG handles. |
| `draw_group.lua` | Group registration + once-per-second `draw_me` visibility (`GROUP_STATE`). |
| `mouse.lua` | `conky_on_mouse(event)` dispatcher: hover tracking, hit-testing (`click`/`click_view`), scroll (Ctrl/Shift/Alt) and click dispatch, shell action support; logs to `/tmp/conky_mouse.log`. |
| `theme_engine.lua` | `apply_theme(item)`: expands gradient names, fills missing fields from `theme.defaults[type]`. |
| `translate.lua` | Binary `.mo` parser + `conky_get_tr(msgid)`; language from `$LANG`/`$LC_ALL`, fallback `en.mo`. |
| `utils.lua` | Shared helpers: `cache_set`, `hex_to_rgba`, OKLab gradient patterns (anti-banding), `rounded_rect_path`, `normalize_with_suffix` (K/M/G), `draw_get_value`, `interpret_name` (auto-interpretation). |

#### `lua/draw/`

| File | Draws |
|---|---|
| `background.lua` | Rounded-rect panel with gradient `bg` + gradient border; auto-sizes to window or group. |
| `bar.lua` | Horizontal progress bar — `smooth`, `block`, `dot`, `polygon` modes. |
| `graph.lua` | Scrolling time-series graph (`line`/`fill`, autoscale, grid, history in `graph_history`). |
| `ring.lua` (→ `rings.lua`) | Circular ring gauges — `ring`, `smooth`, `dot`, `polygon` modes, alarm color above max. |
| `line.lua` (→ `lines.lua`) | Lines with `solid`/`dashed`/`dotted` styles and gradient fill. |
| `clock.lua` | Analog clock: gradient face/rim, ticks, numbers, three hands. |
| `calendar.lua` | Month grid: title, weekday header, ISO week numbers, dimmed outside days, today highlighted. |
| `text.lua` | Text: conky template expansion, align, wrap, hyphenation via `hyphen` module, gradient fill. |
| `image.lua` | PNG display: scale, crop, rotate, circle/rounded clip, flat tint, alpha. |
| `svg.lua` | SVG via librsvg: cached handles, clip/shape, alpha/tint rasterization; `svg_free_all`. |
| `hyphen.lua` | Pure-Lua TeX/Liang hyphenation; `hyphen.load(dic)` + `hyphen.break_word`. |
| `icon_theme.lua` | XDG icon-theme resolver (index.theme + inheritance). Locals only — currently no exported entry point. |

#### `lua/hardware/`

| File | Accessors |
|---|---|
| `core.lua` | Shared: `cached`, `pread`, `read_file`, `dmi(field)`, `get_sensor_val`, `get_root_device`, `conky_updates_repo/aur` (`tmp/updates.txt`), `chassis_map`. |
| `battery.lua` | Battery health %; Bluetooth headset/mouse battery via BlueZ/upower; `conky_external_battery_*`. |
| `dmi.lua` | `conky_sys_vendor`, `conky_product_name`, BIOS/board/chassis fields from `/sys/class/dmi/id/`. |
| `info.lua` | `conky_cpu_name`, `conky_nvme_model`, `conky_install_date`. |
| `mtp.lua` | MTP device detection (KDE `kmtpd`/`kioclient` or GVFS `gio`), `conky_mtp_count/perc`. |
| `network.lua` | WiFi interface/carrier, public IP/city/country (`network_ip.json`), ping avg/jitter (`network_ping.json`). |
| `sensors.lua` | `conky_cpu_temp`, `conky_cpu_core_temp`, `conky_nvme_temp`, `conky_wifi_temp`, `conky_fan_speed` (from `sensors`). |
| `usb.lua` | USB mount detection via `lsblk`; `conky_usb_list/count/name/mount`. |

#### `lua/weather/`

| File | Accessors |
|---|---|
| `core.lua` | Data hub: loads `weather_data.json`, `airquality.json`, `sun.json`, `moon.json`, `city.json` into `W`; units, day names, sun/moon arc progress, icon-path builders, translated text helpers, `conky_units*`. |
| `current.lua` | Current conditions (temp, humidity, wind, UV, pressure, precip, …) — 20 accessors. |
| `hourly.lua` | Per-hour forecast (temp, precip prob, code, wind, UV, …) — 19 accessors. |
| `daily.lua` | Per-day forecast (max/min, sunrise/sunset, daylight, UV, precip hours) — 10 accessors. |
| `air.lua` | Air quality (PM10/PM2.5, CO, O3, NO2, SO2, dust, EAQI/US AQI, pollen) current + hourly. |
| `alerts.lua` | MeteoAlarm XML parsing → `conky_alert_*` alert list. |
| `spaceweather.lua` | NOAA data: Kp/G-scale, solar wind, Bz, X-ray class, sunspot, aurora visibility, alert summary. |
| `sunmoon.lua` | Sun/moon rise/set/high/low times + azimuths + moon phase. |
| `units.lua` | `conky_unit_*` accessors (unit-formatted day/hour fields) + `conky_city_name/postcode*`. |

### Icons & assets

| Folder | Contents |
|---|---|
| `icons/default/`, `metno/`, `weathermap/`, `wmo/` | Four weather icon sets — 28 WMO codes × day/night PNG each. |
| `icons/moon/` | Moon phases 0–8 × northern/southern orientation. |
| `icons/wind/` | 16 compass directions + `variable`/`no_wind` in 4 speed colors (green/yellow/orange/red). |
| `icons/*.png` (root) | Provider logos: met-norway, open-meteo, noaa, rainviewer, meteoalarm. |
| `nd.svg` | 1024×1024 app icon (Inkscape wrapper with embedded PNG), used by the designer window + desktop entry. |

### Temporary data (`tmp/`)

Runtime cache written by the shell fetchers and read by Lua. Safe to delete —
regenerated by `sh/0_fetch_all.sh all`:

- Weather/forecast: `city.json`, `weather_data.json`, `airquality.json`,
  `sun.json`, `moon.json`
- Alerts: `alerts.xml`
- Space weather: `spaceweather_{alerts,aurora,kp,mag,scales,sunspot,wind,xray}.json`
- Network: `network_ip.json`, `network_ping.json`
- Media: `nowplaying.json`, `album_art.png`
- Maps: `osm_big.png`, `rain_big.png`, `temp_big.png`, `wind_big.png`
- Updates: `updates.txt`
- Designer smoke-test artifacts: `smoke2.lua/.conf/*.png`

### Configuration files

| File | Purpose |
|---|---|
| `nextgen-designer.desktop` | App launcher (`Exec=python3 …/designer/main.py`, `Icon=nd.svg`). |
| `conky.kwinrule` | KWin rule forcing the `conky` window class to be borderless, skip taskbar/pager/switcher, minimized. |
| `~/.config/conky-designer.conf` | Optional `conky_dir = /path` override for the designer target dir. |
| `~/.config/conky-designer-state.json` | Designer window geometry (persisted). |
| `~/.config/conky-nextgen/user_agent.txt` | User-Agent for all fetchers (auto-generated or prompted). |


## Environment Variables

| Variable | Used by | Effect |
|---|---|---|
| `CONKY_NEXTGEN_DIR` | Designer | Overrides the target project root (also `--conky-dir`, then `conky-designer.conf`). |
| `JSON_PATH` | `lua/` | Base directory of the fetched JSON files (written by the designer; default `tmp/`). |
| `NEXTGEN_JSON_PATH` / `NEXTGEN_ART_PATH` | `fetch_nowplaying.sh` | Output locations for the now-playing JSON and album art. |
| `NEXTGEN_PLAYER` / `TITLE` / `ARTIST` / `ALBUM` / `STATUS` / `ART_URL` | `fetch_nowplaying.sh` | Data feed for the now-playing accessors. |
| `LANG` / `LC_ALL` / `LC_MESSAGES` / `LC_TIME` | `translate.lua` | Language selection + date/time locale. |
| `XDG_CURRENT_DESKTOP` / `KDE_FULL_SESSION` | `battery.lua`, `mtp.lua` | Desktop detection (KDE `kmtpd` vs GVFS MTP; battery backends). |
| `XDG_ICON_THEME` | designer → widget.lua | Preferred XDG icon theme for icon widgets. |
| `HOME` / `USER` | icon theme, USB detection | Icon theme lookup and USB mount detection. |
| `NO_COLOR`, `TERM` | `list_functions.lua` | Disables ANSI colors when piped. |

## Shell backend (`sh/`)

### Data Flow

The shell backend is the read-only *data producer* of the framework. Every
fetch module downloads remote data (weather, alerts, maps, media, network,
updates) and writes it as a file into `tmp/`. The Lua modules never fetch
anything themselves — they only read these cached files (JSON/XML/text/PNG)
when Conky renders. Fetchers can therefore run in the background (or from
cron/`0_fetch_all.sh`) without ever blocking a frame.

Consumers in `lua/`:

| Fetcher output | Lua consumer |
|---|---|
| `city.json`, `weather_data.json`, `airquality.json`, `sun.json`, `moon.json` | `weather/core.lua`, `current.lua`, `hourly.lua`, `daily.lua`, `air.lua`, `sunmoon.lua`, `units.lua` |
| `alerts.xml` | `weather/alerts.lua` |
| `spaceweather_*.json` | `weather/spaceweather.lua` |
| `*_big.png` (maps) | image/SVG widgets |
| `nowplaying.json`, `album_art.png` | `nowplaying.lua` |
| `network_ping.json`, `network_ip.json` | `hardware/network.lua` |
| `updates.txt` | `hardware/core.lua` (`conky_updates_repo/aur`) |

All scripts live in `sh/`. `sh/designer/` holds the GTK3 Designer application
(documented in `NextGen.md`), not the fetchers.

### Dependencies (Arch packages)

| Tool | Purpose | Required | Used by |
|---|---|---|---|
| `curl` | HTTP downloads with `-f -L --retry 2 --max-time 15` | yes | all network fetchers |
| `jq` | JSON filtering/parsing | yes | weather, alerts, maps, updates |
| `python3` | URL encoding, Mercator math, now-playing render | yes | `0_common.sh`, weather, maps, nowplaying |
| `ping` (iputils) | latency probe (1.1.1.1) | network only | `fetch_network.sh` |
| `playerctl` | MPRIS2 player query (first priority) | no* | `fetch_nowplaying.sh` |
| `cmus-remote` / `mpc` / `mocp` | fallback players (CMUS / MPD / MOC) | no* | `fetch_nowplaying.sh` |
| `imagemagick` | 3×3 tile stitching | maps only | `13_fetch_maps.sh` |
| `checkupdates` / `pacman` / `vercmp` | Arch repo + AUR update counts | updates only | `updates.sh` |

Notes:

- `0_common.sh` hard-requires `curl`, `jq`, `python3` at load time via
  `require_cmds` — a missing tool exits the whole script with status 1.
- `*` the now-playing player tools are probed with `command -v` and the first
  available player wins; without any player the fetcher writes an empty JSON.
- `updates.sh` is Arch-specific and self-contained (it defines its own
  `require_cmds` and does **not** source `0_common.sh`).

### === ./sh/0_common.sh ===

Shared bootstrap sourced by every fetch module. It resolves the project
directories, sets up the User-Agent, and provides the logging/curl/urlencode
helpers plus the unconditional `curl`/`jq`/`python3` check. Idempotent: a
second `source` is a no-op (`_COMMON_LOADED` guard).

####   EXPORTED VARIABLES:

- `_SCRIPT_DIR` — absolute directory of `sh/`.
- `CONKY_DIR` — project root (parent of `sh/`).
- `TMP_DIR` — `CONKY_DIR/tmp`, the cache/output directory.
- `SW_BASE` — NOAA SWPC base URL (`https://services.swpc.noaa.gov`).
- `UA` — the User-Agent string read from the UA file.
- `DEBUG` — debug flag (hardcoded to `1`; `log()` echoes only when `1`).

####   FUNCTIONS (available after sourcing):

- **log(...)** — Prints its arguments to stdout when `DEBUG=1`.
- **require_cmds(...)** — Checks each command with `command -v`; prints
  `[error] Missing: <cmd>` and `exit 1` for the first one that is absent.
- **curl_cmd(...)** — Wraps `curl -s -L --max-time 15 --retry 2 -f -A "$UA"`
  so every download shares timeout, retry, fail-on-error and identity
  settings.
- **urlencode(...)** — Percent-encodes its first argument via
  `python3 urllib.parse.quote`.

#### Pipeline Role

Single point of setup for the whole backend: without it no fetch module can
run, and all of them re-source it defensively. The User-Agent setup is the
only stateful part — it touches `~/.config/conky-nextgen/`.

#### Input / Output

Input: nothing (sourced). Output: exported globals + helpers; also creates
`CONFIG_DIR` and `TMP_DIR` on disk.

#### Internal Logic

On first load it computes paths, runs `require_cmds curl jq python3`, then
handles the UA file (`$CONFIG_DIR/user_agent.txt`):

- If the file exists it is read (trailing newline stripped) and cached in `UA`.
- If it does not exist and stdin is **not** a TTY (cron/systemd), a stable
  unique UA is auto-generated: `ConkyNG-<hostname>-<unix timestamp>`.
- If stdin **is** a TTY, the user is prompted for a User-Agent.
- An empty input falls back to `DEFAULT_UA` (`ConkyNextGen/1.0`); the file is
  written with `chmod 600`.

#### Developer Notes

- `DEBUG=1` is hardcoded, so `log()` is always active; there is no runtime
  switch to silence it.
- The UA file is per-user global, shared by all fetchers, so weather APIs that
  rate-limit per identity see one consistent client.
- `TMP_DIR` is the same directory `widget.lua`'s `JSON_PATH` points at — do
  not change one without the other.

### === ./sh/0_fetch_all.sh ===

Master entry point. Sources `0_common.sh` plus every fetch module and
dispatches to them by mode. When executed directly it becomes the "one
command to fetch everything" front-end; when sourced it only loads the
functions.

####   MODES:

- **all** (default) — `fetch_weather` (default city), `fetch_spaceweather`,
  `fetch_alerts`, `fetch_maps` (default zoom), `fetch_nowplaying`, then
  `fetch_ping` + `fetch_ipinfo` in parallel.
- **weather** — `fetch_weather` only.
- **space** — `fetch_spaceweather` only.
- **alerts** — `fetch_alerts` only.
- **map** — `fetch_maps` only.
- **nowplaying** — `fetch_nowplaying` only.
- **network** — `fetch_ping` + `fetch_ipinfo` in parallel.
- anything else — treated as a city name shorthand for `fetch_weather`.

#### Pipeline Role

Orchestration layer of the backend. It is the *only* script a user has to run
(`./0_fetch_all.sh all`) to refresh the entire cache that every widget
depends on.

#### Input / Output

Input: mode argument + optional arguments (`city`, `zoom`). Output: all files
listed in the `tmp/` data-flow table above.

#### Internal Logic

`${BASH_SOURCE[0]} = $0` guards the dispatch block, so the module only acts
when executed, never when sourced. `network` is always backgrounded
(`&` + `wait`) because the two requests are independent and would otherwise
run serially.

#### Developer Notes

- Defaults: city `Vienna`, map zoom `7`.
- A bare city name (not matching a mode) is passed verbatim to
  `fetch_weather`, so `./0_fetch_all.sh Budapest` works as a shortcut.

### === ./sh/4_fetch_weather.sh ===

Weather backend. Geocodes a city name, then downloads current+hourly+daily
forecast, air quality, and sun/moon data from three free APIs into five JSON
files.

####   FUNCTIONS:

- **fetch_weather(city)** — Runs the full weather pipeline for `city`
  (default `Vienna`). Returns `1` when geocoding fails, otherwise completes
  the five downloads.

#### Pipeline Role

The primary data source for every `weather/*.lua` module. Its `city.json`
output is also a dependency of `11_fetch_alerts.sh` and `13_fetch_maps.sh`
(country code and coordinates) — those scripts check for the file and give up
if it is missing.

#### Input / Output

Input: city name (raw, URL-encoded internally). Output:

| File | API | Content |
|---|---|---|
| `tmp/city.json` | Open-Meteo geocoding | `latitude`, `longitude`, `timezone`, `country_code` |
| `tmp/weather_data.json` | Open-Meteo forecast | current + 7-day hourly + daily weather |
| `tmp/airquality.json` | Open-Meteo air-quality | 4-day PM/gases/pollen/AQI |
| `tmp/sun.json` | MET Norway sunrise | today's sunrise/sunset |
| `tmp/moon.json` | MET Norway sunrise | today's moonrise/moonset/phase |

#### Internal Logic

1. **Geocoding** is fatal: empty/HTTP-error responses remove the `.tmp` file
   and `return 1`; a JSON without `.results[0]` also fails.
2. Lat/lon/timezone are extracted with `jq` and fed into the forecast and air
   quality URLs (`timeformat=unixtime`, `forecast_days=7`,
   `air_forecast_days=4`, `past_days=1`, `timezone=<tz>`).
3. Sun/moon use today's date and the local `%:z` offset.
4. All writes go through `<file>.tmp` then `mv`, so a partial download never
   leaves a truncated cache file. Weather/air/sun/moon failures are logged as
   `[warn]` and do **not** abort the remaining downloads.

#### Developer Notes

- The long Open-Meteo query strings enumerate every field the Lua modules
  read; removing a field there silently empties the corresponding accessor.
- Language is hardcoded to `hu` for geocoding results (city display name).

### === ./sh/11_fetch_alerts.sh ===

MeteoAlarm weather-warning fetcher. Resolves the country code from
`city.json` to a MeteoAlarm feed slug and downloads the Atom XML feed.

####   FUNCTIONS:

- **fetch_alerts()** — Downloads `tmp/alerts.xml`, or removes it (empty
  result) when `city.json` is missing or the country is not supported.

#### Pipeline Role

Feeds `weather/alerts.lua`, which parses the Atom XML (via `lxp`) into
active/upcoming warnings.

#### Input / Output

Input: `tmp/city.json` (`.results[0].country_code`). Output:
`tmp/alerts.xml` (Atom XML), or no file when the country has no feed.

#### Internal Logic

A static `SLUGS` associative array maps ISO country codes to MeteoAlarm slugs
(e.g. `HU`→`hungary`, `GB`→`united-kingdom`). Missing `city.json` or an
unknown code clears any stale `alerts.xml` and returns success, so an
unsupported country degrades to "no alerts" instead of an error.

#### Developer Notes

- The supported-country list is fixed in the `SLUGS` map; adding a country
  means adding its code → slug pair there.
- The `-legacy-atom-` URL variant is intentional and current for the feeds.

### === ./sh/12_fetch_spaceweather.sh ===

NOAA SWPC space weather fetcher. Downloads eight JSON products from
`services.swpc.noaa.gov` in one pass.

####   FUNCTIONS:

- **fetch_spaceweather()** — Fetches all eight products via the local
  `fetch_sw` helper.

####   LOCAL FUNCTIONS:

- **fetch_sw(file, url, name)** — One download: `curl_cmd` to `<file>.tmp`,
  `mv` on success, or warn + `return 1` on empty/error.

#### Pipeline Role

Data source for `weather/spaceweather.lua` (Kp index, solar wind, magnetic
field Bz, X-ray flux, scales, sunspot, aurora, alerts).

#### Input / Output

Input: nothing. Output: eight files in `tmp/`:

| File | Product |
|---|---|
| `spaceweather_kp.json` | NOAA planetary K-index forecast |
| `spaceweather_wind.json` | Solar wind speed |
| `spaceweather_mag.json` | Solar wind magnetic field (Bz) |
| `spaceweather_xray.json` | GOES X-ray flux (1 day) |
| `spaceweather_scales.json` | NOAA space weather scales |
| `spaceweather_sunspot.json` | Sunspot report |
| `spaceweather_aurora.json` | OVATION aurora forecast |
| `spaceweather_alerts.json` | Active alerts |

#### Internal Logic

A single loop over `(file, url, name)` triples; each product is downloaded
and atomically moved. Failures are per-product warnings, so one broken
endpoint does not stop the other seven.

#### Developer Notes

- `SW_BASE` comes from `0_common.sh` — keep the base URL there, not here.
- Some products have `products/…` and some `json/…` paths; the exact URL
  matters and should only change when NOAA moves an endpoint.

### === ./sh/13_fetch_maps.sh ===

Map tile fetcher. Downloads a 3×3 tile grid centered on the user's city from
four sources and stitches it into four composite PNGs with ImageMagick.

####   FUNCTIONS:

- **fetch_maps(zoom)** — Runs the whole map pipeline; `return 1` when
  `city.json` is missing or ImageMagick is not installed.

####   LOCAL FUNCTIONS:

- **fetch_tile(out, url, name)** — Downloads one tile, retries once after 1 s
  when the result is empty.
- **check_tiles(prefix)** — Fills any missing `prefix_i.png` tile with a
  transparent 256×256 placeholder so stitching cannot fail on a gap.
- **stitch(prefix, out)** — Horizontally appends rows 0–2, 3–5, 6–8
  (`+append`) then vertically combines the three rows (`-append`).

#### Pipeline Role

Produces the four `*_big.png` images (base map, radar, temperature, wind)
that image widgets display as a 3×3 region around the city.

#### Input / Output

Input: `tmp/city.json` (lat/lon), optional zoom 5–7 (default 7, out-of-range
falls back to 7). Output: `tmp/{osm_big,rain_big,temp_big,wind_big}.png`.
Tile sources: OpenStreetMap (base), RainViewer (radar, latest past frame
path from `api.rainviewer.com/public/weather-maps.json`), Environment Canada
GDPS WMS (temperature 2 m, wind 10 m).

#### Internal Logic

1. The center tile `(cx, cy)` is computed from lat/lon/zoom with the Web
   Mercator formula (`python3`, `asinh` projection).
2. A 3×3 index grid around the center drives all four downloads per tile.
3. For the WMS layers the EPSG:3857 bounding box is computed per tile
   (tile→world coordinates, `R = 6378137`).
4. After the 36 tiles (4×9) are downloaded, missing ones get transparent
   placeholders, then `stitch` builds the 768×768 composites and the
   individual tiles are deleted.

#### Developer Notes

- Requires ImageMagick; uses `magick` if present, else `convert`.
- `city.json` must exist — running `weather` (or `all`) first is a hard
  prerequisite (`[error] city.json missing`).
- Radar uses only the last past frame (`radar.past[-1]`), not forecasts.

### === ./sh/fetch_nowplaying.sh ===

Now-playing fetcher with multi-player auto-detection and album-art handling.
Detects the active player, extracts track metadata, downloads the album art,
and caches the result so unchanged tracks skip the artwork download.

####   FUNCTIONS:

- **fetch_nowplaying()** — Probes players in priority order, renders JSON +
  album art, and writes `tmp/nowplaying.json` (+ `tmp/album_art.png`).

#### Pipeline Role

Data source for `nowplaying.lua` and its `conky_nowplaying_*()` accessors
(player, title, artist, album, status, art path).

#### Input / Output

Input: the active player session. Output:

| File | Content |
|---|---|
| `tmp/nowplaying.json` | `player`, `title`, `artist`, `album`, `status`, `art` |
| `tmp/album_art.png` | Downloaded/copied album art, or absent |

#### Internal Logic

**Player detection** (first hit wins):

1. **MPRIS/playerctl** — uses the first player of `playerctl -l`, with
   `status`/`xesam:*`/`mpris:artUrl` metadata.
2. **CMUS** — `cmus-remote -Q`, parses `status`/`tag title`/`tag artist`/
   `tag album`; falls back to the filename for the title.
3. **MPD** — `mpc status` + `mpc current -f "%title%"…`; only while playing
   or paused.
4. **MOC** — `mocp -i`, parses `State:`/`Title:`/`Artist:`/`Album:`.

Empty fields get `"Unknown Title"`/`"Unknown Artist"`. If no player is found
or the state is stopped, a minimal JSON with empty values and status
`"Stopped"` is written and any old artwork removed.

**Render + cache** (embedded `python3`): track metadata is passed via the
`NEXTGEN_*` environment variables (exported before the call, unset after).
The Python step:

- Reads the previous `nowplaying.json` and exits without touching anything
  when title/artist/status are unchanged and the existing art file is still
  valid — this is the "no re-download" cache.
- Downloads the art: `file://` URLs are copied locally, `http(s)://` are
  fetched with a 2 s timeout and a browser UA; failures clean up the temp
  files.
- Writes `nowplaying.json` atomically (`<file>.tmp` + `os.replace`).

#### Developer Notes

- Requires `playerctl` plus a running player; without any of them the Lua
  accessors return their empty defaults.
- The environment-variable handoff (not CLI args) keeps the track data safe
  from shell quoting issues.
- The cache check compares title+artist+status only, so an art-URL change
  alone triggers a re-download.

### === ./sh/fetch_network.sh ===

Background network probe: ping latency and public-IP geolocation. Two
independent functions meant to run in parallel; the file is self-sourcing-safe
and only dispatches both when executed directly.

####   FUNCTIONS:

- **fetch_ping()** — Runs `ping -c 3 -q 1.1.1.1` and saves the raw output to
  `tmp/network_ping.json`. The Lua side parses the `rtt min/avg/max/mdev`
  summary line — the file is ping *text*, not JSON.
- **fetch_ipinfo()** — Downloads `https://ipinfo.io/json` to
  `tmp/network_ip.json` (fails silently on error/empty).

#### Pipeline Role

Data source for `hardware/network.lua` (`conky_ping_avg`, `conky_ping_jitter`,
`conky_public_ip/city/country`, `conky_wifi_*` — the WiFi parts read sysfs,
not these files).

#### Input / Output

Input: nothing (external services). Output: `tmp/network_ping.json` (ping
report text), `tmp/network_ip.json` (ipinfo JSON with `ip`, `city`,
`country`, …).

#### Internal Logic

`fetch_ping` writes the ping output even on failure (`|| true`), so a down
host still produces a file the Lua parser can scan. `fetch_ipinfo` only
commits a non-empty response. Both use `mv` on a `.tmp` file for atomicity.

#### Developer Notes

- The `network_ping.json` filename is misleading — it is plain `ping` text.
  `hardware/network.lua` matches the `rtt min/avg/max/mdev` regex, so the
  format must stay compatible.
- Pings are hardcoded to `1.1.1.1`; latency values are per-frame cached for
  10 s in Lua (600 s for IP data).

### === ./sh/updates.sh ===

Arch Linux update checker. Counts available updates from the official repos
and from AUR, writing a single line for the widgets. Standalone: defines its
own `require_cmds` and does **not** source `0_common.sh`.

#### Pipeline Role

Data source for `hardware/core.lua` (`conky_updates_repo`,
`conky_updates_aur`), which parses the two numbers.

#### Input / Output

Input: installed AUR packages + network. Output: `tmp/updates.txt` in the
format `"<repo_count> <aur_count>"`.

#### Internal Logic

1. **Repo count** — `checkupdates 2>/dev/null | wc -l`.
2. **AUR count** — `pacman -Qm` lists locally-installed foreign packages; each
   is looked up via the AUR RPC (`https://aur.archlinux.org/rpc?v=5&type=info`)
   and compared with `vercmp` against the installed version; out-of-date
   packages increment the AUR counter.
3. The two numbers are written as `$repo $aur`.

#### Developer Notes

- Arch-specific (`checkupdates`, `vercmp`, AUR RPC) and non-portable.
- Requires `curl`, `jq`, `pacman`, `vercmp`, `checkupdates` — verified at
  startup with its own `require_cmds`.
- The file is only rewritten when the script runs; it is not refreshed by
  `0_fetch_all.sh all`.

### === ./sh/all_in_one.sh ===

Standalone monolithic fetcher. Inlines the common helpers plus `fetch_weather`,
`fetch_spaceweather`, `fetch_alerts`, and `fetch_maps` into one self-contained
script with **no** `source` dependencies. Intended as the drop-in single-file
variant when modular sourcing is not wanted.

####   MODES:

- **all** (default) — weather (default city) + space weather + alerts + maps.
- **weather** — weather only.
- **space** — space weather only.
- **alerts** — alerts only.
- **map** — maps only.
- anything else — city name shorthand for weather.

#### Pipeline Role

Functional duplicate of `4_fetch_weather.sh` + `12_fetch_spaceweather.sh` +
`11_fetch_alerts.sh` + `13_fetch_maps.sh` + `0_common.sh`, used when a single
portable script is preferred over sourcing modules.

#### Internal Logic

Same code as the modular versions, with two differences: the UA/curl/urlencode
helpers are copied inline, and the dispatcher runs synchronously. The MET
Norway `locationforecast` backup download exists only as commented-out code.

#### Developer Notes

- Unlike `0_fetch_all.sh all`, the `all` mode here does **not** include
  now-playing or network fetching.
- Duplicated logic (weather/space/alerts/maps) must be kept in sync with the
  modular scripts by hand.


## Lua engine (`lua/`)

### Dependencies (Arch packages)

| Package | Lua module | Required | Used by |
|---|---|---|---|
| `lua-dkjson` | `dkjson` (`json`) | yes | `weather/core.lua`, `nowplaying.lua` |
| `lua-expat` | `lxp` | yes | `weather/alerts.lua` (SAX XML) |
| `lua-filesystem` | `lfs` | yes | hardware/, weather/, `draw/hyphen.lua` |
| `librsvg` | `rsvg` | yes | `draw/svg.lua` (SVG rendering) |

Notes:

- `cairo`, `imlib2`, `rsvg` are **not** separate `lua-*` packages — the Lua
  bindings ship with Conky itself (`/usr/lib/conky/libcairo.so`,
  `/usr/lib/conky/libimlib2.so`, `/usr/lib/conky/librsvg.so`, package
  `conky-mng`). `librsvg` still needs the system library installed: it is
  required unconditionally by `require.lua` (so a missing binding fails at
  load time), and `draw/svg.lua` only guards against a *nil* `rsvg` at
  runtime.
- Optional: `lua-lpeg` — not used by the framework directly; it is an
  optional dependency of `lua-dkjson` that speeds up JSON decoding.
- Optional: `lua-utf8` / `utf8` improves hyphenation in `draw/hyphen.lua`
  (falls back to the builtin `utf8` table otherwise).
- `playerctl` — system tool (MPRIS2) needed by the now-playing data
  pipeline: `sh/fetch_nowplaying.sh` queries it and writes
  `tmp/nowplaying.json`, which `nowplaying.lua` then reads. Without it every
  `conky_nowplaying_*()` accessor returns its empty default.
- `lm-sensors` — system tool needed by `hardware/sensors.lua`: it reads
  CPU/NVMe/WiFi temperatures and fan RPM from the `sensors` command output
  (via the cached extractor in `hardware/core.lua`). Without it installed and
  configured, every sensor accessor returns 0.
- `kio-extras` (+ `kde-cli-tools`) — Plasma backend of `hardware/mtp.lua`:
  provides the KDE KIO MTP daemon (`kmtpd` on D-Bus) and `kioclient` that the
  module queries for device/storage fill percentages. On non-Plasma desktops
  the GVFS backend (`gvfs-mtp`, `gio`) is used instead; missing tools yield an
  empty device list.
- `curl` / `jq` — needed by the shell data fetchers (`sh/fetch_*.sh`) that
  download remote data and write the JSON files the Lua modules read.

### What is a View?

A **view** is a named selection of widgets. The runtime shows only the widgets whose `view` list contains the active view name. Switching views changes the whole screen instantly (e.g. main → weather).

### What is a Group?

A **group** bundles widgets that form one logical unit (a panel, a stat block). Two things make it special:

- **Conditional drawing** — a group can carry a `draw_me` condition: when it evaluates false, the whole group is hidden (and its widgets skip drawing).
- **Group-based Y positioning** — groups are laid out vertically; each group's `y` starts at the group's top, and stacked groups are pushed down by the previous groups' heights plus padding.

The runtime also treats the group as a whole for hover highlight, background changes and click routing (hit test).

### Switching Views

- Assign `click_view` on a widget so a click switches to another view.
- Or call `switch_view("name")` from a mouse action handler.
- `view_toggle("name")` toggles between a view and the previous one.
- Mouse leave returns to the main view only if you assign `MOUSE_LEAVE_ACTION = function() switch_view("main") end` in `widget.lua` — nothing happens by default (all `MOUSE_*_ACTION` hooks are nil unless set).

### === ./lua/core/draw_core.lua ===

Core render loop. Owns the global render state (`GROUP_VIEWS`,
`GROUP_OFFSETS`, `HOVER_VIEW`, `current_view`), evaluates draw conditions,
computes the vertical group layout, applies themes, auto-interprets string
fields, and dispatches every draw item to its Cairo drawer.

####   GLOBAL FUNCTIONS:

- **evaluate_draw_me(draw_me)** — Unified `draw_me` condition evaluator.
  Handles booleans (returned as-is), functions (truthy result), strings
  containing `(` and `)` (compiled with `load`, truthy result), plain strings
  (compared via `conky_parse(draw_me) == "1"`), and `nil` (always draw).
  Returns `true`/`false`; used by the render loop and group height logic.

- **draw_allowed(item_view, item_group)** — Per-element visibility gate.
  Returns `false` if the element's own view list does not match
  `current_view` (with `HOVER_VIEW` fallback), if the group's registered
  views exclude the current view, or if the group's `GROUP_STATE` marks it
  hidden (`!group` inverts the check). Otherwise returns `true`.

- **init_groups(group_list)** — One-time startup registration of groups.
  Stores each group's `views` table in `GROUP_VIEWS` and forwards the name
  to `register_group` so mouse and view logic know the group.

- **modify_group_background(group_name, overrides)** — Hover highlight.
  Snapshots `bg`/`border`/`border_width` of every `background` item in the
  group into `GROUP_ORIGINS` (first call only), then applies the override
  fields. Subsequent calls only apply the overrides again.

- **restore_group_background(group_name)** — Reverts the hover highlight.
  Restores the snapshotted `bg`/`border`/`border_width` onto the group's
  background items and clears the stored `GROUP_ORIGINS` entry.

- **compute_group_height(group_name, draw_list)** — Measures the tallest
  visible element of a group. Iterates the draw list, respects `draw_me` and
  view conditions, uses `infer_item_height` for items without an explicit
  height, and returns `max(y + height)` over the group.

- **conky_core_main()** — Conky draw hook (`lua_draw_hook_pre`), entry point
  of every frame. Guards on window/updates/`draw`/`_GROUPS`, refreshes group
  visibility and offsets, creates the Cairo context, lazily builds
  `DRAW_DISPATCH`, then walks every item: applies the theme, interprets
  `text`/`value` strings, adds the group Y offset, calls the matching drawer,
  and restores the original Y. Immediately after creating the Cairo context it
  calls `clear_surface(cr)` (a no-op by default). Destroys the Cairo context
  at the end.

- **clear_surface(cr)** — Overridable hook, called once per frame with the
  fresh Cairo context. The default implementation is a no-op; the designer's
  X11 live preview overrides it (via an extra `lua_load` file,
  `live_clear.lua`) to wipe the surface (CAIRO_OPERATOR_CLEAR) between moves,
  so vacated regions don't leave ghost pixels. The deployed config never loads
  that file, so `clear_surface` stays a no-op in production.

- **conky_cleanup()** — Conky shutdown hook. Releases cached resources by
  calling `svg_free_all()` when available.

####   LOCAL FUNCTIONS:

- **view_contains(v, name)** — Helper that checks whether `name` is inside a
  view spec. `v` may be a plain string or a table (list of views per element);
  returns `true` on the first match.

- **infer_item_height(item)** — Height heuristic for items without explicit
  `h`/`height`. Returns type-specific defaults (clock/ring radius, bar/graph
  height, calendar rows, text size, image/SVG size, etc.), falling back to 30.

- **compute_group_offsets(group_list, draw_list, padding)** — Vertical layout
  pass (default padding 10). Walks groups in order, decides visibility from
  `GROUP_STATE` + `current_view` + registered views, measures each visible
  group, and accumulates Y offsets into the global `GROUP_OFFSETS`.

#### Pipeline Role

Renders the whole widget tree. Called by Conky on every draw cycle; it is the
single orchestrator between view state, layout, theme resolution, and the
individual drawers. Must never be called manually from a config.

#### Input / Output

Input: Conky window, the global `draw` list, `_GROUPS`, `GROUP_STATE`, the
current/hover view, and theme data via `apply_theme`. Output: Cairo drawing on
`conky_surface()`; also writes the `GROUP_OFFSETS` layout table used by mouse
and drawing code.

#### Internal Logic

Frame order: `check_group_visibility()` → `compute_group_offsets()` → per-item
`evaluate_draw_me()` → `draw_allowed()` → `apply_theme()` → auto-interpret
strings → apply group Y offset → dispatch on `item.type` via `DRAW_DISPATCH`.

#### Developer Notes

- The module header comments describe the same functions; keep them in sync.
- `item.y` is temporarily shifted by the group offset and restored right after
  drawing, so items must not rely on `item.y` persisting.
- `draw_me` strings containing brackets are evaluated as Lua, not parsed by
  Conky — a security-relevant detail for untrusted configs.

### === ./lua/core/draw_group.lua ===

Group registry and time-limited visibility evaluation. Keeps `GROUP_STATE`
(which groups are currently visible) and `GROUP_REGISTRY` in sync; group
entries may carry a `draw_me` field that toggles visibility.

####   GLOBAL FUNCTIONS:

- **register_group(name)** — Registers a group name in `GROUP_REGISTRY` and,
  if not yet known, marks it visible in `GROUP_STATE`. Called at startup from
  `init_groups` and by mouse/view logic when a group becomes active.

- **check_group_visibility()** — Evaluates each group's `draw_me` field once
  per second (guarded by `_last_vis_check`). A truthy `draw_me` marks the
  group visible in `GROUP_STATE`, a falsy one removes it; groups without
  `draw_me` are left untouched (always visible). Called at the start of
  `conky_core_main()`.

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

Visibility layer between the config and the render loop. Runs once per frame
(but re-evaluates draw conditions at most once per second) so that hidden
groups are skipped by layout, drawing, and hit-testing.

#### Input / Output

Input: global `_GROUPS` list and each group's `draw_me`. Output: writes the
`GROUP_STATE` table (visible = non-nil) consumed by `draw_allowed`,
`compute_group_offsets`, and mouse hit-testing.

#### Internal Logic

`check_group_visibility` is rate-limited: `os.time()` is compared with
`_last_vis_check`, so within the same second only the first call does real
work. `register_group` is idempotent and never hides an existing group.

#### Developer Notes

- `GROUP_STATE[name] = nil` means hidden; non-nil means visible. `draw_allowed`
  and `compute_group_offsets` rely on this exact convention (`!group` inverts).
- Visibility only updates once per second — cheap conditions are recommended;
  a change is picked up on the next second tick, not instantly.

### === ./lua/core/mouse.lua ===

Mouse event dispatcher. Receives raw Conky mouse events and turns them into
the configured actions (view switches, per-element `click`/`click_view`, global
button/scroll/modifier actions), including hover enter/leave tracking per group.

####   GLOBAL FUNCTIONS:

- **conky_on_mouse(event)** — Conky callback for all mouse events
  (`mouse_enter`, `mouse_leave`, `mouse_move`, `mouse_scroll`,
  `button_down`, `button_up`). Delegates to the local `on_event` and returns
  whether the event was consumed. Do not call manually.

####   LOCAL FUNCTIONS:

- **call_action(action, event)** — Invokes a configured action: functions are
  called with the event table; strings are passed to `os.execute`. Returns
  `true` when an action was present.

- **get_group_at(ex, ey)** — Finds the visible group under a point by walking
  `GROUP_OFFSETS` (visible groups only) and comparing `y` against each group's
  measured height. Returns the group name and its Y offset.

- **hit_test(ex, ey)** — Top-down scan of `draw` for clickable items
  (`click` or `click_view`) inside the pointer rectangle. Respects `draw_me`
  and `draw_allowed`; geometry uses group offsets plus item `x`/`y`/`w`/`h`.
  Returns the hit item or `nil`.

- **handle_scroll(event)** — Scroll dispatch with modifier priority
  (Ctrl/Shift/Alt), then plain `up`/`down`/`left`/`right`, each mapped to the
  matching `MOUSE_*_SCROLL_*` global action.

- **handle_left_click(event)** — Left-press handler: hit-tests the pointer; a
  hit with `click_view` switches the view (`switch_view`), a hit with `click`
  runs the action. Returns whether the click was handled.

- **handle_global_click(event)** — Click not claimed by an element. Modifier
  clicks (Ctrl/Shift/Alt) take priority; otherwise dispatches by button
  (`left`/`right`/`middle`/`back`/`forward`) to the global `MOUSE_CLICK_*`
  actions.

- **on_event(event)** — Central event router: implements enter/leave/move
  hover transitions (`MOUSE_HOVER_*_GROUP_ACTION`), scroll, and button logic
  (modifier-first, then element hit-test on left down, global click on up).

- **log(msg)** — Writes a timestamped message to `/tmp/conky_mouse.log` for
  debugging; the file handle is opened once at module load.

#### Pipeline Role

Input layer of the UI. Conky forwards every mouse event here; the dispatcher
maps them to view switches, per-element clicks, and global actions, and keeps
`HOVER_VIEW`/hover actions in sync with the currently hovered group.

#### Input / Output

Input: `event` table from Conky (`type`, `button`, `x`, `y`, `direction`,
`mods`). Output: side effects only — action callbacks, `os.execute` calls,
`switch_view`, and group hover events. No return value is used by Conky.

#### Mouse action globals

Defined in `widget.lua` (nil unless assigned). Each value is either a Lua
function (called with the event table) or a string (executed via
`os.execute`). The dispatcher reads these globals on every event:

| Global | Trigger |
|---|---|
| `MOUSE_ENTER_ACTION` | pointer enters the Conky window. |
| `MOUSE_LEAVE_ACTION` | pointer leaves the Conky window; e.g. `function() switch_view("main") end` to return to main. |
| `MOUSE_HOVER_IN_CONKY_WINDOW_ACTION` | pointer enters the window (fired together with `MOUSE_ENTER_ACTION`). |
| `MOUSE_HOVER_IN_GROUP_ACTION` | pointer enters a visible group; event gets `.group`. |
| `MOUSE_HOVER_LEAVE_GROUP_ACTION` | pointer leaves a group (or the window while inside one); event gets `.group`. |
| `MOUSE_SCROLL_UP` | wheel up. |
| `MOUSE_SCROLL_DOWN` | wheel down. |
| `MOUSE_SCROLL_LEFT` | wheel left. |
| `MOUSE_SCROLL_RIGHT` | wheel right. |
| `MOUSE_CTRL_SCROLL_UP` | Ctrl + wheel up. |
| `MOUSE_CTRL_SCROLL_DOWN` | Ctrl + wheel down. |
| `MOUSE_SHIFT_SCROLL_UP` | Shift + wheel up. |
| `MOUSE_SHIFT_SCROLL_DOWN` | Shift + wheel down. |
| `MOUSE_ALT_SCROLL_UP` | Alt + wheel up. |
| `MOUSE_ALT_SCROLL_DOWN` | Alt + wheel down. |
| `MOUSE_CLICK_LEFT` | left button (global — only fires when no element claimed the click). |
| `MOUSE_CLICK_RIGHT` | right button (global). |
| `MOUSE_CLICK_MIDDLE` | middle button (global). |
| `MOUSE_CLICK_BACK` | back button (global). |
| `MOUSE_CLICK_FORWARD` | forward button (global). |
| `MOUSE_CTRL_CLICK` | Ctrl + click (global, any button). |
| `MOUSE_SHIFT_CLICK` | Shift + click (global, any button). |
| `MOUSE_ALT_CLICK` | Alt + click (global, any button). |

Per-element `click`/`click_view` take priority over the global `MOUSE_CLICK_*`:
on left press the dispatcher hit-tests the pointer and only falls back to the
global click on release when no element handled it. Modifier clicks always go
global first, so an element is never hit-tested under Ctrl/Shift/Alt.

#### Internal Logic

Left-click flow: `button_down` does the hit-test and remembers the result in
`left_down_handled`; on `button_up` that flag suppresses the global click so
an element click is not double-fired. Modifier combinations always go global
first. Hover groups are tracked in `last_hovered_group` with enter/leave
transitions emitted only on change.

#### Developer Notes

- A debug log is written to `/tmp/conky_mouse.log`; remove `dbg_file` for
  production to avoid the file handle and I/O overhead.
- Action strings are executed via `os.execute` — treat any value coming from a
  config field as executable code.
- `hit_test` relies on the same geometry conventions as the drawers
  (`w`/`h`, radius fallback), so changes to layout logic must stay in sync.

### === ./lua/core/theme_engine.lua ===

Theme resolution engine. Reads the global `THEMES` table (defined in the
`widget.lua` theme block), resolves gradient-name color fields, and fills in
per-widget defaults so draw items can omit colors and get them from the active
theme automatically.

####   GLOBAL FUNCTIONS:

- **apply_theme(item)** — Mutates a draw item in place: resolves every string
  gradient reference in the color fields (`fg`, `bg`, `border`, `color`,
  `grid_color`) against the item's theme (default `DEFAULT_THEME`), then fills
  missing fields from `theme.defaults[item.type]`. Only fills fields that are
  not already set. Called per item by the render loop.

####   LOCAL FUNCTIONS:

- **resolve_field(field_name, value)** — Resolves a single color field:
  string values are looked up as gradient names via `resolve_gradient` and
  replaced with the stop list when found; other values pass through unchanged.

- **resolve_gradient(theme_name, gradient_name)** — Looks up a named gradient
  in `theme.gradients` and returns its stop list, or `nil` when missing.

- **resolve_theme(name)** — Returns the theme table for `name`, or the
  `DEFAULT_THEME` when `name` is `nil`.

#### Pipeline Role

Decoration pass of the render loop. Runs before drawing each item so that
color handling is centralized: gradients are expanded to stop lists and widget
defaults are applied, keeping widget definitions short.

#### Input / Output

Input: global `THEMES`, `DEFAULT_THEME`, and the item's `theme` field.
Output: in-place mutation of the item's color fields and missing defaults.

#### Internal Logic

Gradient resolution only rewrites fields that are strings; already-resolved
tables and numeric colors are left alone. Defaults are applied with a
`nil`-check so explicit item values always win.

#### Developer Notes

- `THEMES` and `DEFAULT_THEME` are `or {}`-initialized: `widget.lua` must be
  loaded before this module so its definitions survive.
- Only the listed five fields get gradient resolution; adding a new color
  field requires extending the `ipairs` list in `apply_theme`.

### === ./lua/core/translate.lua ===

Translation layer. Loads GNU `.mo` files for the active language at module
load time (falling back to `en.mo`), provides `conky_get_tr()` for msgid lookup,
and configures the time locale so `os.date()` names match the system language.

####   GLOBAL FUNCTIONS:

- **conky_get_tr(msgid)** — Returns the translated string for a msgid in the active
  language. Falls back to the English `.mo`, then to the msgid itself when no
  translation exists (empty `msgstr` counts as missing). Returns a plain UTF-8
  string safe for use inside Conky text widgets.

####   LOCAL FUNCTIONS:

- **load_mo(path, into)** — Low-level GNU `.mo` binary parser. Reads the file,
  validates the magic bytes (`0x950412de`), and loads each original→translation
  pair into the target table. Do not call directly.

#### Pipeline Role

Localization service for the whole framework. Loaded first so weather modules
can translate WMO weather codes and wind directions; also sets up the time
locale for `os.date()` weekday/month names.

#### Input / Output

Input: `$LANG`/`$LC_ALL`/`$LC_MESSAGES` env vars, `STRINGS_MO_PATH` (preset
override), and the `language/*.mo` files under `script_dir`. Output: the
`conky_get_tr(msgid)` translation function and the configured time locale.

#### Internal Logic

Locale resolution: `LANG`/`LC_ALL` → two-letter language code → `language/xx.mo`
if present, else `en.mo`. The time locale is tried full → encoding-stripped →
short code → `"C"`. When the active language is not English, `en.mo` is loaded
as a guaranteed-complete fallback table.

#### Developer Notes

- The `.mo` parser reads little-endian 32-bit integers manually; it does not
  use `string.pack`/`unpack`, so it works on any Lua build.
- `conky_get_tr` is only defined if not already present (with a `get_tr` alias), letting `widget.lua`
  override it if needed.

### === ./lua/core/utils.lua ===

General-purpose helpers: color conversion with perceptual OKLab gradient
interpolation, gradient pattern building, rounded-rect path, number/string
normalization, safe accessors, a bounded cache, and the auto-interpretation
of widget `text`/`value`/`name` fields into callable expressions.

####   GLOBAL FUNCTIONS:

- **apply_defaults(cfg, defaults)** — Merges two tables: copies `cfg` first,
  then fills in keys from `defaults` that are still `nil`. Returns a new
  table; the inputs are not mutated.

- **build_gradient_pattern(cr, stops, x1, y1, x2, y2)** — Creates a linear
  cairo pattern from a stop list. Single-stop lists are flat colors; multi-stop
  gradients are pre-sampled in OKLab (256 samples) to avoid banding, then the
  samples are added as sRGB color stops.

- **cache_set(cache, key, value, max)** — Bounded cache insert (default max
  256). Tracks its own `_count`; when the count exceeds the max the whole
  cache is cleared, preventing unbounded growth. Returns the stored value.

- **draw_get_value(m)** — Resolves a widget's `value` field to a plain string:
  an `interpret_name` table with `exec` is called, a plain string passes
  through, and a `name`/`arg` fallback is expanded via `conky_parse`.

- **get_color_from_list(stops, t)** — Interpolates a gradient stop list at
  position `t` (0–1) and returns `r, g, b, a` (0–1 each). Uses OKLab
  interpolation for perceptually even transitions; clamps at the edges.

- **hex_to_rgba(hex, alpha)** — Converts a `#rrggbb` hex string to
  `r, g, b, a` floats in 0–1 range.

- **interpret_name(name)** — Auto-interpretation of a `text`/`value` string:
  strings containing `(` and `)` are compiled with `load` into a Lua function
  (`type = "lua"`); everything else becomes a `conky_parse`-backed wrapper
  (`type = "conky"`). Empty strings produce a no-op text entry.

- **normalize_with_suffix(raw)** — Parses a number string with an optional
  `K`/`M`/`G` suffix (binary multipliers) into a plain number; `0` on garbage.

- **normalize_number(v)** — Converts arbitrary input (string with commas, etc.)
  to a number, extracting the first numeric run; `0` for nil/table input.

- **rounded_rect_path(cr, x, y, w, h, r)** — Appends a rounded-rectangle path
  to the cairo context using four arcs; the radius is clamped to `min(w,h)/2`.

- **safe_num(v, name)** — Returns `v` as a number, or `0` when nil/NaN/invalid;
  logs a message through `conky_log` on failure.

- **safe_str(v, name)** — Returns `tostring(v)`, or `"N/A"` when nil/empty;
  logs a message on failure.

####   LOCAL FUNCTIONS:

- **_safe_log(msg)** — Logs a message via `conky_log` when available (Conky
  only); a no-op otherwise.

- **hex_to_oklab(col)** — Cached conversion of a hex color to OKLab
  coordinates; used by the gradient interpolation path.

- **hex_to_rgb_components(col)** — Cached conversion of a hex color (string or
  numeric) to `r, g, b` floats; the working horse behind the color helpers.

- **linear_to_srgb(c)** — Gamma-encodes a single linear channel (sRGB
  transfer function).

- **normalize_number(v)** — See GLOBAL: local first, then the global wrapper.

- **normalize_stops(stops)** — Validates, clamps to [0,1], sorts, and
  deduplicates a gradient stop list; keeps the later stop on duplicate
  positions. Falls back to a single white stop on empty input.

- **oklab_to_srgb(L, a, b)** — Converts OKLab coordinates back to sRGB
  (gamma-encoded) channels.

- **safe_tbl(v, name)** — Returns `v` when non-nil, else `{}`; logs a message
  on failure.

- **srgb_to_linear(c)** — Gamma-decodes a single sRGB channel.

- **srgb_to_oklab(r, g, b)** — Converts sRGB channels to OKLab coordinates.

#### Pipeline Role

Shared utility layer for every module. Color, gradient, geometry, conversion,
and safe-access helpers are used by all drawers, weather modules, and the
render loop. Also provides the string→expression auto-interpretation used by
`conky_core_main` before dispatch.

#### Input / Output

Input: plain values, hex colors, stop lists, cairo contexts, widget fields.
Output: numbers, strings, `{r,g,b,a}` tuples, cairo patterns/paths, and
`{type, value, exec}` interpret tables.

#### Internal Logic

Gradients are interpolated in OKLab: `normalize_stops` → find the bracketing
pair at `t` → lerp in OKLab → back to sRGB. `build_gradient_pattern` bakes
this into 256 discrete stops because cairo itself only interpolates in sRGB.
The `_hex_cache` and `_oklab_cache` memoize conversions by hex string.

#### Developer Notes

- `interpret_name` treats any string with parentheses as Lua via `load` — this
  is intentional (dynamic `text`/`value`), but config fields are executable.
- `cache_set` clears the whole cache on overflow (not LRU); suitable for
  fixed-size resource caches, wasteful for hot small caches.
- The module header comment lists `normalize_number` both locally and globally:
  the local is the implementation, the global is the same function exposed for
  callers.

### === ./lua/draw/background.lua ===

Rounded-rectangle panel drawer. Fills a rounded rectangle with a vertical
gradient and optionally strokes an inset rounded border. Supports auto-sizing
to the conky window or the owning group's computed height.

####   GLOBAL FUNCTIONS:

- **draw_background(cr, cfg)** — Draws a rounded panel: copies `cfg` over
  `BACKGROUND_DEFAULT`, then fills the rounded rect with the `bg` gradient and
  strokes the inset `border` (when `border_width > 0`). `w = 0`/`h = 0` mean
  auto-size (window width / group height or window height). Returns the drawn
  bounding box `{ x, y, w, h }`.

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

Panel layer. Renders the "card" behind groups/widgets; the return value lets
the caller lay out relative to the actual drawn area. Runs via the
`background` entry in `DRAW_DISPATCH`.

#### Input / Output

Input: cairo context, item fields (`x`, `y`, `w`, `h`, `radius`,
`border_width`, `bg`/`border` stop lists, `group` for auto height). Output:
filled/stroked cairo path and a `{x, y, w, h}` bounding box.

#### Internal Logic

Defaults are applied per call (copy + fill) so items need not carry every
field. Auto height prefers the owning group's measured height over the whole
window; the border is drawn inset by half its width so it stays fully visible.

#### Developer Notes

- `bg`/`border` are expected to be resolved by `apply_theme`; calling this
  drawer directly with raw gradient-name strings will not work.
- Group auto-height depends on `GROUP_OFFSETS[group].height`, which is only
  populated after the first render pass.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (from BACKGROUND_DEFAULT)

| Field | Default | Notes |
|---|---|---|
| `x` | `0` | left edge |
| `y` | `0` | top edge |
| `w` | `0` | `0` = auto → `conky_window.width` |
| `h` | `0` | `0` = auto → group height, else `conky_window.height` |
| `radius` | `20` | corner radius (all corners) |
| `border_width` | `2` | border stroke width; `<= 0` → no border |
| `bg` | *(theme)* | gradient stops `{ {pos, "#hex", alpha}, ... }` |
| `border` | *(theme)* | gradient stops for the border |

#### Example block

```lua
draw[#draw+1] = {
    type = "background",
    x = 20, y = 0, w = 280, h = 100, radius = 12,
    bg = { { 1, "#1a1b26", 0.9 } },
    border = { { 1, "#7aa2f7", 0.6 } },
    border_width = 2,
}
```

### === ./lua/draw/bar.lua ===

Progress-bar drawer. Renders a horizontal bar for a Conky value in four modes
(smooth gradient, segmented blocks, dots, or polygons), with optional rotation
and gradient colors for background and fill.

####   GLOBAL FUNCTIONS:

- **conky_draw_bar_modules(cr, m)** — Entry point for `type = "bar"` items.
  Applies `BAR_DEFAULT` and `style` fields, resolves the value via
  `draw_get_value` + `normalize_with_suffix`, clamps the fill ratio to [0,1],
  applies rotation (when `angle` is non-zero), and dispatches to the matching
  local drawer (`smooth`/`blocks`/`dot`/`polygon`). Returns the bounding box.

####   LOCAL FUNCTIONS:

- **draw_bar_block(cr, m, y, pct)** — Segmented-block style: draws `c` columns
  at even spacing, each shaded by its own position in the gradient; the first
  `floor(c*pct)` blocks are filled with `fg`. Returns `h + 4`.

- **draw_bar_dots(cr, m, y, pct)** — Dot style: same column layout, each block
  rendered as a circle; filled dots up to the ratio. Returns `h + 4`.

- **draw_bar_polygon(cr, m, y, pct)** — Polygon style: each block is a regular
  `n`-sided polygon (uses `m.sides`), filled at position t; active blocks use
  `fg`. Returns `h + 4`.

- **draw_bar_smooth(cr, m, y, pct)** — Smooth style (default): single background
  gradient fill across the full width, then a foreground gradient fill clipped
  to `width * pct`. Returns `m.height + 4`.

#### Pipeline Role

Bar rendering inside the render loop. Value normalization, clamping, angle
handling, and style dispatch are centralized here so the config only supplies
`value`, `width`, `height`, `style`, and colors.

#### Input / Output

Input: cairo context and item fields (`x`, `y`, `width`, `height`, `max`,
`angle`, `value`/`name`/`arg`, `style`, `fg`, `bg`). Output: drawn bar plus a
bounding box `{x, y, w, h}`.

#### Internal Logic

The value is normalized (suffix-aware), divided by `max`, and clamped. Rotation
is applied around the bar center via cairo matrix save/rotate/restore. Block
modes use `blocks` for the count and `blocks_width` (default `height`) for the
cell size; the `sides` field switches polygon mode on.

#### Developer Notes

- `_bar_mx` is a pre-allocated cairo matrix reused every tick to avoid repeated
  binding allocations.
- Block modes compute the gap so total width stays `m.width`; a `blocks < 2`
  falls back to `h + 4` return without drawing.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (from BAR_DEFAULT + style merge)

| Field | Default | Notes |
|---|---|---|
| `x` | `0` | left edge |
| `width` | `100` | bar width in px |
| `height` | `10` | bar height in px |
| `max` | `100` | value mapped to 100%; `<= 0` → 1 |
| `angle` | `0` | rotation in degrees around center |
| `value` | *(required)* | `${...}` string or `name`+`arg` |
| `fg` | *(theme)* | fill gradient stops |
| `bg` | *(theme)* | background gradient stops |
| `blocks` | *(nil)* | **only block/dot/polygon modes** — segment count |
| `blocks_width` | `height` | **only block/dot/polygon modes** — segment width |
| `mode` | *(nil)* | **only when `blocks` set** — `"dot"` vs `"block"` |
| `sides` | *(nil)* | **polygon mode only** — vertex count, needs `>= 3` |

#### Modes

- **smooth** (default) — plain gradient fill; `blocks`/`mode`/`sides` ignored.
- **blocks** — selected when `blocks` set, `mode` ≠ `"dot"`, `sides < 3`;
  uses `blocks` + `blocks_width`.
- **dot** — selected when `blocks` set and `mode = "dot"`; uses `blocks` +
  `blocks_width`.
- **polygon** — selected when `blocks` set and `sides >= 3`; uses `blocks` +
  `blocks_width` + `sides`. `sides` belongs to this mode only.

#### Example block

```lua
draw[#draw+1] = {
    type = "bar",
    x = 30, y = 30, width = 240, height = 10,
    value = "${memperc}", max = 100,
    fg = { { 1, "#bb9af7", 1 } },
    bg = { { 1, "#333333", 0.5 } },
}
```

### === ./lua/draw/calendar.lua ===

Month-calendar drawer. Renders a weekday header, the current month name, and a
6×7 day grid with today highlighted, neighboring-month days dimmed, and an
optional ISO week-number column.

####   GLOBAL FUNCTIONS:

- **draw_calendar(cr, opts)** — Draws the current month. Merges `opts` over
  `CALENDAR_DEFAULT`, computes the calendar layout via `get_calendar_data`,
  draws the month title, separator line, weekday header, then 42 day cells
  (with week numbers in the first column when enabled). Returns the grid
  bounding box `{x, y, w, h}`.

####   LOCAL FUNCTIONS:

- **cell_date(i)** — Maps a grid cell index (0–41) to the concrete date
  `{year, month, day, inside}`, where `inside` is false for days of the
  previous/next month. Handles month/year wraparound at the edges.

- **get_calendar_data()** — Computes month facts for the current date:
  `first_wday` (0 = Monday), `days_in_month`, `prev_days`, `today`, `year`,
  `month`.

#### Pipeline Role

Calendar rendering inside the render loop. All date math is localized here so
the config only supplies geometry, fonts, and colors.

#### Input / Output

Input: cairo context and `opts` (`x`, `y`, `cell_w`, `row_h`, `font`, `size`,
`show_weeknums`, and the six color fields). Output: drawn calendar grid and a
bounding box.

#### Internal Logic

The grid always starts on the Monday of the week containing day 1 (cell 0 =
that Monday, possibly in the previous month). Week numbers are the ISO week of
each row's Monday, so partial first/last rows still get a number. Colors
switch on `inside`/`today` with bold weight for the current day.

#### Developer Notes

- Uses `os.date("%V")` for ISO week numbers — requires the system time locale
  to resolve correctly (see `core/translate.lua`).
- The weekday header names come from `os.date("%a")` and follow the system
  locale, not a hardcoded list.
- Height is fixed at `row_h * 8` (title + header + 6 rows); width is
  `cell_w * (7 + weeknums)`.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (from CALENDAR_DEFAULT)

| Field | Default | Notes |
|---|---|---|
| `x` | `300` | grid left edge |
| `y` | `15` | grid top edge (title line) |
| `cell_w` | `40` | day-cell width in px |
| `row_h` | `30` | row height in px |
| `font` | `"Noto Sans"` | label font family |
| `size` | `18` | label font size (month title uses `size + 8`, bold) |
| `show_weeknums` | `true` | show ISO week-number column |
| `color_month` | *(theme)* | month title color |
| `color_weekdays` | *(theme)* | weekday header + separator line color |
| `color_days` | *(theme)* | in-month day numbers |
| `color_today` | *(theme)* | today's number (bold) |
| `color_outside` | *(theme)* | previous/next-month day numbers |
| `color_weeknums` | *(theme)* | week-number column color |

#### Example block

```lua
draw[#draw+1] = {
    type = "calendar",
    x = 30, y = 10,
    cell_w = 34, row_h = 22,
    font = "Mono", size = 10,
    show_weeknums = false,
}
```

### === ./lua/draw/clock.lua ===

Analog clock drawer. Renders a circular face with gradient fill and border,
minute/hour ticks, rim numbers, hour/minute/second hands, and a center dot,
all driven by the current time.

####   GLOBAL FUNCTIONS:

- **draw_clock(cr, o)** — Draws an analog clock at `(x, y)` with the given
  radius. Reads the current time (`%I`/`%M`/`%S`), draws the gradient face
  and border in 6° wedges, optional ticks/numbers, the hands (hour 0.5r,
  minute 0.75r, optional second 0.9r), and the center dot. Returns the
  bounding box `{x - r, y - r, 2r, 2r}`.

####   LOCAL FUNCTIONS:

- **hand(a, len, th, col)** — Draws a single hand: a line from the center at
  angle `a`, length `len`, width `th`, colored by position along the gradient.

#### Pipeline Role

Clock rendering inside the render loop. Hand angles are computed from the
system clock each frame; all face/rim elements are optional via flags.

#### Input / Output

Input: cairo context and `o` (`x`, `y`, `radius`, `show_ticks`,
`show_numbers`, `show_seconds`, widths, sizes, colors). Output: drawn clock
and a bounding box.

#### Internal Logic

The face and border are drawn as 60 thin wedge slices, each shaded with the
corresponding gradient position so the circle reads as a smooth radial
gradient. Hand angles: second/minute advance continuously (1/60 per unit);
hour combines hour + minute fraction (`h % 12 + m / 720`). Radius is clamped
to ≥ 1 to protect the cairo context.

#### Developer Notes

- `_clock_ext` is a pre-allocated `cairo_text_extents_t` reused for number
  centering to avoid per-frame bindings.
- Gradient sampling uses `get_color_from_list(c.bg, t)` per wedge — 120+ calls
  per frame; fine for a single clock.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (from CLOCK_DEFAULT)

| Field | Default | Notes |
|---|---|---|
| `x` | `100` | clock center X |
| `y` | `100` | clock center Y |
| `radius` | `50` | face radius (clamped to ≥ 1) |
| `show_ticks` | `true` | draw minute/hour ticks |
| `show_numbers` | `true` | draw 1–12 rim numbers |
| `show_seconds` | `true` | draw the second hand |
| `tick_width_hour` | `3` | hour tick width |
| `tick_width_minute` | `1` | minute tick width |
| `number_size` | `14` | rim-number font size |
| `number_radius` | `0.75` | number ring as fraction of `radius` |
| `hour_hand_width` | `4` | hour hand width (length `0.5r`) |
| `minute_hand_width` | `3` | minute hand width (length `0.75r`) |
| `second_hand_width` | `1` | second hand width (length `0.9r`) |
| `center_radius` | `4` | center dot radius (clamped to ≥ 0.5) |
| `bg` | *(theme)* | face gradient stops |
| `border` | *(theme)* | rim gradient stops |
| `tick_color` | *(theme)* | ticks color |
| `number_color` | *(theme)* | numbers color |
| `hour_color` | *(theme)* | hour hand color |
| `minute_color` | *(theme)* | minute hand color |
| `second_color` | *(theme)* | second hand color |
| `center_color` | *(theme)* | center dot color |

#### Example block

```lua
draw[#draw+1] = {
    type = "clock",
    x = 160, y = 50, radius = 40,
    show_seconds = true,
}
```

### === ./lua/draw/graph.lua ===

Scrolling time-series graph drawer. Samples a Conky value each frame, shifts
the history left, and renders it as a line or filled area with an optional
horizontal grid, background, and border.

####   GLOBAL FUNCTIONS:

- **draw_graph(cr, m)** — Renders a scrolling graph. Merges `m` over
  `GRAPH_DEFAULT`, derives a storage `key` from `key`/`name`/`value`, ensures
  a per-width history buffer, samples the value, applies fixed `max` or
  autoscale (max × 1.1), draws the background, optional grid, line/fill trace,
  and border. Returns the bounding box.

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

Graph rendering inside the render loop. Keeps its own `graph_history` table
keyed by the widget's `key` so multiple/stacked graphs stay independent.

#### Input / Output

Input: cairo context and `m` (`x`, `y`, `width`, `height`, `max`, `autoscale`,
`angle`, `key`, `value`, `graph_type`, `line_width`, `border_width`, `grid`,
`grid_steps`, colors). Output: drawn graph and a bounding box.

#### Internal Logic

History: `graph_history[key]` is a fixed-length array of `width` samples;
each frame removes the oldest and appends the new value. Numeric fields are
coerced with `tonumber` to survive string config/theme values. The fill trace
is one closed path filled with a vertical gradient; the line trace strokes
per-segment with per-column color sampling.

#### Developer Notes

- `graph_history` is global so graphs persist across frames; the buffer is
  recreated when the key or width changes.
- Rotation (like bars) is applied around the center via cairo matrix
  save/rotate/restore with the pre-allocated `_graph_mx`.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (from GRAPH_DEFAULT)

| Field | Default | Notes |
|---|---|---|
| `x` | `0` | left edge |
| `y` | `0` | top edge |
| `width` | `100` | graph width (also history length) |
| `height` | `40` | graph height |
| `max` | `100` | full-scale value (ignored when `autoscale`) |
| `autoscale` | `false` | scale to history max × 1.1 |
| `angle` | `0` | rotation in degrees around center |
| `graph_type` | `"line"` | `"line"` or `"fill"` |
| `line_width` | `2` | **line mode only** — trace stroke width |
| `border_width` | `1` | outer border stroke width |
| `grid` | `false` | draw horizontal grid lines |
| `grid_steps` | `4` | **grid only** — number of grid bands |
| `key` | *(auto)* | storage key; else derived from `name`+`arg`/`value` |
| `value` | *(required)* | `${...}` string or `name`+`arg` |
| `fg` | *(theme)* | trace gradient stops |
| `bg` | *(theme)* | background gradient stops |
| `border` | *(theme)* | border gradient stops |
| `grid_color` | *(theme)* | grid line color |

#### Modes

- **line** (default) — stroked trace; `line_width` applies only here.
- **fill** — filled area with vertical gradient; `line_width` ignored.

#### Example block

```lua
draw[#draw+1] = {
    type = "graph",
    x = 30, y = 90, width = 240, height = 40,
    key = "wifi_down",
    value = "${downspeedf wlp59s0}",
    max = 1024*1024, autoscale = true,
    graph_type = "fill",
    fg = { { 0.0, "#9ece6a", 1 }, { 1.0, "#73daca", 1 } },
}
```

### === ./lua/draw/hyphen.lua ===

Pure-Lua hyphenation engine using LibreOffice `.dic` pattern files. Loaded by
`draw/text.lua` (`wrap_dic` parameter) to insert hyphenation points in wrapped
text. Exposes a module table (`hyphen`) rather than global functions.

####   GLOBAL FUNCTIONS:

- **hyphen.break_word(word)** — Returns a table of byte positions where
  `word` may be hyphenated. Runs the Liang algorithm: pads the lowercased word
  with dots, applies all patterns, collects odd level points, and applies the
  `min_left`/`min_right` limits. Returns `{}` when no dictionary is loaded.

- **hyphen.load(path)** — Parses a `.dic` file into patterns. Handles
  `LEFTHYPHENMIN`/`RIGHTHYPHENMIN` (and COMPOUND variants), skips comment and
  `UTF-8` header lines, and caches parsed results per path (invalidated by
  mtime when LuaFileSystem is available). Returns `true`/`false`.

####   LOCAL FUNCTIONS:

- **iter_chars(s)** — Iterates the characters of a string, UTF-8 aware when
  `lua-utf8`/`utf8` is available, byte-by-byte otherwise.

- **utf8_lower(s)** — Lowercases a string using the UTF-8 library when
  present; falls back to per-character `lower()` (ASCII-only).

#### Pipeline Role

Hyphenation service for wrapped text. Standalone module consumed by
`draw_text`; not part of the render loop itself.

#### Input / Output

Input: a `.dic` path and the word to break. Output: `break_word` returns byte
offsets (suitable for `string:sub`) of legal break points.

#### Internal Logic

Patterns encode TeX-style levels (`a1bc2`); multi-digit levels accumulate
digit-by-digit. Breaks are only allowed at odd levels, between `min_left` and
`char_count - min_right`. Byte offsets are re-derived from the original word
(before lowercasing) because lowercasing can change byte length.

#### Developer Notes

- Prefers `lua-utf8`, then `utf8`, then plain bytes — without a UTF-8 library
  the results are ASCII-only.
- The parsed dictionary is cached in `cache[path]`; `mtime` invalidation needs
  LuaFileSystem (`lfs`).

#### Default values (module table `hyphen`)

| Field | Default | Notes |
|---|---|---|
| `min_left` | `2` | min chars before a break (overridable via `.dic` LEFTHYPHENMIN) |
| `min_right` | `2` | min chars after a break (overridable via `.dic` RIGHTHYPHENMIN) |
| `patterns` | `{}` | loaded patterns; populated by `hyphen.load(path)` |
| `cache` | `{}` | parsed-dictionary cache per path (mtime-invalidated) |

#### Example block

Used via the `wrap_dic` parameter of a `text` item:

```lua
draw[#draw+1] = {
    type = "text",
    x = 30, y = 30, font = "Mono", size = 12,
    text = "longwordthatneedsbreaking",
    wrap_width = 120,
    wrap_dic = "/usr/share/hyphen/hyph_hu_HU.dic",
}
```

### === ./lua/draw/icon_theme.lua ===

XDG icon-theme resolver. Locates the closest-size SVG/PNG for an icon name by
searching standard icon directories, parsing `index.theme` files, honoring
inheritance, and caching results (theme metadata + resolved paths).

####   GLOBAL FUNCTIONS:

    (no global function)

####   LOCAL FUNCTIONS:

- **file_exists(path)** — Returns `true` when the file can be opened for
  reading.

- **find_best_size(sizes, target)** — Returns the size closest to `target`
  from a sorted size list (first entry when `target` is not numeric).

- **find_in(dir)** — Closure inside `icon_resolve`: probes the context
  directories in `CONTEXT_PRIORITY` order and tries `.svg` before `.png` for
  `name`, returning the first existing path.

- **icon_resolve(name, target_size, theme_name)** — Core lookup: tries the
  named theme (default `XDG_ICON_THEME` or `"Papirus"`) at the best-matching
  size and in `scalable`, then walks the theme's `Inherits` chain. Results are
  cached in `ICON_PATH_CACHE` (including negative misses).

- **parse_index_theme(theme_name)** — Reads and parses a theme's
  `index.theme`: collects `Size=` values (deduped, sorted) and the
  `Inherits=` list (CRLF-safe). Caches metadata in `ICON_THEME_CACHE`.

- **read_file(path)** — Returns the file contents, or `nil`.

- **try_theme(tname)** — Closure inside `icon_resolve`: for one theme, finds
  the best size dir and probes `find_in` there, then falls back to the
  `scalable` directory.

#### Pipeline Role

Icon lookup service for image/SVG-based widgets (e.g. weather and hardware
icons). Other modules call it indirectly through `draw_png`/`draw_svg` paths
resolved by the config.

#### Input / Output

Input: icon name, target size, theme name (plus `XDG_ICON_THEME`), search
paths under the four standard icon roots. Output: absolute path to the best
icon file, or `nil`.

#### Internal Logic

Search order: `~/.local/share/icons` → `~/.icons` →
`/usr/local/share/icons` → `/usr/share/icons`. Within a theme, `.svg` is
preferred over `.png`; the closest size dir is tried before `scalable`.
Inheritance is resolved depth-first through the `Inherits=` list. Both caches
use `cache_set` bounds (128 / 512).

#### Developer Notes

- `ICON_PATH_CACHE` stores `false` for misses so repeated lookups of missing
  icons are cheap.
- Context order in `CONTEXT_PRIORITY` biases toward `apps`/`places` first; the
  `mimetypes` context is checked late because it is often large.

#### Default values (module constants)

| Setting | Default | Notes |
|---|---|---|
| default theme | `XDG_ICON_THEME` or `"Papirus"` | theme used when none is passed |
| target size | `48` | requested size when not given |
| search paths | `~/.local/share/icons` → `~/.icons` → `/usr/local/share/icons` → `/usr/share/icons` | first hit wins |
| extensions | `.svg` then `.png` | tried per context dir |
| context order | apps, places, devices, status, actions, categories, emblems, mimetypes, panel, emotes | `CONTEXT_PRIORITY` |
| cache bounds | `ICON_THEME_CACHE` 128, `ICON_PATH_CACHE` 512 | via `cache_set` |

#### Example block

Resolved by `icon_resolve(name, target_size, theme_name)` and used as a `path`
for image/SVG items (e.g. `conky_icon_current_weather()` from weather/core.lua):

```lua
draw[#draw+1] = {
    type = "image",
    x = 238, y = 32, width = 24, height = 24,
    path = "/usr/share/icons/Papirus/48x48/apps/htop.svg",
}
```

### === ./lua/draw/image.lua ===

PNG rendering drawer. Paints a cached PNG into a target box with scaling,
cropping, rotation, opacity, optional flat tint, and circle/rounded clip shapes.
Uses a pattern matrix for scaling instead of transforming the context.

####   GLOBAL FUNCTIONS:

- **draw_png(cr, m)** — Entry point for `type = "image"` items. Loads (and
  caches) the PNG surface, applies crop and aspect-preserving sizing, then
  paints it with rotation, clip shape, tint or opacity. Returns the drawn
  bounding box or `nil`.

####   LOCAL FUNCTIONS:

- **is_surface_valid(s)** — Returns `true` when the cairo surface status is
  OK and the image has positive width/height.

#### Pipeline Role

Raster image rendering inside the render loop. All surface caching, aspect
math, tinting, and clipping are localized here.

#### Input / Output

Input: cairo context and item fields (`x`, `y`, `width`, `height`, `path`,
`alpha`, `tint`, `tint_alpha`, `rotate`, `shape`, `radius`, `crop`,
`scale_mode`). Output: painted image and a bounding box.

#### Internal Logic

Only one of width/height is needed — the missing one is derived from the crop
aspect ratio. Scaling is done via the pattern matrix (`translate` crop origin,
`scale` source/target) so the context stays untransformed. A tint masks the
tint color through the image alpha only (folding opacity in) to avoid ghosting.

#### Developer Notes

- `PNG_CACHE` holds surfaces keyed by path (bound 256); surfaces are validated
  on reuse and reloaded when invalid.
- Guard clauses bail out before touching the context when target `w`/`h` is
  non-positive, since 0/0 matrix entries produce NaN patterns.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (from PNG_DEFAULT)

| Field | Default | Notes |
|---|---|---|
| `x` | `0` | left edge |
| `y` | `0` | top edge |
| `width` | *(nil)* | target width; auto = aspect from `height`/`crop` |
| `height` | *(nil)* | target height; auto = aspect from `width`/`crop` |
| `path` | *(nil, required)* | PNG file path |
| `alpha` | `1` | opacity (clamped 0–1) |
| `tint` | *(nil)* | flat tint color `"#hex"` |
| `tint_alpha` | `1` | tint opacity (multiplied with `alpha`) |
| `rotate` | `0` | rotation in degrees around center |
| `scale_mode` | `"bilinear"` | `"bilinear"` \| `"nearest"` \| `"good"` |
| `shape` | *(nil)* | `"circle"` → circular clip |
| `radius` | `0` | rounded-corner clip radius (`> 0` → clip) |
| `crop` | *(nil)* | `{ x, y, w, h }` source region |

#### Example block

```lua
draw[#draw+1] = {
    type = "image",
    x = 238, y = 32, width = 24, height = 24,
    path = "/usr/share/pixmaps/htop.png",
    click = "konsole -e htop &",
}
```

### === ./lua/draw/lines.lua ===

Straight-line drawer. Draws a line between two points in solid, dashed, or
dotted style with a gradient color, thickness, and configurable on/off lengths.

####   GLOBAL FUNCTIONS:

- **draw_line_modules(cr, m)** — Draws a line from `(x1, y1)` to `(x2, y2)`.
  Applies the group Y offset (`m.y`) to both endpoints, coerces dash values to
  non-negative numbers, sets the dash pattern per `style_type`, strokes with a
  gradient, resets the dash, and returns the line's bounding box.

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

Separator/underline rendering. Also called internally by the calendar drawer
for the header rule; used directly for `type = "line"` items.

#### Input / Output

Input: cairo context and `m` (`x1`, `y1`, `x2`, `y2`, `thickness`,
`style_type`, `dash_on`, `dash_off`, `dot_on`, `dot_off`, `fg`). Output:
stroked line and a bounding box.

#### Internal Logic

A missing `fg` falls back to a fixed color. Dash handling: `dashed` uses
`{dash_on, dash_off}`, `dotted` uses `{dot_on, dot_off}`, anything else clears
the dash; non-positive dash values disable that style. The dash is reset at the
end so later stroke-based elements in the same frame are unaffected.

#### Developer Notes

- Endpoint offsets come from `m.y` because the render loop adds the group
  offset to `item.y`; without this, lines in groups would be drawn at the
  wrong Y.
- Negative dash lengths are clamped to avoid poisoning the cairo context.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (from LINE_DEFAULT)

| Field | Default | Notes |
|---|---|---|
| `x1` | `0` | start X |
| `y1` | `0` | start Y |
| `x2` | `100` | end X |
| `y2` | `0` | end Y |
| `thickness` | `2` | stroke width (clamped to ≥ 1) |
| `style_type` | `"solid"` | `"solid"` \| `"dashed"` \| `"dotted"` |
| `dash_on` | `4` | **dashed only** — dash length |
| `dash_off` | `4` | **dashed only** — gap length |
| `dot_on` | `1` | **dotted only** — dot length |
| `dot_off` | `3` | **dotted only** — gap length |
| `fg` | `{ { 1, "#565f89", 1 } }` | line gradient stops |

#### Modes

- **solid** (default) — no dash pattern.
- **dashed** — uses `dash_on`/`dash_off`.
- **dotted** — uses `dot_on`/`dot_off`.

#### Example block

```lua
draw[#draw+1] = {
    type = "line",
    x1 = 30, y1 = 50, x2 = 270, y2 = 50,
    thickness = 1, style_type = "dashed",
    fg = { { 1, "#7aa2f7", 0.6 } },
}
```

### === ./lua/draw/rings.lua ===

Ring-gauge drawer. Draws a circular gauge for a Conky value in four modes
(`ring` segmented sectors, `smooth` arc, `dot`, `polygon`), with configurable
start/end angles, auto-computed sector gaps, and an alarm color when the value
exceeds `max`.

####   GLOBAL FUNCTIONS:

- **draw_one_ring(cr, s0)** — Entry point for `type = "ring"` items. Merges
  `s0` over `RING_DEFAULT`, auto-computes sector layout, resolves the value,
  clamps the ratio, detects the alarm over-range, and dispatches to the mode
  drawer (`smooth`/`dot`/`polygon`/default `ring`). Returns the bounding box.

####   LOCAL FUNCTIONS:

- **draw_ring_dots(cr, s, dv, ov)** — Dot mode: one circle per sector on the
  arc center line; filled dots up to the drawn value, alarm color when
  over-range.

- **draw_ring_mode(cr, s, dv, ov)** — Segmented mode: strokes each sector arc
  with `bg`, then re-strokes the active ones with `fg` (or alarm). Reversed
  spans sweep the short way via `cairo_arc_negative`.

- **draw_ring_polygon(cr, s, dv, ov)** — Polygon mode: a regular `n`-sided
  polygon per sector slot; active slots filled with `fg`/alarm.

- **draw_smooth_mode(cr, s, pct, ov)** — Smooth mode: full `bg` arc plus an
  `fg` arc over the `pct` fraction; handles reversed spans with the negative
  arc function.

- **get_alarm_color(s)** — Returns `{r,g,b,a}` from `s.alarm_color` and
  `s.alarm_alpha` via `hex_to_rgba`.

- **move_to_arc_start(cr, cx, cy, r, angle)** — Moves the cairo pen to a point
  on the arc before stroking.

- **ring_arc_radius(s)** — Returns the stroke radius clamped to ≥ 0.5
  (`radius - thickness/2`) to protect the cairo context from negative arcs.

- **ring_auto_compute(s)** — Fills in `s.gap` between sectors from
  `sector_size`/`sectors`/span (like bars); zero when no sector size is set.

- **ring_slot_center_angle(s, i)** — Returns the center angle (radians) of
  sector slot `i`, respecting span direction.

#### Pipeline Role

Ring rendering inside the render loop. Handles value normalization, sector
layout, mode dispatch, and alarm highlighting so the config only supplies
geometry, mode, and colors.

#### Input / Output

Input: cairo context and item fields (`x`, `y`, `radius`, `thickness`,
`start_angle`, `end_angle`, `sectors`, `sector_size`, `sides`, `mode`, `max`,
`alarm_color`/`alarm_alpha`, `value`, `fg`, `bg`). Output: drawn ring and a
bounding box.

#### Internal Logic

Sector gap is auto-computed when `sector_size` is set (`(span - sectors*size) /
gaps`), with gaps = sectors for full circles and sectors−1 otherwise. The
active sector count is `floor(pct * sectors + 0.5)`, forced to all sectors on
over-range. Direction-aware arc functions keep reversed spans drawing the
short way.

#### Developer Notes

- The arc radius clamp (`ring_arc_radius`) exists because `thickness > 2r`
  yields a negative cairo arc radius and corrupts the whole frame.
- Per-sector colors sample the gradient at `(i-1)/sectors`, so the last sector
  uses the gradient endpoint.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (from RING_DEFAULT)

| Field | Default | Notes |
|---|---|---|
| `x` | `100` | ring center X |
| `y` | `100` | ring center Y |
| `radius` | `50` | outer radius |
| `thickness` | `6` | stroke width |
| `start_angle` | `0` | span start (degrees) |
| `end_angle` | `360` | span end (degrees) |
| `sectors` | `6` | **ring/dot/polygon modes only** — sector count |
| `sector_size` | *(nil)* | **ring/dot/polygon only** — auto-computes sectors + gap |
| `sides` | `6` | **polygon mode only** — vertex count (≥ 3) |
| `mode` | `"ring"` | `"ring"` \| `"smooth"` \| `"dot"` \| `"polygon"` |
| `max` | `100` | full-scale value (0 → 1) |
| `alarm_color` | `"#FF0000"` | color when value exceeds `max` |
| `alarm_alpha` | `1` | alarm opacity |
| `value` | *(required)* | `${...}` string or `name`+`arg` |
| `fg` | *(theme)* | active gradient stops |
| `bg` | *(theme)* | inactive gradient stops |

#### Modes

- **ring** (default) — segmented arcs; uses `sectors` (+ optional `sector_size`).
- **smooth** — single smooth arc; `sectors`/`sector_size`/`sides` ignored.
- **dot** — dots per sector; uses `sectors` (+ `sector_size`).
- **polygon** — polygons per sector; uses `sectors` (+ `sector_size`) and
  `sides`. `sides` belongs to this mode only.

#### Example block

```lua
draw[#draw+1] = {
    type = "ring",
    x = 160, y = 50, radius = 35, thickness = 5,
    value = "${cpu}", max = 100,
    sectors = 12, mode = "smooth",
    fg = { { 0.0, "#7aa2f7", 1 }, { 1.0, "#bb9af7", 1 } },
    bg = { { 1, "#333333", 0.5 } },
}
```

### === ./lua/draw/svg.lua ===

SVG rendering drawer (librsvg). Rasterizes an SVG file into a target box with
opacity, rotation, circle/rounded clip shapes, and optional flat tint. Handles
are cached in `SVG_CACHE` and released at shutdown.

####   GLOBAL FUNCTIONS:

- **draw_svg(cr, opts)** — Entry point for `type = "svg"` items. Loads and
  caches the rsvg handle, clamps the target size to ≥ 1, applies translation,
  rotation and clip, then renders. With tint/opacity it renders into a temp
  surface first (masking or `paint_with_alpha`). Returns nothing.

- **svg_free_all()** — Releases every cached rsvg handle and clears
  `SVG_CACHE`. Called from `conky_cleanup()` at shutdown.

####   LOCAL FUNCTIONS:

- **svg_free(path)** — Frees and removes the cached handle for a single path
  (currently unused by other modules).

#### Pipeline Role

Vector-image rendering inside the render loop. Complements `draw_png` for
SVG assets; participates in the shutdown cleanup chain.

#### Input / Output

Input: cairo context and `opts` (`x`, `y`, `w`, `h`, `path`, `rotate`,
`shape`, `radius`, `alpha`, `tint`, `tint_alpha`). Output: rendered SVG; no
return value.

#### Internal Logic

`need_temp` is true when alpha < 1 or a tint is set — the document is then
rendered to an ARGB32 temp surface and composited as a mask (tint) or with
`paint_with_alpha`. Without those options the SVG renders straight onto the
context. Viewport uses the pre-allocated `_svg_vp` rectangle.

#### Developer Notes

- Requires the librsvg Lua bindings (`rsvg_create_handle_from_file`,
  `rsvg_handle_render_document`); guarded at runtime so missing bindings fail
  softly.
- Handles are cached per path (bound 256); `svg_free_all` must run at exit to
  avoid leaking rsvg handles.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (inline in draw_svg — no default table)

| Field | Default | Notes |
|---|---|---|
| `x` | `0` | left edge |
| `y` | `0` | top edge |
| `w` | `32` | render width (clamped to ≥ 1) |
| `h` | `32` | render height (clamped to ≥ 1) |
| `path` | *(nil, required)* | SVG file path |
| `rotate` | `0` | rotation in degrees around center |
| `shape` | *(nil)* | `"circle"` → circular clip |
| `radius` | `0` | rounded-corner clip radius (`> 0` → clip) |
| `alpha` | `1` | opacity |
| `tint` | *(nil)* | flat tint color `"#hex"` |
| `tint_alpha` | `1` | tint opacity (multiplied with `alpha`) |

#### Example block

```lua
draw[#draw+1] = {
    type = "svg",
    x = 30, y = 225, w = 28, h = 28,
    path = "/usr/share/icons/breeze/places/24/folder-blue-symbolic.svg",
}
```

### === ./lua/draw/text.lua ===

Text rendering drawer. Draws a line (or wrapped paragraph) of text with
alignment, gradient color, template expansion, and optional dictionary
hyphenation. Used directly by `type = "text"` items and by the calendar module
for its labels.

####   GLOBAL FUNCTIONS:

- **draw_text(cr, opts)** — Draws text with defaults merged over `opts`.
  Supports `x`/`y` = `"center"`, left/center/right alignment, template
  expansion via `normalize_text`, word-wrap with optional hyphenation, and
  per-line gradient fills. Returns the bounding box `{x, y, w, h}`.

####   LOCAL FUNCTIONS:

- **normalize_text(cfg)** — Resolves `cfg.text` to a plain string: an
  `interpret_name` table or legacy function is invoked; plain strings pass
  through `conky_parse` for template expansion. Returns `nil` for empty input.

#### Pipeline Role

Text layer of the render loop. All font/metrics/expansion logic is localized
here so the config only supplies the text, font, size, color, and alignment.

#### Input / Output

Input: cairo context and `opts` (`x`, `y`, `font`, `size`, `slant`, `weight`,
`align`, `text`, `color`, `wrap_width`, `wrap_dic`). Output: drawn text and a
measured bounding box.

#### Internal Logic

Without wrapping, the text is measured once with `cairo_text_extents`, aligned
relative to the anchor, and drawn with a horizontal gradient. With wrapping,
lines are packed word-by-word; overflowing words are hyphenated via
`hyphen.break_word` with a fallback to character splitting (UTF-8 aware).
Line height is `font_extents.height * 1.2`.

#### Developer Notes

- `_text_ext`/`_font_ext` are pre-allocated cairo extents structs reused every
  tick to avoid binding churn.
- `normalize_text` runs `conky_parse` on raw strings — templates containing
  brackets are expanded by Conky, not by Lua (unlike `interpret_name`).
- Hyphenation only engages when `wrap_dic` is set and a matching `.dic` file
  loads successfully.

#### Common fields (all drawers)

Every draw item accepts these framework-level fields. They are consumed by the
core loop, group registry, and mouse dispatcher before the drawer runs — the
drawer itself never reads them.

| Field | Type | Default | Notes |
|---|---|---|---|
| `view` | string | `nil` | Comma-separated view names this widget belongs to; omitted = visible in all views. |
| `group` | string | `nil` | Group name for conditional drawing and group-based Y positioning (group padding). |
| `draw_me` | draw_me | `nil` | Conditional drawing: boolean, Conky template, or Lua expression ending in `()`. |
| `click` | string | `nil` | Mouse action on click, e.g. `MOUSE_CLICK_LEFT`. |
| `click_view` | string | `nil` | View to switch to on click. |

#### Default values (from TEXT_DEFAULT)

| Field | Default | Notes |
|---|---|---|
| `x` | `0` | anchor X (or `"center"`) |
| `y` | `0` | anchor Y (or `"center"`) |
| `font` | `"Sans"` | font family |
| `size` | `14` | font size |
| `slant` | `"normal"` | `"normal"` \| `"italic"` |
| `weight` | `"normal"` | `"normal"` \| `"bold"` |
| `align` | `"left"` | `"left"` \| `"center"` \| `"right"` |
| `text` | `""` | string / `interpret_name` table / function (auto-`conky_parse`) |
| `color` | `{ { 1, "#a9b1d6", 1 } }` | text gradient stops |
| `wrap_width` | *(nil)* | wrap width in px (nil/0 → single line) |
| `wrap_dic` | *(nil)* | **wrap only** — hyphenation `.dic` path |

#### Example block

```lua
draw[#draw+1] = {
    type = "text",
    x = 30, y = 20,
    font = "Mono", size = 14, weight = "bold",
    text = "CPU: ${cpu}%",
    color = { { 1, "#7aa2f7", 1 } },
}
```

### === ./lua/hardware/battery.lua ===

Battery and wireless-peripheral info: internal battery health from sysfs, and
Bluetooth headset / wireless mouse battery levels queried via D-Bus (KDE
Plasma or UPower). All values are cached with a TTL.

####   GLOBAL FUNCTIONS:

- **conky_battery_health_data()** — Returns battery health as a percentage
  (0–100): current full capacity ÷ designed capacity from sysfs (energy
  fallback), cached 1 h. Use directly in a bar/ring widget.

- **conky_external_battery_charge(i)** — Charge percentage (0–100) of the
  i-th external battery (1-based); 0 when out of range.

- **conky_external_battery_count()** — Number of external batteries found
  (0 when none).

- **conky_external_battery_list()** — Table of every detachable battery found
  (`{name, pct}` entries); mouse first, then headset.

- **conky_external_battery_name(i)** — Display name of the i-th external
  battery (1-based), `""` when out of range.

- **conky_headset_info()** — `{name, pct}` of a connected Bluetooth headset,
  or `nil`. Queries Plasma's D-Bus path first, then UPower (`headset|headphone`
  filter). Cached 10 s.

- **conky_mouse_info()** — `{name, pct}` of a wireless mouse via UPower
  (`hidpp` filter), or `nil`. Cached 10 s.

####   LOCAL FUNCTIONS:

- **get_battery_path()** — Auto-detects the internal battery's sysfs path
  (`/sys/class/power_supply/<name>/`), cached 1 h. Uses `lfs.dir` when
  available, else `ls`.

- **get_device_upower(filter)** — Generic UPower lookup: finds the first
  device matching the filter, reads its `percentage` and `model`, returns
  `{name, pct}` or `nil`.

- **get_headset_plasma()** — D-Bus lookup of a Bluetooth headset under Plasma
  (`org.bluez` ObjectManager + `qdbus6` name + `Percentage` property).

- **is_plasma()** — Detects a KDE Plasma session via `XDG_CURRENT_DESKTOP`,
  `KDE_FULL_SESSION`, or a `pgrep plasmashell` check. Cached 1 h.

#### Pipeline Role

Hardware-information source for battery/headset/mouse widgets. Pure data
module — read-only, no drawing; values are consumed by text/bar/ring items.

#### Input / Output

Input: sysfs under `/sys/class/power_supply`, `upower`, D-Bus (`org.bluez`),
and env vars. Output: percentages, names, and device lists for the calling
widgets.

#### Internal Logic

All queries go through `cached(key, ttl, fn)`; TTLs: battery path/health 1 h,
headset/mouse 10 s. Device detection prefers sysfs + `lfs`, falls back to
shell. Health prefers `charge_*` files, falls back to `energy_*`.

#### Developer Notes

- D-Bus commands (`qdbus6`, `dbus-send`) must be installed for Plasma-based
  headset queries; missing tools just yield `nil`.
- The external list re-queries mouse + headset on every call — `count`/`name`/
  `charge` call it repeatedly but rely on the 10 s cache.

### === ./lua/hardware/core.lua ===

Shared utilities for all hardware modules: TTL caching, safe shell/file
reading, DMI reads, the `sensors` regex extractor, the lsblk root-device
walker, the chassis code map, and the pending-updates readers.

####   GLOBAL FUNCTIONS:

- **cached(key, interval, f)** — TTL-based memoization in the global `cache`
  table. Returns the stored value when younger than `interval` seconds,
  otherwise calls `f`, stores, and returns the result.

- **conky_updates_aur()** — Returns pending AUR updates as a string
  (`"3 packages"`), read from the `tmp/updates.txt` file written by the Bash
  backend (the trailing number on the second field).

- **conky_updates_repo()** — Pending distro-repo updates as a string
  (`"5 packages"`), from the leading number of `tmp/updates.txt`.

- **dmi(field)** — Reads a DMI value from `/sys/class/dmi/id/<field>` and
  caches it nearly forever. Backs the `conky_*` DMI functions in `dmi.lua`.

- **get_root_device(map, name)** — Walks the lsblk JSON `map` up the `parent`
  chain from a named entry and returns the top-level (root) device table, or
  `nil`. Used by `hardware/usb.lua`.

- **get_sensor_val(pattern)** — Runs `sensors` (cached 2 s) and extracts a
  number matching the Lua `pattern`; 0 when nothing matches. Used by
  `hardware/sensors.lua`.

- **parse_num(v)** — Extracts the first numeric run of a string; 0 on none.

- **pread(cmd)** — Runs `timeout 10 <cmd>` via `io.popen` and returns the
  trimmed stdout (or `""`).

- **read_file(path)** — Reads a file into a trimmed string (or `""`).

- **read_num(path)** — Reads a file and returns the first number found.

- **starts_with(str, prefix)** — Prefix check on strings.

####   LOCAL FUNCTIONS:

- **has_cmd(cmd)** — `command -v` check for an executable.

- **read_sensors_raw()** — Returns the raw `sensors` output, cached 2 s.

#### Pipeline Role

Backbone for the hardware namespace. Every hardware module builds on
`pread`/`read_file`/`cached`/`dmi`; also publishes the update counts as Conky
variables. `static` is the module-scope state table.

#### Input / Output

Input: sysfs files, shell commands (`sensors`, `timeout`, `lsblk`), and the
Bash backend's `tmp/updates.txt`. Output: numbers, strings, cached tables, and
the update-count strings.

#### Internal Logic

`cached` uses `os.time` wall-clock TTL with no invalidation beyond age.
`pread` wraps commands in `timeout 10` to prevent hangs. DMI values are cached
with a huge interval since they never change at runtime.

#### Developer Notes

- `chassis_map` (SMBIOS type 23 → name) is defined here and consumed by
  `hardware/dmi.lua` for `conky_chassis_type_human`.
- `static` is declared but currently unused by this module — kept as shared
  state space for future hardware modules.
- `updates.txt` is produced asynchronously by the shell backend, so these
  calls return `0 packages` until the first refresh.

### === ./lua/hardware/dmi.lua ===

Thin DMI accessors. Each function reads one field from
`/sys/class/dmi/id/*` through the cached `dmi()` helper in `hardware/core.lua`
and returns it as a string. Pure, stateless, interchangeable.

####   GLOBAL FUNCTIONS:

- **conky_bios_date()** — BIOS release date in the vendor's DMI format
  (e.g. `"03/15/2019"`), from `bios_date`.

- **conky_bios_release()** — BIOS release version string (`bios_release`).

- **conky_bios_vendor()** — BIOS/UEFI vendor (e.g. `"American Megatrends"`).

- **conky_bios_version()** — BIOS version string.

- **conky_board_name()** — Motherboard model (e.g. `"X550ZK"`).

- **conky_board_vendor()** — Motherboard manufacturer.

- **conky_board_version()** — Motherboard version string.

- **conky_chassis_type()** — Raw numeric chassis type code (e.g. `"10"` =
  Notebook).

- **conky_chassis_type_human()** — Human-readable chassis name from
  `chassis_map` (e.g. `"Notebook"`); `"Unknown (<code>)"` on an unmapped code.

- **conky_chassis_vendor()** — Chassis manufacturer.

- **conky_product_family()** — Product family name (may be empty).

- **conky_product_name()** — Product/model name (e.g. `"ZenBook"`).

- **conky_product_sku()** — Product SKU as set by the vendor.

- **conky_sys_vendor()** — System manufacturer (e.g. `"ASUSTeK"`).

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

System-identification data for text widgets. Simple field accessors; the
actual I/O and caching live in `hardware/core.lua` (`dmi()`).

#### Input / Output

Input: `/sys/class/dmi/id/<field>` files. Output: plain strings; empty when a
field is absent.

#### Internal Logic

Every function is a one-line wrapper over `dmi(field)`, which caches per-field
for nearly forever. `conky_chassis_type_human` maps the raw code through
`chassis_map` (defined in core.lua).

#### Developer Notes

- Cache interval is effectively infinite — DMI data never changes at runtime;
  a reboot or `sudo dmidecode` equivalent is needed to refresh.
- All fields are optional on some hardware; consumers should treat `""` as
  "unknown".

### === ./lua/hardware/info.lua ===

CPU model, NVMe model, and OS install-date accessors for text widgets.
Long-lived values cached 24 h (or memoized once), so they cost nothing per
frame after the first call.

####   GLOBAL FUNCTIONS:

- **conky_cpu_name()** — CPU model name from `/proc/cpuinfo`, cleaned of the
  words `CPU`/`Processor` and trademark symbols (`™`/`®`), whitespace
  collapsed. Cached 24 h.

- **conky_install_date()** — OS install date (`YYYY-MM-DD`) taken from the
  first line of `/var/log/pacman.log`; memoized in `static.inst_dt` for the
  session. Returns `"N/A"` when unavailable.

- **conky_nvme_model()** — NVMe drive model from
  `/sys/class/nvme/nvme0/model` (24 h cache); `"Unknown NVMe"` when absent.

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

System-identity data for text widgets. All three return static strings used
directly in the UI.

#### Input / Output

Input: `/proc/cpuinfo`, `/sys/class/nvme/nvme0/model`, `/var/log/pacman.log`.
Output: cleaned display strings.

#### Internal Logic

CPU name is extracted from the first `model name` line and normalized with a
chain of `gsub`s. The install date relies on the pacman log timestamp, which
is the OS image creation time; memoization avoids re-reading it.

#### Developer Notes

- The 24 h cache interval means new hardware/install data only appears after a
  restart (or by bumping the interval).
- `conky_install_date` is Arch-specific (`/var/log/pacman.log`); other distros
  would need a different source.

### === ./lua/hardware/mtp.lua ===

MTP (phone/tablet) detection and storage-fill percentages. Queries KDE's KIO
MTP daemon on Plasma (`qdbus6`/`kioclient`) or GVFS (`gio`/`ls`) elsewhere,
and exposes the result to Conky with a 5 s cache.

####   GLOBAL FUNCTIONS:

- **conky_mtp_count()** — Number of connected MTP devices (0 when none).

- **conky_mtp_data()** — Full MTP info: `{ count, devices }`, each device
  having `name` and `storages` (with `max`/`used`/`perc`). Chooses the Plasma
  or GVFS backend from `XDG_CURRENT_DESKTOP`.

- **conky_mtp_perc(dev_idx, storage_idx)** — Fill percentage (0–100) of a
  device's storage (1-based indexes); 0 on out-of-range.

####   LOCAL FUNCTIONS:

- **gvfs_mtp_info()** — GVFS backend: lists `mtp:` mounts under
  `/run/user/<uid>/gvfs/`, reads `filesystem::size`/`free` via `gio info`
  (2 s timeout), returns the same device/storage shape. Cached 5 s.

- **kde_mtp_info()** — Plasma backend: enumerates devices via
  `org.kde.kmtp.Daemon.listDevices`, resolves a display name with
  `kioclient ls mtp:/`, and reads each storage's `maxCapacity`/
  `freeSpaceInBytes`. Cached 5 s.

#### Pipeline Role

Hardware-information source for phone/tablet widgets. Read-only data provider
behind a small Conky-facing API.

#### Input / Output

Input: KIO MTP daemon (D-Bus), `kioclient`, GVFS mounts + `gio info`. Output:
device/storage tables and percentage numbers.

#### Internal Logic

`conky_mtp_data` selects the backend once per call by checking
`XDG_CURRENT_DESKTOP` for KDE/Plasma. Both backends cache their full result
for 5 s. Storage percent is `floor(used/max*100)`.

#### Developer Notes

- Requires `kio-extras`/`kde-cli-tools` on Plasma or `gio`/GVFS elsewhere;
  missing tools yield an empty device list.
- `conky_mtp_perc` builds on `conky_mtp_data`, so the 5 s cache bounds how
  often the D-Bus/GVFS queries actually run.

### === ./lua/hardware/network.lua ===

WiFi status, public IP/geo info, and ping statistics. Network data is fetched
in the background by `sh/fetch_network.sh`; this module only reads the cached
`tmp/` JSON files (no synchronous network I/O in Lua).

####   GLOBAL FUNCTIONS:

- **conky_ping_avg()** — Average ping latency in ms, parsed from
  `network_ping.json` (`rtt min/avg/max/mdev`); 0 when absent.

- **conky_ping_jitter()** — Ping jitter (max − min, 1-decimal rounding) in ms.

- **conky_public_city()** — City of the public IP (geoip), `"N/A"` unknown.

- **conky_public_country()** — Country of the public IP.

- **conky_public_ip()** — Public IPv4 address as reported by the fetcher.

- **conky_wifi_active()** — `1` when the WiFi interface's carrier is up,
  else `0`. Cached 5 s.

- **conky_wifi_interface()** — Name of the active WiFi interface (detected by
  the presence of a `wireless` entry under `/sys/class/net/<iface>/`), cached
  1 h; `""` when offline.

####   LOCAL FUNCTIONS:

- **get_ip_data()** — Returns the `network_ip.json` content, re-read at most
  every 600 s (memoized).

- **get_ping_data()** — Returns the `network_ping.json` content, re-read at
  most every 10 s (memoized).

- **read_network_file(filename)** — Reads a JSON file from `JSON_PATH`, or
  `""`.

#### Pipeline Role

Network-information source for text/graph widgets. Reads only pre-fetched
files, so per-frame cost is negligible; the heavy fetching runs in the Bash
backend.

#### Input / Output

Input: `tmp/network_ping.json`, `tmp/network_ip.json` (written by
`sh/fetch_network.sh`), and `/sys/class/net`. Output: interface names,
numbers, and geo strings.

#### Internal Logic

JSON is not parsed — values are extracted with simple `match` patterns
(`"field":"..."`). The ping/ip files are memoized with module-local TTLs (10 s
/ 600 s). WiFi interface detection prefers `lfs.dir` over `ls`.

#### Developer Notes

- `JSON_PATH` is provided externally (in `widget.lua`); the module depends on
  it being set before load.
- The IP/geo data can be stale up to 10 minutes by design; ping up to 10 s.
- Detection order of interfaces follows `/sys/class/net` enumeration, which is
  not guaranteed to be stable across boots.

### === ./lua/hardware/sensors.lua ===

lm-sensors accessors. Reads CPU package/core, NVMe, WiFi, and fan readings
from `sensors` output via the cached extractor in `hardware/core.lua`;
returns 0 when a sensor is missing.

####   GLOBAL FUNCTIONS:

- **conky_cpu_core_temp(core)** — Temperature of one CPU core in °C
  (0-indexed: `core 0` = first core), via `Core<N>: +X°C`.

- **conky_cpu_temp()** — CPU package temperature in °C (`Package id 0`).

- **conky_fan_speed(index)** — Fan speed in RPM for the 1-based fan index
  (`fan1`, `fan2`, …).

- **conky_nvme_temp()** — NVMe drive temperature in °C from the `Composite`
  sensor.

- **conky_wifi_temp()** — WiFi adapter temperature when the driver exposes it
  (iwlwifi `temp1`), else 0.

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

Sensor-data source for temperature/fan widgets. Each function is a single
`get_sensor_val(pattern)` call backed by the 2 s `sensors` cache.

#### Input / Output

Input: `sensors` command output. Output: temperatures in °C and fan RPM
(numbers; 0 when unavailable).

#### Internal Logic

All patterns match a `sensors` line like `Label: +34.0°C` and capture the
leading number. The core/wifi patterns accept any digit run for the core
index / bus number, keeping them robust across machines.

#### Developer Notes

- Requires `lm-sensors` installed and configured (kernel modules + a working
  `sensors` binary); otherwise every call returns 0.
- Sensor names (`Package id 0`, `Core`, `Composite`, `iwlwifi_*-virtual-0`)
  are hardware/driver dependent — adjust patterns when a reading returns 0.

### === ./lua/hardware/usb.lua ===

USB mount detection via `lsblk`. Lists mounted removable USB devices with
their model and mount point, sorted by partition name, cached 3 s.

####   GLOBAL FUNCTIONS:

- **conky_has_usb()** — `1` when at least one removable USB device is mounted,
  else `0`.

- **conky_usb_count()** — Number of mounted removable USB devices.

- **conky_usb_list()** — Raw list of all mounted removable devices; each entry
  is `{name, part, mount}` (device model, partition name, mount point).
  Cached 3 s. Public despite being a "helper" — usable directly.

- **conky_usb_mount(i)** — Mount point of the i-th USB device (1-based);
  `""` out of range.

- **conky_usb_name(i)** — Human-readable model of the i-th USB device
  (1-based); `""` out of range.

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

USB-information source for mount-status widgets. Reads `lsblk` output and
filters to removable media mounts; depends on `get_root_device` from
`hardware/core.lua` to find each partition's parent device.

#### Input / Output

Input: `lsblk -P -o NAME,PKNAME,MODEL,MOUNTPOINT,TRAN` output and `$USER`.
Output: device list tables, counts, names, mount points.

#### Internal Logic

`lsblk` lines are parsed into a `map` keyed by device name; only entries whose
mount point starts with a user media prefix (`/run/media/<user>/`,
`/media/<user>/`, `/media/`) count. A device qualifies as USB when it or its
root ancestor has `TRAN="usb"`. Results are sorted by partition name.

#### Developer Notes

- Requires `util-linux` (lsblk) with `-P` support.
- Model names fall back to `"USB Device"` when `lsblk` reports none.
- Only mounts under the user media paths are detected — custom mount locations
  are ignored by design.

### === ./lua/mouse_actions.lua ===

Mouse-event action implementations referenced by `widget.lua` (the
`MOUSE_*_ACTION` globals). Provides view switching and the hover highlight
(white border) / restore behaviour.

####   GLOBAL FUNCTIONS:

- **on_hover_group(event)** — Hover highlight: when `event.group` is set,
  applies a white 3 px border override to that group's background via
  `modify_group_background`.

- **on_leave_group(event)** — Restores the group's background after hover via
  `restore_group_background`.

- **switch_view(v)** — Sets `current_view` to `v` (no-op when `nil`).

- **view_toggle(v)** — Toggles between `v` and the previously active view,
  remembering the last one in `_previous_view`.

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

Action glue between the mouse dispatcher and the render state. Functions here
are assigned to the `MOUSE_*` globals in `widget.lua`; they mutate
`current_view` and group backgrounds, which the render loop reads next frame.
See the [Mouse action globals](#mouse-action-globals) table in the
`mouse.lua` section for the full list of assignable globals.

#### Input / Output

Input: mouse events (group name) and view names. Output: side effects —
`current_view` changes and group background restyling.

#### Internal Logic

`view_toggle` swaps between two views: if already on `v` it returns to the
previous view, otherwise it stores the current view and switches to `v`.
Hover handlers wrap the snapshot/restore pair from `draw_core.lua`.

#### Developer Notes

- Assigned in `widget.lua`; these are only active when the designer wires them
  into `MOUSE_HOVER_IN_GROUP_ACTION` etc.
- `_previous_view` defaults to `"main"`, so the first toggle-back lands on the
  main view even if it was never explicitly set.

### === ./lua/nowplaying.lua ===

MPRIS "now playing" info via `playerctl`. Reads a JSON file written by the
Bash backend (`sh/fetch_nowplaying.sh`) and exposes the track's player, title,
artist, album, playback status, and album-art path to Conky widgets.

####   GLOBAL FUNCTIONS:

- **conky_nowplaying_album()** — Album name of the current track (`""` when
  none).

- **conky_nowplaying_art_path()** — Local path to the album art file, for an
  image widget (`""` when none).

- **conky_nowplaying_artist()** — Artist of the current track.

- **conky_nowplaying_player()** — Name of the active MPRIS player
  (e.g. `"spotify"`, `"chromium"`).

- **conky_nowplaying_status()** — Playback state (`"Playing"`, `"Paused"`,
  `"Stopped"`); defaults to `"Stopped"`.

- **conky_nowplaying_title()** — Title of the currently playing track.

####   LOCAL FUNCTIONS:

- **load()** — Re-reads `tmp/nowplaying.json` only when its mtime changed
  (`lfs.attributes`), decodes it with `dkjson`, and populates the module
  `cache` table. Empties the cache when the file is missing.

#### Pipeline Role

Media-info source for now-playing widgets. Pure file reader — all polling and
MPRIS queries happen in the background shell fetcher.

#### Input / Output

Input: `tmp/nowplaying.json` under `JSON_PATH` (default `/tmp/`). Output:
track metadata strings for text/image widgets.

#### Internal Logic

The file is re-read only on mtime change, so repeated per-frame widget calls
are cheap. JSON decoding is optional per field — missing keys yield `""` (or
`"Stopped"` for status).

#### Developer Notes

- Requires `playerctl` + the background fetcher to be running; without the
  file every accessor returns its empty default.
- Uses the global `json` (dkjson) set up in `require.lua`.

### === ./lua/require.lua ===

Central module loader. Requires all C bindings and the framework modules in
dependency order, and assigns the module namespaces (`hyphen`, `json`, `cairo`,
etc.) used across the codebase. Loaded once by the config before anything else.

####   GLOBAL FUNCTIONS:

    (no global function)

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

Bootstrap of the whole Lua engine. Defines load order so every module's
dependencies exist before it runs; the order in this file is authoritative.

#### Input / Output

Input: the `lua/` module tree plus system Lua libraries (cairo, rsvg, imlib2,
lfs, dkjson). Output: all framework globals available globally.

#### Internal Logic

Load order is grouped and commented: C libs → core → weather → hardware →
extras → draw. `draw.icon_theme` must precede the drawers that resolve icon
paths; `core.theme_engine` must load before `draw_core` reads `THEMES`.

#### Developer Notes

- Adding a module means adding a `require` here **and** updating the order
  comment; the load sequence is part of the contract.
- The C libraries are required first — any module that uses `cairo`, `lfs`,
  `json`, etc. assumes these globals exist.
- Debugging helpers live in `debug/` (`debug_weather.lua`,
  `debug_hardware.lua`) and are not loaded here.

### === ./lua/weather/air.lua ===

Air-quality accessors (current + hourly). Reads from `W.air` (populated by
`weather/core.lua`) and returns pollutant, gas, pollen, and AQI values as
safe numbers (0 for missing fields). Units are locale-dependent — pair each
value with the matching `conky_unit_air_*` accessor.

####   GLOBAL FUNCTIONS:

- **conky_air_current_alder()** — Current alder pollen level.
- **conky_air_current_birch()** — Current birch pollen level.
- **conky_air_current_co()** — Carbon monoxide level.
- **conky_air_current_dust()** — Dust / coarse fraction.
- **conky_air_current_eaqi()** — European AQI index (unitless).
- **conky_air_current_grass()** — Current grass pollen level.
- **conky_air_current_mugwort()** — Current mugwort pollen level.
- **conky_air_current_no2()** — Nitrogen dioxide level.
- **conky_air_current_o3()** — Ozone level.
- **conky_air_current_olive()** — Current olive pollen level.
- **conky_air_current_pm10()** — PM10 concentration.
- **conky_air_current_pm25()** — PM2.5 concentration.
- **conky_air_current_ragweed()** — Current ragweed pollen level.
- **conky_air_current_so2()** — Sulphur dioxide level.
- **conky_air_current_usaqi()** — US AQI index (unitless).
- **conky_air_hour_co(i)** — Hourly CO level for the i-th slot.
- **conky_air_hour_dust(i)** — Hourly dust level.
- **conky_air_hour_eaqi(i)** — Hourly European AQI.
- **conky_air_hour_no2(i)** — Hourly nitrogen dioxide.
- **conky_air_hour_o3(i)** — Hourly ozone.
- **conky_air_hour_pm10(i)** — Hourly PM10.
- **conky_air_hour_pm25(i)** — Hourly PM2.5.
- **conky_air_hour_so2(i)** — Hourly sulphur dioxide.
- **conky_air_hour_usaqi(i)** — Hourly US AQI.

(All accessors return a number via `safe_num`; 0 when the field is missing.
Current ones read `W.air.current`, hourly ones index `W.air.hourly.<field>[get_idx(i)]`.)

####   LOCAL FUNCTIONS:

- **air_hourly_data()** — Returns `W.air.hourly` (or `{}`).

- **cur_air_data()** — Returns `W.air.current` (or `{}`).

#### Pipeline Role

Air-quality data source for text/bar widgets. Thin, uniform accessors over
the shared `W.air` table; no I/O of its own.

#### Input / Output

Input: `W.air` (current + hourly groups) filled by `weather/core.lua`. Output:
numbers for pollutants, gases, pollen, and AQI indices.

#### Internal Logic

Every accessor is one `safe_num(field)` call. Hourly variants index arrays
through `get_idx(i)` so slot 1 aligns to the nearest forecast hour. The `*_2_5`
field key maps to `pm2_5` in the JSON.

#### Developer Notes

- Pollen fields only exist when the forecast provider returns them; expect 0
  otherwise.
- Hourly accessors index 1-based arrays returned by `get_idx`; out-of-range
  slots return 0 via `safe_num`.

### === ./lua/weather/alerts.lua ===

MeteoAlarm weather-alert parser. Parses the XML from `tmp/alerts.xml` with a
SAX parser (`lxp`), filters alerts by city/admin1 region, sorts by severity,
keeps the top 3, and caches the result (re-parsed when the file mtime changes,
checked at most every 2 min). Field accessors are localized via `conky_get_tr`.

####   GLOBAL FUNCTIONS:

- **conky_update_alerts()** — Forces a cache refresh by calling `load_cache`.
  Called automatically at startup.

####   LOCAL FUNCTIONS:

- **alert_field(i, field)** — One field of the i-th alert. Valid fields:
  `event`, `severity`, `certainty`, `area`, `onset`, `expires`, `title`,
  `color`. Severity/color/certainty values are translated through `conky_get_tr`;
  `""` when missing or out of range.

- **alerts_count()** — Number of active alerts for the region (0–3).

- **alerts_file_mtime(path)** — File mtime via `lfs`, 0 when missing.

- **alerts_updated()** — ISO timestamp of the last successful alert fetch.

- **flush()** — SAX callback helper: concatenates buffered character data,
  trims it, and stores it into the current entry (or the feed `updated` field).

- **load_alerts()** — Returns the cached alert list (via `load_cache`).

- **load_cache()** — Re-reads `alerts.xml` + `city.json` when stale (>120 s or
  mtime changed) and stores `{alerts, _mtime, updated}`.

- **parse_alerts_from_xml(xml, city_name, admin1)** — Parses the XML into
  alert entries, sorts by severity weight, filters by city/admin1 (falls back
  to all alerts when nothing matches), and returns the top 3 plus the feed
  updated timestamp.

- **sax_parse()** — Closure with the `lxp` callbacks: extracts `entry` elements
  (namespace-tolerant) and their child fields, computing each alert's `color`
  from title keywords.

#### Pipeline Role

Alert data source for warning widgets. Pure parser over the shell-fetched
`alerts.xml`; exposes count, timestamp, and per-field accessors.

#### Input / Output

Input: `tmp/alerts.xml` and `tmp/city.json` (for region filtering). Output:
alert tables, count, updated timestamp, translated field strings.

#### Internal Logic

Severity sorting uses `SEVERITY_WEIGHT` (Minor→Extreme). Color is inferred
from title keywords (red/orange/severe/violent), defaulting to yellow. The
cache is refreshed when older than 120 s or when the XML mtime changes.

#### Developer Notes

- Requires `luaexpat` (`lxp`), required at the top of the module.
- Region filtering compares lowercased substrings of `areaDesc` against the
  city name and admin1 from `city.json`; if neither matches, all alerts are
  shown (bounded to 3).

### === ./lua/weather/core.lua ===

Weather data loader and shared helpers. Reads the forecast JSON files from
`tmp/` (fetched by the shell backend) into the global `W` table, and provides
the text/icon/arc helpers used across all weather modules: WMO codes, wind
directions, moon phase, day names, sun/moon arcs, units, and hour indexing.

####   GLOBAL FUNCTIONS:

- **conky_day_name(o)** — Full weekday name (`"%A"`) for today + `o` days.

- **conky_day_name_short(o)** — Short 3-letter weekday name, memoized per day.

- **conky_icon_current_weather()** — Icon path for the current weather
  (`ICON_BASE/<theme>/<code>d/n.png`, day/night suffix).

- **conky_icon_current_wind()** — Wind-arrow icon path built from speed color
  + direction code (e.g. `green_ne.png`), `no_wind.png` when calm.

- **conky_icon_day_weather(i)** — Icon path for the i-th daily slot (always
  the day variant).

- **conky_icon_hour_weather(i)** — Icon path for the i-th hourly slot.

- **conky_icon_hour_wind(i)** — Wind-arrow icon for the i-th hourly slot.

- **conky_icon_moon()** — Moon-phase icon (`MOON_ICON_BASE/<idx>n/s.png`,
  hemisphere from latitude).

- **conky_load_weather_data()** — Loads the five JSON files (`weather_data`,
  `airquality`, `sun`, `moon`, `city`) into `W`, re-checking file mtimes at
  most every 30 s. Called automatically at startup; safe to call again.

- **conky_moon_arc_x(cx, r)** — X of the moon on an arc (0 when not visible).

- **conky_moon_arc_y(cy, r)** — Y of the moon on its arc.

- **conky_moon_phase_text()** — Textual moon-phase name (translated).

- **conky_moon_progress()** — Moon progress 0–1 along its arc; `-1` when not
  up. Handles overnight (rise > set) spans.

- **conky_read_j(path)** — Decodes a JSON file into a table (`{}` on error).

- **conky_round(v)** — Rounds to an integer, tolerating nil/NaN (→ 0).

- **conky_sun_arc_x(cx, r)** — X of the sun on its arc.

- **conky_sun_arc_y(cy, r)** — Y of the sun on its arc.

- **conky_sun_progress()** — Sun progress 0–1 (0 = rise, 1 = set); 0.5 on
  missing data.

- **conky_units()** — The full units table `{cur, hour, day, air_cur,
  air_hour}` for the active locale.

- **conky_units_air_cur()** — Units for the current air block.

- **conky_units_air_hour()** — Units for the hourly air block.

- **conky_units_cur()** — Units for the current weather block.

- **conky_units_day()** — Units for the daily block.

- **conky_units_hour()** — Units for the hourly block.

- **conky_weather_code_text(code)** — Human-readable WMO code label,
  translated via `conky_get_tr` (`"WMO <code>"` for unknown codes).

- **conky_wind_direction_text(deg)** — Cardinal direction name (e.g.
  `"Northwest"`), translated.

- **fmt_unix(ts)** — Formats a unix timestamp as `"HH:MM"` (`""` for 0/nil).
  Shared with sunmoon/daily.

- **get_idx(i)** — Maps the 1-based hourly slot `i` to the real array index,
  aligning slot 1 to the nearest forecast hour (recomputed max every 60 s).

####   LOCAL FUNCTIONS:

- **arc_x(cx, r, p)** — X position helper for a progress `p` along a
  half-circle arc; 0 when `p < 0`.

- **arc_y(cy, r, p)** — Y position helper for a progress `p`.

- **file_mtime(path)** — Returns a file's modification time (0 when missing).

- **get_wind_dir_code(deg)** — Maps a bearing to a 16-point compass code.

- **iso_to_mins(t)** — Converts an ISO `"T...HH:MM"` time to minutes.

- **json_changed()** — Returns `true` when any of the five JSON files changed
  since the last check (per-file mtime tracking).

- **moon_phase_fraction()** — Synodic-month fraction from a fixed epoch.

- **weather_icon(code, is_day)** — Builds an icon path from code + day/night.

- **wind_color(s)** — Color bucket for wind speed (`green`/`yellow`/`orange`/
  `red`).

#### Pipeline Role

Weather namespace core. Owns data loading and the shared helpers every other
weather module depends on (`W`, `get_idx`, `fmt_unix`, `conky_units*`). The
global `cur_map`/`hour_map` field maps also live here for the field accessors.

#### Input / Output

Input: `tmp/weather_data.json`, `tmp/airquality.json`, `tmp/sun.json`,
`tmp/moon.json`, `tmp/city.json` (written by `sh/4_fetch_weather.sh` etc.),
plus icon theme globals (`ICON_BASE`, `MOON_ICON_BASE`, `WIND_ICON_BASE`).
Output: the `W` table, text labels, icon paths, arc coordinates, units.

#### Internal Logic

`conky_load_weather_data` mtime-checks the JSON files at most every 30 s and
only re-decodes on change; results are cached in `weather_cache_storage`.
Sun/moon progress converts ISO times to minutes and normalizes against the
rise–set span (moon handles overnight spans with a +1440 correction). WMO and
direction lookups go through `conky_get_tr` for localization.

#### Developer Notes

- `cur_map`/`hour_map` map friendly keys to Open-Meteo field names; used by
  `current.lua`/`hourly.lua`.
- `conky_load_weather_data()` runs at the bottom of the module when
  `JSON_PATH` is set, so `W` is populated before widgets query it.
- `conky_icon_moon` needs a latitude — falls back to `W.city.latitude`, then a
  hardcoded 47.

### === ./lua/weather/current.lua ===

Current-weather field accessors. Reads the `current` block of `W.weather`
(loaded by `weather/core.lua`) and returns single fields as numbers. Units are
locale-dependent — pair each value with the matching `conky_unit_cur_*`
accessor. Missing fields → 0.

####   GLOBAL FUNCTIONS:

- **conky_weather_current_apparent()** — Feels-like temperature (rounded).
- **conky_weather_current_clouds()** — Cloud cover % (rounded).
- **conky_weather_current_code()** — WMO weather code (map via
  `conky_weather_code_text`).
- **conky_weather_current_dewpoint()** — Dew-point temperature (rounded).
- **conky_weather_current_humidity()** — Relative humidity (rounded).
- **conky_weather_current_interval()** — Forecast interval seconds.
- **conky_weather_current_is_day()** — `1` daytime, `0` night.
- **conky_weather_current_precip()** — Precipitation in the current period.
- **conky_weather_current_precip_prob()** — Always 0 (probability only exists
  in hourly/daily data).
- **conky_weather_current_pressure_msl()** — Sea-level pressure (rounded).
- **conky_weather_current_radiation()** — Shortwave radiation (rounded).
- **conky_weather_current_snow()** — Snowfall in the current period.
- **conky_weather_current_surface_pressure()** — Surface pressure (rounded).
- **conky_weather_current_temp()** — 2 m air temperature (rounded).
- **conky_weather_current_time()** — Forecast time (unix).
- **conky_weather_current_uv()** — UV index (rounded).
- **conky_weather_current_visibility()** — Visibility (rounded).
- **conky_weather_current_wind_dir()** — Wind bearing in degrees.
- **conky_weather_current_wind_gust()** — Wind gust speed (rounded).
- **conky_weather_current_wind_speed()** — Wind speed (rounded).

####   LOCAL FUNCTIONS:

- **cur_data()** — Returns `W.weather.current` (or `{}`).

#### Pipeline Role

Current-conditions data source for weather widgets. Thin, uniform accessors
over the shared `W.weather.current` table.

#### Input / Output

Input: `W.weather.current` (Open-Meteo `current` block). Output: numbers;
rounded where fractional (via `conky_round`), raw elsewhere.

#### Internal Logic

Every accessor reads one field through `safe_num`; temperature/humidity/etc.
are passed through `conky_round` for display. Field names map directly to the
JSON (`temperature_2m`, `relative_humidity_2m`, …).

#### Developer Notes

- `conky_weather_current_precip_prob` intentionally returns 0 — the current
  block has no probability field.
- Values are only meaningful after `conky_load_weather_data()` has run (the
  module is populated at startup by `weather/core.lua`).

### === ./lua/weather/daily.lua ===

Daily-forecast field accessors. Reads the `daily` block of `W.weather`.
Index 1 = today (up to 7 days). Temperatures/dures are locale-dependent —
pair each value with the matching `conky_unit_day_*` accessor.

####   GLOBAL FUNCTIONS:

- **conky_weather_day_code(i)** — Dominant WMO weather code for day i.
- **conky_weather_day_daylight(i)** — Daylight length in seconds.
- **conky_weather_day_precip_hours(i)** — Estimated precipitation hours.
- **conky_weather_day_sunrise(i)** — Sunrise as `"HH:MM"` (via `fmt_unix`).
- **conky_weather_day_sunset(i)** — Sunset as `"HH:MM"`.
- **conky_weather_day_sunshine(i)** — Expected sunshine duration (seconds).
- **conky_weather_day_temp_max(i)** — Daytime maximum temperature (rounded).
- **conky_weather_day_temp_min(i)** — Night-time minimum temperature (rounded).
- **conky_weather_day_time(i)** — ISO date string of day i.
- **conky_weather_day_uv(i)** — Maximum UV index of the day (rounded).

####   LOCAL FUNCTIONS:

- **daily_data()** — Returns `W.weather.daily` (or `{}`).

#### Pipeline Role

Daily-forecast data source for weather widgets. Thin, uniform array accessors
over `W.weather.daily`.

#### Input / Output

Input: `W.weather.daily` arrays (Open-Meteo `daily` block). Output: numbers,
and `"HH:MM"`/ISO strings.

#### Internal Logic

Each accessor indexes its array at `i` (no `get_idx` — the daily block starts
at today). `safe_num` handles missing entries; `conky_round` rounds
temperature/UV; sunrise/sunset go through `fmt_unix`.

#### Developer Notes

- Index `i` is 1-based and expected within the fetched range; out-of-range
  returns 0/`""` via `safe_num`/`fmt_unix`.

### === ./lua/weather/hourly.lua ===

Hourly-forecast field accessors. Reads the `hourly` block of `W.weather`,
indexing with `get_idx(i)` so slot 1 aligns to the nearest forecast hour
(1–24). Units are locale-dependent — pair each value with the matching
`conky_unit_hour_*` accessor.

####   GLOBAL FUNCTIONS:

- **conky_weather_hour_apparent(i)** — Feels-like temperature (rounded).
- **conky_weather_hour_clouds(i)** — Cloud cover % (rounded).
- **conky_weather_hour_code(i)** — WMO weather code for the hour.
- **conky_weather_hour_dewpoint(i)** — Dew-point temperature (rounded).
- **conky_weather_hour_humidity(i)** — Relative humidity (rounded).
- **conky_weather_hour_is_day(i)** — `1` day / `0` night for the hour.
- **conky_weather_hour_precip(i)** — Expected precipitation amount.
- **conky_weather_hour_precip_prob(i)** — Precipitation probability
  (unitless, rounded).
- **conky_weather_hour_pressure_msl(i)** — Sea-level pressure (rounded).
- **conky_weather_hour_radiation(i)** — Shortwave radiation (rounded).
- **conky_weather_hour_snow(i)** — Expected snowfall amount.
- **conky_weather_hour_surface_pressure(i)** — Surface pressure (rounded).
- **conky_weather_hour_temp(i)** — 2 m air temperature (rounded).
- **conky_weather_hour_time(i)** — Timestamp of the hour slot.
- **conky_weather_hour_uv(i)** — UV index (rounded).
- **conky_weather_hour_visibility(i)** — Visibility (rounded).
- **conky_weather_hour_wind_dir(i)** — Wind bearing in degrees.
- **conky_weather_hour_wind_gust(i)** — Wind gust speed (rounded).
- **conky_weather_hour_wind_speed(i)** — Wind speed (rounded).

####   LOCAL FUNCTIONS:

- **hourly_data()** — Returns `W.weather.hourly` (or `{}`).

#### Pipeline Role

Hourly-forecast data source for weather widgets. Thin array accessors over
`W.weather.hourly`; all slot alignment is delegated to `get_idx`.

#### Input / Output

Input: `W.weather.hourly` arrays (Open-Meteo `hourly` block). Output:
numbers per hour slot.

#### Internal Logic

Every accessor guards the array (`field and field[get_idx(i)]`) before
`safe_num`, so missing variables degrade to 0. Display fields pass through
`conky_round`; `is_day`/`code`/`precip`/`snow`/`wind_dir`/`time` stay raw.

#### Developer Notes

- Indexing relies on `get_idx` (weather/core.lua) recomputing the starting
  offset at most once per 60 s, so slot `i` stays aligned across frames.
- The hourly arrays can be longer than 24 slots; the accessors expose the
  first 24 by convention.

### === ./lua/weather/spaceweather.lua ===

NOAA SWPC space-weather data. Loads seven JSON files (`spaceweather_*.json`),
reduces them into a compact `SW` table, and exposes Kp index, solar wind, Bz,
X-ray flux/class, sunspots, G-scale, aurora visibility, alerts, and a
one-line summary. Optional module — skip the `require` when unused.

####   GLOBAL FUNCTIONS:

- **conky_aurora_visibility_pct(kp, lat)** — Estimates aurora visibility
  (0–100) from Kp and latitude using the aurora-oval approximation; raises a
  floor for strong storms at mid latitudes.

- **conky_kp_to_g_scale(kp)** — Maps Kp to the NOAA G scale (`"G0"`–`"G5"`).

- **conky_load_spaceweather()** — Reads the seven JSON files (trimming
  over-long x-ray/sunspot series), computes `kp_latest`, wind speed, Bz,
  X-ray flux/class, G-scale, sunspot count, and alerts; caches the `SW` table
  (refreshed after 300 s or on mtime change, mtime checked ≤ every 5 s).
  Called at startup when `JSON_PATH` is set.

- **conky_sw_alert_message(i)** — Message text of the i-th active alert
  (1-based), `""` when none.

- **conky_sw_alert_severity(i)** — Severity of the i-th alert (`warning`,
  `watch`, `alert`, `summary`, `info`).

- **conky_sw_alerts_count()** — Number of active SWPC alerts.

- **conky_sw_aurora_pct()** — Aurora visibility % at the user latitude
  (uses `conky_city_lat`).

- **conky_sw_bz()** — IMF Bz component in nT (southward = active).

- **conky_sw_g_scale()** — NOAA G scale for the current Kp (`"G0"`–`"G5"`).

- **conky_sw_kp()** — Current planetary Kp index (0–9).

- **conky_sw_kp_status()** — Status label of the latest Kp observation.

- **conky_sw_summary()** — One-line summary, e.g.
  `"Kp 4.2 G1 450 km/s Bz -5.2 nT M2.3"`.

- **conky_sw_sunspot()** — Current sunspot count.

- **conky_sw_wind_speed()** — Solar wind speed in km/s.

- **conky_sw_xray_class()** — X-ray flux letter class (`A`–`X`), `"--"` when
  invalid.

- **conky_sw_xray_flux()** — Current X-ray flux in W/m².

- **conky_sw_xray_full()** — Full class + magnitude (e.g. `"M2.3"`).

- **conky_xray_full_class(flux)** — Letter + magnitude string for a flux
  value (e.g. `"M2.3"`).

- **conky_xray_short_class(flux)** — Letter class only (`A`–`X`) for a flux.

####   LOCAL FUNCTIONS:

- **sw_alert_severity(msg)** — Derives an alert severity from the message's
  `Message Code:` (WAR/WAT/ALT/SUM → warning/watch/alert/summary, else info).

- **sw_file_mtime(path)** — File mtime via `lfs`, 0 when missing.

- **sw_json_changed()** — Returns `true` when any `sw_files` mtime changed
  since the last check (guarded to run at most every 5 s).

#### Pipeline Role

Space-weather data source for compact widget panels. Loads, trims, and
normalizes the NOAA JSON before exposing the reduced values; caching prevents
re-parsing every frame.

#### Input / Output

Input: `tmp/spaceweather_kp.json`, `_wind`, `_mag`, `_xray`, `_scales`,
`_sunspot`, `_alerts`. Output: the `SW` table and the `conky_sw_*` accessors.

#### Internal Logic

Latest values are the last element of each series (x-ray flux prefers the
0.1–0.8 nm channel, falling back to the last entry; x-ray/sunspot series are
trimmed to the last 100/10). `scales_forecast` is sorted by `DateStamp`.
G-scale prefers the NOAA-provided value, falling back to `kp_to_g_scale`.

#### Developer Notes

- All accessors call `conky_load_spaceweather()` first, so a single call
  populates the cache for the rest of the frame.
- `conky_sw_aurora_pct` depends on `conky_city_lat` (weather/units.lua);
  missing latitude → 47.5.
- Optional: removing the `require("weather.spaceweather")` line disables this
  module entirely.

### === ./lua/weather/sunmoon.lua ===

Sun & moon rise/set accessors. Reads `W.sun` and `W.moon` (loaded by
`weather/core.lua`) and returns times, azimuths, elevations, and the moon
phase percentage.

####   GLOBAL FUNCTIONS:

- **conky_moon_high_elevation()** — Elevation of the moon at its highest
  point (degrees).
- **conky_moon_high_time()** — Time of the moon's highest point (`"HH:MM"`).
- **conky_moon_low_elevation()** — Elevation at the moon's lowest point.
- **conky_moon_low_time()** — Time of the moon's lowest point.
- **conky_moon_phase()** — Moon phase as a percentage (0 = new, 50 = full,
  100 = new again).
- **conky_moon_rise_azimuth()** — Azimuth of the moonrise point (degrees).
- **conky_moon_rise_time()** — Today's moonrise as `"HH:MM"`.
- **conky_moon_set_azimuth()** — Azimuth of the moonset point.
- **conky_moon_set_time()** — Moonset as `"HH:MM"`.
- **conky_sun_midnight_elevation()** — Sun elevation at solar midnight.
- **conky_sun_midnight_time()** — Solar midnight time (`"HH:MM"`).
- **conky_sun_noon_elevation()** — Sun elevation at solar noon.
- **conky_sun_noon_time()** — Solar noon time.
- **conky_sun_rise_azimuth()** — Azimuth of the sunrise point.
- **conky_sun_rise_time()** — Sunrise as `"HH:MM"`.
- **conky_sun_set_azimuth()** — Azimuth of the sunset point.
- **conky_sun_set_time()** — Sunset as `"HH:MM"`.

####   LOCAL FUNCTIONS:

- **fmt_time(t)** — Converts an ISO timestamp (`"...T07:32"`) to `"HH:MM"`;
  returns the input when it has no `T` time part, `""` for empty.

- **moon_data()** — Returns `W.moon.properties` (or `{}`).

- **sun_data()** — Returns `W.sun.properties` (or `{}`).

#### Pipeline Role

Sun/moon timetable source for weather widgets. Thin accessors over `W.sun`/
`W.moon`; no I/O of its own.

#### Input / Output

Input: `W.sun` / `W.moon` (from `tmp/sun.json`, `tmp/moon.json`). Output:
`"HH:MM"` time strings, degree numbers, and the moon-phase percentage.

#### Internal Logic

Times pass through `fmt_time` (extracts `HH:MM` from the ISO string);
azimuths/elevations via `safe_num`. Moon phase normalizes the provider's
phase angle to 0–100 (mod 360).

#### Developer Notes

- `fmt_unix` is imported conceptually from `weather/core.lua` for daily data;
  this module uses its own string-based `fmt_time` instead (the JSON stores
  ISO strings, not unix timestamps).
- Values degrade to `""`/0 through `safe_str`/`safe_num` when fields are
  missing.

### === ./lua/weather/units.lua ===

Unit-label and city-field accessors. Dynamically generates `conky_unit_*`
getters for the current/hourly/daily/air blocks from the field maps defined in
`weather/core.lua`, plus `conky_city_*` accessors from the geocoding result.

####   GLOBAL FUNCTIONS:

- **conky_city_name()** — Name of the forecast city (`"Unknown City"` when
  missing).

- **conky_city_postcode(i)** — Postal code of the city from the geocoding
  result (1-based), `""` when none.

- **conky_city_postcode_count()** — Number of postcodes (0 when none).

- **conky_unit_day_code()** — Unit for the daily WMO code (falls back to
  `conky_unit_cur_code`).

- **conky_unit_day_daylight()** — Unit for daylight duration (`"s"` default).

- **conky_unit_day_precip_hours()** — Unit for precipitation hours (`"h"`).

- **conky_unit_day_sunrise()** — Sunrise unit (`"unixtime"` default).

- **conky_unit_day_sunset()** — Sunset unit (`"unixtime"` default).

- **conky_unit_day_sunshine()** — Unit for sunshine duration (`"s"`).

- **conky_unit_day_temp_max()** — Unit for daily max temperature (falls back
  to the current unit).

- **conky_unit_day_temp_min()** — Unit for daily min temperature.

- **conky_unit_day_time()** — Unit for the daily date (falls back to
  `conky_unit_cur_time`).

- **conky_unit_day_uv()** — Unit for daily UV (`""` — unitless).

- **conky_city_lat / _lon / _elevation / _population / _id / _country_id /
  _admin1_id / _admin2_id** — Numeric city fields (auto-generated from
  `city_num_map`, via `safe_num`).

- **conky_city_timezone / _country / _country_code / _admin1 / _admin2** —
  String city fields (auto-generated from `city_str_map`, via `safe_str`).

- **conky_unit_cur_\* / conky_unit_hour_\* / conky_unit_air_cur_\* /
  conky_unit_air_hour_\*** — Auto-generated unit-label getters for every
  non-unitless field in `cur_map`/`hour_map`/`air_cur_map`/`air_hour_map`
  (e.g. `conky_unit_cur_temp`, `conky_unit_hour_wind_speed`,
  `conky_unit_air_cur_pm10`).

####   LOCAL FUNCTIONS:

- **city_data()** — Returns the first geocoding result (`W.city.results[1]`,
  or `{}`).

- **make_getter(units_fn, field)** — Builds a closure returning
  `safe_str(units_fn()[field], "unit_<field>")`.

#### Pipeline Role

Unit/geocoding data source for weather widgets. Bridges the field maps
(`cur_map`, `hour_map`) to generated `conky_unit_*` globals so widgets can
append the correct unit string without hardcoding.

#### Input / Output

Input: `conky_units*()` tables (from `W.weather.*_units`) and `W.city.results`.
Output: unit strings and city attribute accessors.

#### Internal Logic

`unitless_keys` excludes fields with no unit (is_day, uv, prob, time,
interval). The loops generate globals via `_G[...] = function() ... end`;
daily unit getters hand-write fallbacks. City accessors are generated from
`city_num_map`/`city_str_map` with `safe_num`/`safe_str`.

#### Developer Notes

- The generated names follow the pattern `conky_unit_<block>_<friendly key>`
  (e.g. `cur_temp`), where the key comes from the map — keep the maps in
  `weather/core.lua` and these accessors stay in sync automatically.
- Generation happens at load time; the maps must be defined before this module
  runs (load order in `require.lua` guarantees it).

### === ./sh/designer/live_clear.lua ===

Designer live-preview helper (X11 only). Not part of the framework load —
the designer appends it to the **preview** conky's `lua_load` line (see
`_preview_conf` in `sh/designer/main.py`) while it manages a widget on X11,
and the deployed `.conf` never references it.

It overrides the no-op `clear_surface(cr)` hook from `draw_core.lua` with a
real clear: on X11 an ARGB conky window keeps the previous frame, so moved or
shrunk items would leave permanent ghosts (semi-transparent panels can never
cover the pixels beneath them). Wayland's compositor already clears the
buffer, so the preview never loads this file there.

####   GLOBAL FUNCTIONS:

- **clear_surface(cr)** — Clears the whole surface by setting
  `CAIRO_OPERATOR_CLEAR` (operator `0`) and painting, then restores the
  operator. Runs on the **same** cairo context that `conky_core_main()` draws
  with, right after it is created.

####   LOCAL FUNCTIONS:

    (no local function)

#### Pipeline Role

First frame hook after the surface is wiped. `conky_core_main()` calls
`clear_surface(cr)` immediately after `cairo_create`; with the no-op default
nothing happens, with this override the frame starts on a transparent canvas,
so vacated regions are clean instead of showing ghost pixels.

#### Input / Output

Input: the live cairo context of the current draw cycle. Output: side effect
on the surface (opaque pixels erased). Returns nothing.

#### Internal Logic

`cairo_save(cr)` → `cairo_set_operator(cr, 0)` (= `CAIRO_OPERATOR_CLEAR`) →
`cairo_paint(cr)` → `cairo_restore(cr)`. Reusing the existing `cr` keeps the
override in sync with the widget's own drawing.

#### Developer Notes

- **Must load AFTER the widget lua file** in `lua_load` so its override of
  `clear_surface` survives the widget's own (no-op) definition.
- **Must NOT call `require("cairo")` nor create its own cairo context** from a
  second `lua_load` file — both break conky's Lua drawing entirely
  (fully transparent window). The override only touches the `cr` that
  `draw_core.lua` already created.
- The override survives widget live-reloads: conky re-executes only the
  changed lua file, so `clear_surface` stays overridden.


## Glossary

| Term | Meaning |
|----|----|
| **Widget** | One drawable item (bar, ring, text…) in the `draw` list. |
| **Group** | Named bundle of widgets treated as a unit. |
| **View** | Named selection of widgets shown together. |
| **Theme** | Palette + gradients + defaults filling colors automatically. |
| **Gradient stops** | A list of { pos, hex, alpha } color steps. |
| **draw_me** | Visibility condition for a widget. |
| **WMO code** | Weather condition code mapped to text/icon. |
