#!/usr/bin/env bash
#{{{
#  Conky NextGen Framework — Panel Bluetooth Backend (BlueZ bluetoothctl)
#  Author: István Molnár <molnari811023@gmail.com>
#}}}
set -eo pipefail

if ! command -v bluetoothctl >/dev/null 2>&1; then
    case "${1:-status}" in
        status) printf "0\t0\t0\t\n" ;;
    esac
    exit 0
fi

cmd_status() {
    local info
    info="$(bluetoothctl show 2>/dev/null || true)"
    if [ -z "$info" ] || printf "%s" "$info" | grep -q "No default controller"; then
        printf "0\t0\t0\t\n"
        return
    fi
    local powered=0 count=0 cname=""
    printf "%s\n" "$info" | grep -qE "Powered:[[:space:]]+yes" && powered=1
    if [ "$powered" -eq 1 ]; then
        local devs
        devs="$(bluetoothctl devices Connected 2>/dev/null || true)"
        if [ -n "$devs" ]; then
            count="$(printf "%s\n" "$devs" | wc -l)"
            cname="$(printf "%s\n" "$devs" | head -n1 | sed -E 's/^Device[[:space:]]+[0-9A-Fa-f:]+[[:space:]]+//')"
        fi
    fi
    printf "1\t%d\t%d\t%s\n" "$powered" "$count" "$cname"
}

cmd_list() {
    local connected_macs paired_macs
    connected_macs="$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}' || true)"
    paired_macs="$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}' || true)"

    bluetoothctl devices 2>/dev/null | while IFS= read -r line; do
        local mac name conn=0 paired=0
        mac="$(printf "%s" "$line" | awk '{print $2}')"
        name="$(printf "%s" "$line" | sed -E 's/^Device[[:space:]]+[0-9A-Fa-f:]+[[:space:]]+//')"
        [ -z "$mac" ] && continue
        printf "%s\n" "$connected_macs" | grep -qxF "$mac" && conn=1
        printf "%s\n" "$paired_macs" | grep -qxF "$mac" && paired=1
        printf "%s\t%s\t%d\t%d\n" "$mac" "$name" "$conn" "$paired"
    done | sort -t$'\t' -k3,3rn -k4,4rn -k2,2
}

cmd_toggle() {
    local info
    info="$(bluetoothctl show 2>/dev/null || true)"
    if printf "%s\n" "$info" | grep -qE "Powered:[[:space:]]+yes"; then
        bluetoothctl power off >/dev/null 2>&1 || true
    else
        bluetoothctl power on >/dev/null 2>&1 || true
    fi
}

cmd_scan() {
    bluetoothctl --timeout 6 scan on >/dev/null 2>&1 || true
}

cmd_connect() {
    local mac="${1:-}"
    [ -z "$mac" ] && return 1
    bluetoothctl trust "$mac" >/dev/null 2>&1 || true
    bluetoothctl connect "$mac" >/dev/null 2>&1 || true
}

cmd_disconnect() {
    local mac="${1:-}"
    [ -z "$mac" ] && return 1
    bluetoothctl disconnect "$mac" >/dev/null 2>&1 || true
}

cmd_remove() {
    local mac="${1:-}"
    [ -z "$mac" ] && return 1
    bluetoothctl remove "$mac" >/dev/null 2>&1 || true
}

case "${1:-status}" in
    status)     cmd_status ;;
    list)       cmd_list ;;
    toggle)     cmd_toggle ;;
    scan)       cmd_scan ;;
    connect)    shift; cmd_connect "$@" ;;
    disconnect) shift; cmd_disconnect "$@" ;;
    remove)     shift; cmd_remove "$@" ;;
    *)
        echo "Usage: $0 {status|list|toggle|scan|connect <mac>|disconnect <mac>|remove <mac>}"
        exit 1
        ;;
esac
