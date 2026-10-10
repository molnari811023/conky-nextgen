#!/usr/bin/env bash
set -euo pipefail

# Conky-MNG Debian Package Builder for Ubuntu / Debian
# Maintainer: István Molnár <molnari811023@gmail.com>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src/conky"
BUILD_DIR="$SRC_DIR/build"
STAGE_DIR="$SCRIPT_DIR/deb-stage"
PKGNAME="conky-mng"

echo "==> [1/6] Frissítés / Letöltés a Conky Git tárolóból..."
mkdir -p "$SCRIPT_DIR/src"
if [ ! -d "$SRC_DIR/.git" ]; then
  git clone https://github.com/brndnmtthws/conky.git "$SRC_DIR"
else
  (cd "$SRC_DIR" && git pull --tags origin main || git fetch --tags)
fi

echo "==> [2/6] Verziószám meghatározása..."
cd "$SRC_DIR"
GIT_VER=$(git describe --long --tags --abbrev=7 2>/dev/null | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g' || echo "1.25.3")
DEB_VER="${GIT_VER}-1"
DEB_FILE="$SCRIPT_DIR/${PKGNAME}_${DEB_VER}_amd64.deb"

echo "    Csomag verzió: $DEB_VER"

echo "==> [3/6] CMake konfigurálás és fordítás..."
cmake -B "$BUILD_DIR" -S "$SRC_DIR" \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX=/usr \
  -D CMAKE_INSTALL_DATAROOTDIR=/usr/share \
  -D BUILD_DOCS=ON \
  -D BUILD_EXTRAS=ON \
  -D BUILD_WLAN=ON \
  -D BUILD_XDBE=ON \
  -D BUILD_XSHAPE=ON \
  -D BUILD_IMLIB2=ON \
  -D BUILD_CURL=ON \
  -D BUILD_RSS=ON \
  -D BUILD_NVIDIA_NVML=ON \
  -D BUILD_PULSEAUDIO=ON \
  -D BUILD_JOURNAL=ON \
  -D BUILD_WAYLAND=ON \
  -D BUILD_X11=ON \
  -D BUILD_MOUSE_EVENTS=ON \
  -D BUILD_LUA_CAIRO=ON \
  -D BUILD_LUA_CAIRO_XLIB=ON \
  -D BUILD_LUA_IMLIB2=ON \
  -D BUILD_LUA_RSVG=ON \
  -D BUILD_I18N=ON \
  -D BUILD_COLOUR_NAME_MAP=ON \
  -D BUILD_ICAL=ON \
  -D BUILD_HTTP=ON \
  -D BUILD_MYSQL=ON \
  -D mysql_INCLUDE_PATH=/usr/include/mariadb \
  -D MYSQLCLIENT_LIB=/usr/lib/x86_64-linux-gnu/libmariadb.so \
  -D BUILD_IRC=ON \
  -D BUILD_ICONV=ON \
  -D BUILD_OPENSOUNDSYS=ON \
  -D BUILD_AUDACIOUS=ON \
  -D DOC_PATH=share/doc/$PKGNAME

cmake --build "$BUILD_DIR" -j"$(nproc)"

echo "==> [4/6] Előkészítés staging könyvtárba..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR/DEBIAN"

DESTDIR="$STAGE_DIR" cmake --install "$BUILD_DIR"

# Felesleges statikus könyvtár eltávolítása
rm -f "$STAGE_DIR/usr/lib/libtcp-portmon.a"

# Extra fájlok másolása
install -vDm 644 "$SRC_DIR/COPYING" "$STAGE_DIR/usr/share/doc/$PKGNAME/copyright"
install -vDm 644 "$SRC_DIR/extras/vim/ftdetect/conkyrc.vim" "$STAGE_DIR/usr/share/vim/vimfiles/ftdetect/conkyrc.vim"
mkdir -p "$STAGE_DIR/usr/share/vim/vimfiles/syntax"
if [ -f "$STAGE_DIR/usr/share/vim/syntax/conkyrc.vim" ]; then
  install -vDm 644 "$STAGE_DIR/usr/share/vim/syntax/conkyrc.vim" "$STAGE_DIR/usr/share/vim/vimfiles/syntax/conkyrc.vim"
fi

# Binárisok tömörítése (strip)
strip --strip-unneeded "$STAGE_DIR/usr/bin/conky" "$STAGE_DIR/usr/lib/conky/"*.so

echo "==> [5/6] DEBIAN/control létrehozása..."
cat << EOF > "$STAGE_DIR/DEBIAN/control"
Package: $PKGNAME
Version: $DEB_VER
Section: utils
Priority: optional
Architecture: amd64
Maintainer: István Molnár <molnari811023@gmail.com>
Provides: conky
Conflicts: conky, conky-all, conky-std
Replaces: conky, conky-all, conky-std
Depends: libc6, libstdc++6, libgcc-s1, libcairo2, libcurl4t64, libfontconfig1, libglib2.0-0t64, libimlib2t64, libical3t64, libircclient1, libmicrohttpd12t64, libpulse0, librsvg2-2, libx11-6, libxdamage1, libxext6, libxfixes3, libxft2, libxinerama1, libxi6, libxml2-16, liblua5.4-0, libmariadb3, libncurses6, libpango-1.0-0, libpangocairo-1.0-0, libsystemd0, libwayland-client0, libiw30t64, libaudclient2, libdbus-glib-1-2
Description: Light-weight system monitor for X, Wayland, and other things, too — with mouse events and audacious
 Conky is an advanced, highly configurable system monitor for X and Wayland
 based on torsmo.
 This package is compiled with mouse events, Lua Cairo/Imlib2/RSVG, Nvidia NVML,
 PulseAudio, Wayland, and Audacious support.
EOF

echo "==> [6/6] .deb csomag összeállítása..."
dpkg-deb -Zzstd --root-owner-group --build "$STAGE_DIR" "$DEB_FILE"
rm -rf "$STAGE_DIR"

echo "=========================================================="
echo " SIKERES CSOMAGOLÁS!"
echo " Létrejött csomag: $DEB_FILE"
echo " Telepítés:"
echo "   sudo dpkg -i $DEB_FILE"
echo "=========================================================="
