--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/google/data.lua — Google data accessors for the Conky widget layer.
Exposes conky_google_* functions so conky_config can render Gmail,
Calendar, Tasks, Contacts, Drive, YouTube and Meet metrics inline.
]]--
--{{{
-- ## Google Dashboard — Data Accessors
--
-- Reads the parsed Google JSON (loaded by `lua/google/core.lua`) through the
-- global `load_google_data()` and exposes one `conky_google_*` accessor per
-- metric. Safe/empty values are returned for missing data so widgets never
-- crash.
--
-- **Data sources** (current items via `[...][idx]`):
--
-- - **Gmail** — `conky_google_unread_count()`, `conky_google_gmail_count()`,
--   `conky_google_gmail_subject(idx)`, `conky_google_gmail_from(idx)`,
--   `conky_google_gmail_date(idx)`, `conky_google_gmail_label(idx)`,
--   `conky_google_gmail_id(idx)`, `conky_google_gmail_is_unread(idx)`
-- - **Calendar** — `conky_google_calendar_count()`, `_summary(idx)`,
--   `_start(idx)`, `_end(idx)`, `_location(idx)`, `_hangout(idx)`
-- - **Tasks** — `conky_google_tasks_count()`, `_title(idx)`, `_due(idx)`,
--   `_status(idx)`, and list title via `conky_google_tasks_list_title(idx)`
-- - **Contacts** — `conky_google_contacts_count()`, `_name(idx)`, `_phone(idx)`
-- - **Drive** — `conky_google_drive_count()`, `_filesize(idx)` (B/kB/MB/GB),
--   `_name(idx)`, `_doctype(idx)` (Doc/Sheet/Slides/Folder/PDF)
-- - **YouTube** — `conky_google_youtube_count()`, `_title(idx)`
-- - **Meet** — `conky_google_meet_count()`
--
-- Local helpers `*_raw()` wrap `load_google_data()`. Uses `safe_str`,
-- `google_sender_name`, `google_date_str`, `google_msg_label` and `get_tr`
-- (translated labels) from the shared core modules.
--}}}

local function gmail_raw()
	return (load_google_data().gmail) or {}
end
local function cal_raw()
	return (load_google_data().calendar) or {}
end
local function tasks_raw()
	local t = load_google_data().tasks
	if type(t) ~= "table" or not t[1] then return {} end
	return t
end
local function tlists_raw()
	return (load_google_data().tlists) or {}
end
local function contacts_raw()
	return (load_google_data().contacts) or {}
end
local function drive_raw()
	return (load_google_data().drive) or {}
end
local function youtube_raw()
	return (load_google_data().youtube) or {}
end
local function meet_raw()
	return (load_google_data().meet) or {}
end

-- ═══ GMAIL ═══

function conky_google_unread_count()
	local n = 0
	for _, m in ipairs(gmail_raw()) do
		local labels = m.labels or {}
		local unread = false
		for _, l in ipairs(labels) do
			if l == "UNREAD" then unread = true break end
		end
		if unread then n = n + 1 end
	end
	return tostring(n)
end

