# 34 — draw_image.lua

## Purpose
Renders PNG images with support for scaling, cropping, tinting, rotation, and shape clipping.

## Default Config
```lua
PNG_DEFAULT = {
    path = nil, x = 0, y = 0,
    width = nil, height = nil,
    alpha = 1,
    tint = nil, tint_alpha = 1,
    rotate = 0,
    scale_mode = "bilinear",
    shape = nil, radius = 0,
    crop = nil,
}
```

## Example
```lua
draw = {
    -- Simple icon
    { type = "image", path = "icons/default/0d.png", x = 20, y = 20 },

    -- Scaled image
    { type = "image", path = "images/photo.png", x = 50, y = 50,
      width = 200, height = 150, alpha = 0.9 },

    -- Circular avatar with tint
    { type = "image", path = "images/avatar.png", x = 10, y = 10,
      width = 64, height = 64, shape = "circle",
      tint = "#ff6600", tint_alpha = 0.3 },

    -- Cropped + rounded corners
    { type = "image", path = "images/banner.png", x = 0, y = 0,
      crop = { x = 100, y = 50, w = 400, h = 200 },
      radius = 10 },

    -- Rotated
    { type = "image", path = "images/logo.png", x = 100, y = 100,
      rotate = 45 },
}
```

## Config Fields
| Field | Description |
|-------|-------------|
| `path` | PNG file path |
| `width` / `height` | Output size (maintains ratio if only one set) |
| `alpha` | Opacity (0–1) |
| `tint` | Hex color tint (applied as mask) |
| `rotate` | Rotation (degrees) |
| `scale_mode` | `"bilinear"`, `"nearest"`, `"good"` |
| `shape` | `"circle"` for circular clip |
| `radius` | Rounded corner radius |
| `crop` | `{ x, y, w, h }` source rectangle |

## Variants
- **Direct**: no scaling, no crop
- **Scaled**: set width/height
- **Circular**: shape = "circle" + equal width/height
- **Rounded corners**: radius > 0
- **Tinted**: colorized with alpha mask
- **Cropped**: source region selection
