#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## all_in_one — combined weather, alerts and maps fetcher
#
# Standalone script that embeds its own copy of the shared helpers
# (log, require_cmds, User-Agent setup, curl_cmd, urlencode) and bundles the
# weather, alerts and maps fetch routines into one file. It does not source
# 0_common.sh; paths and TMP_DIR are computed locally.
#
# **What it does:**
# - Builds a persisted User-Agent under ~/.config/conky-nextgen
#   (auto-generated without a TTY, prompted otherwise)
# - fetch_weather(): geocoding + Open-Meteo forecast/air-quality + Yr
#   sun/moon → $TMP_DIR/city.json, weather_data.json, airquality.json,
#   sun.json, moon.json, moon_next.json
# - fetch_alerts(): MeteoAlarm feed → $TMP_DIR/alerts.xml
# - fetch_maps(): ImageMagick 3x3 tile stitch → $TMP_DIR/osm_big.png,
#   temp_big.png, rain_big.png, wind_big.png
# - Dispatches by first argument: all / weather / alerts / map / <city>
#
# **Environment/requirements:** requires curl, jq, python3 and ImageMagick;
# optional WEATHER_LANG
#}}}
DEBUG=1
log() { [ "$DEBUG" -eq 1 ] && echo "$@"; }
require_cmds() { local m=0; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || { echo "[error] Missing: $c"; m=1; }; done; [ "$m" -eq 1 ] && exit 1; }
require_cmds curl jq python3
CONFIG_DIR="$HOME/.config/conky-nextgen"
UA_FILE="$CONFIG_DIR/user_agent.txt"
DEFAULT_UA="ConkyNextGen/1.0"

mkdir -p "$CONFIG_DIR"

if [ ! -f "$UA_FILE" ]; then
    if [ ! -t 0 ]; then
        # Running without TTY (systemd/cron) → generate stable unique UA
        _host=$(cat /proc/sys/kernel/hostname 2>/dev/null || hostname 2>/dev/null || echo "unknown-host")
        UA_INPUT="ConkyNG-${_host}-$(date +%s)"
        echo "[setup] Auto-generated UA: $UA_INPUT"
    else
        echo "[setup] No User-Agent found. Example: MyConky/1.0"
        read -r -p "User-Agent: " UA_INPUT
    fi
    if [ -z "$UA_INPUT" ]; then
        UA_INPUT="$DEFAULT_UA"
        echo "[setup] Using default UA: $DEFAULT_UA"
    fi
    printf '%s\n' "$UA_INPUT" > "$UA_FILE"
    chmod 600 "$UA_FILE"
fi

read -r UA < "$UA_FILE"
UA="${UA//$'\n'/}"
log "[ua] Using UA: $UA"

curl_cmd() { command curl -s -L --max-time 15 --retry 2 -f -A "$UA" "$@"; }

urlencode() {
    python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))" "$1"
}

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONKY_DIR="$(readlink -f "$SCRIPT_DIR/..")"
TMP_DIR="$CONKY_DIR/tmp"
mkdir -p "$TMP_DIR"


