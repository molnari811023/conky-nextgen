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
