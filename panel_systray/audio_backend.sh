#!/usr/bin/env bash
#{{{
#  Conky NextGen Framework — Panel Audio Backend (PipeWire wpctl + PulseAudio pactl)
#  Author: István Molnár <molnari811023@gmail.com>
#}}}
set -eo pipefail

BACKEND="${AUDIO_BACKEND:-auto}"

detect_backend() {
    if [ "$BACKEND" = "pipewire" ] || [ "$BACKEND" = "pulseaudio" ]; then
        echo "$BACKEND"
        return
    fi
    if command -v wpctl >/dev/null 2>&1 && wpctl get-volume @DEFAULT_AUDIO_SINK@ >/dev/null 2>&1; then
        echo "pipewire"
    elif command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
        echo "pulseaudio"
    else
        echo "none"
    fi
}

cmd_status() {
    local b
    b="$(detect_backend)"
    if [ "$b" = "pipewire" ]; then
        local out vol muted=0 pct=0
        out="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
        vol="$(printf "%s" "$out" | awk '{print $2}')"
        printf "%s" "$out" | grep -q "MUTED" && muted=1
        pct="$(awk -v v="${vol:-0}" 'BEGIN{printf "%d", (v * 100) + 0.5}')"
        printf "pipewire\t%d\t%d\n" "$pct" "$muted"
    elif [ "$b" = "pulseaudio" ]; then
        local pct muted_str muted=0
        pct="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oE '[0-9]+%' | head -n1 | tr -d '%' || echo 0)"
        muted_str="$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}' || echo no)"
        [ "$muted_str" = "yes" ] && muted=1
        printf "pulseaudio\t%d\t%d\n" "${pct:-0}" "$muted"
    else
        printf "none\t0\t0\n"
    fi
}

cmd_up() {
    local step="${1:-5}"
    local b
    b="$(detect_backend)"
    if [ "$b" = "pipewire" ]; then
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${step}%+" >/dev/null 2>&1 || true
    elif [ "$b" = "pulseaudio" ]; then
        pactl set-sink-volume @DEFAULT_SINK@ "+${step}%" >/dev/null 2>&1 || true
    fi
}

cmd_down() {
    local step="${1:-5}"
    local b
    b="$(detect_backend)"
    if [ "$b" = "pipewire" ]; then
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${step}%-" >/dev/null 2>&1 || true
    elif [ "$b" = "pulseaudio" ]; then
        pactl set-sink-volume @DEFAULT_SINK@ "-${step}%" >/dev/null 2>&1 || true
    fi
}

cmd_mute() {
    local b
    b="$(detect_backend)"
    if [ "$b" = "pipewire" ]; then
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle >/dev/null 2>&1 || true
    elif [ "$b" = "pulseaudio" ]; then
        pactl set-sink-mute @DEFAULT_SINK@ toggle >/dev/null 2>&1 || true
    fi
}

cmd_mixer() {
    for app in pavucontrol-qt pavucontrol kmix qasmixer; do
        if command -v "$app" >/dev/null 2>&1; then
            "$app" >/dev/null 2>&1 &
            return 0
        fi
    done
    if command -v systemsettings >/dev/null 2>&1; then
        systemsettings kcm_pulseaudio >/dev/null 2>&1 &
    fi
}

case "${1:-status}" in
    status) cmd_status ;;
    up)     cmd_up "${2:-5}" ;;
    down)   cmd_down "${2:-5}" ;;
    mute)   cmd_mute ;;
    mixer)  cmd_mixer ;;
    *)
        echo "Usage: $0 {status|up [step]|down [step]|mute|mixer}"
        exit 1
        ;;
esac
