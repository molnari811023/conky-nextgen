# 24 — draw_core.lua

## Purpose
Cairo initialization, color helpers, the main draw loop `conky_core_main()`, and the mouse event handler `conky_on_mouse()`.

## Dependencies
- Requires `cairo` and optionally `cairo_xlib`
- All draw modules must be loaded before this
- **Requires Conky built with `BUILD_MOUSE_EVENTS=ON`** (custom `conky-mng` PKGBUILD at `pkg/PKGBUILD`) — see [docs/pkg/conky-mng.md](../pkg/conky-mng.md)

## Cairo Surface API
The main loop uses `conky_surface()` (modern Conky API) if available; otherwise falls back to `cairo_xlib_surface_create()`. This avoids the deprecation warning on Conky ≥1.24 while maintaining compatibility with older builds. The surface is only destroyed via `cairo_surface_destroy()` when the fallback path is used — `conky_surface()` manages its own lifetime.

## Main Loop
`conky_core_main()` is registered as `lua_draw_hook_pre` in `conky.conf`. It:
1. Checks file changes (watcher)
2. Loads weather/spaceweather data
3. Computes layout (if `layout[]` table exists)
4. Loops through `draw[]` items and dispatches to the correct draw function
5. **Each draw function returns `{x, y, w, h}` bounds** — if the item has `click`, `click_view`, or `click_toggle`, these bounds are registered in `click_registry` for hit testing

## Function-Based Fields
Any draw item can use functions instead of static values for: `x`, `y`, `w`, `h`, `width`, `height`, `radius`, `text`, `color`, `path`. These are resolved every draw cycle, then restored — so they can reference dynamic globals like `y_end_dynamic`.

```lua
y = function() return (y_end_dynamic or 150) + 10 end,
color = function()
  return current_view == "main" and ACTIVE_COLOR or INACTIVE_COLOR
end,
```

## Draw Item Fields
Every draw item can have these optional fields for interactivity:

| Field | Type | Description |
|-------|------|-------------|
| `view` | string | View filter — only drawn when `current_view == view` |
| `group` | string | Group toggle — only drawn when `GROUP_STATE[group] == true` |
| `click` | string | Shell command executed on click (`os.execute`) |
| `click_view` | string | Switch to this view name on click |
| `click_toggle` | string | Toggle this group name on click |

## View Switching
`current_view` (global) controls which view is active:
- Items with `view = "main"` are only visible when `current_view == "main"`
- Items with `view = "player"` are only visible when `current_view == "player"`
- Items **without** a `view` field are always visible

Set via `click_view` in any draw item, or directly: `current_view = "main"`

## Group Toggle
`GROUP_STATE` (global table) controls collapsible sections:
- Items with `group = "details"` are only visible when `GROUP_STATE["details"] == true`
- Items with `group = "!details"` (negation) are visible when `GROUP_STATE["details"] == false`

Toggle via `click_toggle` in any draw item, or call `toggle_group("details")`.

## `draw_allowed()`
```lua
function draw_allowed(draw_me, view, group)
```
Returns `true`/`false`. Called by every draw function:
1. If `view` is set and doesn't match `current_view` → false
2. If `group` is set and `GROUP_STATE[group]` doesn't match → false
3. If `draw_me` is a condition (function/conky var/bool) → evaluate it

## Mouse Events
`conky_on_mouse()` is registered as `lua_mouse_hook` in `conky.conf`. Supports:
- `mouse_move` — updates `hover_idx` (0 = no hover, >0 = index in click_registry)
- `button_down` — iterates `click_registry` in reverse Z-order (last drawn = topmost), executes the first matching action

```lua
conky.config = {
  own_window_type = "override",
  own_window_hints = "undecorated,below,sticky,skip_taskbar,skip_pager",
  lua_mouse_hook = "conky_on_mouse",
}
```

**Important**: Clicks only work reliably with `own_window_type = "override"`. See [docs/button_compatibility.md](../button_compatibility.md) for DE-specific notes.

## `conky_mouse_status()`
Returns a status string (view + hover index) for debugging:
```lua
conky.text = [[${lua conky_mouse_status}]]
```

## `toggle_group(name)`
Toggles `GROUP_STATE[name]` between `true`/`false`.

## `draw[]` Dispatch Table
| type | Function |
|------|----------|
| `background` | `draw_background` |
| `line` | `draw_line_modules` |
| `text` | `draw_text` |
| `bar` | `draw_bar_modules` |
| `ring` | `draw_one_ring` |
| `image` | `draw_png` |
| `graph` | `draw_graph` |
| `calendar` | `draw_calendar` |
| `clock` | `draw_clock` |

## Helper Functions
| Function | Description |
|----------|-------------|
| `normalize_number(v)` | Convert any value to a number |
| `normalize_with_suffix(raw)` | Parse numbers with K/M/G suffixes |
| `hex_to_rgba(hex, alpha)` | Convert hex color to r,g,b,a floats |
| `hex_to_rgb_components(col)` | Convert hex to separate r,g,b floats |
| `get_color_from_list(stops, t)` | Interpolate color from gradient stop list |
| `draw_get_value(m)` | Get numeric value from `m.value` or Conky template `m.name` |
