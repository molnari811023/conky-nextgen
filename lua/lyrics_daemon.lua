--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lyrics_daemon.lua — pure-Lua lyrics fetcher + synchronizer (standalone)

Runs OUTSIDE Conky with the system Lua interpreter (no Python):

    lua lyrics_daemon.lua          # foreground
    nohup lua lyrics_daemon.lua &  # background (or systemd unit)

Loop (every ~1s):
  1. Read Audacious state via `audtool` (artist, title, status,
     position in ms, duration in ms).
  2. On track change, fetch time-synced lyrics from LRCLIB over HTTPS
     (lua-sec) — only once per track.
  3. Parse the LRC and pick the current line from the position.
  4. Write tmp/lyrics.json atomically:
     {player,status,title,artist,position_ms,duration_ms,
      index,total,current,prev[],next[],synced}

Conky side reads only this file (lua/songtext.lua), never blocks.
]]--

local socket     = require("socket")
local ssl_https  = require("ssl.https")
local ltn12      = require("ltn12")
local dkjson     = require("dkjson")
local lfs        = require("lfs")

-- {{{ Config
local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local JSON_PATH  = script_dir .. "tmp/"
local OUT_FILE   = JSON_PATH .. "lyrics.json"

local QBASE      = "https://lrclib.net/api/get?"
local UA         = "conky-nextgen/1.0 (https://github.com/molnari811023/conky-nextgen)"
local POLL_MS    = 1000          -- daemon loop interval
local PREV_N     = 2             -- how many previous lines to expose
local NEXT_N     = 2             -- how many following lines to expose
-- }}}

local function sh(cmd)
	local p = io.popen(cmd .. " 2>/dev/null")
	if not p then return "" end
	local out = p:read("*a")
	p:close()
	return (out and out:gsub("[\r\n]+$", "") or "")
end

local function urlencode(s)
	return (s:gsub("[^%w%-%._~]", function(c)
		return ("%%%02X"):format(c:byte())
	end))
