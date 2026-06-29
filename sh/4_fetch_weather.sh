#!/bin/bash
#[[
#  Conky NextGen Framework
#  Author: István Molnár
#]]
# 4_fetch_weather.sh — Download weather, air quality, sun/moon data

_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/0_common.sh"

fetch_weather() {
	local city_raw="${1:-Vienna}"
	local city=$(urlencode "$city_raw")
	local lang="hu" forecast_days=7 air_forecast_days=4
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
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	fetch_weather "$@"
fi
