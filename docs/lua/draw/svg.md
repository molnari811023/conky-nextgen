# draw/svg.lua — SVG rendering via librsvg + XDG icon theme resolver

Renders SVG vector graphics onto Cairo surfaces using Conky's built-in RSVG bindings.
Includes automatic icon lookup from XDG icon themes (Papirus, Adwaita, etc.).

## Dependencies

- Conky compiled with `BUILD_LUA_RSVG=ON` (enabled in PKGBUILD)
- `librsvg2` (runtime)

## Modules

| Module | File | Description |
|--------|------|-------------|
| SVG renderer | `lua/draw/svg.lua` | Cairo rendering, handle cache, clip/tint/rotate |
| Icon resolver | `lua/draw/icon_theme.lua` | XDG `index.theme` parser, closest-size finder |

## Global Config

```lua
-- main.lua
XDG_ICON_THEME = "Papirus"   -- XDG icon theme name (weather icons use ICON_THEME, NOT this)
```

## API — draw_svg(cr, opts)

Renders an SVG file at the given position and size.

### Direct path

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `path` | string | **required** | SVG file path (absolute) |
| `x` | number | `0` | X position |
| `y` | number | `0` | Y position |
| `w` | number | `32` | Width (auto aspect ratio if only w set) |
| `h` | number | `32` | Height (auto aspect ratio if only h set) |
| `rotate` | number | `0` | Rotation in degrees (around center) |
| `shape` | string | `nil` | Clip shape: `nil`/`"circle"` |
| `radius` | number | `0` | Corner radius clip |
| `alpha` | number | `1` | Opacity 0-1 (uses temp surface) |
| `tint` | string | `nil` | Hex tint color `#rrggbb` (uses temp surface) |
| `tint_alpha` | number | `1` | Tint opacity 0-1 |

### XDG icon auto-lookup

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `icon` | string | `nil` | Icon name (e.g. `"folder-download"`, `"firefox"`) |
| `icon_size` | number | `opts.w` or `48` | Target size in pixels |
| `icon_theme` | string | `XDG_ICON_THEME` | Override theme name |

When `opts.icon` is set, `draw_svg` calls `icon_resolve()` to find the closest-size SVG
from the XDG icon theme. `path` is resolved automatically — do not set both `path` and `icon`.

If only `w` or only `h` is given, the other dimension is calculated from the SVG's intrinsic aspect ratio.

## API — Icon resolver

### `icon_resolve(name, target_size, theme_name)`

Finds the closest-size SVG for an icon name from the XDG icon theme.

**Search order:**
1. `~/.local/share/icons/{theme}/{size}x{size}/{context}/{name}.svg`
2. `~/.icons/{theme}/{size}x{size}/{context}/{name}.svg`
3. `/usr/local/share/icons/{theme}/{size}x{size}/{context}/{name}.svg`
4. `/usr/share/icons/{theme}/{size}x{size}/{context}/{name}.svg`
5. Falls back to `scalable/` subdirectory
6. Falls back to inherited themes (from `Inherits=` in `index.theme`)

**Contexts searched (priority order):**
`apps`, `places`, `devices`, `status`, `actions`, `categories`, `emblems`, `mimetypes`, `panel`, `emotes`

Returns the full file path, or `nil` if not found. Results are cached in `ICON_PATH_CACHE`.

### `parse_index_theme(theme_name)`

Parses an XDG `index.theme` file. Returns `{ sizes = {}, inherits = {}, path = "..." }`.
Cached in `ICON_THEME_CACHE`.

### `find_best_size(sizes, target)`

From a list of available sizes, returns the closest match to `target`.

## Cache

| Cache | Location | Contents |
|-------|----------|----------|
| `SVG_CACHE` | `svg.lua` | `path → RsvgHandle` (must be freed!) |
| `ICON_THEME_CACHE` | `icon_theme.lua` | `theme_name → { sizes, inherits, path }` |
| `ICON_PATH_CACHE` | `icon_theme.lua` | `"theme:name:size" → full_path` |

## Cleanup

```lua
svg_free(path)      -- free one handle
svg_free_all()      -- free all handles
```

**Important:** RSVG handles must be freed to avoid memory leaks. Call `svg_free_all()`
when the widget config is reloaded, or `svg_free(path)` when a specific icon is no longer used.

## Examples

Basic render:
```lua
draw_svg(cr, {
    path = "/usr/share/icons/Papirus/48x48/status/weather-showers.svg",
    x = 50, y = 50, w = 64, h = 64,
})
```

XDG icon auto-lookup:
```lua
draw_svg(cr, {
    icon = "folder-download",
    x = 50, y = 50, w = 48,
    icon_theme = "Papirus",   -- optional, defaults to XDG_ICON_THEME
})
```

Rotated + tinted:
```lua
draw_svg(cr, {
    path = "/usr/share/icons/Papirus/48x48/status/weather-showers.svg",
    x = 100, y = 100, w = 48,
    rotate = 15,
    tint = "#FF8000", tint_alpha = 0.8,
})
```

Circle clip + alpha:
```lua
draw_svg(cr, {
    icon = "avatar-default",
    x = 50, y = 50, w = 48,
    shape = "circle", alpha = 0.5,
})
```

Widget definition (in `raw_elements`):
```lua
{ type = "image",
  icon = "folder-downloads", icon_size = 48,
  x = 20, y = 60, w = 48, h = 48,
  layout_box = "g1", group = "g1" },
```

## Notes

- `rotate` and `shape`/`radius` work directly on the Cairo context (no performance cost).
- `alpha` and `tint` require a temporary Cairo surface (slight overhead).
- Handle cache ensures SVG is loaded only once per path.
- Icon resolver caches both theme metadata and resolved paths — subsequent lookups are O(1).
- `ICON_THEME` (weather icon set) and `XDG_ICON_THEME` (XDG theme) are separate globals — never merge them.
