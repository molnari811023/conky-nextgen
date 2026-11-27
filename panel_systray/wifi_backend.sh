#!/usr/bin/env bash
#{{{
#  Conky NextGen Framework — Panel Wi-Fi Backend (nmcli + iwd auto-detect)
#  Author: István Molnár <molnari811023@gmail.com>
#  Description: Unified Wi-Fi status, scan, toggle, and connect helper
#               supporting both NetworkManager (nmcli) and iwd (iwctl).
#}}}
set -eo pipefail

BACKEND="${WIFI_BACKEND:-auto}"

detect_backend() {
    if [ "$BACKEND" = "nmcli" ] || [ "$BACKEND" = "iwd" ]; then
        echo "$BACKEND"
        return
    fi
    if command -v nmcli >/dev/null 2>&1 && systemctl is-active --quiet NetworkManager 2>/dev/null; then
        echo "nmcli"
        return
    fi
    if command -v iwctl >/dev/null 2>&1 && systemctl is-active --quiet iwd 2>/dev/null; then
        echo "iwd"
        return
    fi
    if command -v nmcli >/dev/null 2>&1; then
        echo "nmcli"
    elif command -v iwctl >/dev/null 2>&1; then
        echo "iwd"
    else
        echo "none"
    fi
}

strip_ansi() {
    sed -r 's/\x1B\[[0-9;]*[mK]//g'
}

iwd_dev() {
    iwctl station list 2>/dev/null | strip_ansi | awk 'NR>4 && $1 != "" && $1 !~ /^-/ && $1 != "No" {print $1; exit}'
}

rssi_to_pct() {
    local rssi="$1"
    if [ -z "$rssi" ]; then echo 0; return; fi
    local pct=$(( (rssi + 100) * 2 ))
    [ "$pct" -lt 0 ] && pct=0
    [ "$pct" -gt 100 ] && pct=100
    echo "$pct"
}

cmd_status() {
    local b
    b="$(detect_backend)"
    if [ "$b" = "nmcli" ]; then
        local radio dev state ssid sig ip
        radio="$(nmcli radio wifi 2>/dev/null || echo "disabled")"
        local powered=0
        [ "$radio" = "enabled" ] && powered=1

        dev="$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')"
        local active_line
        active_line="$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk '
            /^yes:/ {
                line = substr($0, 5)
                # Last unescaped colon separates SSID from SIGNAL
                match(line, /^(.*):([0-9]+)$/, m)
                if (m[1] != "") {
                    gsub(/\\:/, ":", m[1])
                    print m[1] "\t" m[2]
                    exit
                }
            }
        ' || true)"
        if [ -n "$active_line" ]; then
            ssid="${active_line%%$'\t'*}"
            sig="${active_line#*$'\t'}"
            [ -n "$dev" ] && ip="$(nmcli -t -f IP4.ADDRESS dev show "$dev" 2>/dev/null | head -n1 | cut -d: -f2 | cut -d/ -f1 || true)"
            printf "nmcli\t%s\t1\t%s\t%s\t%s\t%s\n" "$powered" "$ssid" "${sig:-0}" "${ip:-}" "${dev:-}"
        else
            printf "nmcli\t%s\t0\t\t0\t\t%s\n" "$powered" "${dev:-}"
        fi
    elif [ "$b" = "iwd" ]; then
        local dev
        dev="$(iwd_dev)"
        if [ -z "$dev" ]; then
            printf "iwd\t0\t0\t\t0\t\t\n"
            return
        fi
        local dev_info powered=0 info state ssid rssi sig ip
        dev_info="$(iwctl device "$dev" show 2>/dev/null | strip_ansi || true)"
        [ "$(printf "%s\n" "$dev_info" | awk '/Powered/{print $2; exit}')" = "on" ] && powered=1
        info="$(iwctl station "$dev" show 2>/dev/null | strip_ansi || true)"
        state="$(printf "%s\n" "$info" | awk '/State/{print $2; exit}')"
        ssid="$(printf "%s\n" "$info" | awk '/Connected network/{sub(/.*Connected network[[:space:]]+/, ""); gsub(/[[:space:]]+$/, ""); print; exit}')"
        rssi="$(printf "%s\n" "$info" | awk '/AverageRSSI/{print $2; exit}')"
        sig="$(rssi_to_pct "$rssi")"
        if [ "$powered" -eq 1 ] && [ "$state" = "connected" ] && [ -n "$ssid" ]; then
            ip="$(ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
            printf "iwd\t%s\t1\t%s\t%s\t%s\t%s\n" "$powered" "$ssid" "${sig:-0}" "${ip:-}" "$dev"
        else
            printf "iwd\t%s\t0\t\t0\t\t%s\n" "$powered" "$dev"
        fi
    else
        printf "none\t0\t0\t\t0\t\t\n"
    fi
}

