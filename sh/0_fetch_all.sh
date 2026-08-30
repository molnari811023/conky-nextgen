#!/bin/bash

_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/0_common.sh"
source "$_SCRIPT_DIR/4_fetch_weather.sh"
source "$_SCRIPT_DIR/11_fetch_alerts.sh"
source "$_SCRIPT_DIR/13_fetch_maps.sh"
source "$_SCRIPT_DIR/fetch_nowplaying.sh"
source "$_SCRIPT_DIR/fetch_network.sh"
source "$_SCRIPT_DIR/fetch_google.sh"

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	MODE="${1:-all}"

	case "$MODE" in
	all)
		fetch_weather "${2:-Vienna}"
		fetch_alerts
		fetch_maps "${3:-7}"
		fetch_nowplaying
		fetch_google &
		fetch_ping &
		fetch_ipinfo &
		wait
		;;
	weather)
		fetch_weather "${2:-Vienna}"
		;;
	google)
		fetch_google
		;;
	space)
		;;
	alerts)
		fetch_alerts
		;;
	map)
		fetch_maps "${2:-7}"
		;;
	nowplaying)
		fetch_nowplaying
		;;
	network)
		fetch_ping &
		fetch_ipinfo &
		wait
		;;
	*)
		fetch_weather "$*"
		;;
	esac
fi
