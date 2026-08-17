#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}

#{{{
# 13_fetch_maps.sh — Download OSM tiles, radar, temperature, wind maps
#
# Downloads a 3x3 tile grid centered on the user's city (from tmp/city.json).
# Tile sources:
#   - OpenStreetMap (base map)
#   - RainViewer API (radar overlay)
#   - Environment Canada GDPS (temperature 2m, wind 10m)
#
# Uses ImageMagick to stitch 9 tiles into 4 composite images.
# Zoom levels: 5-7 (default 7). Zoom >7 or <5 falls back to 7.
#
# Usage: source 0_common.sh && fetch_maps [zoom]
# Output: tmp/{osm_big,rain_big,temp_big,wind_big}.png
# Requires: ImageMagick (magick or convert), python3, jq
#}}}

_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/0_common.sh"

fetch_maps() {
	local MAGICK="magick"
	command -v magick >/dev/null 2>&1 || MAGICK="convert"
	command -v "$MAGICK" >/dev/null 2>&1 || { echo "[error] ImageMagick not found"; return 1; }

	local cj="$TMP_DIR/city.json"
	if [ ! -f "$cj" ]; then
		echo "[error] city.json missing — run 'weather' first!"
		return 1
	fi

	local lat=$(jq -r '.results[0].latitude' "$cj")
	local lon=$(jq -r '.results[0].longitude' "$cj")
	local zoom="${1:-7}"

	if [ "$zoom" -gt 7 ] || [ "$zoom" -lt 5 ]; then
		log "[warn] Zoom $zoom not supported → fallback to 7"
		zoom=7
	fi

	log "[map] LAT=$lat LON=$lon ZOOM=$zoom"

	read cx cy < <(python3 -c '
import sys, math
lat = float(sys.argv[1]); lon = float(sys.argv[2]); z = int(sys.argv[3])
n = 2**z
rad = math.radians(lat)
x = int((lon + 180) / 360 * n)
y = int((1 - math.asinh(math.tan(rad)) / math.pi) / 2 * n)
print(x, y)
' "$lat" "$lon" "$zoom")
	log "[map] Center tile: X=$cx Y=$cy"

	declare -a xarr yarr
	local idx=0
	for dy in -1 0 1; do
		for dx in -1 0 1; do
			xarr[$idx]=$((cx + dx))
			yarr[$idx]=$((cy + dy))
			idx=$((idx + 1))
		done
	done

	log "[map] Getting RainViewer metadata"
	local rv_data=$(curl_cmd "https://api.rainviewer.com/public/weather-maps.json")
	local rv_path=$(echo "$rv_data" | jq -r '.radar.past[-1].path')
	log "[map] Radar path: $rv_path"

	fetch_tile() {
		local out=$1 url=$2 name=$3
		curl_cmd -o "$out" "$url"
		if [ ! -s "$out" ]; then
			log "[map] Empty tile $name, retrying…"
			sleep 1
			curl_cmd -o "$out" "$url"
		fi
	}

	for i in {0..8}; do
		local x=${xarr[$i]} y=${yarr[$i]}

		fetch_tile "$TMP_DIR/osm_$i.png" \
			"https://tile.openstreetmap.org/$zoom/$x/$y.png" "osm_$i"

		read xmin ymin xmax ymax < <(python3 -c '
import sys, math
z = int(sys.argv[1]); x = int(sys.argv[2]); y = int(sys.argv[3])
n = 2**z
R = 6378137
res = 2 * math.pi * R / n
xmin = -math.pi * R + x * res
xmax = -math.pi * R + (x + 1) * res
ymax = math.pi * R - y * res
ymin = math.pi * R - (y + 1) * res
print(xmin, ymin, xmax, ymax)
' "$zoom" "$x" "$y")

		fetch_tile "$TMP_DIR/temp_$i.png" \
			"https://geo.weather.gc.ca/geomet?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&BBOX=$xmin,$ymin,$xmax,$ymax&CRS=EPSG:3857&WIDTH=256&HEIGHT=256&LAYERS=GDPS_15km_AirTemp_2m&FORMAT=image/png" "temp_$i"

		fetch_tile "$TMP_DIR/radar_$i.png" \
			"https://tilecache.rainviewer.com${rv_path}/256/$zoom/$x/$y/1/1_1.png" "radar_$i"

		fetch_tile "$TMP_DIR/wind_$i.png" \
			"https://geo.weather.gc.ca/geomet?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&BBOX=$xmin,$ymin,$xmax,$ymax&CRS=EPSG:3857&WIDTH=256&HEIGHT=256&LAYERS=GDPS_15km_Winds_10m&FORMAT=image/png&TRANSPARENT=TRUE" "wind_$i"
	done

	check_tiles() {
		local p=$1
		for i in {0..8}; do
			if [ ! -s "$TMP_DIR/${p}_$i.png" ]; then
				log "[map] Missing tile ${p}_$i.png — creating placeholder"
				$MAGICK -size 256x256 xc:transparent "$TMP_DIR/${p}_$i.png"
			fi
		done
	}

	stitch() {
		local p=$1 o=$2
		log "[map] Stitch $p → $o"
		check_tiles "$p"
		$MAGICK \
			\( "$TMP_DIR/${p}_0.png" "$TMP_DIR/${p}_1.png" "$TMP_DIR/${p}_2.png" +append \) \
			\( "$TMP_DIR/${p}_3.png" "$TMP_DIR/${p}_4.png" "$TMP_DIR/${p}_5.png" +append \) \
			\( "$TMP_DIR/${p}_6.png" "$TMP_DIR/${p}_7.png" "$TMP_DIR/${p}_8.png" +append \) \
			-append "$TMP_DIR/$o"
	}

	stitch osm  osm_big.png
	stitch radar rain_big.png
	stitch temp  temp_big.png
	stitch wind  wind_big.png

	rm -f "$TMP_DIR"/{osm,temp,radar,wind}_[0-8].png
	log "[map] Done"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	fetch_maps "$@"
fi
