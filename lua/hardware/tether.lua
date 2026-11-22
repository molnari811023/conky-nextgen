--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[=[
lua/hardware/tether.lua — Wireless Tether daemon (`tetherd`), Bluetooth (Classic/BLE/AVRCP) and Apple Continuity (ANCS/MAP/PBAP/HFP/AirPods) telemetry via pure-Lua UNIX domain socket (`socket.unix`).
]=]
--{{{
-- ## Tether Daemon & Continuity Module
--
-- Communicates directly with the local `tetherd` UNIX domain socket
-- (`/run/user/<uid>/tether/tetherd.sock`) using `socket.unix` and `dkjson`
-- with zero external process spawning (`< 0.5 ms` latency), plus `/sys/class/input`
-- Bluetooth AVRCP detection.
--
-- **Capabilities:**
-- - Daemon & Wireless Connection state (`Wi-Fi`, `BT Classic`, `BLE`, `Clipboard Sync`)
-- - Continuity Notifications (`ANCS` list, count, app, title, body)
-- - SMS / iMessage Threads (`MAP` list, count, unread count, sender, preview, timestamp)
-- - Cellular & Calls (`HFP` operator, signal bars `0..5`, roaming, active calls, call history, missed calls)
-- - Contacts (`PBAP` synced count & lookup)
-- - AirPods (`AAP` left, right, case battery `%` clamped `0..100`)
--}}}

local tether_cache = {}

local unix_socket
if package.searchpath and package.searchpath("socket.unix", package.cpath) then
	unix_socket = require("socket.unix")
end

local function cached_tether(key, ok_ttl, retry_ttl, fn)
	local now = os.time()
	local e = tether_cache[key]
	if e and now < e.expires then
		return e.value
	end
	local val, ok = fn()
	local ttl = ok and ok_ttl or (retry_ttl or 3)
	tether_cache[key] = {
		expires = now + ttl,
		value = val,
	}
	return val
end

local function get_tether_sock_path()
	if not lfs then
		return nil
	end
	local runtime = os.getenv("XDG_RUNTIME_DIR")
	if runtime and runtime ~= "" then
		local p = runtime .. "/tether/tetherd.sock"
		if lfs.attributes(p, "mode") == "socket" then
			return p
		end
	end
	local uid = lfs.attributes("/proc/self", "uid")
	if uid then
		local p = "/run/user/" .. tostring(uid) .. "/tether/tetherd.sock"
		if lfs.attributes(p, "mode") == "socket" then
			return p
		end
	end
	return nil
end

local function query_tether_json(cmd)
	local sock_path = get_tether_sock_path()
	if not sock_path or not unix_socket or not json then
		return nil, false
	end
	local s = unix_socket()
	if not s then
		return nil, false
	end
	s:settimeout(1)
	local ok = s:connect(sock_path)
	if not ok then
		s:close()
		return nil, false
	end
	local sent = s:send('{"command":"' .. cmd .. '"}\n')
	if not sent then
		s:close()
		return nil, false
	end
	local line = s:receive("*l")
	s:close()
	if not line or line == "" then
		return nil, false
	end
	local data = json.decode(line)
	if type(data) ~= "table" then
		return nil, false
	end
	return data, true
end

local function get_tether_config()
	return cached("tether_bt_cfg", 60, function()
		local home = os.getenv("HOME") or ""
		if home == "" or not json then
			return {}
		end
		local bt_raw = read_file(home .. "/.config/tether/bluetooth.json")
		local bt_cfg = (bt_raw and bt_raw ~= "") and json.decode(bt_raw) or {}
		return type(bt_cfg) == "table" and bt_cfg or {}
	end)
end

local function get_tether_snapshot()
	return cached_tether("tether_snapshot", 5, 3, function()
		local d, ok = query_tether_json("state_snapshot")
		return d or {}, ok
	end)
end

