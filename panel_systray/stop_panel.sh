#!/usr/bin/env bash
# Conky NextGen — Stop Universal Panel

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

killall -q panel_systray conky_wayland_tasklist conky_wayland_systray conky_wayland_volume 2>/dev/null || true
pkill -f "conky -c ${DIR}/panel.conf" 2>/dev/null || true
pkill -f "conky.*start_menu\.conf" 2>/dev/null || true
pkill -f "conky.*calendar_popup\.conf" 2>/dev/null || true
pkill -f "conky -c /home/molnar/.conky/panel_systray_wayland_experiment/test_panel.conf" 2>/dev/null || true
echo "Conky NextGen Universal Panel stopped."
