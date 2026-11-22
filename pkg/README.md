# Conky NextGen — Local Package Recipes (`pkg/`)

This directory contains standalone Arch Linux (`PKGBUILD`) recipes and build scripts specifically tailored for Conky NextGen and its device telemetry backends.

---

## 📦 Included Packages

| Directory | Package Name | Purpose | Notes |
| :--- | :--- | :--- | :--- |
| `pkg/` | `conky-mng` | Conky C++ engine with mouse events | Replaces standard `conky` with interactive event hooks |
| `pkg/aur/` | `conky-nextgen-git` | Main Conky NextGen suite & GTK3 Designer | Primary framework package |
| `pkg/python-pyicloud/` | `python-pyicloud` | Apple iCloud & Find My iOS telemetry | Modern 2026.11.x release (the AUR version is outdated) |
| `pkg/googlefindmytools-git/` | `googlefindmytools-git` | Android Google Find My Device API | E2EE Spot & Nova protocol support |

---

## ⚠️ Important: AUR Dependencies & `makepkg` Notice

These local package recipes are maintained directly within this project.

When building a package with:
```bash
makepkg -si
```
`makepkg` attempts to automatically install missing dependencies using standard `pacman`. 

> [!IMPORTANT]
> If `makepkg -si` fails with an error such as:
> ```text
> error: target not found: <dependency-name>
> ==> ERROR: 'pacman' failed to install missing dependencies.
> ```
> this means the missing dependency is hosted on the **AUR** (Arch User Repository) rather than the official Arch Linux core/extra repositories (`pacman` cannot fetch AUR packages directly).

### Resolution:
Install the missing dependencies from the AUR using your AUR helper (`yay` or `paru`) before running `makepkg`, or build them from the AUR beforehand:

#### For `googlefindmytools-git`:
```bash
# Install required AUR dependencies first:
yay -S --needed python-gpsoauth python-http-ece python-pyscrypt python-undetected-chromedriver

# Then build and install the package:
cd ~/.conky/pkg/googlefindmytools-git
makepkg -si
```

#### For `python-pyicloud` (Bundled Dependencies & Conflict Handling):
The official `python-pyicloud` package in the AUR is severely outdated. This local recipe provides the modern 2026.11.x release and **bundles** the latest verified versions of:
- `python-srp` (1.0.22)
- `python-tinyhtml` (1.3.0)

```bash
cd ~/.conky/pkg/python-pyicloud
makepkg -si
```

> [!NOTE]
> If `pacman` asks to replace or warns about a conflict with an existing `python-srp` or `python-tinyhtml` package on your system, select **YES (Y/I)**. `python-pyicloud` explicitly provides both libraries and satisfies system dependencies.

---

## 🛠️ Automated Arch Tarball Builder

To generate a ready-to-install `.pkg.tar.zst` package directly from your active working tree:
```bash
cd ~/.conky/pkg
./build_nextgen_arch.sh
```
Install the resulting package with:
```bash
sudo pacman -U conky-nextgen-git-*.pkg.tar.zst
```
