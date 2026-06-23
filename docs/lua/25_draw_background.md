# 25 — draw_background.lua

## Purpose
Draws rounded rectangle backgrounds with gradient fill and optional border.

## Default Config
```lua
BACKGROUND_DEFAULT = {
    draw_me = true,
    x = 0, y = 0,
    w = 0,        -- 0 = full window width
    h = 0,        -- 0 = full window height
    radius = 20,
    bg = { { 1, "#141618", 1 } },         -- gradient stops: { pos, hex, alpha }
    border = { { 1, "#4c4e51", 1 } },
    border_width = 2,
}
```

## Example
```lua
draw = {
    { type = "background", x = 10, y = 10, w = 300, h = 200, radius = 15,
      bg = { { 0, "#000000", 0.8 }, { 1, "#333333", 0.9 } },
      border = { { 0, "#ffffff", 0.5 } }, border_width = 1 },
}
```

## Variants
- Full window background: omit w/h (defaults to 0 = window size)
- Flat color: single stop `{ { 1, "#ff0000", 1 } }`
- Gradient: multiple stops
- No border: `border_width = 0`
