#!/usr/bin/env bash
# Toggle the Clipboard History popup above the panel
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/clip_popup.conf"

if pgrep -f "conky.*clip_popup\.conf" >/dev/null 2>&1; then
    pkill -f "conky.*clip_popup\.conf"
else
    conky -c "$CONF" >/dev/null 2>&1 &
fi
