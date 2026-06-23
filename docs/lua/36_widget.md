# 36 — widget.lua

## Purpose
User-defined widget configuration. This is where you define your `draw` and `layout` tables.

## Usage
```lua
draw = {
    { type = "background", x = 0, y = 0, radius = 10,
      bg = { { 1, "#141618", 0.9 } } },
    { type = "text", text = "${time %H:%M}", x = 20, y = 30,
      font = "Sans", size = 48, weight = "bold",
      color = { { 1, "#ffffff", 1 } } },
    { type = "bar", name = "cpu", arg = "cpu1", x = 20, y = 100,
      width = 200, height = 8, max = 100 },
}

layout = {
    { name = "header", height = 60, enabled = true },
    { name = "stats",  height = 200, enabled = true },
}
```

This is the entry point for customizing the Conky display. The main loop in `24_draw_core.lua` reads from these globals.