local function get_tether_bt_conn()
	return cached_tether("tether_bt_conn", 5, 3, function()
		local d, ok = query_tether_json("bt_connection")
		return d or {}, ok
	end)
end

local function get_tether_airpods()
	return cached_tether("tether_airpods", 10, 5, function()
		local d, ok = query_tether_json("bt_airpods")
		return d or {}, ok
	end)
end

local function get_tether_notifications()
	return cached_tether("tether_notifications", 5, 5, function()
		local d, ok = query_tether_json("bt_list_notifications")
		return (d and type(d.notifications) == "table") and d.notifications or {}, ok
	end)
end

local function get_tether_threads()
	return cached_tether("tether_threads", 10, 5, function()
		local d, ok = query_tether_json("bt_list_threads")
		return (d and type(d.threads) == "table") and d.threads or {}, ok
	end)
end

local function get_tether_calls()
	return cached_tether("tether_calls", 3, 3, function()
		local d, ok = query_tether_json("bt_list_calls")
		return (d and type(d.calls) == "table") and d.calls or {}, ok
	end)
end

local function get_tether_call_history()
	return cached_tether("tether_call_history", 30, 10, function()
		local d, ok = query_tether_json("bt_list_call_history")
		return (d and type(d.calls) == "table") and d.calls or {}, ok
	end)
end

local function get_tether_contacts()
	return cached_tether("tether_contacts", 60, 15, function()
		local d, ok = query_tether_json("bt_list_contacts")
		return (d and type(d.contacts) == "table") and d.contacts or {}, ok
	end)
end

local function get_bt_iphone_input()
	return cached("iphone_bt_input", 5, function()
		if not lfs or lfs.attributes("/sys/class/input", "mode") ~= "directory" then
			return nil
		end
		for entry in lfs.dir("/sys/class/input") do
			if entry:match("^input%d+$") then
				local base = "/sys/class/input/" .. entry .. "/"
				local bustype = read_file(base .. "id/bustype")
				local vendor = read_file(base .. "id/vendor")
				if bustype == "0005" and vendor and vendor:lower() == "004c" then
					local raw_name = read_file(base .. "name") or "iPhone"
					local clean_name = raw_name:gsub("%s*%(AVRCP%)%s*$", "")
					return {
						name = (clean_name ~= "" and clean_name or "iPhone"),
						raw_name = raw_name,
						phys = read_file(base .. "phys") or "",
						version = read_file(base .. "id/version") or "",
					}
				end
			end
		end
		return nil
	end)
end

------------------------------------------------------------
-- 1. Daemon, Bluetooth & Wi-Fi Connection State
------------------------------------------------------------

function tether_running()
	return get_tether_sock_path() ~= nil
end
iphone_tether_running = tether_running

function conky_tether_running()
	return tether_running() and 1 or 0
end
conky_iphone_tether_running = conky_tether_running

function tether_bt_connected()
	if get_bt_iphone_input() ~= nil then
		return true
	end
	local btc = get_tether_bt_conn()
	return btc.classic_connected == true or btc.le_connected == true
end
iphone_bt_connected = tether_bt_connected

function conky_tether_bt_connected()
	return tether_bt_connected() and 1 or 0
end
conky_iphone_bt_connected = conky_tether_bt_connected

function conky_tether_bt_name()
	local bt = get_bt_iphone_input()
	if bt and bt.name ~= "" then
		return bt.name
	end
	local snap = get_tether_snapshot()
	if type(snap.paired_devices) == "table" and snap.paired_devices[1] and snap.paired_devices[1].device_name then
		return snap.paired_devices[1].device_name
	end
	return ""
end
conky_iphone_bt_name = conky_tether_bt_name

function conky_tether_bt_mac()
	local btc = get_tether_bt_conn()
	if type(btc.calls) == "table" and btc.calls.address and btc.calls.address ~= "" then
		return btc.calls.address:upper()
	end
	local tcfg = get_tether_config()
	if tcfg.device_address and tcfg.device_address ~= "" then
		return tcfg.device_address:upper()
	end
	return "N/A"
