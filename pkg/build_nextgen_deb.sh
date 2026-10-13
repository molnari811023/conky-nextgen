#!/usr/bin/env bash
set -euo pipefail

# Conky-NextGen Debian Package Builder for Ubuntu / Debian
# Maintainer: István Molnár <molnari811023@gmail.com>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(readlink -f "$SCRIPT_DIR/..")"
STAGE_DIR="$SCRIPT_DIR/stage-nextgen"
PKGNAME="conky-nextgen"

echo "==> [1/5] Verziószám meghatározása..."
BASE_VER="1.1.0"
[ -f "$PROJECT_DIR/VERSION" ] && BASE_VER=$(tr -d ' \r\n' < "$PROJECT_DIR/VERSION")
REV_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD 2>/dev/null || echo "150")
SHORT_SHA=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "custom")
VERSION="${BASE_VER}.r${REV_COUNT}.g${SHORT_SHA}-1"
DEB_FILE="$SCRIPT_DIR/${PKGNAME}_${VERSION}_all.deb"

echo "    Csomag: $PKGNAME"
echo "    Verzió: $VERSION"

echo "==> [2/5] Staging könyvtár felépítése..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/DEBIAN"
mkdir -p "$STAGE_DIR/usr/share/conky-nextgen"
mkdir -p "$STAGE_DIR/usr/bin"
mkdir -p "$STAGE_DIR/usr/share/applications"
mkdir -p "$STAGE_DIR/usr/share/icons/hicolor/scalable/apps"

echo "==> [3/5] Fájlok másolása és jogosultságok beállítása..."
# NextGen fájlok másolása /usr/share/conky-nextgen alá
cp -a "$PROJECT_DIR/lua" "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR/icons" "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR/images" "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR/language" "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR/sh" "$STAGE_DIR/usr/share/conky-nextgen/"

# Konfigurációk és gyökér widget fájlok
cp -a "$PROJECT_DIR"/*.conf "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR"/*.lua "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/cava_visualizer.ini" ] && cp -a "$PROJECT_DIR/cava_visualizer.ini" "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/left.png" ] && cp -a "$PROJECT_DIR/left.png" "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/nd.svg" ] && cp -a "$PROJECT_DIR/nd.svg" "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/NextGen.md" ] && cp -a "$PROJECT_DIR/NextGen.md" "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/README.md" ] && cp -a "$PROJECT_DIR/README.md" "$STAGE_DIR/usr/share/conky-nextgen/"
echo "$VERSION" > "$STAGE_DIR/usr/share/conky-nextgen/VERSION"

# Felesleges cache és ideiglenes fájlok takarítása
find "$STAGE_DIR/usr/share/conky-nextgen" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$STAGE_DIR/usr/share/conky-nextgen" -type f -name "*.pyc" -delete
find "$STAGE_DIR/usr/share/conky-nextgen" -type f \( -name "*.orig" -o -name "*~" \) -delete

# Jogosultságok: mappák 755, fájlok 644, sh scriptek 755
find "$STAGE_DIR/usr/share/conky-nextgen" -type d -exec chmod 755 {} +
find "$STAGE_DIR/usr/share/conky-nextgen" -type f -exec chmod 644 {} +
find "$STAGE_DIR/usr/share/conky-nextgen/sh" -type f -name "*.sh" -exec chmod 755 {} +
[ -f "$STAGE_DIR/usr/share/conky-nextgen/sh/designer/main.py" ] && chmod 755 "$STAGE_DIR/usr/share/conky-nextgen/sh/designer/main.py"

mkdir -p "$STAGE_DIR/usr/share/man/man1"

# /usr/bin CLI és Designer indítók
install -m 755 "$PROJECT_DIR/sh/conky-nextgen" "$STAGE_DIR/usr/bin/conky-nextgen"
sed -i "s/^CONKY_NEXTGEN_BUILD_VERSION=.*/CONKY_NEXTGEN_BUILD_VERSION=\"$VERSION\"/" "$STAGE_DIR/usr/bin/conky-nextgen"

cat << 'EOF' > "$STAGE_DIR/usr/bin/nextgen-designer"
#!/bin/sh
exec python3 /usr/share/conky-nextgen/sh/designer/main.py "$@"
EOF
chmod 755 "$STAGE_DIR/usr/bin/nextgen-designer"

