#!/usr/bin/env bash
# Toggle the popup calendar above the panel clock (first click: start, second click: stop)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/calendar_popup.conf"

if pgrep -f "conky.*calendar_popup\.conf" >/dev/null 2>&1; then
    pkill -f "conky.*calendar_popup\.conf"
else
    conky -c "$CONF" >/dev/null 2>&1 &
fi
