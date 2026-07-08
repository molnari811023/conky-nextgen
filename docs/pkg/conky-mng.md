# conky-mng — Custom Conky PKGBUILD

## What is it?
A custom Arch Linux PKGBUILD that builds Conky with **mouse events enabled** (`BUILD_MOUSE_EVENTS=ON`). This is the only feature the official Arch `conky` package lacks for the NextGen framework's interactive widgets (click, hover, view switching, group toggle).

Cairo support (`BUILD_LUA_CAIRO=ON`) is **already included** in the official Arch `conky` package since version 1.22.3.

## Why is this needed?
The official Arch Linux `conky` package (1.22.3) does NOT include:
- `BUILD_MOUSE_EVENTS` — receives XInput2 mouse events (click, hover)

Arch's official package already includes:
- `BUILD_LUA_CAIRO=ON` ✅ — Lua bindings for Cairo graphics
- `BUILD_LUA_IMLIB2=ON` ✅
- `BUILD_LUA_RSVG=ON` ✅
- `BUILD_XSHAPE=ON` ✅ — click-through support

## Location
- **PKGBUILD**: `pkg/PKGBUILD`
- **Built package**: `pkg/conky-mng-<version>-x86_64.pkg.tar.zst`
- **Source**: `https://github.com/brndnmtthws/conky`

## Build & Install
```bash
cd pkg
makepkg -si
```

This installs `conky-mng` which provides `conky` (conflicts with official `conky` package).

## Key Build Flags vs Official
| Flag | conky-mng | official conky | Why |
|------|-----------|----------------|-----|
| `BUILD_MOUSE_EVENTS` | ON | absent (OFF) | XInput2 mouse click/hover events |
| `BUILD_LUA_CAIRO` | ON | ON | Lua Cairo drawing functions |
| `BUILD_LUA_CAIRO_XLIB` | ON | absent (OFF) | Cairo XLib surface for Conky |
| `BUILD_WAYLAND` | OFF | ON | Wayland via XWayland only |
| `BUILD_X11` | ON | ON | X11 backend |
| `BUILD_XSHAPE` | ON | ON | Click-through shape extension |
| `BUILD_NVIDIA` | ON | ON | NVIDIA GPU support |
| `BUILD_PULSEAUDIO` | ON | ON | Audio volume support |
| `BUILD_CURL` | ON | ON | Weather API downloads |

## Which features require this build?
| Feature | Works with official `conky` (1.22.3)? |
|---------|--------------------------------------|
| Static drawing (text, bars, graphs, rings) | ✅ Yes (Cairo is on) |
| Weather data | ✅ Yes |
| Hardware sensors | ✅ Yes |
| Layout engine | ✅ Yes |
| Image (PNG) rendering | ✅ Yes |
| **Click/hover on draw items** | **❌ No — requires `BUILD_MOUSE_EVENTS=ON`** |
| **View switching** | **❌ No — requires mouse events** |
| **Group toggle** | **❌ No — requires mouse events** |

## Version
Current build: `1.24.2.r17.gf145135` (Conky git commit gf145135, newer than official 1.22.3)

## Notes
- Lua 5.5 is used (`lua` package on Arch) — official uses Lua 5.4 (`lua54`)
- `BUILD_XINPUT` was removed in Conky 1.23.0 — XInput2 is always used
- The package provides `conky` and conflicts with `conky` / `conky-git`
- After installation: `conky --version` should show "conky-mng" and "Mouse events" in features
