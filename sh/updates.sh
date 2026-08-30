#!/bin/bash

require_cmds() { local m=0; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || { echo "[error] Missing: $c"; m=1; }; done; [ "$m" -eq 1 ] && exit 1; }
require_cmds curl jq pacman vercmp checkupdates

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONKY_DIR="$(readlink -f "$SCRIPT_DIR/..")"
TMP_DIR="$CONKY_DIR/tmp"
OUT="$TMP_DIR/updates.txt"
mkdir -p "$TMP_DIR"
repo=$(checkupdates 2>/dev/null | wc -l)
aur=0
aur_pkgs=$(pacman -Qm 2>/dev/null | awk '{print $1}')
if [ -n "$aur_pkgs" ]; then
	args=""
	for pkg in $aur_pkgs; do
		args="$args&arg[]=$pkg"
	done
	json=$(curl -s -f --max-time 10 "https://aur.archlinux.org/rpc?v=5&type=info$args" 2>/dev/null)
	if [ -n "$json" ]; then
		names_json=$(echo "$json" | jq -r '.results[] | "\(.Name) \(.Version)"' 2>/dev/null)
		if [ -n "$names_json" ]; then
			while read -r name ver; do
				[ -z "$name" ] && continue
				local_ver=$(pacman -Q "$name" 2>/dev/null | awk '{print $2}')
				if [ -n "$local_ver" ] && vercmp "$local_ver" "$ver" | grep -q "^-1"; then
					aur=$((aur+1))
				fi
			done <<< "$names_json"
		fi
	fi
fi
echo "$repo $aur" > "$OUT"
