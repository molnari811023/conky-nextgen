# Button & Mouse Event Compatibility

## Requirements
- **Conky built with `BUILD_MOUSE_EVENTS=ON`** (custom `conky-mng` PKGBUILD) — see [docs/pkg/conky-mng.md](pkg/conky-mng.md)
- `lua_mouse_hook = "conky_on_mouse"` in config

## Window Type

`own_window_type` depends on your desktop environment:

| DE / WM | Backend | `own_window_type` | Notes |
|---------|---------|-------------------|-------|
| KDE Plasma 6 | Wayland | `"normal"` | Works |
| KDE Plasma 5 | X11 | `"override"` | Works |
| MATE | X11 | `"override"` | Works |
| XFCE | X11 | `"override"` | Works |
| GNOME | Wayland | — | Not supported (Mutter) |
| Sway / Hyprland | Wayland | awaiting test | Likely works under XWayland |

> **Not every DE/WM has been tested.** The table above reflects my own experience. If you use a different environment, you'll need to find the correct setting in `conky.conf`. Generally: X11 → `"override"`, Wayland → `"normal"`.

## Transparency Limitation

> Semi-transparent backgrounds do not work with override windows because compositors typically do not composite override-redirect windows. — Conky man page

This means:
- `own_window_colour` with alpha is **ignored**
- The window background is always solid (default black, configurable via `own_window_colour`)
- **Cairo-level alpha works** — hover effects, gradients within Cairo are fine
- Only the **window-level transparency** is lost

Workaround: set `own_window_colour = "#000000"` and use Cairo to draw any desired background with internal alpha.

## Draw-Based Click System

Click actions are defined directly on draw items:

```lua
{ type = "text", text = "Launch", click = "ghostty",
  click_view = "player", click_toggle = "details" }
```

Every draw function returns `{x, y, w, h}` bounds. The main loop auto-registers items with click fields into `click_registry`. `conky_on_mouse` iterates this registry in reverse Z-order (last drawn = topmost) to find the clicked item.

## Mouse Events

All mouse events in Conky use **XInput2** on X11 — there is no fallback.

- X11/XWayland: XInput2 (`XI_ButtonPress`, `XI_Motion`, `XI_Enter`, `XI_Leave`)
- Wayland (native): `wl_pointer`

`BUILD_XINPUT` was removed in Conky 1.23.0 — XInput2 is always used.

## Recommended Config Template

```lua
conky.config = {
  own_window = true,
  own_window_type = "normal",   -- Wayland; use "override" on X11
  own_window_hints = "undecorated,below,sticky,skip_taskbar,skip_pager",
  own_window_colour = "#000000",
  double_buffer = true,
  lua_mouse_hook = "conky_on_mouse",
}
```

The window background colour can be customized. Cairo draws all content on top.
