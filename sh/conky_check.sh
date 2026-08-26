#!/usr/bin/env bash
# conky_check.sh — List all conky processes with state info.
# Usage: watch -n2 bash ~/.conky/sh/conky_check.sh

echo "=== Conky processes ==="
found=0
for pid in /proc/[0-9]*; do
    p="${pid##*/}"
    comm=$(cat /proc/$p/comm 2>/dev/null) || continue
    [ "$comm" = "conky" ] || continue
    found=1
    state=$(awk '{print $3}' /proc/$p/stat 2>/dev/null)
    ppid=$(awk '{print $4}' /proc/$p/stat 2>/dev/null)
    start=$(stat -c %Y /proc/$p 2>/dev/null)
    starttime=$(date -d "@$start" '+%H:%M:%S' 2>/dev/null)
    cmdline=$(cat /proc/$p/cmdline 2>/dev/null | tr '\0' ' ')
    # state: R=running, S=sleeping, Z=zombie, T=stopped
    case "$state" in
        Z) label="ZOMBIE (defunct)";;
        S) label="sleeping";;
        R) label="running";;
        T) label="stopped";;
        *) label="$state";;
    esac
    echo "  PID=$p  PPID=$ppid  state=$label  started=$starttime"
    echo "    cmd: ${cmdline:-(empty — zombie)}"
done
if [ $found -eq 0 ]; then
    echo "  (no conky processes found)"
fi

echo ""
echo "=== Designer PID files ==="
if [ -f /tmp/conky_preview/conky.pid ]; then
    echo "  /tmp/conky_preview/conky.pid: $(cat /tmp/conky_preview/conky.pid 2>/dev/null)"
fi
# Also check the designer log for PID
log="$HOME/.conky/tmp/conky.log"
if [ -f "$log" ]; then
    pid_line=$(grep -o 'pid is [0-9]*' "$log" 2>/dev/null | tail -1)
    echo "  log says: $pid_line"
fi
