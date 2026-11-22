--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[=[
lua/icloud/data.lua — Apple iCloud data accessors for the Conky widget layer.
Exposes conky_icloud_* functions for Account, Storage quota/media, Find My
devices, GPS coordinates, reverse-geocoded street address, OSM street map,
iCloud Calendar events, and iOS Reminders.
]=]
--{{{
-- ## iCloud Dashboard — Data Accessors
--
-- Reads the parsed iCloud JSON (loaded by `lua/icloud/core.lua` via
-- `load_icloud_data()`) and exposes `conky_icloud_*` accessors:
--
-- - **Status & Account:** `conky_icloud_status()`, `conky_icloud_error()`,
--   `conky_icloud_apple_id()`, `conky_icloud_updated()`
-- - **Storage Quota & Media Breakdown:** `conky_icloud_storage_total_gb()`,
--   `conky_icloud_storage_used_gb()`, `conky_icloud_storage_free_gb()`,
--   `conky_icloud_storage_perc()`, `conky_icloud_media_count()`,
--   `conky_icloud_media_key(i)`, `conky_icloud_media_label(i)`,
--   `conky_icloud_media_gb(i)`, `conky_icloud_media_mb(i)`,
--   `conky_icloud_media_perc(i)`, `conky_icloud_media_color(i)`
-- - **Find My Devices & Battery:** `conky_icloud_device_count()`,
--   `conky_icloud_device_name(i)`, `conky_icloud_device_model(i)`,
--   `conky_icloud_device_class(i)`, `conky_icloud_device_battery(i)`,
--   `conky_icloud_device_battery_status(i)`
-- - **Find My GPS & Street Address (Nominatim):** `conky_icloud_loc_lat(i)`,
--   `conky_icloud_loc_lon(i)`, `conky_icloud_loc_accuracy(i)`,
--   `conky_icloud_loc_type(i)`, `conky_icloud_loc_updated(i)`,
--   `conky_icloud_loc_country(i)`, `conky_icloud_loc_postcode(i)`,
--   `conky_icloud_loc_city(i)`, `conky_icloud_loc_district(i)`,
--   `conky_icloud_loc_street(i)`, `conky_icloud_loc_house_number(i)`,
--   `conky_icloud_loc_street_full(i)`, `conky_icloud_loc_short(i)`,
--   `conky_icloud_loc_display(i)`, `conky_icloud_map_path()`
-- - **Calendar & Reminders:** `conky_icloud_calendar_count()`,
--   `conky_icloud_calendar_title(i)`, `conky_icloud_calendar_start(i)`,
--   `conky_icloud_calendar_end(i)`, `conky_icloud_calendar_location(i)`,
--   `conky_icloud_reminders_count()`, `conky_icloud_reminder_title(i)`,
--   `conky_icloud_reminder_list(i)`, `conky_icloud_reminder_due(i)`
--}}}

local function icloud_root()
	return load_icloud_data() or {}
end

local function icloud_storage_raw()
	local s = icloud_root().storage
	return type(s) == "table" and s or {}
end

local function icloud_media_raw()
	local m = icloud_storage_raw().media
	return type(m) == "table" and m or {}
end

local function icloud_devices_raw()
	local d = icloud_root().devices
	return type(d) == "table" and d or {}
end

local function icloud_dev(i)
	local idx = tonumber(i) or 1
	return icloud_devices_raw()[idx] or {}
end

local function icloud_cal_raw()
	local c = icloud_root().calendar
	return type(c) == "table" and c or {}
end

local function icloud_rem_raw()
	local r = icloud_root().reminders
	return type(r) == "table" and r or {}
end

local function clamp_perc(v)
	local n = tonumber(v) or 0
	return math.min(100, math.max(0, math.floor(n + 0.5)))
end

------------------------------------------------------------
-- 1. Status & Account
------------------------------------------------------------

function icloud_is_ready()
	return icloud_root().status == "ok"
end

function conky_icloud_is_ready()
	return icloud_is_ready() and 1 or 0
