#!/bin/bash
#[[
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#]]
# fetch_nowplaying.sh — Fetch current track info + album art via playerctl (MPRIS)
# Sources 0_common.sh. Call: source fetch_nowplaying.sh && fetch_nowplaying

[ -n "$_FETCH_NOWPLAYING" ] && return || _FETCH_NOWPLAYING=1

fetch_nowplaying() {
	json="$TMP_DIR/nowplaying.json"
	art="$TMP_DIR/album_art.png"

	if ! command -v playerctl &>/dev/null; then
		printf '{"player":"","title":"","artist":"","album":"","status":"Stopped","art":""}\n' > "$json"
		rm -f "$art"
		return
	fi

	player=$(playerctl -l 2>/dev/null | head -1)
	if [ -z "$player" ]; then
		printf '{"player":"","title":"","artist":"","album":"","status":"Stopped","art":""}\n' > "$json"
		rm -f "$art"
		return
	fi

	curr_title=$(playerctl metadata xesam:title 2>/dev/null)
	prev_title=$(python3 -c "
import sys, json
try:
    with open('$json') as f: d = json.load(f)
    print(d.get('title', ''))
except: print('')
" 2>/dev/null)

	[ "$curr_title" = "$prev_title" ] && return

	title=$(playerctl metadata xesam:title 2>/dev/null)
	artist=$(playerctl metadata xesam:artist 2>/dev/null)
	album=$(playerctl metadata xesam:album 2>/dev/null)
	status=$(playerctl status 2>/dev/null)
	art_url=$(playerctl metadata mpris:artUrl 2>/dev/null)

	art_path=""
	if [ -n "$art_url" ]; then
		python3 -c "
import sys, urllib.parse, shutil
url = '$art_url'
path = urllib.parse.unquote(url.replace('file://', ''))
shutil.copy2(path, '$art')
" 2>/dev/null && art_path="$art"
	fi

	printf '{"player":"%s","title":"%s","artist":"%s","album":"%s","status":"%s","art":"%s"}\n' \
		"$player" "$title" "$artist" "$album" "$status" "$art_path" > "$json"
}
