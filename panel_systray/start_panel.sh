#!/usr/bin/env bash
# Conky NextGen — Universal X11 & Wayland Panel Launcher
# Both Conky (panel.conf) and panel_systray automatically switch between
# Wayland and X11 at startup.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

killall -q panel_systray conky_wayland_tasklist conky_wayland_systray conky_wayland_volume 2>/dev/null || true
pkill -f "conky -c ${DIR}/panel.conf" 2>/dev/null || true
pkill -f "conky.*start_menu\.conf" 2>/dev/null || true
pkill -f "conky -c /home/molnar/.conky/panel_systray_wayland_experiment/test_panel.conf" 2>/dev/null || true
sleep 0.2

if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP SWAYSOCK DISPLAY 2>/dev/null || true
elif [ -z "${WAYLAND_DISPLAY:-}" ] && command -v xsettingsd >/dev/null 2>&1 && ! pgrep -x xsettingsd >/dev/null 2>&1; then
    xsettingsd >/dev/null 2>&1 &
    sleep 0.2
fi

conky -c "${DIR}/panel.conf" >/dev/null 2>&1 &
"${DIR}/panel_systray" >/dev/null 2>&1 &

if command -v nm-applet >/dev/null 2>&1 && ! pgrep -x nm-applet >/dev/null 2>&1; then
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then
        nm-applet --indicator >/dev/null 2>&1 &
    else
        nm-applet >/dev/null 2>&1 &
    fi
fi

echo "Conky NextGen Universal Panel started."
