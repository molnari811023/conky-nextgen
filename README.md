<p align="center">
  <img src="screenshots/banner.png" alt="Conky NextGen">
</p>

# Conky NextGen

Conky NextGen is a modular Conky framework with a Lua/Cairo renderer, Bash
data fetchers, self-contained themed widgets, and a GTK3 visual Designer. It
supports X11 and Wayland-capable Conky builds.

![NextGen desktop](screenshots/desktop.png)

## Engine Requirement: conky-mng

> [!IMPORTANT]
> Conky NextGen requires the **`conky-mng`** engine (Conky 1.25+ compiled with mouse events, Lua 5.4, and flicker-free X11 window reload). Stock distribution builds (such as Ubuntu's `conky-all` 1.22.x) **do not support mouse events** and will fail.
> - **Ubuntu / Debian:** A pre-compiled stable `.deb` package is provided in the repository: [`pkg/conky-mng_1.25.2.r7.g6628aff-1_amd64.deb`](pkg/conky-mng_1.25.2.r7.g6628aff-1_amd64.deb).
> - **Arch Linux:** Available via [`pkg/PKGBUILD`](pkg/PKGBUILD) / AUR (`conky-mng-git`).

## Distribution Support: Ubuntu & Arch Linux / Manjaro

Conky NextGen provides dual distribution intelligence that automatically adapts widgets to the host operating system without manual reconfiguration:

| Feature / Metric | Ubuntu / Debian | Arch Linux / Manjaro |
|---|---|---|
| **Package Updates** (`left`, `info`) | APT total updates + Security updates (`conky_updates_apt`, `conky_updates_security`) | Official repository + AUR pending packages (`conky_updates_repo`, `conky_updates_aur`) |
| **Package Count** | `dpkg-query` (`conky_packages_ubuntu`) | `pacman -Q` (`conky_packages_arch`) |
| **Installation Date** | Earliest `dpkg.log` or `/etc/machine-id` | `pacman.log` |
| **Distro Branding** (`tux`) | Ubuntu distributor logo (`images/ubuntu-logo-dark.png`) | Arch Linux logo (`images/archlinux-logo-dark.png`) |
| **Update Dispatcher** (`sh/updates.sh`) | Automatically executes `fetch_updates_ubuntu.sh` | Automatically executes `fetch_updates.sh` |
| **Hardware & GPU** | Native NVML via `conky-mng` + NVIDIA auto-detection in `conky-nextgen start default` | Native NVML / NvCtrl |

## Quick start

### Method 1: Git Clone (Recommended / Stable)

Cloning the repository directly is the most mature and battle-tested way to run Conky NextGen:

```bash
git clone https://github.com/molnari811023/conky-nextgen.git ~/.conky
cd ~/.conky

# Fetch weather, alerts, maps, media, network, and optional Google data.
bash sh/fetch_all.sh

# Start any widget directly (dynamic paths allow launching from any directory).
conky -c clock_cal.conf
# Or any custom/renamed configuration:
conky -c akarmi.conf

# Start the visual Designer.
python3 sh/designer/main.py
```

The default weather location is Vienna. Supply a city name to fetch weather
for another location:

```bash
bash sh/fetch_all.sh Budapest
```

### Method 2: Native Packages (`conky-nextgen` — Testing / WIP)

> [!WARNING]
> **Package status notice:**
> - The standalone `conky-nextgen` packages were **freshly created today** and are currently in **active testing / unstable (WIP)**. There may still be minor edge cases or packaging bugs.
> - **Debian / Ubuntu (.deb):** Initial live testing has been completed successfully on Ubuntu 26.04.
> - **Arch Linux (AUR / PKGBUILD):** The `PKGBUILD` and build scripts are provided in `pkg/aur/`, but **have NOT been tested on live Arch Linux yet**. Testers and community feedback are welcome!
> - **Rock-solid fallback:** If you encounter any packaging issues, cloning the repository directly (**Method 1**) and launching widgets via `conky -c <widget>.conf` (or `conky -c akarmi.conf`) is completely independent, mature, and guaranteed to work out of the box.

To install and test the Debian/Ubuntu package:
```bash
sudo apt install ./pkg/conky-nextgen_1.0.0.*_all.deb
```

Once installed, it provides:
- CLI widget manager: `conky-nextgen start [widget]`, `conky-nextgen stop`, `conky-nextgen list`, `conky-nextgen status`
- Shell auto-completion: native Bash completion with Tab support for commands and widget names
- Visual Designer application launcher: `nextgen-designer`
- UNIX manual pages: `man conky-nextgen` and `man nextgen-designer`

### Customizing Widgets & Fixing "Show Desktop" (Win + D)

> [!TIP]
> **Conky Configuration Reference:**
> For the complete reference of all Conky window and layout settings, run **`man conky`**.
>
> In Conky 1.25+ (`conky-mng`), legacy options `own_window_argb_visual` (removed) and `own_window_transparent` (deprecated) are no longer needed. ARGB support is always enabled automatically, and background transparency is controlled directly with `own_window_color` using an alpha channel (e.g. `'#0000'` for fully transparent background, or `'#8000'` for semi-transparent).

System widgets installed under `/usr/share/conky-nextgen/` are read-only templates. To customize widget positions or window behavior:

1. **Copy the widget to your home directory:**
   ```bash
   # Copy all templates to ~/.conky:
   conky-nextgen init ~/.conky

   # Or copy an individual widget:
   cp /usr/share/conky-nextgen/clock_cal.conf ~/.conky/akarmi.conf
   ```

2. **Prevent disappearing on "Show Desktop" (`Win + D` / `Super + D`):**
   In desktop environments like MATE, XFCE, or GNOME, pressing `Win+D` may minimize Conky if `own_window_type` is not tailored to your compositor.
   
   Edit your `~/.conky/akarmi.conf` file:
   ```lua
   conky.config = {
       -- Output backend (Conky 1.25+):
       output_backend = 'x11',

       -- Window behavior settings (see man conky for all options):
       own_window = true,
       own_window_color = '#0000',  -- fully transparent background in Conky 1.25+
       own_window_class = 'Conky',

       -- Option A: 'normal' with below/sticky hints (best for mouse clicks in MATE / XFCE)
       own_window_type = 'normal',
       own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',

       -- Option B: 'desktop' (pinned to root desktop, immune to Win+D in most DEs)
       -- own_window_type = 'desktop',

       -- Option C: 'dock' (treated as a system panel, stays below/above windows)
       -- own_window_type = 'dock',

       -- Screen coordinates:
       alignment = 'top_right',
       gap_x = 20,
       gap_y = 50,
   }
   ```

3. **Launch your customized widget:**
   ```bash
   conky -c ~/.conky/akarmi.conf
   # Or using the CLI:
   conky-nextgen start akarmi
   ```

The Designer writes widget files atomically and sends `SIGUSR1` to reload the
live preview without restarting the Conky process.

## Included widgets

Every root-level `.conf` file starts the matching `.lua` widget. The complete suite of 20 widgets includes:

| Widget | Purpose | Distribution Support |
|---|---|---|
| `clock_cal`, `clock_cal_combi` | analog clock and interactive multi-view calendar | Universal |
| `cpu`, `mem_swap` | CPU usage, per-core metrics, RAM and Swap usage | Universal |
| `disk`, `disk_2_bars` | storage usage, I/O rates, and NVMe temperatures | Universal |
| `nvidia` | NVIDIA GPU temperature, VRAM usage, and NVML metrics | Universal (NVML) |
| `info`, `left` | system dashboard, kernel, uptime, session, and package updates | Ubuntu (APT / Security) & Arch (Repo / AUR) |
| `top` | interactive process monitor (top CPU vs top memory consumers) | Universal |
| `network`, `wifi`, `vnstat` | network interface traffic, ping latency, session & monthly stats | Universal |
| `weather` | multi-view weather (current conditions, hourly, 7-day forecast, air quality) | Universal |
| `now-playing`, `lyrics` | media player tracker with synchronized live lyrics (Audacious, MPRIS) | Universal |
| `tux` | Tux mascot with dynamic distribution branding | Ubuntu & Arch / Manjaro |
| `visualizer` | audio visualizer (CAVA integration) | Universal |
| `google` | interactive web/search bookmarks panel | Universal |
| `widget` | Designer-managed general-purpose widget | Universal |

## Screenshots

| Clock and calendar | Calendar view | System information |
|:---:|:---:|:---:|
| ![Clock and calendar](screenshots/clock_cal.png) | ![Calendar](screenshots/clock_cal_calendar.png) | ![System information](screenshots/info.png) |

| CPU | CPU alternative view | Memory and swap |
|:---:|:---:|:---:|
| ![CPU](screenshots/cpu_main.png) | ![CPU alternative view](screenshots/cpu_view_1.png) | ![Memory and swap](screenshots/mem_swap.png) |

| Disk | NVIDIA GPU | Top processes | Top processes alternative view |
|:---:|:---:|:---:|:---:|
| ![Disk](screenshots/disk.png) | ![NVIDIA GPU](screenshots/nvidia.png) | ![Top processes](screenshots/top.png) | ![Top processes alternative view](screenshots/top_view_1.png) |

| Current weather | Hourly forecast | Daily forecast |
|:---:|:---:|:---:|
| ![Current weather](screenshots/weather.png) | ![Hourly forecast](screenshots/weather_view_1.png) | ![Daily forecast](screenshots/weather_view_2.png) |

![Designer](screenshots/designer.png)

## Designer

Run the GTK3 Designer with:

```bash
python3 sh/designer/main.py
```

It edits `widget.lua` and `widget.conf`, provides a live Conky preview, and
includes widget, theme, view, group, mouse, weather, and Conky configuration
controls. Module profiles are fixed checkboxes in the left-side **Profile**
panel, so selecting them does not cover any other control.

Profiles choose data modules while every visual renderer remains available:

| Profile | Loads data for |
|---|---|
| `basic` | no additional data source |
| `weather` | weather, alerts, air quality, sun, moon, city, and icons |
| `system` | hardware, battery, DMI, MTP, network, sensors, and USB |
| `media` | now-playing and song-text data |
| `panel` | panel system data |
| `google` | Google cache data |
| `full` | weather, system, media, and Google data |

Profiles can be combined, for example:

```lua
MODULE_PROFILE = { "weather", "media" }
```

`full` is exclusive. Invalid profile definitions, missing required modules,
and invalid Lua renderer expressions fail explicitly instead of being silently
ignored.

## Fetching data

All fetchers are Bash scripts. Run them with `bash`, not a generic `sh`
wrapper. They update the generated `tmp/` cache, which is intentionally not
stored in Git.

| Command | Purpose |
|---|---|
| `bash sh/fetch_all.sh` | fetch all regular data |
| `bash sh/fetch_all.sh weather` | fetch weather only |
| `bash sh/fetch_all.sh alerts` | fetch MeteoAlarm alerts |
| `bash sh/fetch_all.sh map` | fetch weather maps |
| `bash sh/fetch_all.sh nowplaying` | fetch media-player data (Audacious, MPRIS) |
| `bash sh/fetch_all.sh network` | fetch ping and public-IP data |
| `bash sh/fetch_all.sh google` | fetch optional Google data through `gog` |
| `bash sh/updates.sh` | universal update dispatcher (APT on Ubuntu, pacman/AUR on Arch) |
| `bash sh/fetch_updates_ubuntu.sh` | fetch Ubuntu APT and Security update counts |
| `bash sh/fetch_updates.sh` | fetch Arch Linux repo and AUR update counts |
| `lua lua/lyrics_daemon.lua` | standalone synchronized lyrics synchronizer (Audacious / LRCLIB) |

For periodic refreshes, use Bash explicitly in cron:

```cron
0 * * * * /bin/bash /path/to/conky-nextgen/sh/fetch_all.sh && /bin/bash /path/to/conky-nextgen/sh/updates.sh
```

## Requirements

Package names vary between distributions. The project needs:

- Conky built with Lua, Cairo, Xft, Imlib2, and RSVG support;
- Python 3 with PyGObject/GTK3 for the Designer;
- Bash, `curl`, `jq`, and `python3` for the fetcher framework;
- Lua bindings including `cairo`, `rsvg`, `imlib2`, `lfs`, and `dkjson`;
- `ImageMagick` for map images and `ping` for network latency;
- optional tools according to enabled modules: `playerctl`, `cmus-remote`,
  `mpc`, `mocp`, `gog`, `lm-sensors`, `upower`, and Arch package tools.

## Project layout

```text
.
├── *.lua / *.conf   standalone widget bundles
├── debug/           renderer stress tests and diagnostics
├── icons/           weather, moon, wind, and UI assets
├── language/        gettext catalogs and translation template
├── lua/             core engine, renderers, and data modules
├── panel_systray/   panel and systray helper sources/configuration
├── pkg/             package build files and patches
├── sh/              fetchers and the GTK3 Designer
├── tools/           development utilities
└── tmp/             generated runtime cache
```

## Documentation and validation

The detailed, source-derived reference is in
[NextGen.md](NextGen.md). It documents the renderer properties, Lua modules,
fetchers, Designer components, profiles, translations, panel integration, and
debug tooling.

Run the Designer schema and round-trip regression test with:

```bash
cd sh/designer
python3 tests/test_widget_schema.py
```