# -------------------------------------------------------------------
fetch_weather() {
    local city_raw="${1:-Vienna}"
    local city=$(urlencode "$city_raw")
    local lang="${WEATHER_LANG:-en}" forecast_days=7 air_forecast_days=4
    local cj="$TMP_DIR/city.json"

    log "[geo] Geocoding $city_raw"
    curl_cmd "https://geocoding-api.open-meteo.com/v1/search?name=${city}&count=1&language=${lang}&format=json" >"${cj}.tmp" || { rm -f "${cj}.tmp"; echo "[error] Geocoding failed"; return 1; }
    [ -s "${cj}.tmp" ] || { rm -f "${cj}.tmp"; echo "[error] Geocoding empty response"; return 1; }
    mv "${cj}.tmp" "$cj"

    if ! jq -e '.results and .results[0]' "$cj" >/dev/null 2>&1; then
        echo "[error] Geocoding failed for '$city_raw'"
        return 1
    fi

    local lat=$(jq -r '.results[0].latitude' "$cj")
    local lon=$(jq -r '.results[0].longitude' "$cj")
    local tz=$(jq -r '.results[0].timezone' "$cj")
    log "[geo] $city_raw LAT=$lat LON=$lon TZ=$tz"

    log "[wx] weather_data.json"
    curl_cmd "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,dew_point_2m,apparent_temperature,precipitation,rain,showers,snowfall,weather_code,pressure_msl,surface_pressure,cloud_cover,visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,is_day,direct_radiation&hourly=temperature_2m,relative_humidity_2m,dew_point_2m,apparent_temperature,precipitation_probability,precipitation,snowfall,weather_code,pressure_msl,surface_pressure,cloud_cover,visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,is_day,direct_radiation&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,daylight_duration,sunshine_duration,uv_index_max,uv_index_clear_sky_max,precipitation_sum,rain_sum,showers_sum,snowfall_sum,precipitation_hours,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,shortwave_radiation_sum,et0_fao_evapotranspiration&timeformat=unixtime&forecast_days=${forecast_days}&past_days=1&timezone=${tz}" >"$TMP_DIR/weather_data.json.tmp" || { rm -f "$TMP_DIR/weather_data.json.tmp"; log "[warn] Weather download failed"; }
    [ -s "$TMP_DIR/weather_data.json.tmp" ] && mv "$TMP_DIR/weather_data.json.tmp" "$TMP_DIR/weather_data.json" || { rm -f "$TMP_DIR/weather_data.json.tmp"; log "[warn] Weather empty response"; }

    log "[air] airquality.json"
    curl_cmd "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${lat}&longitude=${lon}&current=european_aqi,us_aqi,pm10,pm2_5,carbon_monoxide,ozone,dust,nitrogen_dioxide,sulphur_dioxide,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen&hourly=pm10,pm2_5,carbon_monoxide,ozone,dust,european_aqi,us_aqi,nitrogen_dioxide,sulphur_dioxide,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen&timeformat=unixtime&forecast_days=${air_forecast_days}&past_days=1&timezone=${tz}" >"$TMP_DIR/airquality.json.tmp" || { rm -f "$TMP_DIR/airquality.json.tmp"; log "[warn] Air quality download failed"; }
    [ -s "$TMP_DIR/airquality.json.tmp" ] && mv "$TMP_DIR/airquality.json.tmp" "$TMP_DIR/airquality.json" || { rm -f "$TMP_DIR/airquality.json.tmp"; log "[warn] Air quality empty response"; }

    local date=$(date +%Y-%m-%d)
    local offset=$(date +%:z)

    log "[sun] sun.json"
    curl_cmd "https://api.met.no/weatherapi/sunrise/3.0/sun?lat=${lat}&lon=${lon}&date=${date}&offset=${offset}" >"$TMP_DIR/sun.json.tmp" || { rm -f "$TMP_DIR/sun.json.tmp"; log "[warn] Sun download failed"; }
    [ -s "$TMP_DIR/sun.json.tmp" ] && mv "$TMP_DIR/sun.json.tmp" "$TMP_DIR/sun.json" || { rm -f "$TMP_DIR/sun.json.tmp"; log "[warn] Sun empty response"; }

    log "[moon] moon.json"
    curl_cmd "https://api.met.no/weatherapi/sunrise/3.0/moon?lat=${lat}&lon=${lon}&date=${date}&offset=${offset}" >"$TMP_DIR/moon.json.tmp" || { rm -f "$TMP_DIR/moon.json.tmp"; log "[warn] Moon download failed"; }
    [ -s "$TMP_DIR/moon.json.tmp" ] && mv "$TMP_DIR/moon.json.tmp" "$TMP_DIR/moon.json" || { rm -f "$TMP_DIR/moon.json.tmp"; log "[warn] Moon empty response"; }

    local next_date=$(date -d "${date} +1 day" +%Y-%m-%d 2>/dev/null || date -v+1d +%Y-%m-%d 2>/dev/null)
    if [ -n "$next_date" ]; then
        log "[moon] moon_next.json"
        curl_cmd "https://api.met.no/weatherapi/sunrise/3.0/moon?lat=${lat}&lon=${lon}&date=${next_date}&offset=${offset}" >"$TMP_DIR/moon_next.json.tmp" || { rm -f "$TMP_DIR/moon_next.json.tmp"; log "[warn] Moon next download failed"; }
        [ -s "$TMP_DIR/moon_next.json.tmp" ] && mv "$TMP_DIR/moon_next.json.tmp" "$TMP_DIR/moon_next.json" || { rm -f "$TMP_DIR/moon_next.json.tmp"; log "[warn] Moon next empty response"; }
    fi

    # MET Norway locationforecast backup (when Open-Meteo fails)
    # log "[met] metnorway_raw.json"
    # curl_cmd "https://api.met.no/weatherapi/locationforecast/2.0/complete?lat=${lat}&lon=${lon}" >"$TMP_DIR/metnorway_raw.json.tmp" || { rm -f "$TMP_DIR/metnorway_raw.json.tmp"; log "[warn] MET Norway download failed"; }
    # [ -s "$TMP_DIR/metnorway_raw.json.tmp" ] && mv "$TMP_DIR/metnorway_raw.json.tmp" "$TMP_DIR/metnorway_raw.json" || { rm -f "$TMP_DIR/metnorway_raw.json.tmp"; log "[warn] MET Norway empty response"; }
}

# -------------------------------------------------------------------
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

# -------------------------------------------------------------------
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

    # --- Mercator tile center ---
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

    # --- Download 3x3 tile grid ---
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

    # --- Stitch with ImageMagick ---
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

    # --- Cleanup ---
    rm -f "$TMP_DIR"/{osm,temp,radar,wind}_[0-8].png
    log "[map] Done"
}

# -------------------------------------------------------------------
# ARGUMENT PARSING
# -------------------------------------------------------------------
MODE="${1:-all}"

case "$MODE" in
all)
    fetch_weather "${2:-Vienna}"
    fetch_alerts
    fetch_maps "${3:-7}"
    ;;
weather)
    fetch_weather "${2:-Vienna}"
    ;;
space)
    ;;
alerts)
    fetch_alerts
    ;;
map)
    fetch_maps "${2:-7}"
    ;;
*)
    fetch_weather "$*"
    ;;
esac
