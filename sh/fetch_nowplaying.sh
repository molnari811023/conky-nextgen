#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}

#{{{
# fetch_nowplaying.sh — Multi-player track info + album art fetcher
#
# Supported players (auto-detected in priority order):
#   1. playerctl (MPRIS2) — Spotify, VLC, Firefox, Chrome, etc.
#   2. CMUS — cmus-remote
#   3. MPD — mpc
#   4. MOC — mocp
#
# Features:
#   - Caches JSON to avoid re-downloading album art when track unchanged
#   - Supports file:// and http:// album art URLs
#   - Falls back to "Unknown Title"/"Unknown Artist" for empty fields
#
# Usage: source 0_common.sh && fetch_nowplaying
# Output: tmp/nowplaying.json, tmp/album_art.png
#}}}

[ -n "$_FETCH_NOWPLAYING" ] && return || _FETCH_NOWPLAYING=1

fetch_nowplaying() {
	json="$TMP_DIR/nowplaying.json"
	art="$TMP_DIR/album_art.png"

	player=""
	status="Stopped"
	title=""
	artist=""
	album=""
	art_url=""

	# --- DETECTION ---

	# A) Modern players (MPRIS / playerctl)
	if command -v playerctl &>/dev/null && playerctl -l 2>/dev/null | grep -q .; then
		player=$(playerctl -l 2>/dev/null | head -1)
		status=$(playerctl status 2>/dev/null || echo "Stopped")
		title=$(playerctl metadata xesam:title 2>/dev/null || echo "")
		artist=$(playerctl metadata xesam:artist 2>/dev/null || echo "")
		album=$(playerctl metadata xesam:album 2>/dev/null || echo "")
		art_url=$(playerctl metadata mpris:artUrl 2>/dev/null || echo "")

	# B) CMUS
	elif command -v cmus-remote &>/dev/null && pgrep -x cmus &>/dev/null; then
		player="CMUS"
		cmus_out=$(cmus-remote -Q 2>/dev/null)
		status=$(echo "$cmus_out" | grep '^status ' | sed 's/^status //')
		title=$(echo "$cmus_out" | grep '^tag title ' | sed 's/^tag title //')
		artist=$(echo "$cmus_out" | grep '^tag artist ' | sed 's/^tag artist //')
		album=$(echo "$cmus_out" | grep '^tag album ' | sed 's/^tag album //')
		if [ -z "$title" ]; then
			file_path=$(echo "$cmus_out" | grep '^file ' | sed 's/^file //')
			title=$(basename "$file_path")
		fi

	# C) MPD
	elif command -v mpc &>/dev/null && pgrep -x mpd &>/dev/null; then
		player="MPD"
		mpc_out=$(mpc status 2>/dev/null)
		if echo "$mpc_out" | grep -q "playing"; then status="Playing"
		elif echo "$mpc_out" | grep -q "paused"; then status="Paused"
		else status="Stopped"; fi

		if [ "$status" != "Stopped" ]; then
			title=$(mpc current -f "%title%" 2>/dev/null)
			artist=$(mpc current -f "%artist%" 2>/dev/null)
			album=$(mpc current -f "%album%" 2>/dev/null)
			[ -z "$title" ] && title=$(mpc current -f "%file%" 2>/dev/null)
		fi

	# D) MOC
	elif command -v mocp &>/dev/null && pgrep -x mocp &>/dev/null; then
		player="MOC"
		moc_out=$(mocp -i 2>/dev/null)
		status=$(echo "$moc_out" | grep '^State: ' | sed 's/^State: //')
		title=$(echo "$moc_out" | grep '^Title: ' | sed 's/^Title: //')
		artist=$(echo "$moc_out" | grep '^Artist: ' | sed 's/^Artist: //')
		album=$(echo "$moc_out" | grep '^Album: ' | sed 's/^Album: //')
	fi

	# Normalize fields and apply fallbacks
	[ -z "$title" ]  && title="Unknown Title"
	[ -z "$artist" ] && artist="Unknown Artist"
	local status_lower="${status,,}"

	# --- RENDER + CACHE (Python via Environment) ---
	if [ -z "$player" ] || [ "$status_lower" = "stopped" ] || [ "$status_lower" = "stop" ]; then
		printf '{"player":"","title":"","artist":"","album":"","status":"Stopped","art":""}\n' > "$json"
		rm -f "$art"
		return
	fi

	export NEXTGEN_PLAYER="$player"
	export NEXTGEN_STATUS="${status^}"
	export NEXTGEN_TITLE="$title"
	export NEXTGEN_ARTIST="$artist"
	export NEXTGEN_ALBUM="$album"
	export NEXTGEN_ART_URL="$art_url"
	export NEXTGEN_JSON_PATH="$json"
	export NEXTGEN_ART_PATH="$art"

	python3 -c "
import sys, json, os, urllib.parse, urllib.request

json_path = os.environ.get('NEXTGEN_JSON_PATH')
art_path_target = os.environ.get('NEXTGEN_ART_PATH')

curr_data = {
    'player': os.environ.get('NEXTGEN_PLAYER', '').strip(),
    'title': os.environ.get('NEXTGEN_TITLE', '').strip(),
    'artist': os.environ.get('NEXTGEN_ARTIST', '').strip(),
    'album': os.environ.get('NEXTGEN_ALBUM', '').strip(),
    'status': os.environ.get('NEXTGEN_STATUS', '').strip().title(),
    'art': ''
}

if os.path.exists(json_path):
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            prev_data = json.load(f)
            art_file_ok = not prev_data.get('art') or os.path.exists(prev_data.get('art'))
            if (prev_data.get('title') == curr_data['title'] and
                prev_data.get('artist') == curr_data['artist'] and
                prev_data.get('status') == curr_data['status'] and
                art_file_ok):
                sys.exit(0)
    except:
        pass

art_url = os.environ.get('NEXTGEN_ART_URL', '').strip()
tmp_art = art_path_target + '.tmp'
if art_url:
    try:
        if art_url.startswith('file://'):
            local_path = urllib.parse.unquote(art_url.replace('file://', ''))
            import shutil
            shutil.copy2(local_path, tmp_art)
            os.replace(tmp_art, art_path_target)
            curr_data['art'] = art_path_target
        elif art_url.startswith('http://') or art_url.startswith('https://'):
            req = urllib.request.Request(art_url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=2) as response, open(tmp_art, 'wb') as out_file:
                out_file.write(response.read())
            os.replace(tmp_art, art_path_target)
            curr_data['art'] = art_path_target
    except:
        if os.path.exists(tmp_art): os.remove(tmp_art)
        if os.path.exists(art_path_target): os.remove(art_path_target)
else:
    if os.path.exists(art_path_target):
        os.remove(art_path_target)

with open(json_path + '.tmp', 'w', encoding='utf-8') as f:
    json.dump(curr_data, f, ensure_ascii=False)
os.replace(json_path + '.tmp', json_path)
" 2>/dev/null

	# Cleanup environment
	unset NEXTGEN_PLAYER NEXTGEN_STATUS NEXTGEN_TITLE NEXTGEN_ARTIST NEXTGEN_ALBUM NEXTGEN_ART_URL NEXTGEN_JSON_PATH NEXTGEN_ART_PATH
}
