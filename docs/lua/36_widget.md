# 36 — widget.lua

## Purpose
User-defined widget configuration. This is where you define `draw[]` and `layout[]` tables. Every module in the framework is the motor — your `36_widget.lua` is the steering wheel.

## Draw Items
Each item is a table with a `type` field plus optional fields. All types support:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `draw_me` | bool/string/func | `true` | Condition (true/false, `${conky_var}`, Lua function) |
| `view` | string | nil | View filter — drawn only when `current_view == view` |
| `group` | string | nil | Group toggle — drawn only when `GROUP_STATE[name] == true` |
| `click` | string | nil | Shell command on click (requires custom Conky) |
| `click_view` | string | nil | Switch to this view on click |
| `click_toggle` | string | nil | Toggle this group on click |
| `x`, `y` | number/func | 0 | Position (can be function referencing `y_end_dynamic`) |
| `w`, `h` | number/func | type-dependent | Size (can be function) |

### Function-based fields
`x`, `y`, `w`, `h`, `width`, `height`, `radius`, `text`, `color`, `path` can be functions. They are evaluated every draw cycle and can reference dynamic globals:

```lua
y = function() return (y_end_dynamic or 0) + 10 end,
```

### Type-specific fields

**background** — `x`, `y`, `w`, `h`, `radius`, `bg` (stops), `border` (stops), `border_width`

**text** — `text` (required), `font`, `size`, `slant`, `weight`, `align`, `color` (stops), `wrap_width`, `wrap_dic`

**bar** — `name` or `value`, `arg`, `width`, `height`, `max`, `angle`, `blocks`, `mode`, `sides`, `bg` (stops), `fg` (stops)

**graph** — `name` or `value`, `arg`, `width`, `height`, `max`, `autoscale`, `angle`, `graph_type` (line/fill), `line_width`, `bg`, `fg`, `border`, `border_width`, `grid`, `grid_steps`

**clock** — `x`, `y`, `radius`, `show_ticks`, `show_numbers`, `show_seconds`, `number_size`, `center_radius`, `bg`, `border`, `hour_color`, `minute_color`, `second_color`

**ring** — `name` or `value`, `arg`, `x`, `y`, `radius`, `thickness`, `start_angle`, `end_angle`, `sectors`, `mode`, `max`, `bg`, `fg`

**line** — `x1`, `y1`, `x2`, `y2`, `thickness`, `angle`, `style_type`, `fg`

**calendar** — `x`, `y`, `cell_w`, `row_h`, `font`, `size`, `show_weeknums`, `color_month`, `color_days`, `color_today`, `color_outside`

**image** — `path` (required), `width`, `height`, `alpha`, `tint`, `rotate`, `radius`, `shape`, `scale_mode`, `crop`

See individual module docs for full field lists.

## Layout Items
Layout sections enable dynamic Y-position stacking:

```lua
layout = {
  { name = "header", height = 150 },
  { name = "details", height = function()
      return GROUP_STATE["details"] and 55 or 0
    end, group = "details" },
}
```

Creates `y_start_<name>`, `height_<name>` globals, and `y_end_dynamic` for total height. See [docs/lua/35_draw_layout.md](35_draw_layout.md).

## Example
```lua
current_view = "main"
GROUP_STATE = { details = false }

layout = {
  { name = "header", height = 150 },
  { name = "details", height = function()
      return GROUP_STATE["details"] and 55 or 0
    end, group = "details" },
}

draw = {
  { type = "background", x = 0, y = 0, w = 500, h = 500,
    bg = { { 1, "#1a1a1a", 0.7 } } },
  { type = "text", text = "Hello", x = 250, y = 50, size = 16,
    align = "center", color = { { 1, "#FFFFFF", 1 } } },
  { type = "text", text = "▶ Toggle", x = 20,
    y = function() return 140 end, click_toggle = "details",
    color = { { 1, "#00FFAA", 1 } } },
  { type = "bar", x = 20, y = function() return (y_end_dynamic or 150) + 10 end,
    width = 200, height = 20, value = 66, max = 100,
    click = "notify-send hello bar" },
}
```

## Requirements
Mouse events (click/click_view/click_toggle) require a custom Conky build with `BUILD_MOUSE_EVENTS=ON`. See [docs/pkg/conky-mng.md](../pkg/conky-mng.md) for the PKGBUILD.