end

function conky_tether_battery_perc()
	local btc = get_tether_bt_conn()
	if tonumber(btc.battery) and tonumber(btc.battery) > 0 then
		return math.min(100, math.max(0, math.floor(tonumber(btc.battery) + 0.5)))
	end
	if type(btc.calls) == "table" and tonumber(btc.calls.battery) and tonumber(btc.calls.battery) > 0 then
		return math.min(100, math.max(0, math.floor(tonumber(btc.calls.battery) + 0.5)))
	end
	return 0
end

function tether_wifi_connected()
	local snap = get_tether_snapshot()
	return type(snap.connected_clients) == "table" and #snap.connected_clients > 0
end
iphone_wifi_connected = tether_wifi_connected

function conky_tether_wifi_connected()
	return tether_wifi_connected() and 1 or 0
end
conky_iphone_wifi_connected = conky_tether_wifi_connected

function tether_le_connected()
	return get_tether_bt_conn().le_connected == true
end
iphone_le_connected = tether_le_connected

function conky_tether_le_connected()
	return tether_le_connected() and 1 or 0
end
conky_iphone_le_connected = conky_tether_le_connected

function iphone_any_connected(i)
	local usb_ok = iphone_usb_connected and iphone_usb_connected(i) or false
	return usb_ok or tether_bt_connected() or tether_wifi_connected()
end

function conky_iphone_any_connected(i)
	return iphone_any_connected(i) and 1 or 0
end

