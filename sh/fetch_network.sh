#!/bin/bash
#[[
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#]]
# fetch_network.sh — Background ping + public IP fetcher
# Writes results to tmp/network_ping.json and tmp/network_ip.json
# Usage: ./fetch_network.sh

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
	curl_cmd "https://ipinfo.io" > "$out.tmp" || { rm -f "$out.tmp"; return 1; }
	[ -s "$out.tmp" ] || { rm -f "$out.tmp"; return 1; }
	mv "$out.tmp" "$out"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	fetch_ping &
	fetch_ipinfo &
	wait
fi
