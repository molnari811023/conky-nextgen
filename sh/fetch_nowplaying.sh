#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## Now Playing — metadata + cover art fetcher
#
# Detects the active music player (MPRIS via `playerctl`, `cmus`, `mpd`,
# or `moc`), collects title/artist/album/status, downloads the cover art,
# and writes the result to `$TMP_DIR/nowplaying.json` (+ `album_art.png`).
#
# **Output JSON:**
#   `{"player","title","artist","album","status","art"}`
#   When stopped/no player → empty player and `"Stopped"` status, art removed.
#
# **Player detection order** (first match wins):
#   1. MPRIS/`playerctl` — modern desktops
#   2. `cmus-remote` — CMUS
#   3. `mpc` + `mpd` — MPD
#   4. `mocp` — MOC
#
# **Cover art** (via embedded python3): `file://` and `http(s)` URLs are
#   copied/downloaded to the tmp path; missing/failed art is cleaned up.
#   A change-cache skips rewriting when title/artist/status/art are unchanged.
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
		local p_list
		p_list=$(playerctl -l 2>/dev/null || true)
		local active_player=""
		for p in $p_list; do
			local st
			st=$(playerctl -p "$p" status 2>/dev/null || echo "Stopped")
			if [ "$st" = "Playing" ]; then
				active_player="$p"
				status="Playing"
				break
			elif [ "$st" = "Paused" ] && [ -z "$active_player" ]; then
				active_player="$p"
				status="Paused"
			fi
		done
		[ -z "$active_player" ] && active_player=$(echo "$p_list" | head -1)

		if [ -n "$active_player" ]; then
			player="$active_player"
			status=$(playerctl -p "$player" status 2>/dev/null || echo "Stopped")
			title=$(playerctl -p "$player" metadata xesam:title 2>/dev/null || echo "")
			artist=$(playerctl -p "$player" metadata xesam:artist 2>/dev/null || echo "")
			album=$(playerctl -p "$player" metadata xesam:album 2>/dev/null || echo "")
			art_url=$(playerctl -p "$player" metadata mpris:artUrl 2>/dev/null || echo "")
		fi
	fi

	# B) Native Audacious via audtool (fallback if playerctl is not Playing)
	if [ "$status" != "Playing" ] && command -v audtool &>/dev/null && pgrep -x audacious &>/dev/null; then
		local aud_st
		aud_st=$(audtool playback-status 2>/dev/null || echo "stopped")
		if [ "$aud_st" = "playing" ] || [ "$aud_st" = "paused" ]; then
			player="Audacious"
			status="${aud_st^}"
			title=$(audtool current-song-tuple-data title 2>/dev/null || true)
			[ -z "$title" ] && title=$(audtool current-song 2>/dev/null || echo "")
			artist=$(audtool current-song-tuple-data artist 2>/dev/null || echo "")
			album=$(audtool current-song-tuple-data album 2>/dev/null || echo "")
			local fn
			fn=$(audtool current-song-filename 2>/dev/null || echo "")
			if [ -n "$fn" ]; then
				local dir
				dir=$(dirname "$fn")
				for cov in "$dir/cover.jpg" "$dir/cover.png" "$dir/folder.jpg" "$dir/folder.png"; do
					if [ -f "$cov" ]; then
						art_url="file://$cov"
						break
					fi
				done
			fi
		fi
	# C) CMUS
	elif [ "$status" != "Playing" ] && command -v cmus-remote &>/dev/null && pgrep -x cmus &>/dev/null; then
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

	# D) MPD
	elif [ "$status" != "Playing" ] && command -v mpc &>/dev/null && pgrep -x mpd &>/dev/null; then
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

	# E) MOC
	elif [ "$status" != "Playing" ] && command -v mocp &>/dev/null && pgrep -x mocp &>/dev/null; then
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
        from PIL import Image
        import io
        if art_url.startswith('file://'):
            local_path = urllib.parse.unquote(art_url.replace('file://', ''))
            with Image.open(local_path) as im:
                im.convert('RGBA').save(tmp_art, 'PNG')
            os.replace(tmp_art, art_path_target)
            curr_data['art'] = art_path_target
        elif art_url.startswith('http://') or art_url.startswith('https://'):
            req = urllib.request.Request(art_url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=2) as response:
                raw = response.read()
            with Image.open(io.BytesIO(raw)) as im:
                im.convert('RGBA').save(tmp_art, 'PNG')
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

	if [ "$TMP_DIR" != "$HOME/.conky/tmp" ] && [ -f "$json" ]; then
		mkdir -p "$HOME/.conky/tmp" 2>/dev/null || true
		cp -f "$json" "$HOME/.conky/tmp/nowplaying.json" 2>/dev/null || true
		[ -f "$art" ] && cp -f "$art" "$HOME/.conky/tmp/album_art.png" 2>/dev/null || true
	fi
}