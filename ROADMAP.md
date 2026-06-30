# Conky NextGen — Roadmap

## 1. Conky 1.23+ Upgrade (Arch extra repo)
**Status:** v1.23.0 (May 17) - v1.24.2 (Jun 19) released on GitHub.
Arch package still at 1.22.3-3 (March). Waiting for Arch extra repo update.

### What it brings:
- `conky_surface()` → replaces `cairo_xlib_surface_create(...)` + fallback chain
- `conky_window.pixel_size`, `conky_window.scale` → HiDPI support
- `BUILD_XINPUT` removed → mouse events work unconditionally
- Event propagation fix (1.24.0), cursor steal fix (1.24.1)
- Official example: `data/conky_mouse_events.conf`

## 2. NVIDIA NVML Dual-mode (19_hardware_nvidia.lua)
Conky 1.24.2 ships a native NVML backend for `${nvidia}...` variables. Works on Wayland too.

**Plan:** Runtime detection:
- If `${nvidia gputemp 0}` → returns a number → use NVML backend
- Otherwise → `nvidia-smi -x -q` fallback (current behavior)
- All `conky_nv_*()` function signatures stay unchanged
- TODO: update `14_hardware_core.lua`, `24_draw_core.lua` for conditional calls

## 3. Multi-view / Mouse Events
On hold until conky ≥1.23 lands in distro repos.
Revisit when Arch extra repo ships it. Then:
- `conky_surface()` + `lua_mouse_hook` combination
- View switching architecture
- Rebuild `examples/multi_view/`

## 4. Now Playing Controls (requires Conky ≥ 1.23 for mouse events)
Current `nowplaying.lua` is display-only (title, artist, album, album art). Once Conky 1.23 lands:

- Play/pause, next, previous buttons using `playerctl play-pause` / `playerctl next` / `playerctl previous`
- Clickable buttons via `lua_mouse_hook` (Conky 1.23+ feature)
- Seeking/progress bar integration
- Volume control (via `playerctl volume`)
- Player switching (if multiple MPRIS players are active)

## 5. Combination Widgets (works with current 1.22.3)
New direction: combine existing drawing modules into composite widgets:
- Bar + text overlay (label/value rendered on top of the bar)
- Ring + text overlay (value in center of ring gauge)
- Graph + text overlay (annotations at key data points)
- Reference: [Bargraph Widget 2.2 (edit by Nooby4Ever) by N00by4Ever](https://www.deviantart.com/n00by4ever/art/conky-Bargraph-Widget-2-2-edit-by-Nooby4Ever-401252985) (fork of wlourf's Bargraph 2.1)
- Reference: [Pie Chart Widget for Conky 1.3 by wlourf](https://www.deviantart.com/wlourf/art/Pie-Chart-Widget-for-Conky-1-3-165734819)

## 6. OS Detection Module
Detect the running OS/distro and version at load time. Enables distro-agnostic widgets.

**Use cases:**
- Package updates: `checkupdates` (Arch), `apt list --upgradable` (Debian/Ubuntu), `dnf check-update` (Fedora)
- AUR updates: `yay -Qua` or `paru -Qua` — only on Arch with AUR helper
- Flatpak/Snap updates detection
- Distro-specific paths, icons, and default configs
- Conditional module loading per distro

## 7. Lua 5.5 Compatibility Layer

Conky 1.23.0+ is already compatible with Lua 5.5 (GC API fix merged in [#2335](https://github.com/brndnmtthws/conky/pull/2335)).
Arch Linux will switch Conky to Lua 5.5 when the package is updated.

**NextGen tasks:**
- Runtime detection of Lua ABI (5.1 / 5.3 / 5.4 / 5.5)
- Version-agnostic `require()` wrapper for dkjson, filesystem, lpeg, etc.
- Version-agnostic `unpack`/`load` compatibility
- Extended `package.path` for Debian/Ubuntu Lua module directories
- Ensure all modules remain compatible when Conky switches to Lua 5.5
