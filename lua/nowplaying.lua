--[[[
nowplaying.lua — "now playing" media data provider (support module)

Support module that reads the JSON_PATH/nowplaying.json cache file
(produced by an external fetch script) and exposes per-field getter
functions for use in draw text via ${lua conky_nowplaying_*}. The file
is re-read lazily only when its modification time changes; decoded
results are memoized in a module-local cache.
]]--

--{{{
-- ## Now playing support module
--
-- Not a standalone widget. Decodes tmp/nowplaying.json (player, title,
-- artist, album, status, art) on demand and reloads it only when the
-- file's mtime changes.
--
-- **Exposed/global functions:**
-- - `conky_nowplaying_player()` — player name
-- - `conky_nowplaying_title()` — track title
-- - `conky_nowplaying_artist()` — artist name
-- - `conky_nowplaying_album()` — album name
-- - `conky_nowplaying_status()` — playback status
-- - `conky_nowplaying_art_path()` — cover art path
--
-- **Config/globals used:**
-- `JSON_PATH` — directory holding nowplaying.json (defaults to /tmp/)
-- `lfs.attributes()` / `json.decode()` — file stat and JSON parsing helpers
--}}}

local cache = {}
local last_mtime = 0

local function load()
	local base_path = JSON_PATH or "/tmp/"
	if base_path:sub(-1) ~= "/" then base_path = base_path .. "/" end
	local path = base_path .. "nowplaying.json"

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

function conky_nowplaying_player()
	load()
	return cache.player
end

function conky_nowplaying_title()
	load()
	return cache.title
end

function conky_nowplaying_artist()
	load()
	return cache.artist
end

function conky_nowplaying_album()
	load()
	return cache.album
end

function conky_nowplaying_status()
	load()
	return cache.status
end

function conky_nowplaying_art_path()
	load()
	return cache.art
end
