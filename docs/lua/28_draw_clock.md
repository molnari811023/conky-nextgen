# 28 — draw_clock.lua

## Purpose
Draws an analog clock face with hour/minute/second hands, tick marks, and hour numbers.

## Default Config
```lua
CLOCK_DEFAULT = {
    x = 100, y = 100, radius = 50,
    show_ticks = true, show_numbers = true, show_seconds = true,
    tick_width_hour = 3, tick_width_minute = 1,
    number_size = 14, number_radius = 0.75,
    hour_hand_width = 4, minute_hand_width = 3, second_hand_width = 1,
    bg = { { 0.0, 0x222222, 1 }, { 1.0, 0x000000, 1 } },
    border = { { 0.0, 0xFFFFFF, 1 }, { 1.0, 0x888888, 1 } },
    tick_color, number_color, hour_color, minute_color, second_color, center_color,
    center_radius = 4,
}
```

## Example
```lua
draw = {
    { type = "clock", x = 200, y = 200, radius = 80,
      show_seconds = false,
      bg = { { 0, 0x1a1a2e, 1 }, { 1, 0x16213e, 1 } },
      hour_color = { { 1, 0xffffff, 1 } },
      minute_color = { { 1, 0xcccccc, 1 } },
      second_color = { { 1, 0xff4444, 1 } } },
}
```

## Variants
- Minimal: `show_ticks = false, show_numbers = false, show_seconds = false`
- Custom face colors via gradient stops
- Adjustable hand proportions
