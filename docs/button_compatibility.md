# Button & Mouse Event Compatibility

## Requirements
- **Conky built with `BUILD_MOUSE_EVENTS=ON`** (custom `conky-mng` PKGBUILD) — see [docs/pkg/conky-mng.md](pkg/conky-mng.md)
- `lua_mouse_hook = "conky_on_mouse"` in config
- `own_window_type = "override"` for reliable click detection

## Draw-Based Click System
As of the framework cleanup, there is **no separate button table or `37_button_logic.lua`**. Click actions are defined directly on draw items:

```lua
{ type = "text", text = "Launch", click = "ghostty",
  click_view = "player", click_toggle = "details" }
```

Every draw function returns `{x, y, w, h}` bounds. The main loop auto-registers items with click fields into `click_registry`. `conky_on_mouse` iterates this registry in reverse Z-order (last drawn = topmost) to find the clicked item.

See [docs/lua/24_draw_core.md](lua/24_draw_core.md) for details.

## Mouse Events vs XInput
All mouse events in Conky use **XInput2** on X11 — there is no fallback.

- X11/XWayland: XInput2 (`XI_ButtonPress`, `XI_Motion`, `XI_Enter`, `XI_Leave`)
- Wayland (native): `wl_pointer`

`BUILD_XINPUT` was removed in Conky 1.23.0 — XInput2 is always used.

## Window Type
Clicks require `own_window_type = "override"` to receive mouse events reliably across desktop environments.

```lua
own_window = true,
own_window_type = "override",
own_window_hints = "undecorated,below,sticky,skip_taskbar,skip_pager",
```

## Transparency Limitation
> Semi-transparent backgrounds do not work with override windows because compositors typically do not composite override-redirect windows. — Conky man page

This means:
- `own_window_colour` with alpha is **ignored**
- The window background is always solid (default black, configurable via `own_window_colour`)
- **Cairo-level alpha works** — hover effects, gradients within Cairo are fine
- Only the **window-level transparency** is lost

Workaround: set `own_window_colour = "#000000"` and use Cairo to draw any desired background with internal alpha.

## Tested Desktop Environments

The NextGen interactive system works reliably on any X11 or XWayland session when using `own_window_type = "override"`.

| DE | Backend | Window Type | Clicks | Notes |
|---|---|---|---|---|
| KDE Plasma | X11 | `override` | ✅ | Tested |
| MATE | X11 | `override` | ✅ | Tested |
| XFCE | X11 | `override` | ✅ | Tested |
| GNOME | Wayland | — | ❌ | Mutter does not support desktop‑surface / layer‑shell |

**General rule:**  
✔ Works: any X11 or XWayland compositor  
✖ Does not work: GNOME Wayland

Other Wayland compositors (Sway, Hyprland, etc.) are not documented, but should work if Conky runs under XWayland. Not included in the tested list.

## Recommended Config Template
```lua
conky.config = {
  own_window = true,
  own_window_type = "override",
  own_window_hints = "undecorated,below,sticky,skip_taskbar,skip_pager",
  own_window_colour = "#000000",
  double_buffer = true,
  lua_mouse_hook = "conky_on_mouse",
}
```

The window background colour can be customized. Cairo draws all content on top.
