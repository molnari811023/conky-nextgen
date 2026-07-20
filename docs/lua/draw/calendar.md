# 33 — draw_calendar.lua

## Purpose
Draws a month calendar grid with weekday headers, week numbers, and current day highlighting.

## Default Config
```lua
CALENDAR_DEFAULT = {
    draw_me = true,
    month_format = "year_month",
    x = 300, y = 15,
    cell_w = 40, row_h = 30,
    font = "Noto Sans", size = 18,
    show_weeknums = true,
    color_month, color_weekdays, color_days, color_today, color_outside, color_weeknums,
}
```

## Example
```lua
draw = {
    { type = "calendar", x = 20, y = 20, cell_w = 35, row_h = 25,
      font = "Sans", size = 14, show_weeknums = true,
      color_today = { { 1, "#ff6600", 1 } },
      color_month = { { 1, "#ffffff", 1 } },
      color_weekdays = { { 1, "#aaaaaa", 0.8 } },
      color_days = { { 1, "#cccccc", 1 } } },
}
```

## Config Fields
| Field | Description |
|-------|-------------|
| `month_format` | `"year_month"`, `"month_year"`, or `"month"` |
| `show_weeknums` | Show ISO week numbers in first column |
| `cell_w` | Cell width (px) |
| `row_h` | Row height (px) |
