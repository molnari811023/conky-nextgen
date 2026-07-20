# 27 — draw_graph.lua

## Purpose
Draws scrolling time-series graphs for any Conky variable. Two modes: line and fill.

## Default Config
```lua
GRAPH_DEFAULT = {
    x = 0, y = 0, width = 100, height = 40, max = 100,
    autoscale = false, angle = 0, graph_type = "line", line_width = 2,
    bg = { { 0.0, "#333333", 1 }, { 1.0, "#111111", 1 } },
    fg = { { 0.0, "#00FFAA", 1 }, { 1.0, "#008866", 1 } },
    border = { { 0.0, "#FFFFFF", 0.8 }, { 1.0, "#FFFFFF", 0.2 } },
    border_width = 1,
    grid = false, grid_color = { { 0.0, "#FFFFFF", 0.10 } }, grid_steps = 4,
}
```

## Example
```lua
draw = {
    -- Line graph: CPU
    { type = "graph", name = "cpu", arg = "cpu1", x = 20, y = 100,
      width = 200, height = 50, max = 100,
      fg = { { 0, "#00ff00", 1 }, { 1, "#ff0000", 1 } },
      grid = true, grid_color = { { 1, "#ffffff", 0.15 } } },

    -- Fill graph: memory with autoscale
    { type = "graph", name = "memperc", x = 20, y = 160,
      width = 200, height = 40, graph_type = "fill", autoscale = true },
}
```

## Config Fields
| Field | Description |
|-------|-------------|
| `name` | Conky variable name |
| `arg` | Variable argument |
| `max` | Fixed maximum (ignored if `autoscale = true`) |
| `autoscale` | Auto-adjust max based on data |
| `graph_type` | `"line"` or `"fill"` |
| `grid` | Show horizontal grid lines |
| `grid_steps` | Number of grid sections |

## Variants
- **Line**: stroke with gradient
- **Fill**: filled area with vertical gradient
- **Autoscale**: useful for variable-range metrics
