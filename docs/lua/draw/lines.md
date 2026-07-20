# 32 — draw_lines.lua

## Purpose
Draws lines with configurable style, thickness, and rotation. Used as separators or decorative elements.

## Default Config
```lua
LINE_DEFAULT = {
    x1 = 0, y1 = 0, x2 = 100, y2 = 0,
    thickness = 2, angle = 0,
    style_type = "solid",
    dash_on = 4, dash_off = 4,
    dot_on = 1, dot_off = 3,
    fg = { { 0.0, 0xFFFFFF, 1 }, { 1.0, 0xAAAAAA, 1 } },
}
```

## Example
```lua
draw = {
    -- Solid separator
    { type = "line", x1 = 20, y1 = 150, x2 = 300, y2 = 150,
      thickness = 2, fg = { { 1, "#ffffff", 0.3 } } },

    -- Dashed line
    { type = "line", x1 = 20, y1 = 200, x2 = 300, y2 = 200,
      style_type = "dashed", dash_on = 8, dash_off = 4,
      fg = { { 0, "#ffcc00", 1 }, { 1, "#ff8800", 1 } } },

    -- Diagonal dotted line
    { type = "line", x1 = 20, y1 = 20, x2 = 200, y2 = 100,
      style_type = "dotted", angle = 0 },
}
```

## Config Fields
| Field | Description |
|-------|-------------|
| `style_type` | `"solid"`, `"dashed"`, or `"dotted"` |
| `dash_on` / `dash_off` | Dash pattern lengths (px) |
| `dot_on` / `dot_off` | Dot pattern lengths (px) |
| `angle` | Rotation angle (degrees) |

## Variants
- **Solid**: full line, gradient supported
- **Dashed**: alternating on/off segments
- **Dotted**: small dots with gaps
- **Gradient**: color stops along the line