end

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- {{{ LRC parsing
local function parse_lrc(text)
	local lines = {}
	for raw in (text .. "\n"):gmatch("([^\n]*)\n") do
		local l = raw:gsub("\r$", "")

		local tags = {}
		while true do
			local t, rest = l:match("^%[([^%]]+)%](.*)$")
			if not t then break end
			tags[#tags + 1] = t
			l = rest
		end

		local words = trim(l)
		if #tags > 0 and words ~= "" then
			for _, tag in ipairs(tags) do
				local mm, ss, ms = tag:match("(%d+):(%d+)[%.%:](%d+)")
				if mm and ss and ms then
					ms = tonumber(ms)
					if #tostring(ms) == 1 then ms = ms * 100
					elseif #tostring(ms) == 2 then ms = ms * 10 end
					lines[#lines + 1] = {
						time  = tonumber(mm) * 60000 + tonumber(ss) * 1000 + ms,
						words = words,
					}
				end
			end
		end
	end
	table.sort(lines, function(a, b) return a.time < b.time end)
	return lines
end

local function current_index(pos_ms, lines)
	local idx = 0
	for i, l in ipairs(lines) do
		if pos_ms >= l.time then idx = i else break end
	end
	return idx
end
-- }}}

-- {{{ LRCLIB fetch (once per track)
local function fetch_synced(artist, title)
	local url = QBASE
		.. "artist_name=" .. urlencode(artist)
		.. "&track_name=" .. urlencode(title)

	local chunk = {}
	local _, code = ssl_https.request{
		url     = url,
		headers = { ["User-Agent"] = UA, ["Accept"] = "application/json" },
		timeout = 8,
		sink    = ltn12.sink.table(chunk),
	}
	if code ~= 200 then
		if code == 404 then return nil, nil end   -- not in database
		return nil, "HTTP " .. tostring(code)
	end
	local body = table.concat(chunk)
	if body == "" then return nil, nil end

	local ok, js = pcall(dkjson.decode, body)
	if not ok or type(js) ~= "table" then return nil, "bad json" end

	local synced = js.syncedLyrics
	if type(synced) ~= "string" or synced == "" then
		return nil, nil   -- only plain/unsynced lyrics available
	end

	local lines = parse_lrc(synced)
	return lines
end
-- }}}

-- {{{ JSON output helpers
local function snapshot(state, lines, position_ms, status)
	local idx = 0
	local synced = #lines > 1 and lines[1].time ~= 0
	if synced then
		idx = current_index(position_ms, lines)
	end

	local prev, next = {}, {}
	for i = math.max(1, idx - PREV_N), idx - 1 do
		prev[#prev + 1] = lines[i].words
	end
	for i = idx + 1, math.min(#lines, idx + NEXT_N) do
		next[#next + 1] = lines[i].words
	end

	local out = {
		player      = "Audacious",
		status      = status,
		title       = state.title,
		artist      = state.artist,
		position_ms = position_ms,
		duration_ms = state.duration_ms,
		index       = idx,
		total       = #lines,
		current     = synced and (lines[idx] and lines[idx].words or "") or "",
		prev        = prev,
		next        = next,
		synced      = synced,
	}

	local f = io.open(OUT_FILE .. ".tmp", "w")
	if f then
		f:write(dkjson.encode(out))
		f:close()
		os.rename(OUT_FILE .. ".tmp", OUT_FILE)
	end
end

local function write_stopped()
	local out = {
		player      = "Audacious",
		status      = "Stopped",
		title       = "", artist = "",
		position_ms = 0, duration_ms = 0,
		index = 0, total = 0,
		current = "", prev = {}, next = {},
		synced  = false,
	}
	local f = io.open(OUT_FILE .. ".tmp", "w")
	if f then
		f:write(dkjson.encode(out))
		f:close()
		os.rename(OUT_FILE .. ".tmp", OUT_FILE)
	end
end
-- }}}

-- {{{ Main loop
local state = { artist = "", title = "", duration_ms = 0 }
local lines = {}

if not lfs.attributes(JSON_PATH, "mode") then
	lfs.mkdir(JSON_PATH)
end

while true do
	local status   = trim(sh("audtool playback-status"))
	local artist   = trim(sh("audtool current-song-tuple-data artist"))
	local title    = trim(sh("audtool current-song-tuple-data title"))
	local pos_s    = trim(sh("audtool current-song-output-length-frames"))
	local dur_s    = trim(sh("audtool current-song-length-frames"))

	if status == "" or status == "stopped" then
		state.artist, state.title = "", ""
		lines = {}
		write_stopped()
		socket.sleep(POLL_MS / 1000)
	else
		local position_ms = tonumber(pos_s) or 0
		local duration_ms = tonumber(dur_s) or 0

		if artist ~= state.artist or title ~= state.title then
			state.artist, state.title = artist, title
			state.duration_ms = duration_ms

			-- swap the UI immediately: never keep the previous track's
			-- lyrics glued to the new header while the fetch runs
			lines = {}
			snapshot(state, lines, 0, "Loading")

			local ok, fetched = pcall(fetch_synced, artist, title)
			if ok and fetched then
				lines = fetched
				-- the fetch may have taken a while; re-read position so
				-- the first idx matches the new track
				local pos2 = trim(sh("audtool current-song-output-length-frames"))
				local dur2 = trim(sh("audtool current-song-length-frames"))
				position_ms = tonumber(pos2) or 0
				duration_ms = tonumber(dur2) or duration_ms
				state.duration_ms = duration_ms
			else
				if not ok or fetched ~= nil then
					io.stderr:write("LYRICS fetch failed for '"
						.. artist .. " - " .. title .. "': " .. tostring(fetched) .. "\n")
				end
			end
		end

		if duration_ms ~= 0 then state.duration_ms = duration_ms end
		snapshot(state, lines, position_ms, status)
	end

	socket.sleep(POLL_MS / 1000)
end
-- }}}