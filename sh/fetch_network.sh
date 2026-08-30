#!/bin/bash
#{{{
# ## fetch_network — network metrics fetcher
#
# Defines fetch_ping() and fetch_ipinfo(), which collect connectivity and
# public-IP data. fetch_ping pings 1.1.1.1 three times and saves the raw
# output, while fetch_ipinfo downloads the ipinfo.io geolocation JSON. Both
# write into TMP_DIR; running the script standalone launches the two in
# parallel and waits.
#
# **What it does:**
# - fetch_ping(): ping probe → $TMP_DIR/network_ping.json
# - fetch_ipinfo(): over HTTPS → $TMP_DIR/network_ip.json
# - When run directly, starts both fetchers as background jobs
#
# **Environment/requirements:** needs 0_common.sh (curl_cmd, TMP_DIR) and
# the system `ping` command
#}}}
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
