#!/usr/bin/env bash
# Toggle the Bluetooth popup above the panel Bluetooth indicator
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/bt_popup.conf"

if pgrep -f "conky.*bt_popup\.conf" >/dev/null 2>&1; then
    pkill -f "conky.*bt_popup\.conf"
else
    conky -c "$CONF" >/dev/null 2>&1 &
fi
