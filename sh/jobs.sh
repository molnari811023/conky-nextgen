#!/usr/bin/env bash
#{{{
#  Conky NextGen Framework — Background Jobs & Cron/Timer Manager
#  Author: István Molnár <molnari811023@gmail.com>
#  Description: Manages ~/.config/conky-nextgen/jobs.conf, interval-based
#               execution, user crontab entry, and systemd --user timer.
#}}}
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/conky-nextgen"
JOBS_CONF="$CONFIG_DIR/jobs.conf"
STAMP_DIR="${XDG_RUNTIME_DIR:-/tmp}/conky-nextgen-jobs"
LOCK_FILE="$STAMP_DIR/runner.lock"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
CRON_BEGIN="# >>> conky-nextgen-jobs"
CRON_END="# <<< conky-nextgen-jobs"

JOB_ORDER=(
    "weather"
    "alerts"
    "map"
    "network"
    "nowplaying"
    "updates"
    "vnstat"
    "google"
    "icloud"
    "antigravity"
)

declare -A DEFAULT_JOBS=(
    [weather]="1:15m"
    [alerts]="1:15m"
    [map]="1:30m"
    [network]="1:2m"
    [nowplaying]="1:1m"
    [updates]="1:60m"
    [vnstat]="1:15m"
    [google]="0:10m"
    [icloud]="0:15m"
    [antigravity]="0:5m"
)

ensure_jobs_conf() {
    mkdir -p "$CONFIG_DIR"
    if [ ! -f "$JOBS_CONF" ]; then
        {
            echo "# Conky NextGen Background Jobs Configuration"
            echo "# Format: <job>=<0|1>:<interval>  (e.g. 1m, 5m, 15m, 30m, 60m, 2h)"
            echo "CITY=Vienna"
            for j in "${JOB_ORDER[@]}"; do
                echo "${j}=${DEFAULT_JOBS[$j]}"
            done
        } > "$JOBS_CONF"
    fi
}

parse_interval_secs() {
    local spec="$1"
    local num unit
    if [[ "$spec" =~ ^([0-9]+)([smhd]?)$ ]]; then
        num="${BASH_REMATCH[1]}"
        unit="${BASH_REMATCH[2]}"
        case "$unit" in
            ""|m) echo $((num * 60)) ;;
            s)    echo "$num" ;;
            h)    echo $((num * 3600)) ;;
            d)    echo $((num * 86400)) ;;
        esac
    else
        echo 900
    fi
}

get_job_entry() {
    local job="$1"
    local line
    line=$(grep -E "^${job}=" "$JOBS_CONF" 2>/dev/null | tail -n 1 || true)
    if [ -n "$line" ]; then
        echo "${line#*=}"
    else
        echo "${DEFAULT_JOBS[$job]:-0:15m}"
    fi
}

set_job_entry() {
    local job="$1"
    local new_val="$2"
    ensure_jobs_conf
    if grep -qE "^${job}=" "$JOBS_CONF"; then
        sed -i "s|^${job}=.*|${job}=${new_val}|" "$JOBS_CONF"
    else
        echo "${job}=${new_val}" >> "$JOBS_CONF"
    fi
}

get_city() {
    local line
    line=$(grep -E "^CITY=" "$JOBS_CONF" 2>/dev/null | tail -n 1 || true)
    if [ -n "$line" ]; then
        echo "${line#*=}"
    else
        echo "Vienna"
    fi
}

run_single_job() {
    local job="$1"
    local city="$2"
    case "$job" in
        weather)     "$SCRIPT_DIR/fetch_all.sh" weather "$city" ;;
        alerts)      "$SCRIPT_DIR/fetch_all.sh" alerts ;;
        map)         "$SCRIPT_DIR/fetch_all.sh" map ;;
        network)     "$SCRIPT_DIR/fetch_all.sh" network ;;
        nowplaying)  "$SCRIPT_DIR/fetch_all.sh" nowplaying ;;
        updates)     "$SCRIPT_DIR/fetch_all.sh" updates ;;
        vnstat)      [ -x "$SCRIPT_DIR/vnstat.sh" ] && "$SCRIPT_DIR/vnstat.sh" ;;
        google)      "$SCRIPT_DIR/fetch_all.sh" google ;;
        icloud)      "$SCRIPT_DIR/fetch_all.sh" icloud ;;
        antigravity) "$SCRIPT_DIR/fetch_all.sh" antigravity ;;
    esac
}

