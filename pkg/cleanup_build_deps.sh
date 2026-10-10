#!/usr/bin/env bash
set -euo pipefail

# Cleanup script: removes compilation tools and -dev header packages
# Note: Run this AFTER installing conky-mng so its runtime libraries are preserved!

echo "==> Fordítási és -dev függőségek eltávolítása..."
sudo apt purge -y \
  cmake gperf pandoc python3-jinja2 gettext checkinstall \
  libcairo2-dev libcurl4-openssl-dev libfontconfig1-dev libglib2.0-dev libimlib2-dev \
  libical-dev libircclient-dev libmicrohttpd-dev libpulse-dev librsvg2-dev \
  libx11-dev libxdamage-dev libxext-dev libxfixes-dev libxft-dev libxinerama-dev \
  libxml2-dev libxnvctrl-dev libmariadb-dev libncurses-dev \
  libpango1.0-dev libsystemd-dev libwayland-dev wayland-protocols libiw-dev \
  libaudclient-dev audacious-dev libdbus-glib-1-dev liblua5.4-dev

echo "==> Árva függőségek kitakarítása..."
sudo apt autoremove -y

echo "==> Kész! A rendszer tiszta, a conky-mng futásidejű csomagjai megmaradtak."
