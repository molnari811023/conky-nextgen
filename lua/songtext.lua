--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
songtext.lua — synchronized lyrics data provider (support module)

Mirrors lua/nowplaying.lua: reads tmp/lyrics.json (written by the
lyrics_daemon.lua standalone process) lazily, only when the file's
modification time changes, and exposes per-field getters for draw text
via ${lua conky_lyrics_*}.
]]--

--{{{
-- ## Lyrics support module
--
-- Not a standalone widget. Decodes tmp/lyrics.json (player, status,
-- title, artist, position_ms, duration_ms, index, total, current,
-- prev[], next[], synced) on demand and reloads it only when the
-- file's mtime changes.
--
-- **Exposed/global functions:**
-- - `conky_lyrics_status()` — playback status (Playing/Paused/Stopped)
-- - `conky_lyrics_title()` — track title
-- - `conky_lyrics_artist()` — artist name
-- - `conky_lyrics_current()` — current (active) lyric line
-- - `conky_lyrics_prev()` — previous lines, newline-joined
-- - `conky_lyrics_next()` — following lines, newline-joined
-- - `conky_lyrics_position()` — position as mm:ss
-- - `conky_lyrics_position_ms()` — position as string in ms
-- - `conky_lyrics_total()` — number of synced lines
-- - `conky_lyrics_index()` — index of the active line (1-based)
-- - `conky_lyrics_synced()` — "1" when the lyrics are time-synced
--
-- **Config/globals used:**
-- `JSON_PATH` — directory holding lyrics.json (defaults to /tmp/)
-- `lfs.attributes()` / `json.decode()` — file stat and JSON parsing helpers
--}}}

local cache = {}
local last_mtime = 0

local function load()
	local base_path = JSON_PATH or "/tmp/"
	if base_path:sub(-1) ~= "/" then base_path = base_path .. "/" end
	local path = base_path .. "lyrics.json"

	local attr = lfs.attributes(path)
	if not attr then
		cache = {}
		return
	end
	if attr.modification == last_mtime then
		return
	end
	last_mtime = attr.modification
	local f = io.open(path, "r")
	if not f then
		cache = {}
		return
	end
	local content = f:read("*a")
	f:close()
	local data = json.decode(content)
	if type(data) == "table" then
		cache = data
	else
		cache = {}
	end
end

local function arr(list)
	if type(list) ~= "table" then return "" end
	return table.concat(list, "\n")
end

local function fmt_pos(ms)
	ms = tonumber(ms) or 0
	local s = math.floor(ms / 1000)
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

function conky_lyrics_status()
	load()
	return cache.status or ""
end

function conky_lyrics_title()
	load()
	return cache.title or ""
end

function conky_lyrics_artist()
	load()
	return cache.artist or ""
end

function conky_lyrics_current()
	load()
	return cache.current or ""
end

function conky_lyrics_prev()
	load()
	return arr(cache.prev)
end

function conky_lyrics_next()
	load()
	return arr(cache.next)
end

function conky_lyrics_position()
	load()
	return fmt_pos(cache.position_ms)
end

function conky_lyrics_position_ms()
	load()
	return tostring(cache.position_ms or 0)
end

function conky_lyrics_total()
	load()
	return tostring(cache.total or 0)
end

function conky_lyrics_index()
	load()
	return tostring(cache.index or 0)
end

function conky_lyrics_synced()
	load()
	return (cache.synced and "1") or "0"
end