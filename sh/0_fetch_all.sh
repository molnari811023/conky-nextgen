#!/bin/bash
#[[
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#]]
# 0_fetch_all.sh — Master fetcher entry point.
# Sources all fetch modules and dispatches by mode.
# Usage: ./0_fetch_all.sh [mode] [arguments]
#   all                  weather + space + alerts + maps (default)
#   weather [city]       weather + air + sun + moon
#   space                space weather data
#   alerts               MeteoAlarm alerts
#   map [zoom]           map tiles (zoom 5-7)
#   [city name]          shorthand for weather

_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/0_common.sh"
source "$_SCRIPT_DIR/4_fetch_weather.sh"
source "$_SCRIPT_DIR/11_fetch_alerts.sh"
source "$_SCRIPT_DIR/12_fetch_spaceweather.sh"
source "$_SCRIPT_DIR/13_fetch_maps.sh"
source "$_SCRIPT_DIR/fetch_nowplaying.sh"

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	MODE="${1:-all}"

	case "$MODE" in
	all)
		fetch_weather "${2:-Vienna}"
		fetch_spaceweather
		fetch_alerts
		fetch_maps "${3:-7}"
		fetch_nowplaying
		;;
	weather)
		fetch_weather "${2:-Vienna}"
		;;
	space)
		fetch_spaceweather
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
	*)
		fetch_weather "$*"
		;;
	esac
fi