cmd_list() {
    ensure_jobs_conf
    printf "%-14s %-8s %-10s %s\n" "JOB" "STATE" "INTERVAL" "LAST_RUN"
    printf "%-14s %-8s %-10s %s\n" "--------------" "--------" "----------" "-------------------"
    for j in "${JOB_ORDER[@]}"; do
        local entry enabled interval stamp last_str
        entry="$(get_job_entry "$j")"
        enabled="${entry%%:*}"
        interval="${entry#*:}"
        [ "$interval" = "$entry" ] && interval="15m"
        stamp="$STAMP_DIR/${j}.ts"
        if [ -f "$stamp" ]; then
            last_str=$(date -d "@$(cat "$stamp")" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
        else
            last_str="never"
        fi
        if [ "$enabled" = "1" ]; then
            printf "%-14s %-8s %-10s %s\n" "$j" "ON" "$interval" "$last_str"
        else
            printf "%-14s %-8s %-10s %s\n" "$j" "OFF" "$interval" "$last_str"
        fi
    done
}

cmd_toggle() {
    local target_state="$1"
    shift
    if [ $# -eq 0 ]; then
        echo "Usage: conky-nextgen jobs $([ "$target_state" = "1" ] && echo enable || echo disable) <job...>"
        exit 1
    fi
    ensure_jobs_conf
    for j in "$@"; do
        local entry interval
        entry="$(get_job_entry "$j")"
        interval="${entry#*:}"
        [ "$interval" = "$entry" ] && interval="15m"
        set_job_entry "$j" "${target_state}:${interval}"
        echo "  $j -> $([ "$target_state" = "1" ] && echo ON || echo OFF) ($interval)"
    done
}

cmd_set() {
    local job="${1:-}"
    local interval="${2:-}"
    if [ -z "$job" ] || [ -z "$interval" ]; then
        echo "Usage: conky-nextgen jobs set <job> <interval>"
        exit 1
    fi
    ensure_jobs_conf
    local entry enabled
    entry="$(get_job_entry "$job")"
    enabled="${entry%%:*}"
    set_job_entry "$job" "${enabled}:${interval}"
    echo "  $job -> $([ "$enabled" = "1" ] && echo ON || echo OFF) ($interval)"
}

cmd_run() {
    local force=0
    [ "${1:-}" = "--force" ] && force=1
    ensure_jobs_conf
    mkdir -p "$STAMP_DIR"

    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        exit 0
    fi

    local now city pids=()
    now=$(date +%s)
    city="$(get_city)"

    for j in "${JOB_ORDER[@]}"; do
        local entry enabled interval secs stamp last_ts
        entry="$(get_job_entry "$j")"
        enabled="${entry%%:*}"
        interval="${entry#*:}"
        [ "$enabled" != "1" ] && continue

        secs=$(parse_interval_secs "$interval")
        stamp="$STAMP_DIR/${j}.ts"
        last_ts=0
        [ -f "$stamp" ] && last_ts=$(cat "$stamp" 2>/dev/null || echo 0)

        if [ "$force" -eq 1 ] || [ $((now - last_ts)) -ge "$secs" ]; then
            echo "$now" > "$stamp"
            run_single_job "$j" "$city" >/dev/null 2>&1 &
            pids+=($!)
        fi
    done

    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
}

cmd_install_cron() {
    ensure_jobs_conf
    if ! command -v crontab >/dev/null 2>&1; then
        echo "[error] 'crontab' command not found (install cronie or use 'install-timer')."
        exit 1
    fi
    local runner="$SCRIPT_DIR/jobs.sh"
    [ -x "/usr/share/conky-nextgen/sh/jobs.sh" ] && runner="/usr/share/conky-nextgen/sh/jobs.sh"

    local current filtered
    current="$(crontab -l 2>/dev/null || true)"
    filtered="$(printf "%s\n" "$current" | awk -v b="$CRON_BEGIN" -v e="$CRON_END" '
        $0 == b { skip=1; next }
        $0 == e { skip=0; next }
        !skip { print }
    ')"
    {
        [ -n "$filtered" ] && printf "%s\n" "$filtered"
        echo "$CRON_BEGIN"
        echo "* * * * * /usr/bin/env bash \"$runner\" run >/dev/null 2>&1"
        echo "$CRON_END"
    } | crontab -
    echo "Installed user crontab entry for conky-nextgen jobs."
}

cmd_uninstall_cron() {
    if ! command -v crontab >/dev/null 2>&1; then
        echo "[info] 'crontab' not installed."
        return 0
    fi
    local current filtered
    current="$(crontab -l 2>/dev/null || true)"
    filtered="$(printf "%s\n" "$current" | awk -v b="$CRON_BEGIN" -v e="$CRON_END" '
        $0 == b { skip=1; next }
        $0 == e { skip=0; next }
        !skip { print }
    ')"
    printf "%s\n" "$filtered" | crontab -
    echo "Removed user crontab entry for conky-nextgen jobs."
}

cmd_install_timer() {
    ensure_jobs_conf
    mkdir -p "$SYSTEMD_USER_DIR"
    local runner="$SCRIPT_DIR/jobs.sh"
    [ -x "/usr/share/conky-nextgen/sh/jobs.sh" ] && runner="/usr/share/conky-nextgen/sh/jobs.sh"

    cat > "$SYSTEMD_USER_DIR/conky-nextgen-jobs.service" << EOF
[Unit]
Description=Conky NextGen Background Jobs Runner

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash "$runner" run
EOF

    cat > "$SYSTEMD_USER_DIR/conky-nextgen-jobs.timer" << EOF
[Unit]
Description=Run Conky NextGen background jobs every minute

[Timer]
OnBootSec=15s
OnUnitActiveSec=60s
AccuracySec=10s

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now conky-nextgen-jobs.timer
    echo "Installed and enabled systemd user timer: conky-nextgen-jobs.timer"
}

cmd_uninstall_timer() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user disable --now conky-nextgen-jobs.timer 2>/dev/null || true
    fi
    rm -f "$SYSTEMD_USER_DIR/conky-nextgen-jobs.timer" "$SYSTEMD_USER_DIR/conky-nextgen-jobs.service"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload 2>/dev/null || true
    fi
    echo "Removed systemd user timer: conky-nextgen-jobs.timer"
}

cmd_status() {
    local timer_state="inactive" cron_state="not installed"
    if command -v systemctl >/dev/null 2>&1; then
        timer_state=$(systemctl --user is-active conky-nextgen-jobs.timer 2>/dev/null || true)
        [ -z "$timer_state" ] && timer_state="inactive"
    fi
    if command -v crontab >/dev/null 2>&1; then
        if crontab -l 2>/dev/null | grep -qF "$CRON_BEGIN"; then
            cron_state="installed"
        fi
    fi
    echo "Config:        $JOBS_CONF"
    echo "Systemd timer: $timer_state"
    echo "User crontab:  $cron_state"
    echo ""
    cmd_list
}

SUBCMD="${1:-status}"
shift || true

case "$SUBCMD" in
    init)            ensure_jobs_conf; echo "Initialized $JOBS_CONF" ;;
    list)            cmd_list ;;
    status)          cmd_status ;;
    enable)          cmd_toggle "1" "$@" ;;
    disable)         cmd_toggle "0" "$@" ;;
    set)             cmd_set "$@" ;;
    run)             cmd_run "$@" ;;
    install-cron)    cmd_install_cron ;;
    uninstall-cron)  cmd_uninstall_cron ;;
    install-timer)   cmd_install_timer ;;
    uninstall-timer) cmd_uninstall_timer ;;
    -h|--help|help)
        cat << EOF
Usage: conky-nextgen jobs <subcommand>

Subcommands:
  status                 Show scheduler status and job table
  list                   List jobs from jobs.conf
  enable <job...>        Enable one or more jobs
  disable <job...>       Disable one or more jobs
  set <job> <interval>   Set interval (e.g. 1m, 5m, 15m, 1h)
  run [--force]          Run due enabled jobs now
  install-timer          Install & enable systemd --user timer (recommended)
  uninstall-timer        Disable & remove systemd --user timer
  install-cron           Install single entry in user crontab
  uninstall-cron         Remove entry from user crontab
  init                   Create default ~/.config/conky-nextgen/jobs.conf
EOF
        ;;
    *)
        echo "Unknown jobs subcommand: $SUBCMD"
        exit 1
        ;;
esac
