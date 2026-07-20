# core/draw_core.lua

## Purpose

Cairo initialization, global state variables (DRAG, Z_INDEX, THEME), helper functions, and the main draw loop `conky_core_main()`. This is the central orchestrator — it calls all other modules.

## Split Modules

The old monolithic `24_draw_core.lua` was split into 5 modules:

| Module | Purpose |
|--------|---------|
| `core/draw_core.lua` | Cairo init, state, helpers, main loop |
| `core/draw_input.lua` | Input registration, click/scroll actions, `build_draw()` |
| `core/draw_group.lua` | GROUP_STATE toggle, register, visibility |
| `core/draw_context.lua` | Right-click context menu |
| `core/draw_mouse.lua` | Mouse event handler, drag-and-drop |

## Dependencies

- Requires `cairo` and optionally `cairo_xlib`
- All draw modules must be loaded before this

## Cairo Surface API

Uses `conky_surface()` (modern Conky API) if available; falls back to `cairo_xlib_surface_create()`. The surface is only destroyed via `cairo_surface_destroy()` when the fallback path is used — `conky_surface()` manages its own lifetime.

## Global State

| Variable | Type | Description |
|----------|------|-------------|
| `GROUP_STATE` | table | Three-state model: `nil`/`"collapsed"`/`"expanded"` |
| `GROUP_REGISTRY` | table | Set of registered group names |
| `GROUP_HIDDEN_BY_DRAW_ME` | table | Saved states for groups hidden by `draw_me` |
| `current_view` | string | Active view name (default: `"main"`) |
| `HOVER_VIEW` | string/nil | View set by hover (overrides `current_view`) |
| `MOUSE_INSIDE` | bool | Whether mouse is inside the window |
| `DRAG` | table | Drag-and-drop state (Neovim-inspired) |
| `Z_INDEX` | table | Layer ordering constants |
| `SCROLL` | table | Scroll state: `{offset, step, content_height, window_height}` |
| `THEME` | table | UI theme colors and dimensions |

## Z-Index System

Neovim floating window-inspired layer ordering:

| Constant | Value | Used for |
|----------|-------|----------|
| `Z_INDEX.DEFAULT` | 0 | Regular elements |
| `Z_INDEX.HEADER` | 5 | Group headers |
| `Z_INDEX.CONTEXT_MENU` | 100 | Right-click menu |
| `Z_INDEX.TOOLTIP` | 200 | Hover tooltips |
| `Z_INDEX.DRAG_OVERLAY` | 300 | Drag ghost + drop target |

`ensure_sorted_draw()` returns a copy of `draw[]` sorted by z-index.

## Floating Layer Stack

Context menu and drag overlay are rendered in a separate "floating" table, sorted by z-index, drawn after the main element loop:

```lua
local floating = {}
-- drag overlay at z=300
-- context menu at z=100
table.sort(floating, function(a,b) return a.z_index < b.z_index end)
for _, layer in ipairs(floating) do layer.draw(cr) end
```

## Main Loop (`conky_core_main()`)

Registered as `lua_draw_hook_pre` in `conky.conf`. Execution order:

1. **Watcher**: check file changes, arm reload
2. **Backend**: `conky_load_weather_data()`, `conky_update_alerts()`
3. **First-run**: `build_draw(raw_elements)` if `draw` not yet built
4. **Reset registries**: `click_registry`, `text_registry`, `group_hit_registry`, `HEADER_REGISTRY`, `hover_idx`
5. **Cairo surface**: create via `conky_surface()` or fallback
6. **Layout**: if `layout[]` exists, `register_groups_from_layout()`, `check_group_visibility()`, `DynamicLayout.compute()`
7. **Scroll**: `cairo_translate(cr, 0, -SCROLL.offset)`
8. **Draw loop**: iterate `draw[]` (sorted by z-index), for each element:
   - Check `draw_me` condition
   - Check `draw_allowed(view, group)`
   - Skip if `is_element_collapsed()`
   - Resolve function fields
   - Apply `layout_box` offset
   - Register in `click_registry` / `text_registry` / `group_hit_registry` / `HEADER_REGISTRY`
   - Dispatch to draw function by type
9. **Floating layers**: render context menu + drag overlay
10. **Cleanup**: destroy Cairo surface

## Function-Based Fields

Any draw item can use functions instead of static values for: `x`, `y`, `w`, `h`, `width`, `height`, `radius`, `text`, `color`, `path`. These are resolved every draw cycle, then restored.

```lua
y = function() return (y_end_dynamic or 150) + 10 end,
color = function()
    return current_view == "main" and ACTIVE_COLOR or INACTIVE_COLOR
end,
```

## Draw Dispatch Table

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
| `rounded_rect_path(cr, x, y, w, h, r)` | Cairo path for rounded rectangle |
| `draw_allowed(view, group)` | Check if element should be drawn |
| `normalize_number(v)` | Convert any value to a number |
| `normalize_with_suffix(raw)` | Parse numbers with K/M/G suffixes |
| `hex_to_rgba(hex, alpha)` | Convert hex color to r,g,b,a floats |
| `hex_to_rgb_components(col)` | Convert hex to separate r,g,b floats |
| `get_color_from_list(stops, t)` | Interpolate color from gradient stop list |
| `draw_get_value(m)` | Get numeric value from `m.value` or Conky template |
| `btn_color(view_name)` | Returns active/inactive color based on current view |
| `arrow(name)` | Returns arrow string based on group state |
| `arrow_color(name)` | Returns color based on group state |

## Draw Hooks

Overridable callbacks:

```lua
on_draw_start = function(cr) end  -- called before draw loop
on_draw_end = function(cr) end    -- called after floating layers
```
