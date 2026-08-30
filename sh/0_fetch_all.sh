#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}

#{{{
# 0_fetch_all.sh — Master fetcher entry point.
# Sources all fetch modules and dispatches by mode.
# Usage: ./0_fetch_all.sh [mode] [arguments]
#   all                  weather + alerts + maps + nowplaying + network (default)
#   weather [city]       weather + air + sun + moon
#   alerts               MeteoAlarm alerts
#   map [zoom]           map tiles (zoom 5-7)
#   nowplaying           now-playing track info + album art
#   network              ping + public IP info
#   google               Gmail + Calendar + Tasks + Contacts + Drive + YouTube
#   [city name]          shorthand for weather
#
# Requires: curl, jq, python3
# Output files: tmp/weather_data.json, tmp/airquality.json, tmp/sun.json,
#               tmp/alerts.xml, tmp/*.png (maps), tmp/network_*.json,
#               tmp/nowplaying.json, tmp/album_art.png,
#               tmp/gmail_emails.json, tmp/calendar_events.json,
#               tmp/tasks_lists.json, tmp/tasks.json, tmp/contacts.json,
#               tmp/drive_files.json, tmp/youtube_subs.json
#}}}

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
