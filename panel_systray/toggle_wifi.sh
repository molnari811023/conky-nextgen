#!/usr/bin/env bash
# Toggle the Wi-Fi popup above the panel Wi-Fi indicator
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/wifi_popup.conf"

if pgrep -f "conky.*wifi_popup\.conf" >/dev/null 2>&1; then
    pkill -f "conky.*wifi_popup\.conf"
else
    conky -c "$CONF" >/dev/null 2>&1 &
fi
