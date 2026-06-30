# 26 — draw_bar.lua

## Purpose
Draws horizontal progress bars. Two styles: smooth bars and block bars.

## Default Config
```lua
BAR_DEFAULT = {
    x = 0, width = 100, height = 10, max = 100, angle = 0,
    bg = { { 0.0, "#333333", 1 }, { 1.0, "#111111", 1 } },
    fg = { { 0.0, "#00FF00", 1 }, { 1.0, "#009900", 1 } },
}
```

## Example
```lua
draw = {
    -- Smooth bar: CPU usage
    { type = "bar", name = "cpu", arg = "cpu1", x = 20, y = 50,
      width = 200, height = 12, max = 100,
      fg = { { 0, "#00ff00", 1 }, { 0.5, "#ffff00", 1 }, { 1, "#ff0000", 1 } } },

    -- Block bar: memory
    { type = "bar", name = "memperc", x = 20, y = 70,
      width = 200, height = 10, blocks = 10,
      fg = { { 0, "#66ccff", 1 }, { 1, "#3399cc", 1 } } },

    -- Polygon bar: triangle blocks, CPU
    { type = "bar", name = "cpu", arg = "cpu1", x = 20, y = 90,
      width = 200, height = 12, blocks = 12, sides = 3,
      fg = { { 0, "#00ff00", 1 }, { 1, "#ff0000", 1 } } },

    -- Polygon bar: hexagon blocks, memory
    { type = "bar", name = "memperc", x = 20, y = 110,
      width = 200, height = 12, blocks = 10, sides = 6,
      fg = { { 0, "#66ccff", 1 }, { 1, "#3399cc", 1 } } },
}
```

## Config Fields
| Field | Description |
|-------|-------------|
| `name` | Conky variable name (e.g. `cpu`, `memperc`, `fs_used_perc`) |
| `arg` | Conky variable argument (e.g. cpu core number) |
| `max` | Maximum value (default 100) |
| `blocks` | If set → block bar style; omit → smooth |
| `sides` | Polygon sides per block (`3`=triangle, `6`=hexagon, any ≥3); requires `blocks` |
| `angle` | Rotation angle (degrees) |

## Variants
- **Smooth**: continuous gradient fill (no `blocks`)
- **Block**: segmented rectangle blocks (`blocks = N`)
- **Polygon**: segmented polygonal blocks (`blocks = N` + `sides ≥ 3`)
- **Gradient stops**: `fg` and `bg` accept multiple `{ pos, hex, alpha }` stops
