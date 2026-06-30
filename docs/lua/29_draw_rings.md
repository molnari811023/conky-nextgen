# 29 — draw_rings.lua

## Purpose
Draws ring gauges (segmented or smooth). Useful for CPU, memory, disk usage displays.

## Default Config
```lua
RING_DEFAULT = {
    x = 100, y = 100, radius = 50, thickness = 6,
    start_angle = 0, end_angle = 360, sectors = 6,
    mode = "ring", max = 100,
    alarm_color = 0xFF0000, alarm_alpha = 1,
    bg = { { 0.0, "#333333", 1 }, { 1.0, "#111111", 1 } },
    fg = { { 0.0, "#00FFAA", 1 }, { 1.0, "#008866", 1 } },
}
```

## Example
```lua
draw = {
    -- Segmented ring: CPU
    { type = "ring", name = "cpu", arg = "cpu1",
      x = 100, y = 100, radius = 50, thickness = 8,
      start_angle = 180, end_angle = 540, sectors = 12,
      fg = { { 0, "#00ff00", 1 }, { 0.5, "#ffaa00", 1 }, { 1, "#ff0000", 1 } },
      max = 100 },

    -- Smooth ring: memory
    { type = "ring", name = "memperc", mode = "smooth",
      x = 100, y = 100, radius = 40, thickness = 6, max = 100 },

    -- Polygon ring: gear-tooth triangle sectors
    { type = "ring", name = "cpu", arg = "cpu1",
      x = 100, y = 100, radius = 50, thickness = 8,
      sectors = 12, sides = 3,
      fg = { { 0, "#00ff00", 1 }, { 0.5, "#ffaa00", 1 }, { 1, "#ff0000", 1 } } },

    -- Polygon ring: hexagon sectors
    { type = "ring", name = "memperc",
      x = 100, y = 100, radius = 45, thickness = 10,
      sectors = 8, sides = 6,
      fg = { { 0, "#66ccff", 1 }, { 1, "#3399cc", 1 } } },

    -- Dot ring: circle sectors
    { type = "ring", name = "cpu", arg = "cpu1",
      x = 100, y = 100, radius = 50, thickness = 8,
      sectors = 16, mode = "dot",
      fg = { { 0, "#00ff00", 1 }, { 0.5, "#ffaa00", 1 }, { 1, "#ff0000", 1 } } },
}
```

## Config Fields
| Field | Description |
|-------|-------------|
| `name` | Conky variable name |
| `arg` | Variable argument |
| `mode` | `"ring"` (segmented arc), `"smooth"` (continuous), or `"dot"` (circle sectors) |
| `sectors` | Number of segments (for ring/dot mode) |
| `sides` | Polygon sides per sector (`3`=gear tooth, `6`=hexagon, any ≥3); requires `mode = "ring"` |
| `start_angle` / `end_angle` | Arc range in degrees |
| `sector_size` | Auto-calculate sectors from arc span |
| `gap` | Gap between segments (auto if `sector_size` set) |
| `max` | Maximum value |
| `alarm_color` | Color when value exceeds max |

## Variants
- **Ring (segmented)**: evenly divided arc sectors
- **Dot**: circle sectors (`mode = "dot"`)
- **Polygon**: gear-tooth style sectors (`sides = 3`) or hexagonal sectors (`sides = 6`)
- **Smooth**: continuous arc with gradient
- **Partial arc**: set start/end to 180/540 for bottom-half ring