# Man oldalak (man conky-nextgen és man nextgen-designer)
if [ -f "$PROJECT_DIR/man/conky-nextgen.1" ]; then
    gzip -9cn "$PROJECT_DIR/man/conky-nextgen.1" > "$STAGE_DIR/usr/share/man/man1/conky-nextgen.1.gz"
    chmod 644 "$STAGE_DIR/usr/share/man/man1/conky-nextgen.1.gz"
fi
if [ -f "$PROJECT_DIR/man/nextgen-designer.1" ]; then
    gzip -9cn "$PROJECT_DIR/man/nextgen-designer.1" > "$STAGE_DIR/usr/share/man/man1/nextgen-designer.1.gz"
    chmod 644 "$STAGE_DIR/usr/share/man/man1/nextgen-designer.1.gz"
fi

# Bash completion
if [ -f "$PROJECT_DIR/completion/conky-nextgen" ]; then
    mkdir -p "$STAGE_DIR/usr/share/bash-completion/completions"
    install -m 644 "$PROJECT_DIR/completion/conky-nextgen" "$STAGE_DIR/usr/share/bash-completion/completions/conky-nextgen"
fi

# Asztali ikon és .desktop menübejegyzés
cp -a "$PROJECT_DIR/nd.svg" "$STAGE_DIR/usr/share/icons/hicolor/scalable/apps/nd.svg"
chmod 644 "$STAGE_DIR/usr/share/icons/hicolor/scalable/apps/nd.svg"

cat << 'EOF' > "$STAGE_DIR/usr/share/applications/nextgen-designer.desktop"
[Desktop Entry]
Name=NextGen Designer
GenericName=Conky Widget Designer
Comment=Visual GTK3 editor and live preview tool for Conky NextGen widgets
Exec=nextgen-designer
Icon=nd
Terminal=false
Type=Application
Categories=Settings;DesktopSettings;Utility;
Keywords=conky;designer;widget;monitor;nextgen;
EOF
chmod 644 "$STAGE_DIR/usr/share/applications/nextgen-designer.desktop"

echo "==> [4/5] DEBIAN/control létrehozása..."
cat << EOF > "$STAGE_DIR/DEBIAN/control"
Package: $PKGNAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: all
Maintainer: István Molnár <molnari811023@gmail.com>
Depends: conky-mng, lua-filesystem, lua-dkjson, lua-expat, lua-sec, lua-socket, python3, python3-gi, gir1.2-gtk-3.0, gir1.2-gtksource-4 | gir1.2-gtksource-3.0, python3-pil, curl, jq, bc, lm-sensors, procps, psmisc, libcanberra-gtk3-module
Recommends: playerctl, cava, vnstat
Homepage: https://github.com/molnari811023/conky-nextgen
Description: NextGen Conky theme framework and GTK visual designer
 Conky NextGen is a modular Conky framework with a Lua/Cairo renderer, Bash
 data fetchers, self-contained themed widgets, and a GTK3 visual Designer.
 It supports X11 and Wayland-capable Conky builds.
EOF

echo "==> [5/5] .deb csomag összeállítása..."
dpkg-deb -Zzstd --root-owner-group --build "$STAGE_DIR" "$DEB_FILE"
rm -rf "$STAGE_DIR"

# Másolás a dotfiles mappába ha létezik
DOTFILES_DIR="$HOME/Projektek/dotfiles_ubuntu"
if [ -d "$DOTFILES_DIR" ]; then
    cp -vf "$DEB_FILE" "$DOTFILES_DIR/"
    # Létrehozunk egy stabil conky-nextgen_latest_all.deb symlinket vagy másolatot is ha szükséges
fi

echo "=========================================================="
echo " SIKERES CSOMAGOLÁS!"
echo " Létrejött csomag: $DEB_FILE"
if [ -d "$DOTFILES_DIR" ]; then
    echo " Másolva a dotfiles-ba: $DOTFILES_DIR/$(basename "$DEB_FILE")"
fi
echo " Telepítés:"
echo "   sudo dpkg -i $DEB_FILE"
echo "=========================================================="
