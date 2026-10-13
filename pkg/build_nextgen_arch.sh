#!/usr/bin/env bash
set -euo pipefail

# Conky-NextGen Arch Linux Package (.pkg.tar.zst) Builder
# Maintainer: István Molnár <molnari811023@gmail.com>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(readlink -f "$SCRIPT_DIR/..")"
STAGE_DIR="$SCRIPT_DIR/stage-arch"
PKGNAME="conky-nextgen-git"

echo "==> [1/5] Verziószám meghatározása..."
BASE_VER="1.1.0"
[ -f "$PROJECT_DIR/VERSION" ] && BASE_VER=$(tr -d ' \r\n' < "$PROJECT_DIR/VERSION")
REV_COUNT=$(git -C "$PROJECT_DIR" rev-list --count HEAD 2>/dev/null || echo "150")
SHORT_SHA=$(git -C "$PROJECT_DIR" rev-parse --short HEAD 2>/dev/null || echo "custom")
VERSION="${BASE_VER}.r${REV_COUNT}.g${SHORT_SHA}-1"
PKG_FILE="$SCRIPT_DIR/${PKGNAME}-${VERSION}-any.pkg.tar.zst"

echo "    Csomag: $PKGNAME"
echo "    Verzió: $VERSION"

echo "==> [2/5] Staging könyvtár felépítése..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/usr/share/conky-nextgen"
mkdir -p "$STAGE_DIR/usr/bin"
mkdir -p "$STAGE_DIR/usr/share/applications"
mkdir -p "$STAGE_DIR/usr/share/icons/hicolor/scalable/apps"
mkdir -p "$STAGE_DIR/usr/share/man/man1"

echo "==> [3/5] Fájlok másolása és jogosultságok beállítása..."
cp -a "$PROJECT_DIR/lua" "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR/icons" "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR/images" "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR/language" "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR/sh" "$STAGE_DIR/usr/share/conky-nextgen/"

cp -a "$PROJECT_DIR"/*.conf "$STAGE_DIR/usr/share/conky-nextgen/"
cp -a "$PROJECT_DIR"/*.lua "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/cava_visualizer.ini" ] && cp -a "$PROJECT_DIR/cava_visualizer.ini" "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/left.png" ] && cp -a "$PROJECT_DIR/left.png" "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/nd.svg" ] && cp -a "$PROJECT_DIR/nd.svg" "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/NextGen.md" ] && cp -a "$PROJECT_DIR/NextGen.md" "$STAGE_DIR/usr/share/conky-nextgen/"
[ -f "$PROJECT_DIR/README.md" ] && cp -a "$PROJECT_DIR/README.md" "$STAGE_DIR/usr/share/conky-nextgen/"
echo "$VERSION" > "$STAGE_DIR/usr/share/conky-nextgen/VERSION"

find "$STAGE_DIR/usr/share/conky-nextgen" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$STAGE_DIR/usr/share/conky-nextgen" -type f -name "*.pyc" -delete
find "$STAGE_DIR/usr/share/conky-nextgen" -type f \( -name "*.orig" -o -name "*~" \) -delete

find "$STAGE_DIR/usr/share/conky-nextgen" -type d -exec chmod 755 {} +
find "$STAGE_DIR/usr/share/conky-nextgen" -type f -exec chmod 644 {} +
find "$STAGE_DIR/usr/share/conky-nextgen/sh" -type f -name "*.sh" -exec chmod 755 {} +
[ -f "$STAGE_DIR/usr/share/conky-nextgen/sh/designer/main.py" ] && chmod 755 "$STAGE_DIR/usr/share/conky-nextgen/sh/designer/main.py"

# CLI indító
install -m 755 "$PROJECT_DIR/sh/conky-nextgen" "$STAGE_DIR/usr/bin/conky-nextgen"
sed -i "s/^CONKY_NEXTGEN_BUILD_VERSION=.*/CONKY_NEXTGEN_BUILD_VERSION=\"$VERSION\"/" "$STAGE_DIR/usr/bin/conky-nextgen"

# Designer indító
cat << 'EOF' > "$STAGE_DIR/usr/bin/nextgen-designer"
#!/bin/sh
exec python3 /usr/share/conky-nextgen/sh/designer/main.py "$@"
EOF
chmod 755 "$STAGE_DIR/usr/bin/nextgen-designer"

# Man oldalak
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

# Asztali ikon és .desktop
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

echo "==> [4/5] Arch .PKGINFO létrehozása..."
INSTALLED_SIZE=$(du -sb "$STAGE_DIR" | cut -f1)
BUILD_DATE=$(date +%s)

cat << EOF > "$STAGE_DIR/.PKGINFO"
# Generated for Arch Linux / pacman
pkgname = $PKGNAME
pkgbase = $PKGNAME
xdata = pkgtype=pkg
pkgver = $VERSION
pkgdesc = Modular Conky theme framework, widget manager, and GTK3 visual designer
url = https://github.com/molnari811023/conky-nextgen
builddate = $BUILD_DATE
packager = István Molnár <molnari811023@gmail.com>
size = $INSTALLED_SIZE
arch = any
license = GPL-3.0-or-later
conflict = conky-nextgen
provides = conky-nextgen
depend = conky-mng
depend = lua
depend = lua-filesystem
depend = lua-dkjson
depend = lua-expat
depend = lua-sec
depend = lua-socket
depend = python
depend = python-gobject
depend = gtk3
depend = gtksourceview4
depend = python-pillow
depend = curl
depend = jq
depend = bc
depend = lm_sensors
depend = procps-ng
depend = psmisc
optdepend = cava: audio spectrum visualizer widget
optdepend = vnstat: network bandwidth traffic tracker
optdepend = playerctl: media player status and controls
optdepend = pacman-contrib: Arch package updates monitor
EOF

echo "==> [5/5] Arch .pkg.tar.zst csomag tömörítése..."
(
    cd "$STAGE_DIR"
    tar --zstd --owner=0 --group=0 --numeric-owner -cf "$PKG_FILE" .PKGINFO usr
)
rm -rf "$STAGE_DIR"

echo "=========================================================="
echo " SIKERES ARCH CSOMAGOLÁS!"
echo " Létrejött Arch csomag: $PKG_FILE"
echo " Telepítés Arch / Manjaro alatt:"
echo "   sudo pacman -U $PKG_FILE"
echo "=========================================================="
