--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- nowplaying.lua — MPRIS now playing info via playerctl (title, artist, album, album art)

local JSON = require("dkjson")

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
	local ok, data = pcall(JSON.decode, content)
	if ok and type(data) == "table" then
		cache = data
	else
		cache = {}
	end
end

function conky_nowplaying_player()
	load()
	return cache.player or ""
end

function conky_nowplaying_title()
	load()
	return cache.title or ""
end

function conky_nowplaying_artist()
	load()
	return cache.artist or ""
end

function conky_nowplaying_album()
	load()
	return cache.album or ""
end

function conky_nowplaying_status()
	load()
	return cache.status or "Stopped"
end

function conky_nowplaying_art_path()
	load()
	return cache.art or ""
end