function conky_google_gmail_count()
	return tostring(#gmail_raw())
end

function conky_google_gmail_subject(idx)
	return safe_str((gmail_raw()[tonumber(idx) or 1] or {}).subject, "gmail_subject")
end

function conky_google_gmail_from(idx)
	local m = gmail_raw()[tonumber(idx) or 1] or {}
	return safe_str(google_sender_name(m.from), "gmail_from")
end

function conky_google_gmail_date(idx)
	local m = gmail_raw()[tonumber(idx) or 1] or {}
	return google_date_str(m.internalDateIso or m.date)
end

function conky_google_gmail_label(idx)
	local m = gmail_raw()[tonumber(idx) or 1] or {}
	return m.subject ~= nil and google_msg_label(m) or ""
end

function conky_google_gmail_id(idx)
	local m = gmail_raw()[tonumber(idx) or 1] or {}
	return m.id or ""
end

function conky_google_gmail_is_unread(idx)
	local m = gmail_raw()[tonumber(idx) or 1] or {}
	for _, l in ipairs(m.labels or {}) do
		if l == "UNREAD" then return "1" end
	end
	return "0"
end

-- ═══ CALENDAR ═══

function conky_google_calendar_count()
	return tostring(#cal_raw())
end

function conky_google_calendar_summary(idx)
	return safe_str((cal_raw()[tonumber(idx) or 1] or {}).summary, "cal_summary")
end

function conky_google_calendar_start(idx)
	local e = cal_raw()[tonumber(idx) or 1] or {}
	if e.start then
		if type(e.start) == "table" then
			return google_date_str(e.start.dateTime or e.start.date)
		else
			return google_date_str(e.start)
		end
	end
	return e.dateTime or ""
end

function conky_google_calendar_end(idx)
	local e = cal_raw()[tonumber(idx) or 1] or {}
	if e["end"] then
		if type(e["end"]) == "table" then
			return google_date_str(e["end"].dateTime or e["end"].date)
		end
		return google_date_str(e["end"])
	end
	return ""
end

function conky_google_calendar_location(idx)
	return safe_str((cal_raw()[tonumber(idx) or 1] or {}).location, "cal_location")
end

function conky_google_calendar_hangout(idx)
	local e = cal_raw()[tonumber(idx) or 1] or {}
	local conf = e.conferenceData and e.conferenceData.entryPoints
	if conf then
		for _, ep in ipairs(conf) do
			if ep.entryPointType == "video" and ep.uri then return ep.uri end
		end
	end
	if e.hangoutLink then return e.hangoutLink end
	return ""
end

-- ═══ TASKS ═══

function conky_google_tasks_count()
	return tostring(#tasks_raw())
end

function conky_google_tasks_title(idx)
	return safe_str((tasks_raw()[tonumber(idx) or 1] or {}).title, "tasks_title")
end

function conky_google_tasks_due(idx)
	local t = tasks_raw()[tonumber(idx) or 1] or {}
	return google_date_str(t.due or t.dueDate or "")
end

function conky_google_tasks_status(idx)
	local t = tasks_raw()[tonumber(idx) or 1] or {}
	local s = t.status or ""
	if s == "completed" then return get_tr("Task_Completed") end
	if s == "needsAction" then return get_tr("Task_NeedsAction") end
	return s
end

function conky_google_tasks_list_title(idx)
	return safe_str((tlists_raw()[tonumber(idx) or 1] or {}).title, "tasks_list_title")
end

-- ═══ CONTACTS ═══

function conky_google_contacts_count()
	return tostring(#contacts_raw())
end

function conky_google_contacts_name(idx)
	return safe_str((contacts_raw()[tonumber(idx) or 1] or {}).name, "contacts_name")
end

function conky_google_contacts_phone(idx)
	return safe_str((contacts_raw()[tonumber(idx) or 1] or {}).phone, "contacts_phone")
end

-- ═══ DRIVE ═══

function conky_google_drive_count()
	return tostring(#drive_raw())
end

function conky_google_drive_filesize(idx)
	local f = drive_raw()[tonumber(idx) or 1] or {}
	local s = tonumber(f.size or 0) or 0
	if s >= 1073741824 then return string.format("%.1f GB", s / 1073741824) end
	if s >= 1048576 then return string.format("%.1f MB", s / 1048576) end
	if s >= 1024 then return string.format("%.1f kB", s / 1024) end
	return s .. " B"
end

function conky_google_drive_name(idx)
	return safe_str((drive_raw()[tonumber(idx) or 1] or {}).name, "drive_name")
end

function conky_google_drive_doctype(idx)
	local f = drive_raw()[tonumber(idx) or 1] or {}
	local mt = f.mimeType or ""
	if mt == "application/vnd.google-apps.document" then return get_tr("Drive_Doc") end
	if mt == "application/vnd.google-apps.spreadsheet" then return get_tr("Drive_Sheet") end
	if mt == "application/vnd.google-apps.presentation" then return get_tr("Drive_Slides") end
	if mt == "application/vnd.google-apps.folder" then return get_tr("Drive_Folder") end
	if mt == "application/pdf" then return "PDF" end
	return ""
end

-- ═══ YOUTUBE ═══

function conky_google_youtube_count()
	return tostring(#youtube_raw())
end

function conky_google_youtube_title(idx)
	return safe_str((youtube_raw()[tonumber(idx) or 1] or {}).title, "youtube_title")
end

-- ═══ MEET ═══

function conky_google_meet_count()
	return tostring(#meet_raw())
end
