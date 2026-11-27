#!/usr/bin/env bash
#{{{
#  Conky NextGen Framework — Panel Clipboard Backend (Wayland wl-clipboard + X11 xclip/xsel)
#  Author: István Molnár <molnari811023@gmail.com>
#}}}
set -eo pipefail

HIST_FILE="${XDG_RUNTIME_DIR:-/tmp}/conky-nextgen-clipboard.tsv"
MAX_ITEMS="${CLIP_MAX_ITEMS:-30}"

detect_clip() {
    if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-paste >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then
        echo "wayland"
    elif command -v xclip >/dev/null 2>&1; then
        echo "xclip"
    elif command -v xsel >/dev/null 2>&1; then
        echo "xsel"
    elif command -v wl-paste >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1; then
        echo "wayland"
    else
        echo "none"
    fi
}

read_clip_b64() {
    local b
    b="$(detect_clip)"
    local raw=""
    case "$b" in
        wayland) raw="$(wl-paste --no-newline 2>/dev/null || true)" ;;
        xclip)   raw="$(xclip -o -selection clipboard 2>/dev/null || true)" ;;
        xsel)    raw="$(xsel -ob 2>/dev/null || true)" ;;
    esac
    [ -z "$raw" ] && return 0
    printf "%s" "$raw" | base64 -w 0 2>/dev/null || printf "%s" "$raw" | base64 | tr -d '\n'
}

write_clip_b64() {
    local b64="$1"
    local b
    b="$(detect_clip)"
    case "$b" in
        wayland) printf "%s" "$b64" | base64 -d | wl-copy 2>/dev/null || true ;;
        xclip)   printf "%s" "$b64" | base64 -d | xclip -i -selection clipboard 2>/dev/null || true ;;
        xsel)    printf "%s" "$b64" | base64 -d | xsel -ib 2>/dev/null || true ;;
    esac
}

make_preview() {
    local b64="$1"
    printf "%s" "$b64" | base64 -d 2>/dev/null | tr '\r\n\t' '   ' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+/ /g' | cut -c1-80
}

cmd_poll() {
    touch "$HIST_FILE"
    local b64
    b64="$(read_clip_b64)"
    if [ -n "$b64" ]; then
        local first_b64=""
        first_b64="$(head -n1 "$HIST_FILE" 2>/dev/null | cut -f2 || true)"
        if [ "$b64" != "$first_b64" ]; then
            local prev tmp
            prev="$(make_preview "$b64")"
            if [ -n "$prev" ]; then
                tmp="${HIST_FILE}.tmp.$$"
                {
                    printf "%s\t%s\n" "$prev" "$b64"
                    awk -F'\t' -v cur="$b64" '$2 != cur { print }' "$HIST_FILE" 2>/dev/null | head -n $((MAX_ITEMS - 1))
                } > "$tmp"
                mv -f "$tmp" "$HIST_FILE"
            fi
        fi
    fi
    local cnt=0 top=""
    if [ -s "$HIST_FILE" ]; then
        cnt="$(wc -l < "$HIST_FILE" | tr -d ' ')"
        top="$(head -n1 "$HIST_FILE" | cut -f1)"
    fi
    printf "%s\t%s\n" "$cnt" "$top"
}

cmd_list() {
    [ ! -s "$HIST_FILE" ] && return 0
    nl -ba -w1 -s$'\t' "$HIST_FILE" | cut -f1,2
}

cmd_copy() {
    local idx="${1:-1}"
    [ ! -s "$HIST_FILE" ] && return 1
    local line prev b64 tmp
    line="$(sed -n "${idx}p" "$HIST_FILE" || true)"
    [ -z "$line" ] && return 1
    prev="${line%%$'\t'*}"
    b64="${line#*$'\t'}"
    write_clip_b64 "$b64"
    tmp="${HIST_FILE}.tmp.$$"
    {
        printf "%s\t%s\n" "$prev" "$b64"
        awk -F'\t' -v cur="$b64" '$2 != cur { print }' "$HIST_FILE" 2>/dev/null | head -n $((MAX_ITEMS - 1))
    } > "$tmp"
    mv -f "$tmp" "$HIST_FILE"
}

cmd_delete() {
    local idx="${1:-}"
    [ -z "$idx" ] || [ ! -s "$HIST_FILE" ] && return 0
    local tmp="${HIST_FILE}.tmp.$$"
    sed "${idx}d" "$HIST_FILE" > "$tmp"
    mv -f "$tmp" "$HIST_FILE"
}

cmd_clear() {
    : > "$HIST_FILE"
}

case "${1:-poll}" in
    poll)   cmd_poll ;;
    list)   cmd_list ;;
    copy)   shift; cmd_copy "${1:-1}" ;;
    delete) shift; cmd_delete "${1:-}" ;;
    clear)  cmd_clear ;;
    *)
        echo "Usage: $0 {poll|list|copy <idx>|delete <idx>|clear}"
        exit 1
        ;;
esac
