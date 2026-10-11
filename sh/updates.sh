#!/bin/bash
# Conky NextGen — update check dispatcher
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

if command -v pacman >/dev/null 2>&1; then
    exec "$SCRIPT_DIR/fetch_updates.sh" "$@"
elif command -v apt-get >/dev/null 2>&1 || command -v apt >/dev/null 2>&1; then
    exec "$SCRIPT_DIR/fetch_updates_ubuntu.sh" "$@"
fi