end

function conky_icloud_status()
	local st = icloud_root().status
	return (st and st ~= "") and st or "unconfigured"
end

function conky_icloud_error()
	return icloud_root().error or ""
end

function conky_icloud_apple_id()
	local acc = icloud_root().account
	if type(acc) == "table" and acc.apple_id and acc.apple_id ~= "" then
		return acc.apple_id
	end
	return "N/A"
end

function conky_icloud_updated()
	local u = icloud_root().updated_str
	return (u and u ~= "") and u or "N/A"
end

------------------------------------------------------------
-- 2. iCloud Storage Quota & Media Breakdown
------------------------------------------------------------

function conky_icloud_storage_total_gb()
	return string.format("%.1f GB", tonumber(icloud_storage_raw().total_gb) or 0)
end

function conky_icloud_storage_used_gb()
	return string.format("%.2f GB", tonumber(icloud_storage_raw().used_gb) or 0)
end

function conky_icloud_storage_free_gb()
	return string.format("%.2f GB", tonumber(icloud_storage_raw().free_gb) or 0)
end

function conky_icloud_storage_perc()
	return clamp_perc(icloud_storage_raw().used_perc)
end

function conky_icloud_media_count()
	return #icloud_media_raw()
end

function conky_icloud_media_key(i)
	local m = icloud_media_raw()[tonumber(i) or 1] or {}
	return m.key or ""
end

function conky_icloud_media_label(i)
	local m = icloud_media_raw()[tonumber(i) or 1] or {}
	return (m.label and m.label ~= "") and m.label or "N/A"
end

function conky_icloud_media_gb(i)
	local m = icloud_media_raw()[tonumber(i) or 1] or {}
	return string.format("%.2f GB", tonumber(m.usage_gb) or 0)
end

function conky_icloud_media_mb(i)
	local m = icloud_media_raw()[tonumber(i) or 1] or {}
	return string.format("%.1f MB", tonumber(m.usage_mb) or 0)
end

function conky_icloud_media_size(i)
	local m = icloud_media_raw()[tonumber(i) or 1] or {}
	local b = tonumber(m.usage_bytes) or 0
	if b >= 1073741824 then
		return string.format("%.2f GB", b / 1073741824)
	elseif b >= 1048576 then
		return string.format("%.1f MB", b / 1048576)
	elseif b >= 1024 then
		return string.format("%.1f KB", b / 1024)
	end
	return tostring(math.floor(b)) .. " B"
end

function conky_icloud_media_perc(i)
	local m = icloud_media_raw()[tonumber(i) or 1] or {}
	return clamp_perc(m.usage_perc)
end

function conky_icloud_media_color(i)
	local m = icloud_media_raw()[tonumber(i) or 1] or {}
	return (m.color and m.color ~= "") and m.color or "#888888"
end

------------------------------------------------------------
-- 3. Find My Devices & Battery
------------------------------------------------------------

function conky_icloud_device_count()
	return #icloud_devices_raw()
end

function conky_icloud_device_name(i)
	local d = icloud_dev(i)
	return (d.name and d.name ~= "") and d.name or "N/A"
end

function conky_icloud_device_model(i)
	local d = icloud_dev(i)
	return (d.model and d.model ~= "") and d.model or "N/A"
end

function conky_icloud_device_class(i)
	local d = icloud_dev(i)
	return (d.device_class and d.device_class ~= "") and d.device_class or "N/A"
end

function conky_icloud_device_battery(i)
	local d = icloud_dev(i)
	return clamp_perc(d.battery)
end

function conky_icloud_device_battery_status(i)
	local d = icloud_dev(i)
	return (d.battery_status and d.battery_status ~= "") and d.battery_status or "Unknown"
end

------------------------------------------------------------
-- 4. Find My GPS Coordinates, Street Address & Mini-Map
------------------------------------------------------------

local function dev_loc(i)
	local loc = icloud_dev(i).location
	return type(loc) == "table" and loc or {}
end

