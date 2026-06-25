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

## 4. Combination Widgets (works with current 1.22.3)
New direction: combine existing drawing modules into composite widgets:
- Bar + text overlay (label/value rendered on top of the bar)
- Ring + text overlay (value in center of ring gauge)
- Graph + text overlay (annotations at key data points)
- Reference: community combination widgets on DeviantArt
