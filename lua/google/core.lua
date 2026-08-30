--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/google/core.lua — loads Google JSON data files into a global `G` table and exposes helpers for labels, senders, and dates
]]--

--{{{
-- ## Google Dashboard — Core
--
-- Loads Google API JSON files (gmail, calendar, tasks, contacts, drive,
-- youtube, meet) from the configured `JSON_PATH` into a global `G` table,
-- wrapping each payload into the single-object array where needed. Reads are
-- cached in memory and only re-populated when any source file's mtime changes
-- (checked at most once every 5 seconds).
--
-- **Exposed/global functions:**
-- - `load_google_data()` — returns cached Google data, triggering `G.populate()` on file changes
-- - `G.populate()` — reads and parses all JSON files into the `G` data structure
-- - `google_label_text(label)` — maps a Gmail label to its translation or a readable fallback
-- - `google_msg_label(msg)` — returns the first human-readable label prioritizing INBOX/CATEGORY
-- - `google_label_is_system(label)` — whether a label is a Gmail system label
-- - `google_sender_name(from)` — extracts and cleans a sender display name from a raw address
-- - `google_date_str(internalDateIso)` — converts an ISO date to a readable string
--
-- **Globals/data structures:**
-- - `G` — global table holding parsed data under keys `gmail`, `calendar`, `tlists`, `tasks`, `contacts`, `drive`, `youtube`, `meet`
-- - requires `package.path` to provide `JSON_PATH`, `get_tr`, and `lfs`
--}}}

local google_cache_storage = nil
local google_cache_mtimes = {}
local last_google_mtime_check = 0

local google_cached_files = {
	"gmail_emails.json",
	"calendar_events.json",
	"tasks_lists.json",
	"tasks.json",
	"contacts.json",
	"drive_files.json",
	"youtube_subs.json",
	"meet_history.json",
}

local function gfile_mtime(path)
	local attrs = lfs.attributes(path)
	return attrs and attrs.modification or 0
end

local function gjson_changed()
	local changed = false
	for i = 1, #google_cached_files do
		local path = JSON_PATH .. google_cached_files[i]
		local m = gfile_mtime(path)
		if (google_cache_mtimes[path] or 0) ~= m then
			google_cache_mtimes[path] = m
			changed = true
		end
	end
	return changed
end

local function gread_j(path)
	local f = io.open(path, "r")
	if not f then return {} end
	local c = f:read("*all")
	f:close()
	if not c or c == "" then return {} end
	return json.decode(c) or {}
end

G = G or {}
function G.populate()
	local data = {
		gmail   = gread_j(JSON_PATH .. "gmail_emails.json"),
		calendar= gread_j(JSON_PATH .. "calendar_events.json"),
		tlists  = gread_j(JSON_PATH .. "tasks_lists.json"),
		tasks   = gread_j(JSON_PATH .. "tasks.json"),
		contacts= gread_j(JSON_PATH .. "contacts.json"),
		drive   = gread_j(JSON_PATH .. "drive_files.json"),
		youtube = gread_j(JSON_PATH .. "youtube_subs.json"),
		meet    = gread_j(JSON_PATH .. "meet_history.json"),
	}
	-- gmail may be a single object (not array) in some gog versions
	if type(data.gmail) == "table" and not data.gmail[1] and data.gmail.subject then
		data.gmail = { data.gmail }
	end
	if type(data.calendar) == "table" and not data.calendar[1] and data.calendar.summary then
		data.calendar = { data.calendar }
	end
	if type(data.tlists) == "table" and not data.tlists[1] and data.tlists.title then
		data.tlists = { data.tlists }
	end
	if type(data.tasks) == "table" and not data.tasks[1] and data.tasks.title then
		data.tasks = { data.tasks }
	end
	if type(data.contacts) == "table" and not data.contacts[1] and data.contacts.name then
		data.contacts = { data.contacts }
	end
	if type(data.youtube) == "table" and not data.youtube[1] and data.youtube.title then
		data.youtube = { data.youtube }
	end
	google_cache_storage = data
end

function load_google_data()
	local now = os.time()
	if not google_cache_storage or (now - last_google_mtime_check > 5) then
		last_google_mtime_check = now
		if gjson_changed() or not google_cache_storage then
			G.populate()
		end
	end
	return google_cache_storage or {}
end

-- ═══ GMAIL LABELS ═══

local GMAIL_LABEL_MAP = {
	["INBOX"]             = "Labels_Inbox",
	["SPAM"]              = "Labels_Spam",
	["TRASH"]             = "Labels_Trash",
	["STARRED"]           = "Labels_Starred",
	["IMPORTANT"]         = "Labels_Important",
	["SENT"]              = "Labels_Sent",
	["DRAFT"]             = "Labels_Drafts",
	["CATEGORY_PERSONAL"] = "Labels_CategoryPersonal",
	["CATEGORY_SOCIAL"]   = "Labels_CategorySocial",
	["CATEGORY_PROMOTIONS"]= "Labels_CategoryPromotions",
	["CATEGORY_UPDATES"]  = "Labels_CategoryUpdates",
	["CATEGORY_FORUMS"]   = "Labels_CategoryForums",
	["UNREAD"]            = "Labels_Unread",
	["CHAT"]              = "Labels_Chat",
}

function google_label_text(label)
	local key = GMAIL_LABEL_MAP[label]
	if key then
		return get_tr(key)
	end
	-- fallback: strip CATEGORY_/INBOX-ish prefixes, keep readable
	local s = tostring(label)
	s = s:gsub("^CATEGORY_", "")
	s = s:gsub("^[%u]+_", "")
	return s
end

-- first human-readable label of a message (uses INBOX/CATEGORY priority)
function google_msg_label(msg)
	if type(msg) ~= "table" then return "" end
	local labels = msg.labels or {}
	local order = {
		"INBOX", "STARRED", "IMPORTANT",
		"CATEGORY_PERSONAL", "CATEGORY_SOCIAL",
		"CATEGORY_PROMOTIONS", "CATEGORY_UPDATES", "CATEGORY_FORUMS",
		"SPAM", "TRASH", "DRAFT", "UNREAD", "CHAT",
	}
	for _, o in ipairs(order) do
		for _, l in ipairs(labels) do
			if l == o then return google_label_text(l) end
		end
	end
	for _, l in ipairs(labels) do
		if not l:match("^CATEGORY_") and not google_label_is_system(l) then
			return l
		end
	end
	return labels[1] or ""
end

function google_label_is_system(label)
	local sys = {
		"INBOX", "SPAM", "TRASH", "STARRED", "IMPORTANT", "SENT", "DRAFT",
		"UNREAD", "CHAT", "Snoozed", "Scheduled",
	}
	for _, s in ipairs(sys) do if s == label then return true end end
	return false
end

function google_sender_name(from)
	if type(from) ~= "string" then return "" end
	local name = from:match("^(.-)%s*<%s*[^%s>]+%s*>")
	if not name then
		name = from:match("^([^@]+)")
	end
	return (name or ""):gsub("%s+$", ""):gsub('^"', ""):gsub('"$', "")
end

function google_date_str(internalDateIso)
	if type(internalDateIso) ~= "string" then return "" end
	return (internalDateIso:gsub("T", " "):gsub("([+%-]%d%d):?(%d%d)$", "%1%2"))
end

if JSON_PATH then
	load_google_data()
end