cmd_list() {
    local b
    b="$(detect_backend)"
    if [ "$b" = "nmcli" ]; then
        nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | awk '
            {
                # Parse from end: ...:<SIGNAL>:<SECURITY>
                if (match($0, /^(yes|no):(.*):([0-9]*):([^:]*)$/, m)) {
                    conn = (m[1] == "yes") ? 1 : 0
                    ssid = m[2]
                    sig  = m[3] + 0
                    sec  = (m[4] != "" && m[4] != "--") ? m[4] : "open"
                    gsub(/\\:/, ":", ssid)
                    if (ssid != "" && (!seen[ssid]++ || conn == 1)) {
                        data[ssid] = ssid "\t" sig "\t" sec "\t" conn
                    }
                }
            }
            END {
                for (s in data) print data[s]
            }
        ' | sort -t$'\t' -k4,4rn -k2,2rn
    elif [ "$b" = "iwd" ]; then
        local dev
        dev="$(iwd_dev)"
        [ -z "$dev" ] && return 0
        iwctl station "$dev" get-networks 2>/dev/null | strip_ansi | awk '
            NR > 4 && NF >= 2 {
                line = $0
                conn = (line ~ /^[[:space:]]*>/) ? 1 : 0
                sub(/^[[:space:]]*>?[[:space:]]*/, "", line)
                n = split(line, parts, /[[:space:]]{2,}/)
                if (n >= 3) {
                    stars = parts[n]
                    sec   = parts[n - 1]
                    ssid  = parts[1]
                    for (i = 2; i <= n - 2; i++) ssid = ssid "  " parts[i]
                    gsub(/[^*]/, "", stars)
                    sig = length(stars) * 25
                    if (sig == 0) sig = 20
                    if (ssid != "" && ssid !~ /^-+$/) {
                        printf "%s\t%d\t%s\t%d\n", ssid, sig, sec, conn
                    }
                }
            }
        ' | sort -t$'\t' -k4,4rn -k2,2rn
    fi
}

cmd_scan() {
    local b
    b="$(detect_backend)"
    if [ "$b" = "nmcli" ]; then
        nmcli dev wifi rescan 2>/dev/null || true
    elif [ "$b" = "iwd" ]; then
        local dev
        dev="$(iwd_dev)"
        [ -n "$dev" ] && iwctl station "$dev" scan 2>/dev/null || true
    fi
}

cmd_toggle() {
    local b
    b="$(detect_backend)"
    if [ "$b" = "nmcli" ]; then
        local cur
        cur="$(nmcli radio wifi 2>/dev/null || echo disabled)"
        if [ "$cur" = "enabled" ]; then
            nmcli radio wifi off
        else
            nmcli radio wifi on
        fi
    elif [ "$b" = "iwd" ]; then
        local dev cur
        dev="$(iwd_dev)"
        [ -z "$dev" ] && return 1
        cur="$(iwctl device "$dev" show 2>/dev/null | strip_ansi | awk '/Powered/{print $2; exit}')"
        if [ "$cur" = "on" ]; then
            iwctl device "$dev" set-property Powered off
        else
            iwctl device "$dev" set-property Powered on
        fi
    fi
}

cmd_disconnect() {
    local b
    b="$(detect_backend)"
    if [ "$b" = "nmcli" ]; then
        local dev
        dev="$(nmcli -t -f DEVICE,TYPE dev 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')"
        [ -n "$dev" ] && nmcli dev disconnect "$dev" 2>/dev/null || true
    elif [ "$b" = "iwd" ]; then
        local dev
        dev="$(iwd_dev)"
        [ -n "$dev" ] && iwctl station "$dev" disconnect 2>/dev/null || true
    fi
}

