#!/usr/bin/env bash
# Toggle the Conky NextGen Start Menu popup on/off
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/start_menu.conf"

if pgrep -f "conky.*start_menu\.conf" >/dev/null 2>&1; then
    pkill -f "conky.*start_menu\.conf"
else
    conky -c "$CONF" >/dev/null 2>&1 &
fi
