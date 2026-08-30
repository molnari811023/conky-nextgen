#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## 0_common — shared shell environment for all fetch scripts
#
# Common bootstrap imported by the other fetch scripts. Defines the script,
# project and tmp directories, an idempotent include guard, a DEBUG/log()
# helper, a require_cmds() validator (curl, jq, python3), a persisted
# per-user User-Agent under ~/.config/conky-nextgen (auto-generated when not
# run from a TTY, prompted otherwise), the curl_cmd() wrapper used for all
# HTTP requests, and a urlencode() helper. Ensures CONFIG_DIR and TMP_DIR
# exist.
#
# **What it does:**
# - Computes _SCRIPT_DIR, CONKY_DIR and TMP_DIR from the script location
# - Provides log() (enabled via DEBUG) and require_cmds()
# - Loads/creates a User-Agent file and exposes it via $UA
# - Defines curl_cmd() (quiet, follows redirects, 15s timeout, 2 retries)
# - Defines urlencode() and creates the tmp dir
#
# **Environment/requirements:** requires curl, jq, python3
#}}}
[ -n "$_COMMON_LOADED" ] && return || _COMMON_LOADED=1

_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
CONKY_DIR="$(readlink -f "$_SCRIPT_DIR/..")"
TMP_DIR="$CONKY_DIR/tmp"

DEBUG=1
log() { [ "$DEBUG" -eq 1 ] && echo "$@"; }

require_cmds() {
	local m=0
	for c in "$@"; do
		command -v "$c" >/dev/null 2>&1 || { echo "[error] Missing: $c"; m=1; }
	done
	[ "$m" -eq 1 ] && exit 1
}
require_cmds curl jq python3

CONFIG_DIR="$HOME/.config/conky-nextgen"
UA_FILE="$CONFIG_DIR/user_agent.txt"
DEFAULT_UA="ConkyNextGen/1.0"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$UA_FILE" ]; then
	if [ ! -t 0 ]; then
		_host=$(cat /proc/sys/kernel/hostname 2>/dev/null || hostname 2>/dev/null || echo "unknown-host")
		UA_INPUT="ConkyNG-${_host}-$(date +%s)"
		echo "[setup] Auto-generated UA: $UA_INPUT"
	else
		echo "[setup] No User-Agent found. Example: MyConky/1.0"
		read -r -p "User-Agent: " UA_INPUT
	fi
	[ -z "$UA_INPUT" ] && UA_INPUT="$DEFAULT_UA"
	printf '%s\n' "$UA_INPUT" > "$UA_FILE"
	chmod 600 "$UA_FILE"
fi

read -r UA < "$UA_FILE"
UA="${UA//$'\n'/}"
log "[ua] Using UA: $UA"

curl_cmd() { command curl -s -L --max-time 15 --retry 2 -f -A "$UA" "$@"; }

urlencode() {
	python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

mkdir -p "$TMP_DIR"
