# 24 — draw_core.lua

## Purpose
Cairo initialization, color helper functions, and the main draw loop `conky_core_main()`.

## Dependencies
- Requires `cairo` and optionally `cairo_xlib`
- All draw modules must be loaded before this

## Main Loop
`conky_core_main()` is registered as `lua_draw_hook_pre` in `conky.conf`. It:
1. Checks file changes (watcher)
2. Loads weather/spaceweather data
3. Computes layout (if `layout` table exists)
4. Loops through `draw[]` items and dispatches to the correct draw function

## Helper Functions

| Function | Description |
|----------|-------------|
| `draw_allowed(f)` | Evaluates a `draw_me` condition (true/false/function/conky var) |
| `normalize_number(v)` | Convert any value to a number |
| `normalize_with_suffix(raw)` | Parse numbers with K/M/G suffixes |
| `hex_to_rgba(hex, alpha)` | Convert hex color to r,g,b,a floats |
| `hex_to_rgb_components(col)` | Convert hex to separate r,g,b floats |
| `get_color_from_list(stops, t)` | Interpolate color from gradient stop list |

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
