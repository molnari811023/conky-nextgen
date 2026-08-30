#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## 0_fetch_all — orchestrator for all fetch sub-scripts
#
# Sources 0_common.sh together with the weather, alerts, maps, nowplaying,
# network and google fetchers and dispatches them based on the first
# command-line argument (default `all`). In `all` mode weather, alerts, maps
# and nowplaying run sequentially while google, ping and ipinfo run as
# parallel background jobs, then waits for them.
#
# **What it does:**
# - Sources every fetch module so their functions are available
# - `all`: fetch_weather, fetch_alerts, fetch_maps, fetch_nowplaying,
#   then fetch_google / fetch_ping / fetch_ipinfo in parallel
# - `weather`, `alerts`, `map`, `nowplaying`, `network`, `google`: run only
#   the matching fetcher
# - Any other argument is passed as a city to fetch_weather
#
# **Environment/requirements:** depends on 0_common.sh and the sourced
# fetch scripts
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
