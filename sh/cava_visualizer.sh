#!/bin/bash
#{{{
#  Conky NextGen Framework (fork) — cava_visualizer.sh
#  by wim66
#
#  Starts `cava` in raw-ASCII output mode and keeps only its latest
#  frame in tmp/cava_bars.txt, for visualizer.lua to read each draw
#  call. Unlike every other sh/*.sh fetcher in this project, cava is
#  a *continuously streaming* process, not a one-shot fetch — so this
#  script is meant to be started ONCE (it tracks its own PID and
#  refuses to spawn a second copy) and left running in the background
#  for as long as the widget is active, not re-triggered periodically.
#
#  Requires: cava (AUR: yay -S cava)
#  Usage:
#    ./sh/cava_visualizer.sh start   — start if not already running
#    ./sh/cava_visualizer.sh stop    — stop the running instance
#    ./sh/cava_visualizer.sh status  — check if it's running
#}}}

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CONKY_DIR="$(readlink -f "$SCRIPT_DIR/..")"
TMP_DIR="$CONKY_DIR/tmp"
CONF="$CONKY_DIR/cava_visualizer.ini"
OUT="$TMP_DIR/cava_bars.txt"
PID_FILE="$TMP_DIR/cava_visualizer.pid"

mkdir -p "$TMP_DIR"

is_running() {
	[ -f "$PID_FILE" ] || return 1
	local pid
	pid=$(cat "$PID_FILE" 2>/dev/null)
	[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

start() {
	if is_running; then
		exit 0
	fi
	command -v cava >/dev/null 2>&1 || { echo "[error] cava not found — install it (AUR: yay -S cava)"; exit 1; }
	[ -f "$CONF" ] || { echo "[error] Config not found: $CONF"; exit 1; }

	# Seed a neutral starting frame so the widget doesn't read an empty
	# file before cava's first real frame arrives.
	printf '0;0;0;0;0;0;0;0;0;0;0;0\n' > "$OUT"

	# cava streams continuously; the while-read loop overwrites $OUT
	# with only the latest frame each time, instead of letting it grow
	# forever (matching how every other tmp/ file in this project is a
	# plain, re-readable snapshot).
	( cava -p "$CONF" 2>/dev/null | while IFS= read -r line; do
		printf '%s\n' "$line" > "$OUT"
	done ) </dev/null >/dev/null 2>&1 &
	echo $! > "$PID_FILE"
}

stop() {
	if is_running; then
		local pid
		pid=$(cat "$PID_FILE")
		# Kill the whole process group (cava + the while-read wrapper),
		# not just the backgrounded subshell's own PID.
		pkill -P "$pid" 2>/dev/null
		kill "$pid" 2>/dev/null
	fi
	rm -f "$PID_FILE"
}

status() {
	if is_running; then
		echo "running (pid $(cat "$PID_FILE"))"
	else
		echo "not running"
	fi
}

case "${1:-start}" in
start) start ;;
stop) stop ;;
status) status ;;
*)
	echo "Usage: $0 {start|stop|status}"
	exit 1
	;;
esac
