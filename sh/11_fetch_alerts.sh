#!/bin/bash

_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/0_common.sh"

fetch_alerts() {
	local cj="$TMP_DIR/city.json"
	if [ ! -f "$cj" ]; then
		rm -f "$TMP_DIR/alerts.xml"
		return 0
	fi

	local cc=$(jq -r '.results[0].country_code' "$cj")
	declare -A SLUGS=(
		[AD]="andorra"             [AT]="austria"             [BE]="belgium"
		[BA]="bosnia-herzegovina"  [BG]="bulgaria"           [HR]="croatia"
		[CY]="cyprus"              [CZ]="czechia"            [DK]="denmark"
		[EE]="estonia"             [FI]="finland"            [FR]="france"
		[DE]="germany"             [GR]="greece"             [HU]="hungary"
		[IS]="iceland"             [IE]="ireland"            [IL]="israel"
		[IT]="italy"               [LV]="latvia"             [LT]="lithuania"
		[LU]="luxembourg"          [MT]="malta"              [MD]="moldova"
		[ME]="montenegro"          [NL]="netherlands"        [MK]="republic-of-north-macedonia"
		[NO]="norway"              [PL]="poland"             [PT]="portugal"
		[RO]="romania"             [RS]="serbia"             [SK]="slovakia"
		[SI]="slovenia"            [ES]="spain"              [SE]="sweden"
		[CH]="switzerland"         [UA]="ukraine"            [GB]="united-kingdom"
	)
	local slug="${SLUGS[$cc]}"

	if [ -z "$slug" ]; then
		rm -f "$TMP_DIR/alerts.xml"
		return 0
	fi

	log "[alerts] $cc → $slug"
	curl_cmd "https://feeds.meteoalarm.org/feeds/meteoalarm-legacy-atom-${slug}" >"$TMP_DIR/alerts.xml.tmp" || { rm -f "$TMP_DIR/alerts.xml.tmp"; log "[warn] Alerts download failed"; }
	[ -s "$TMP_DIR/alerts.xml.tmp" ] && mv "$TMP_DIR/alerts.xml.tmp" "$TMP_DIR/alerts.xml" || { rm -f "$TMP_DIR/alerts.xml.tmp"; log "[warn] Alerts empty response"; }
	log "[alerts] Done → alerts.xml"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	fetch_alerts "$@"
fi
