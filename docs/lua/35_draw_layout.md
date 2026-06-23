# 35 — draw_layout.lua

## Purpose
Dynamic layout engine. Computes y-positions for named sections based on their heights. Makes it easy to stack widgets without hardcoding Y coordinates.

## How it works
Defines a `layout` table (in `36_widget.lua`). Each entry has a `name` and `height`. The engine computes `y_start_<name>` and `height_<name>` global variables, and `y_end_dynamic` for total height tracking.

## Example
```lua
layout = {
    { name = "weather", height = 200, enabled = true },
    { name = "cpu", height = 100, enabled = function() return conky_nvidia_active() == "1" end },
    { name = "memory", height = function() return 40 + 20 * 5 end, enabled = true },
}
```

This creates:
- `y_start_weather = 0`, `height_weather = 200`
- `y_start_cpu = 207`, `height_cpu = 100` (if NVIDIA active)
- `y_start_memory = 314`, `height_memory = 140`
- `y_end_dynamic = 461`

Then in draw items:
```lua
draw = {
    { type = "text", text = "Weather", y = y_start_weather, ... },
    { type = "text", text = "CPU", y = y_start_cpu, ... },
}
```

## Config Fields
| Field | Description |
|-------|-------------|
| `name` | Section name (used for `y_start_<name>` variable) |
| `height` | Section height (number or function) |
| `enabled` | Boolean or function – skip if false |

## Padding
Default padding between sections: 7px (set via `PADDING` constant).