function conky_iphone_conn_type(i)
	local parts = {}
	if iphone_usb_connected and iphone_usb_connected(i) then
		parts[#parts + 1] = "USB"
	end
	if tether_wifi_connected() then
		parts[#parts + 1] = "Wi-Fi"
	end
	if tether_bt_connected() then
		parts[#parts + 1] = "BT"
	end
	if #parts == 0 then
		return "N/A"
	end
	return table.concat(parts, " + ")
end
conky_tether_conn_type = conky_iphone_conn_type

function conky_tether_wifi_ip()
	local snap = get_tether_snapshot()
	if type(snap.connected_clients) == "table" and snap.connected_clients[1] then
		local c = snap.connected_clients[1]
		return c.ip or c.address or c.host or "N/A"
	end
	return "N/A"
end
conky_iphone_wifi_ip = conky_tether_wifi_ip

function tether_clipboard_sync()
	return get_tether_snapshot().clipboard_available == true
end
iphone_clipboard_sync = tether_clipboard_sync

function conky_tether_clipboard_sync()
	return tether_clipboard_sync() and 1 or 0
end
conky_iphone_clipboard_sync = conky_tether_clipboard_sync

function tether_ancs_active()
	return get_tether_bt_conn().ancs_ready == true
end
iphone_ancs_active = tether_ancs_active

function conky_tether_ancs_active()
	return tether_ancs_active() and 1 or 0
end
conky_iphone_ancs_active = conky_tether_ancs_active

function tether_map_active()
	return get_tether_bt_conn().map_open == true
end
iphone_map_active = tether_map_active

function conky_tether_map_active()
	return tether_map_active() and 1 or 0
end
conky_iphone_map_active = conky_tether_map_active

function tether_pbap_active()
	return get_tether_bt_conn().pbap_open == true
end
iphone_pbap_active = tether_pbap_active

function conky_tether_pbap_active()
	return tether_pbap_active() and 1 or 0
end
conky_iphone_pbap_active = conky_tether_pbap_active

------------------------------------------------------------
-- 2. Continuity Notifications (ANCS)
------------------------------------------------------------

function conky_tether_notifications_list()
	return get_tether_notifications()
end
conky_iphone_notifications_list = conky_tether_notifications_list

function conky_tether_notifications_count()
	return #get_tether_notifications()
end
conky_iphone_notifications_count = conky_tether_notifications_count

function conky_tether_last_notif_app(idx)
	local n = get_tether_notifications()[tonumber(idx) or 1]
	return (n and n.app and n.app ~= "") and n.app or ""
end
conky_iphone_last_notif_app = conky_tether_last_notif_app

function conky_tether_last_notif_title(idx)
	local n = get_tether_notifications()[tonumber(idx) or 1]
	return (n and n.title and n.title ~= "") and n.title or ""
end
conky_iphone_last_notif_title = conky_tether_last_notif_title

function conky_tether_last_notif_body(idx)
	local n = get_tether_notifications()[tonumber(idx) or 1]
	return (n and n.body and n.body ~= "") and n.body or ""
end
conky_iphone_last_notif_body = conky_tether_last_notif_body

------------------------------------------------------------
-- 3. Messages (MAP / SMS / iMessage)
------------------------------------------------------------

function conky_tether_threads_list()
	return get_tether_threads()
end
conky_iphone_threads_list = conky_tether_threads_list

function conky_tether_threads_count()
	return #get_tether_threads()
end
conky_iphone_threads_count = conky_tether_threads_count

function conky_tether_unread_messages()
	local total = 0
	for _, th in ipairs(get_tether_threads()) do
		total = total + (tonumber(th.unread) or 0)
	end
	return total
end
conky_iphone_unread_messages = conky_tether_unread_messages

function conky_tether_msg_sender(idx)
	local th = get_tether_threads()[tonumber(idx) or 1]
	if not th then
		return ""
	end
	return (th.name and th.name ~= "") and th.name or (th.address or "")
end
conky_iphone_msg_sender = conky_tether_msg_sender

function conky_tether_msg_preview(idx)
	local th = get_tether_threads()[tonumber(idx) or 1]
	if not th or not th.preview then
		return ""
	end
	return (th.preview:gsub("[\r\n]+", " "))
end
conky_iphone_msg_preview = conky_tether_msg_preview

function conky_tether_msg_time(idx)
	local th = get_tether_threads()[tonumber(idx) or 1]
	local ts = th and tonumber(th.timestamp)
	if not ts or ts <= 0 then
		return ""
	end
	return os.date("%Y-%m-%d %H:%M", ts)
end
conky_iphone_msg_time = conky_tether_msg_time

function conky_tether_msg_unread(idx)
	local th = get_tether_threads()[tonumber(idx) or 1]
	return th and (tonumber(th.unread) or 0) or 0
end
conky_iphone_msg_unread = conky_tether_msg_unread

------------------------------------------------------------
-- 4. Cellular & Calls (HFP & Call History)
------------------------------------------------------------

function conky_tether_operator()
	local btc = get_tether_bt_conn()
	if type(btc.calls) == "table" and btc.calls.operator and btc.calls.operator ~= "" then
		return btc.calls.operator
	end
	return "N/A"
end
conky_iphone_operator = conky_tether_operator

function conky_tether_signal_bars()
	local btc = get_tether_bt_conn()
	if type(btc.calls) == "table" and tonumber(btc.calls.signal) then
		return math.min(5, math.max(0, math.floor(tonumber(btc.calls.signal) + 0.5)))
	end
	return 0
end
conky_iphone_signal_bars = conky_tether_signal_bars

function tether_is_roaming()
	local btc = get_tether_bt_conn()
	return type(btc.calls) == "table" and btc.calls.roaming == true
end
iphone_is_roaming = tether_is_roaming

function conky_tether_is_roaming()
	return tether_is_roaming() and 1 or 0
end
conky_iphone_is_roaming = conky_tether_is_roaming

function conky_tether_active_calls()
	local list = get_tether_calls()
	if #list > 0 then
		return #list
	end
	local btc = get_tether_bt_conn()
	if type(btc.calls) == "table" and tonumber(btc.calls.calls) then
		return tonumber(btc.calls.calls) or 0
	end
	return 0
end
conky_iphone_active_calls = conky_tether_active_calls

function conky_tether_call_state()
	local list = get_tether_calls()
	if list[1] and list[1].state and list[1].state ~= "" then
		return list[1].state
	end
	local btc = get_tether_bt_conn()
	if type(btc.calls) == "table" and btc.calls.state and btc.calls.state ~= "" then
		return btc.calls.state
	end
	return ""
end
conky_iphone_call_state = conky_tether_call_state

function conky_tether_call_history_count()
	return #get_tether_call_history()
end
conky_iphone_call_history_count = conky_tether_call_history_count

function conky_tether_missed_calls_count()
	local count = 0
	for _, c in ipairs(get_tether_call_history()) do
		if c.type == "missed" then
			count = count + 1
		end
	end
	return count
end
conky_iphone_missed_calls_count = conky_tether_missed_calls_count

function conky_tether_last_call_name(idx)
	local c = get_tether_call_history()[tonumber(idx) or 1]
	if not c then
		return ""
	end
	return (c.name and c.name ~= "") and c.name or (c.number or "")
end
conky_iphone_last_call_name = conky_tether_last_call_name

function conky_tether_last_call_type(idx)
	local c = get_tether_call_history()[tonumber(idx) or 1]
	return (c and c.type) or ""
end
conky_iphone_last_call_type = conky_tether_last_call_type

function conky_tether_last_call_time(idx)
	local c = get_tether_call_history()[tonumber(idx) or 1]
	local ts = c and tonumber(c.timestamp)
	if not ts or ts <= 0 then
		return ""
	end
	return os.date("%Y-%m-%d %H:%M", ts)
end
conky_iphone_last_call_time = conky_tether_last_call_time

------------------------------------------------------------
-- 5. Contacts (PBAP) & AirPods (AAP)
------------------------------------------------------------

function conky_tether_contacts_count()
	return #get_tether_contacts()
end
conky_iphone_contacts_count = conky_tether_contacts_count

function conky_tether_contact_name(idx)
	local c = get_tether_contacts()[tonumber(idx) or 1]
	return (c and c.name and c.name ~= "") and c.name or ""
end

function conky_tether_contact_phone(idx)
	local c = get_tether_contacts()[tonumber(idx) or 1]
	if not c then
		return ""
	end
	if type(c.phones) == "table" and c.phones[1] then
		return tostring(c.phones[1])
	end
	return c.phone or c.number or ""
end

function tether_airpods_connected()
	local ap = get_tether_airpods()
	return ap.status ~= nil and ap.status ~= "idle" and ap.status ~= ""
end
iphone_airpods_connected = tether_airpods_connected

function conky_tether_airpods_connected()
	return tether_airpods_connected() and 1 or 0
end
conky_iphone_airpods_connected = conky_tether_airpods_connected

function conky_tether_airpods_name()
	local ap = get_tether_airpods()
	return (ap.name and ap.name ~= "") and ap.name or "N/A"
end
conky_iphone_airpods_name = conky_tether_airpods_name

function conky_tether_airpods_left()
	local v = tonumber(get_tether_airpods().left)
	if not v or v < 0 then
		return 0
	end
	return math.min(100, math.max(0, math.floor(v + 0.5)))
end
conky_iphone_airpods_left = conky_tether_airpods_left

function conky_tether_airpods_right()
	local v = tonumber(get_tether_airpods().right)
	if not v or v < 0 then
		return 0
	end
	return math.min(100, math.max(0, math.floor(v + 0.5)))
end
conky_iphone_airpods_right = conky_tether_airpods_right

function conky_tether_airpods_case()
	local v = tonumber(get_tether_airpods().case)
	if not v or v < 0 then
		return 0
	end
	return math.min(100, math.max(0, math.floor(v + 0.5)))
end
conky_iphone_airpods_case = conky_tether_airpods_case