ask_password() {
    local ssid="$1"
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --password "Wi-Fi Password for $ssid:" 2>/dev/null || true
    elif command -v zenity >/dev/null 2>&1; then
        zenity --password --title="Wi-Fi: $ssid" 2>/dev/null || true
    elif command -v rofi >/dev/null 2>&1; then
        rofi -dmenu -password -p "Password ($ssid)" </dev/null 2>/dev/null || true
    elif command -v python3 >/dev/null 2>&1; then
        python3 - "$ssid" << 'PYEOF' 2>/dev/null || true
import sys, gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk
ssid = sys.argv[1]
dlg = Gtk.Dialog(title=f"Wi-Fi: {ssid}")
dlg.add_buttons(Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL, Gtk.STOCK_OK, Gtk.ResponseType.OK)
box = dlg.get_content_area()
box.set_spacing(6)
box.set_margin_start(12); box.set_margin_end(12); box.set_margin_top(10)
box.add(Gtk.Label(label=f"Password for {ssid}:"))
entry = Gtk.Entry()
entry.set_visibility(False)
entry.set_activates_default(True)
box.add(entry)
dlg.set_default_response(Gtk.ResponseType.OK)
dlg.show_all()
if dlg.run() == Gtk.ResponseType.OK:
    print(entry.get_text())
dlg.destroy()
PYEOF
    fi
}

cmd_forget() {
    local ssid="${1:-}"
    [ -z "$ssid" ] && return 1
    local b
    b="$(detect_backend)"
    if [ "$b" = "nmcli" ]; then
        nmcli connection delete id "$ssid" >/dev/null 2>&1 || true
    elif [ "$b" = "iwd" ]; then
        iwctl known-networks "$ssid" forget >/dev/null 2>&1 || true
    fi
    notify-send -a "Wi-Fi" "Forgot network" "$ssid" >/dev/null 2>&1 || true
}

cmd_connect() {
    local ssid="${1:-}"
    local sec="${2:-psk}"
    [ -z "$ssid" ] && return 1
    local b
    b="$(detect_backend)"

    if [ "$b" = "nmcli" ]; then
        if nmcli dev wifi connect "$ssid" >/dev/null 2>&1; then
            notify-send -a "Wi-Fi" "Connected" "$ssid" >/dev/null 2>&1 || true
            return 0
        fi
        if [ "$sec" != "open" ]; then
            local pw
            pw="$(ask_password "$ssid")"
            [ -z "$pw" ] && return 1
            if nmcli dev wifi connect "$ssid" password "$pw" >/dev/null 2>&1; then
                notify-send -a "Wi-Fi" "Connected" "$ssid" >/dev/null 2>&1 || true
                return 0
            fi
        fi
        notify-send -a "Wi-Fi" "Connection failed" "$ssid" >/dev/null 2>&1 || true
        return 1
    elif [ "$b" = "iwd" ]; then
        local dev
        dev="$(iwd_dev)"
        [ -z "$dev" ] && return 1
        if iwctl station "$dev" connect "$ssid" >/dev/null 2>&1; then
            notify-send -a "Wi-Fi" "Connected" "$ssid" >/dev/null 2>&1 || true
            return 0
        fi
        if [ "$sec" != "open" ]; then
            local pw
            pw="$(ask_password "$ssid")"
            [ -z "$pw" ] && return 1
            if iwctl --passphrase "$pw" station "$dev" connect "$ssid" >/dev/null 2>&1; then
                notify-send -a "Wi-Fi" "Connected" "$ssid" >/dev/null 2>&1 || true
                return 0
            fi
        fi
        notify-send -a "Wi-Fi" "Connection failed" "$ssid" >/dev/null 2>&1 || true
        return 1
    fi
}

case "${1:-status}" in
    status)     cmd_status ;;
    list)       cmd_list ;;
    scan)       cmd_scan ;;
    toggle)     cmd_toggle ;;
    disconnect) cmd_disconnect ;;
    connect)    shift; cmd_connect "$@" ;;
    forget)     shift; cmd_forget "$@" ;;
    *)
        echo "Usage: $0 {status|list|scan|toggle|disconnect|connect <ssid> [sec]|forget <ssid>}"
        exit 1
        ;;
esac
