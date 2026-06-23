# 31 — draw_text.lua

## Purpose
Renders text with support for alignment, word wrap, and hyphenation.

## Default Config
```lua
TEXT_DEFAULT = {
    x = 0, y = 0,
    font = "Sans", size = 14,
    slant = "normal", weight = "normal",
    align = "left",
    text = "",
    color = { { 0.0, 0xFFFFFF, 1 }, { 1.0, 0xCCCCCC, 1 } },
    wrap_width = nil,
    wrap_dic = nil,
}
```

## Example
```lua
draw = {
    -- Simple text
    { type = "text", text = "Hello Conky", x = 20, y = 30,
      font = "Sans", size = 24, weight = "bold",
      color = { { 1, "#ffffff", 1 } } },

    -- Centered, wrapped text with hyphenation
    { type = "text", text = "Long paragraph text...",
      x = 100, y = 200, align = "center", wrap_width = 180,
      wrap_dic = "/usr/share/hyphen/hyph_en_US.dic",
      color = { { 0, "#ffffff", 1 }, { 1, "#aaaaaa", 1 } } },

    -- Conky variable text
    { type = "text", text = "${time %Y-%m-%d %H:%M}", x = 10, y = 10,
      size = 18, color = { { 1, "#66ccff", 1 } } },
}
```

## Config Fields
| Field | Description |
|-------|-------------|
| `text` | Text or Conky template (`${...}` variables are parsed) |
| `x` / `y` | Position (can use `"center"` for window center) |
| `align` | `"left"`, `"center"`, `"right"` |
| `wrap_width` | Line wrap width (px). If nil → single line |
| `wrap_dic` | Path to hyphenation `.dic` file for automatic hyphenation |
| `slant` / `weight` | Font style: `"normal"`, `"italic"`, `"bold"` |

## Variants
- **Single line**: omit `wrap_width`
- **Wrapped**: set `wrap_width` (pixels)
- **Wrapped + hyphenated**: set both `wrap_width` and `wrap_dic`
- **Dynamic text**: use Conky variables in `text`
