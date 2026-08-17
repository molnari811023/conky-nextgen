#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}

#{{{
# 12_fetch_spaceweather.sh — Download NOAA SWPC space weather data
#
# Fetches 8 JSON files from NOAA Space Weather Prediction Center:
#   Kp index forecast, solar wind speed, magnetic field (Bz),
#   X-ray flux (GOES), NOAA scales, sunspot report,
#   aurora forecast (OVATION), and active alerts.
#
# Usage: source 0_common.sh && fetch_spaceweather
# Output: tmp/spaceweather_{kp,wind,mag,xray,scales,sunspot,aurora,alerts}.json
#}}}

_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/0_common.sh"

fetch_spaceweather() {
	fetch_sw() { local f=$1 u=$2 n=$3; log "[sw] $n"; curl_cmd "$u" >"${f}.tmp" || { rm -f "${f}.tmp"; log "[warn] $n download failed"; return 1; }; [ -s "${f}.tmp" ] && mv "${f}.tmp" "$f" || { rm -f "${f}.tmp"; log "[warn] $n empty response"; return 1; }; }

	fetch_sw "$TMP_DIR/spaceweather_kp.json"      "$SW_BASE/products/noaa-planetary-k-index-forecast.json"  "Kp index"
	fetch_sw "$TMP_DIR/spaceweather_wind.json"     "$SW_BASE/products/summary/solar-wind-speed.json"          "Solar wind speed"
	fetch_sw "$TMP_DIR/spaceweather_mag.json"      "$SW_BASE/products/summary/solar-wind-mag-field.json"      "Magnetic field Bz"
	fetch_sw "$TMP_DIR/spaceweather_xray.json"     "$SW_BASE/json/goes/primary/xrays-1-day.json"              "X-ray flux"
	fetch_sw "$TMP_DIR/spaceweather_scales.json"   "$SW_BASE/products/noaa-scales.json"                        "NOAA scales"
	fetch_sw "$TMP_DIR/spaceweather_sunspot.json"  "$SW_BASE/json/sunspot_report.json"                         "Sunspot report"
	fetch_sw "$TMP_DIR/spaceweather_aurora.json"   "$SW_BASE/json/ovation_aurora_latest.json"                  "Aurora forecast"
	fetch_sw "$TMP_DIR/spaceweather_alerts.json"   "$SW_BASE/products/alerts.json"                             "Alerts"

	log "[sw] all done"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	fetch_spaceweather "$@"
fi