local function dev_addr(i)
	local addr = icloud_dev(i).address
	return type(addr) == "table" and addr or {}
end

function icloud_has_location(i)
	local loc = dev_loc(i)
	return tonumber(loc.lat) ~= nil and tonumber(loc.lon) ~= nil
end

function conky_icloud_has_location(i)
	return icloud_has_location(i) and 1 or 0
end

function conky_icloud_loc_lat(i)
	return tonumber(dev_loc(i).lat) or 0
end

function conky_icloud_loc_lon(i)
	return tonumber(dev_loc(i).lon) or 0
end

function conky_icloud_loc_accuracy(i)
	local a = tonumber(dev_loc(i).accuracy) or 0
	return string.format("%.0f m", a)
end

function conky_icloud_loc_type(i)
	local t = dev_loc(i).position_type
	return (t and t ~= "") and t or "N/A"
end

function conky_icloud_loc_updated(i)
	local t = dev_loc(i).updated_time
	return (t and t ~= "") and t or "N/A"
end

function conky_icloud_loc_updated_full(i)
	local t = dev_loc(i).updated_full
	return (t and t ~= "") and t or "N/A"
end

function conky_icloud_loc_country(i)
	local c = dev_addr(i).country
	return (c and c ~= "") and c or "N/A"
end

function conky_icloud_loc_country_code(i)
	local c = dev_addr(i).country_code
	return (c and c ~= "") and c or ""
end

function conky_icloud_loc_postcode(i)
	local p = dev_addr(i).postcode
	return (p and p ~= "") and p or ""
end

function conky_icloud_loc_city(i)
	local c = dev_addr(i).city
	return (c and c ~= "") and c or "N/A"
end

function conky_icloud_loc_district(i)
	local d = dev_addr(i).district
	return (d and d ~= "") and d or ""
end

function conky_icloud_loc_street(i)
	local s = dev_addr(i).street
	return (s and s ~= "") and s or "N/A"
end

function conky_icloud_loc_house_number(i)
	local h = dev_addr(i).house_number
	return (h and h ~= "") and h or ""
end

function conky_icloud_loc_street_full(i)
	local sf = dev_addr(i).street_full
	return (sf and sf ~= "") and sf or "N/A"
end

function conky_icloud_loc_short(i)
	local sh = dev_addr(i).short
	return (sh and sh ~= "") and sh or "N/A"
end

function conky_icloud_loc_display(i)
	local dn = dev_addr(i).display_name
	return (dn and dn ~= "") and dn or "N/A"
end

function conky_icloud_map_path()
	return icloud_map_file()
end

------------------------------------------------------------
-- 5. iCloud Calendar & Reminders
------------------------------------------------------------

function conky_icloud_calendar_count()
	return #icloud_cal_raw()
end

function conky_icloud_calendar_title(i)
	local e = icloud_cal_raw()[tonumber(i) or 1] or {}
	return (e.title and e.title ~= "") and e.title or "N/A"
end

function conky_icloud_calendar_start(i)
	local e = icloud_cal_raw()[tonumber(i) or 1] or {}
	return e.start or ""
end

function conky_icloud_calendar_end(i)
	local e = icloud_cal_raw()[tonumber(i) or 1] or {}
	return e["end"] or ""
end

function conky_icloud_calendar_location(i)
	local e = icloud_cal_raw()[tonumber(i) or 1] or {}
	return (e.location and e.location ~= "") and e.location or ""
end

function conky_icloud_reminders_count()
	return #icloud_rem_raw()
end

function conky_icloud_reminder_title(i)
	local r = icloud_rem_raw()[tonumber(i) or 1] or {}
	return (r.title and r.title ~= "") and r.title or "N/A"
end

function conky_icloud_reminder_list(i)
	local r = icloud_rem_raw()[tonumber(i) or 1] or {}
	return (r.list and r.list ~= "") and r.list or ""
end

function conky_icloud_reminder_due(i)
	local r = icloud_rem_raw()[tonumber(i) or 1] or {}
	return r.due or ""
end
