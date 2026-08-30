#!/bin/bash

_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/0_common.sh"

NETWORK_DIR="$TMP_DIR"

fetch_ping() {
	local out="$NETWORK_DIR/network_ping.json"
	ping -c 3 -q 1.1.1.1 2>/dev/null > "$out.tmp" || true
	mv "$out.tmp" "$out"
}

fetch_ipinfo() {
	local out="$NETWORK_DIR/network_ip.json"
	curl_cmd "https://ipinfo.io/json" > "$out.tmp" || { rm -f "$out.tmp"; return 1; }
	[ -s "$out.tmp" ] || { rm -f "$out.tmp"; return 1; }
	mv "$out.tmp" "$out"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	fetch_ping &
	fetch_ipinfo &
	wait
fi
