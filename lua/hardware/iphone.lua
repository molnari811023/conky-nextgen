--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[=[
lua/hardware/iphone.lua — Wired USB / sysfs / MFi / libimobiledevice / GVFS / iFuse diagnostics for Apple iPhone devices.
]=]
--{{{
-- ## iPhone Hardware Module (USB / Sysfs / MFi / libimobiledevice / GVFS / iFuse)
--
-- Combines zero-overhead Lua filesystem reads (`/sys/bus/usb/devices/`,
-- `/sys/class/power_supply/`, `/sys/class/net/`, `/proc/mounts`,
-- `/run/user/<uid>/gvfs/`, `/var/lib/lockdown/`, `/var/lib/upower/`) with
-- adaptive `cached_iphone()` queries to `ideviceinfo`, `idevicediagnostics`,
-- and `ideviceinstaller` when an iPhone is connected via USB, plus automatic
-- JSON persistence (`tmp/iphone_<udid>.json`) for offline inspection.
--
-- Wireless `tetherd` / Bluetooth / Wi-Fi / Continuity telemetry lives in
-- `lua/hardware/tether.lua`; cloud iCloud API / Find My map telemetry lives in
-- `lua/icloud/core.lua` and `lua/icloud/data.lua`.
--}}}

local IPHONE_MODELS = {
	["iPhone8,1"] = "iPhone 6s",
	["iPhone8,2"] = "iPhone 6s Plus",
	["iPhone8,4"] = "iPhone SE (1st gen)",
	["iPhone9,1"] = "iPhone 7",
	["iPhone9,2"] = "iPhone 7 Plus",
	["iPhone9,3"] = "iPhone 7",
	["iPhone9,4"] = "iPhone 7 Plus",
	["iPhone10,1"] = "iPhone 8",
	["iPhone10,2"] = "iPhone 8 Plus",
	["iPhone10,3"] = "iPhone X",
	["iPhone10,4"] = "iPhone 8",
	["iPhone10,5"] = "iPhone 8 Plus",
	["iPhone10,6"] = "iPhone X",
	["iPhone11,2"] = "iPhone XS",
	["iPhone11,4"] = "iPhone XS Max",
	["iPhone11,6"] = "iPhone XS Max",
	["iPhone11,8"] = "iPhone XR",
	["iPhone12,1"] = "iPhone 11",
	["iPhone12,3"] = "iPhone 11 Pro",
	["iPhone12,5"] = "iPhone 11 Pro Max",
	["iPhone12,8"] = "iPhone SE (2nd gen)",
	["iPhone13,1"] = "iPhone 12 mini",
	["iPhone13,2"] = "iPhone 12",
	["iPhone13,3"] = "iPhone 12 Pro",
	["iPhone13,4"] = "iPhone 12 Pro Max",
	["iPhone14,2"] = "iPhone 13 Pro",
	["iPhone14,3"] = "iPhone 13 Pro Max",
	["iPhone14,4"] = "iPhone 13 mini",
	["iPhone14,5"] = "iPhone 13",
	["iPhone14,6"] = "iPhone SE (3rd gen)",
	["iPhone14,7"] = "iPhone 14",
	["iPhone14,8"] = "iPhone 14 Plus",
	["iPhone15,2"] = "iPhone 14 Pro",
	["iPhone15,3"] = "iPhone 14 Pro Max",
	["iPhone15,4"] = "iPhone 15",
	["iPhone15,5"] = "iPhone 15 Plus",
	["iPhone16,1"] = "iPhone 15 Pro",
	["iPhone16,2"] = "iPhone 15 Pro Max",
	["iPhone17,1"] = "iPhone 16 Pro",
	["iPhone17,2"] = "iPhone 16 Pro Max",
	["iPhone17,3"] = "iPhone 16",
	["iPhone17,4"] = "iPhone 16 Plus",
	["iPhone17,5"] = "iPhone 16e",
	["iPhone18,1"] = "iPhone 17 Pro",
	["iPhone18,2"] = "iPhone 17 Pro Max",
	["iPhone18,3"] = "iPhone 17",
	["iPhone18,4"] = "iPhone 17 Air",
}

local iphone_cache = {}

local function cached_iphone(key, ok_ttl, retry_ttl, fn)
	local now = os.time()
	local e = iphone_cache[key]
	if e and now < e.expires then
		return e.value
	end
	local val, ok = fn()
	local ttl = ok and ok_ttl or (retry_ttl or 5)
	iphone_cache[key] = {
		expires = now + ttl,
		value = val,
	}
	return val
end

local function run_idevice_cmd(cmd)
	if not lfs or lfs.attributes("/var/run/usbmuxd", "mode") == nil then
		return ""
	end
	local f = io.popen("timeout 3 " .. cmd .. " 2>/dev/null")
	if not f then
		return ""
	end
	local out = f:read("*a") or ""
	f:close()
	return out
end

local function serial_to_udid(serial)
	if not serial or serial == "" then
		return ""
	end
	local p1, p2 = serial:match("^(%x%x%x%x%x%x%x%x)(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)$")
	if p1 and p2 then
		return p1 .. "-" .. p2
	end
	return serial
end

local function split_bytes(b)
	local n = tonumber(b) or 0
	if n >= 1073741824 then
		return math.floor((n / 1073741824) * 100 + 0.5) / 100, "GiB"
	elseif n >= 1048576 then
		return math.floor((n / 1048576) * 10 + 0.5) / 10, "MiB"
	elseif n >= 1024 then
		return math.floor((n / 1024) * 10 + 0.5) / 10, "KiB"
	end
	return math.floor(n), "B"
end

local function to_gb_num(b)
	local n = tonumber(b) or 0
	if n <= 0 then
		return 0
	end
	return math.floor((n / 100000000) + 0.5) / 10
end

local function tr(key)
	if conky_get_tr then
		return conky_get_tr(key)
	end
	return key
end

------------------------------------------------------------
-- 1. USB Discovery & Connection State (Pure LFS, 2s cache)
------------------------------------------------------------

function conky_iphone_list()
	return cached("iphone_usb_list", 2, function()
		local list = {}
		if not lfs or lfs.attributes("/sys/bus/usb/devices", "mode") ~= "directory" then
			return list
		end
		for entry in lfs.dir("/sys/bus/usb/devices") do
			if entry ~= "." and entry ~= ".." and not entry:find(":") and not entry:match("^usb%d+$") then
				local base = "/sys/bus/usb/devices/" .. entry .. "/"
				local vendor = read_file(base .. "idVendor")
				if vendor == "05ac" then
					local product = read_file(base .. "product")
					local pid = read_file(base .. "idProduct")
					if (product and product:find("iPhone")) or (pid and pid:match("^12[9a]%x$")) then
						local serial = read_file(base .. "serial") or ""
						local busnum = read_num(base .. "busnum") or 0
						local devnum = read_num(base .. "devnum") or 0
						list[#list + 1] = {
							port = entry,
							usb_path = base,
							serial = serial,
							udid = serial_to_udid(serial),
							pid = pid or "",
							busnum = busnum,
							devnum = devnum,
						}
					end
				end
			end
		end
		table.sort(list, function(a, b)
			return a.port < b.port
		end)
		return list
	end)
end

local function get_dev(i)
	local idx = tonumber(i) or 1
	return conky_iphone_list()[idx]
end

function conky_iphone_count()
	return #conky_iphone_list()
end

function get_iphone_usb_path(i)
	local dev = get_dev(i)
	return dev and dev.usb_path or nil
end

function conky_iphone_port(i)
	local dev = get_dev(i)
	return dev and dev.port or ""
end

function conky_iphone_serial_raw(i)
	local dev = get_dev(i)
	return dev and dev.serial or ""
end

function conky_iphone_udid(i)
	local dev = get_dev(i)
	if dev and dev.udid ~= "" then
		return dev.udid
	end
	if lfs and lfs.attributes("/var/lib/lockdown", "mode") == "directory" then
		local plist_udids = {}
		for entry in lfs.dir("/var/lib/lockdown") do
			local u = entry:match("^([%x%-]+)%.plist$")
			if u and u ~= "SystemConfiguration" then
				plist_udids[#plist_udids + 1] = u
			end
		end
		table.sort(plist_udids)
		local idx = tonumber(i) or 1
		if plist_udids[idx] then
			return plist_udids[idx]
		end
	end
	return ""
end

function iphone_is_connected(i)
	return get_dev(i) ~= nil
end

function conky_iphone_is_connected(i)
	return iphone_is_connected(i) and 1 or 0
end

function iphone_usb_connected(i)
	return get_dev(i) ~= nil
end

function conky_iphone_usb_connected(i)
	return iphone_usb_connected(i) and 1 or 0
end

------------------------------------------------------------
-- 2. Lockdown & UPower Persistence Fallbacks (Pure LFS)
------------------------------------------------------------

local function get_lockdown_plist_data(udid)
	if not udid or udid == "" then
		return {}
	end
	return cached("iphone_lockdown_" .. udid, 300, function()
		local info = {}
		local path = "/var/lib/lockdown/" .. udid .. ".plist"
		local content = read_file(path)
		if content and content ~= "" then
			info.paired = true
			info.wifi_mac = content:match("<key>WiFiMACAddress</key>%s*<string>([^<]+)</string>")
			info.host_id = content:match("<key>HostID</key>%s*<string>([^<]+)</string>")
			info.system_buid = content:match("<key>SystemBUID</key>%s*<string>([^<]+)</string>")
		end
		if lfs and lfs.attributes("/var/lib/upower", "mode") == "directory" then
			for entry in lfs.dir("/var/lib/upower") do
				local name_part = entry:match("^history%-charge%-(.+)%-" .. udid:gsub("%-", "%%-") .. "%.dat$")
				if name_part then
					info.upower_name = name_part:gsub("_", " ")
					info.upower_usb_file = "/var/lib/upower/" .. entry
				end
			end
			if info.upower_name then
				local prefix = "history-charge-" .. info.upower_name:gsub(" ", "_") .. "-"
				for entry in lfs.dir("/var/lib/upower") do
					if starts_with(entry, prefix) then
						local mac = entry:match("([%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x]:[%x][%x])%.dat$")
						if mac then
							info.bt_mac = mac:upper()
							info.upower_bt_file = "/var/lib/upower/" .. entry
						end
					end
				end
			end
		end
		return info
	end)
end

local function read_upower_last_charge(filepath)
	if not filepath then
		return nil, nil
	end
	local f = io.open(filepath, "r")
	if not f then
		return nil, nil
	end
	local last_line
	for line in f:lines() do
		if line ~= "" then
			last_line = line
		end
	end
	f:close()
	if not last_line then
		return nil, nil
	end
	local _, pct, state = last_line:match("^(%d+)%s+(%d+%.?%d*)%s+(%S+)")
	return tonumber(pct), state
end

function iphone_is_paired(i)
	local udid = conky_iphone_udid(i)
	if udid == "" then
		return false
	end
	return get_lockdown_plist_data(udid).paired == true
end

function conky_iphone_is_paired(i)
	return iphone_is_paired(i) and 1 or 0
end

------------------------------------------------------------
-- 3. Live USB, MFi Fastcharge, USB Tethering (ipheth) & Mounts (GVFS / iFuse)
------------------------------------------------------------

function conky_iphone_usb_speed(i)
	local base = get_iphone_usb_path(i)
	if not base then
		return "N/A"
	end
	local spd = read_file(base .. "speed")
	return (spd and spd ~= "") and (spd .. " Mbps") or "N/A"
end

function conky_iphone_usb_version(i)
	local base = get_iphone_usb_path(i)
	if not base then
		return "N/A"
	end
	local ver = read_file(base .. "version")
	return (ver and ver ~= "") and ver:gsub("^%s+", "") or "N/A"
end

function conky_iphone_usb_max_power(i)
	local base = get_iphone_usb_path(i)
	if not base then
		return "N/A"
	end
	local pwr = read_file(base .. "bMaxPower")
	return (pwr and pwr ~= "") and pwr or "N/A"
end

function conky_iphone_usb_power_status(i)
	local base = get_iphone_usb_path(i)
	if not base then
		return "N/A"
	end
	local st = read_file(base .. "power/runtime_status")
	return (st and st ~= "") and st or "N/A"
end

function conky_iphone_connected_time(i)
	local base = get_iphone_usb_path(i)
	if not base then
		return "00" .. tr("minute_short")
	end
	local ms = read_num(base .. "power/connected_duration")
	if not ms or ms <= 0 then
		return "00" .. tr("minute_short")
	end
	local sec = math.floor(ms / 1000)
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then
		return string.format("%02d%s %02d%s %02d%s", h, tr("hour_short"), m, tr("minute_short"), s, tr("second_short"))
	end
	return string.format("%02d%s %02d%s", m, tr("minute_short"), s, tr("second_short"))
end

function conky_iphone_charge_type(i)
	local dev = get_dev(i)
	if not dev then
		return "N/A"
	end
	local psy_dir = dev.usb_path .. "power_supply"
	if lfs and lfs.attributes(psy_dir, "mode") == "directory" then
		for entry in lfs.dir(psy_dir) do
			if entry ~= "." and entry ~= ".." then
				local ct = read_file(psy_dir .. "/" .. entry .. "/charge_type")
				if ct and ct ~= "" then
					return ct
				end
			end
		end
	end
	if dev.busnum > 0 and dev.devnum > 0 then
		local p1 = string.format("/sys/class/power_supply/apple_mfi_fastcharge_%d-%d/charge_type", dev.busnum, dev.devnum)
		local ct1 = read_file(p1)
		if ct1 and ct1 ~= "" then
			return ct1
		end
	end
	local path = "/sys/class/power_supply/apple_mfi_fastcharge_" .. dev.port .. "/charge_type"
	local ct = read_file(path)
	if ct and ct ~= "" then
		return ct
	end
	return "N/A"
end

function iphone_is_fastcharging(i)
	return conky_iphone_charge_type(i) == "Fast"
end

function conky_iphone_is_fastcharging(i)
	return iphone_is_fastcharging(i) and 1 or 0
end

function conky_iphone_tether_iface(i)
	local dev = get_dev(i)
	if not dev then
		return ""
	end
	return cached("iphone_tether_iface_" .. dev.port, 5, function()
		if not lfs or lfs.attributes("/sys/class/net", "mode") ~= "directory" then
			return ""
		end
		local pattern = "/" .. dev.port:gsub("%-", "%%-"):gsub("%.", "%%.") .. "/"
		for iface in lfs.dir("/sys/class/net") do
			if iface ~= "." and iface ~= ".." and iface ~= "lo" then
				local target = lfs.symlinkattributes("/sys/class/net/" .. iface, "target")
				if target and target:find(pattern) then
					return iface
				end
			end
		end
		return ""
	end)
end

function iphone_tether_active(i)
	local iface = conky_iphone_tether_iface(i)
	if iface == "" then
		return false
	end
	return read_file("/sys/class/net/" .. iface .. "/carrier") == "1"
end

function conky_iphone_tether_active(i)
	return iphone_tether_active(i) and 1 or 0
end

function conky_iphone_tether_state(i)
	local iface = conky_iphone_tether_iface(i)
	if iface == "" then
		return "N/A"
	end
	local st = read_file("/sys/class/net/" .. iface .. "/operstate")
	return (st and st ~= "") and st or "down"
end

function conky_iphone_tether_mac(i)
	local iface = conky_iphone_tether_iface(i)
	if iface == "" then
		return "N/A"
	end
	local mac = read_file("/sys/class/net/" .. iface .. "/address")
	return (mac and mac ~= "") and mac:upper() or "N/A"
end

function conky_iphone_tether_rx_bytes(i)
	local iface = conky_iphone_tether_iface(i)
	if iface == "" then
		return 0
	end
	return read_num("/sys/class/net/" .. iface .. "/statistics/rx_bytes") or 0
end

function conky_iphone_tether_tx_bytes(i)
	local iface = conky_iphone_tether_iface(i)
	if iface == "" then
		return 0
	end
	return read_num("/sys/class/net/" .. iface .. "/statistics/tx_bytes") or 0
end

function conky_iphone_tether_rx(i)
	local val, unit = split_bytes(conky_iphone_tether_rx_bytes(i))
	return tostring(val) .. " " .. unit
end

function conky_iphone_tether_rx_unit(i)
	local _, unit = split_bytes(conky_iphone_tether_rx_bytes(i))
	return unit
end

function conky_iphone_tether_tx(i)
	local val, unit = split_bytes(conky_iphone_tether_tx_bytes(i))
	return tostring(val) .. " " .. unit
end

function conky_iphone_tether_tx_unit(i)
	local _, unit = split_bytes(conky_iphone_tether_tx_bytes(i))
	return unit
end

local function unescape_mount(s)
	return (s:gsub("\\(%d%d%d)", function(oct)
		local n = tonumber(oct, 8)
		return n and string.char(n) or oct
	end))
end

local function get_gvfs_base_dir()
	local uid = lfs and lfs.attributes("/proc/self", "uid")
	if uid then
		local p = "/run/user/" .. tostring(uid) .. "/gvfs"
		if lfs.attributes(p, "mode") == "directory" then
			return p
		end
	end
	if lfs and lfs.attributes("/run/user", "mode") == "directory" then
		for entry in lfs.dir("/run/user") do
			if entry:match("^%d+$") then
				local p = "/run/user/" .. entry .. "/gvfs"
				if lfs.attributes(p, "mode") == "directory" then
					return p
				end
			end
		end
	end
	return nil
end

function conky_iphone_mount_info(i)
	local idx = tonumber(i) or 1
	local dev = get_dev(idx)
	local key = dev and ("iphone_mnt_" .. dev.port) or ("iphone_mnt_idx_" .. idx)
	return cached(key, 3, function()
		local gvfs_base = get_gvfs_base_dir()
		if gvfs_base and lfs then
			local afc_root, afc_app, gphoto_match
			local afc_all = {}
			for entry in lfs.dir(gvfs_base) do
				if entry ~= "." and entry ~= ".." then
					local full = gvfs_base .. "/" .. entry
					if starts_with(entry, "afc:host=") then
						afc_all[#afc_all + 1] = full
						if dev then
							local matches_dev = (dev.udid ~= "" and entry:find(dev.udid, 1, true))
								or (dev.serial ~= "" and entry:find(dev.serial, 1, true))
							if matches_dev then
								if not entry:find(",port=") then
									afc_root = full
								else
									afc_app = afc_app or full
								end
							end
						end
					elseif starts_with(entry, "gphoto2:host=") and dev then
						local usb_tag1 = (dev.busnum > 0 and dev.devnum > 0)
							and string.format("%03d%%2C%03d", dev.busnum, dev.devnum)
							or nil
						local usb_tag2 = (dev.busnum > 0 and dev.devnum > 0)
							and string.format("%03d,%03d", dev.busnum, dev.devnum)
							or nil
						if (dev.serial ~= "" and entry:find(dev.serial, 1, true))
							or (usb_tag1 and entry:find(usb_tag1, 1, true))
							or (usb_tag2 and entry:find(usb_tag2, 1, true))
						then
							gphoto_match = full
						end
					end
				end
			end
			if afc_root then
				return { path = afc_root, type = "gvfs-afc" }
			elseif afc_app then
				return { path = afc_app, type = "gvfs-afc" }
			elseif gphoto_match then
				return { path = gphoto_match, type = "gvfs-gphoto2" }
			elseif not dev and afc_all[idx] then
				table.sort(afc_all)
				return { path = afc_all[idx], type = "gvfs-afc" }
			end
		end

		local f = io.open("/proc/mounts", "r")
		if f then
			local ifuse_mounts = {}
			for line in f:lines() do
				local src, mnt, fstype = line:match("^(%S+)%s+(%S+)%s+(%S+)")
				if src and mnt and (fstype:find("ifuse") or src:find("ifuse") or src:find("afc://")) then
					local clean_mnt = unescape_mount(mnt)
					if dev and dev.udid ~= "" and (src:find(dev.udid, 1, true) or clean_mnt:find(dev.udid, 1, true)) then
						f:close()
						return { path = clean_mnt, type = "ifuse" }
					end
					ifuse_mounts[#ifuse_mounts + 1] = clean_mnt
				end
			end
			f:close()
			if ifuse_mounts[idx] then
				return { path = ifuse_mounts[idx], type = "ifuse" }
			end
		end

		return { path = "", type = "N/A" }
	end)
end

function conky_iphone_mount_path(i)
	return conky_iphone_mount_info(i).path or ""
end

function conky_iphone_mount_type(i)
	return conky_iphone_mount_info(i).type or "N/A"
end

function conky_iphone_gvfs_path(i)
	local info = conky_iphone_mount_info(i)
	if info.type == "gvfs-afc" or info.type == "gvfs-gphoto2" then
		return info.path
	end
	return ""
end

function iphone_is_mounted(i)
	return conky_iphone_mount_path(i) ~= ""
end

function conky_iphone_is_mounted(i)
	return iphone_is_mounted(i) and 1 or 0
end

------------------------------------------------------------
-- 4. Cached libimobiledevice Queries (ideviceinfo / diagnostics)
------------------------------------------------------------

local function get_persisted_path(udid)
	if not udid or udid == "" then
		return nil
	end
	local dir = (JSON_PATH and JSON_PATH ~= "") and JSON_PATH or ((os.getenv("HOME") or "/tmp") .. "/.conky/tmp/")
	return dir .. "iphone_" .. udid .. ".json"
end

local function load_persisted_udid(udid)
	if not udid or udid == "" or not json then
		return {}
	end
	return cached("iphone_persist_" .. udid, 30, function()
		local p = get_persisted_path(udid)
		if not p then
			return {}
		end
		local raw = read_file(p)
		if not raw or raw == "" then
			return {}
		end
		local d = json.decode(raw)
		return type(d) == "table" and d or {}
	end)
end

local function save_persisted_section(udid, section, tbl)
	if not udid or udid == "" or not json or type(tbl) ~= "table" then
		return
	end
	local p = get_persisted_path(udid)
	if not p then
		return
	end
	local data = load_persisted_udid(udid)
	data[section] = tbl
	local encoded = json.encode(data, { indent = true })
	if encoded then
		local f = io.open(p, "w")
		if f then
			f:write(encoded)
			f:close()
		end
	end
	if cache then
		cache["iphone_persist_" .. udid] = { time = os.time(), value = data }
	end
end

local function parse_kv_output(raw)
	local t = {}
	local count = 0
	for line in (raw or ""):gmatch("[^\r\n]+") do
		local k, v = line:match("^%s*([%w_]+)%s*:%s*(.-)%s*$")
		if k and v and k ~= "ERROR" then
			t[k] = v
			count = count + 1
		end
	end
	return t, count > 0
end

local function get_idevice_general(i)
	local dev = get_dev(i)
	local udid = (dev and dev.udid ~= "") and dev.udid or conky_iphone_udid(i)
	if not dev or dev.udid == "" then
		return load_persisted_udid(udid).general or {}
	end
	return cached_iphone("iphone_general_" .. dev.udid, 3600, 5, function()
		local out = run_idevice_cmd("ideviceinfo -u " .. dev.udid)
		local t, ok = parse_kv_output(out)
		if ok then
			save_persisted_section(dev.udid, "general", t)
			return t, true
		end
		return load_persisted_udid(dev.udid).general or {}, false
	end)
end

local function get_idevice_battery(i)
	local dev = get_dev(i)
	local udid = (dev and dev.udid ~= "") and dev.udid or conky_iphone_udid(i)
	if not dev or dev.udid == "" then
		return load_persisted_udid(udid).battery or {}
	end
	return cached_iphone("iphone_battery_" .. dev.udid, 15, 5, function()
		local out = run_idevice_cmd("ideviceinfo -u " .. dev.udid .. " -q com.apple.mobile.battery")
		local t, ok = parse_kv_output(out)
		if ok then
			save_persisted_section(dev.udid, "battery", t)
			return t, true
		end
		return load_persisted_udid(dev.udid).battery or {}, false
	end)
end

local function get_idevice_disk(i)
	local dev = get_dev(i)
	local udid = (dev and dev.udid ~= "") and dev.udid or conky_iphone_udid(i)
	if not dev or dev.udid == "" then
		return load_persisted_udid(udid).disk or {}
	end
	return cached_iphone("iphone_disk_" .. dev.udid, 60, 5, function()
		local out = run_idevice_cmd("ideviceinfo -u " .. dev.udid .. " -q com.apple.disk_usage")
		local t, ok = parse_kv_output(out)
		if ok then
			save_persisted_section(dev.udid, "disk", t)
			return t, true
		end
		return load_persisted_udid(dev.udid).disk or {}, false
	end)
end

local function get_smart_battery(i)
	local dev = get_dev(i)
	local udid = (dev and dev.udid ~= "") and dev.udid or conky_iphone_udid(i)
	if not dev or dev.udid == "" then
		return load_persisted_udid(udid).smart_battery or {}
	end
	return cached_iphone("iphone_smartbatt_" .. dev.udid, 60, 10, function()
		local xml = run_idevice_cmd("idevicediagnostics -u " .. dev.udid .. " ioregentry AppleSmartBattery")
		if xml == "" or not xml:find("<plist") then
			return load_persisted_udid(dev.udid).smart_battery or {}, false
		end
		local info = {}
		for k, ttype, val in xml:gmatch("<key>([^<]+)</key>%s*<(%w+)>([^<]*)</%w+>") do
			if ttype == "integer" then
				local n = tonumber(val)
				if n and (info[k] == nil or info[k] == 0) then
					info[k] = n
				end
			elseif ttype == "string" then
				if info[k] == nil or info[k] == "" then
					info[k] = val
				end
			end
		end
		for k, bval in xml:gmatch("<key>([^<]+)</key>%s*<(%a+)/>") do
			if bval == "true" or bval == "false" then
				info[k] = (bval == "true")
			end
		end
		local ok = (info.CycleCount ~= nil or info.DesignCapacity ~= nil)
		if ok then
			save_persisted_section(dev.udid, "smart_battery", info)
			return info, true
		end
		return load_persisted_udid(dev.udid).smart_battery or {}, false
	end)
end

------------------------------------------------------------
-- 5. Device Identification Accessors
------------------------------------------------------------

function conky_iphone_name(i)
	local gen = get_idevice_general(i)
	if gen.DeviceName and gen.DeviceName ~= "" then
		return gen.DeviceName
	end
	if conky_tether_bt_name then
		local tname = conky_tether_bt_name()
		if tname and tname ~= "" then
			return tname
		end
	end
	local udid = conky_iphone_udid(i)
	local ld = get_lockdown_plist_data(udid)
	if ld.upower_name and ld.upower_name ~= "" then
		return ld.upower_name
	end
	return iphone_is_connected(i) and "iPhone" or "N/A"
end

function conky_iphone_product_type(i)
	local gen = get_idevice_general(i)
	return gen.ProductType or "N/A"
end

function conky_iphone_model(i)
	local pt = conky_iphone_product_type(i)
	if pt ~= "N/A" then
		return IPHONE_MODELS[pt] or pt
	end
	return iphone_is_connected(i) and "iPhone" or "N/A"
end

function conky_iphone_model_number(i)
	local gen = get_idevice_general(i)
	if gen.ModelNumber and gen.ModelNumber ~= "" then
		return gen.ModelNumber .. (gen.RegionInfo or "")
	end
	return "N/A"
end

function conky_iphone_hw_model(i)
	local gen = get_idevice_general(i)
	return gen.HardwareModel or "N/A"
end

function conky_iphone_cpu_arch(i)
	local gen = get_idevice_general(i)
	return gen.CPUArchitecture or "N/A"
end

function conky_iphone_ios_version(i)
	local gen = get_idevice_general(i)
	return gen.ProductVersion or "N/A"
end

function conky_iphone_build_version(i)
	local gen = get_idevice_general(i)
	return gen.BuildVersion or "N/A"
end

function conky_iphone_ios_full(i)
	local ver = conky_iphone_ios_version(i)
	local bld = conky_iphone_build_version(i)
	if ver ~= "N/A" and bld ~= "N/A" then
		return ver .. " (" .. bld .. ")"
	end
	return ver
end

function conky_iphone_serial(i)
	local gen = get_idevice_general(i)
	if gen.SerialNumber and gen.SerialNumber ~= "" then
		return gen.SerialNumber
	end
	local raw = conky_iphone_serial_raw(i)
	return (raw ~= "") and raw or "N/A"
end

function conky_iphone_imei(i)
	local gen = get_idevice_general(i)
	return gen.InternationalMobileEquipmentIdentity or "N/A"
end

function conky_iphone_phone_number(i)
	local gen = get_idevice_general(i)
	return gen.PhoneNumber or "N/A"
end

function conky_iphone_sim_status(i)
	local gen = get_idevice_general(i)
	local s = gen.SIMStatus
	if not s or s == "" then
		return "N/A"
	end
	if s:find("Ready") then
		return "Ready"
	elseif s:find("NotInserted") then
		return "No SIM"
	elseif s:find("PIN") then
		return "PIN Locked"
	end
	return s:gsub("^kCTSIMSupportSIMStatus", "")
end

function conky_iphone_wifi_mac(i)
	local gen = get_idevice_general(i)
	if gen.WiFiAddress and gen.WiFiAddress ~= "" then
		return gen.WiFiAddress:upper()
	end
	local udid = conky_iphone_udid(i)
	local ld = get_lockdown_plist_data(udid)
	if ld.wifi_mac and ld.wifi_mac ~= "" then
		return ld.wifi_mac:upper()
	end
	return "N/A"
end

function conky_iphone_bt_mac(i)
	local gen = get_idevice_general(i)
	if gen.BluetoothAddress and gen.BluetoothAddress ~= "" then
		return gen.BluetoothAddress:upper()
	end
	if conky_tether_bt_mac then
		local tmac = conky_tether_bt_mac()
		if tmac and tmac ~= "N/A" and tmac ~= "" then
			return tmac
		end
	end
	local udid = conky_iphone_udid(i)
	local ld = get_lockdown_plist_data(udid)
	if ld.bt_mac and ld.bt_mac ~= "" then
		return ld.bt_mac:upper()
	end
	return "N/A"
end

------------------------------------------------------------
-- 6. Battery & AppleSmartBattery Accessors
------------------------------------------------------------

function conky_iphone_battery_perc(i)
	if iphone_is_connected(i) then
		local b = get_idevice_battery(i)
		if b.BatteryCurrentCapacity then
			return math.min(100, math.max(0, tonumber(b.BatteryCurrentCapacity) or 0))
		end
	end
	if conky_tether_battery_perc then
		local tb = conky_tether_battery_perc()
		if tb and tb > 0 then
			return tb
		end
	end
	if conky_icloud_device_battery then
		local ib = conky_icloud_device_battery(i)
		if ib and ib > 0 then
			return ib
		end
	end
	local b = get_idevice_battery(i)
	if b.BatteryCurrentCapacity then
		return math.min(100, math.max(0, tonumber(b.BatteryCurrentCapacity) or 0))
	end
	local sb = get_smart_battery(i)
	if sb.CurrentCapacity then
		return math.min(100, math.max(0, tonumber(sb.CurrentCapacity) or 0))
	end
	local udid = conky_iphone_udid(i)
	local ld = get_lockdown_plist_data(udid)
	local pct = read_upower_last_charge(ld.upower_usb_file) or read_upower_last_charge(ld.upower_bt_file)
	return pct and math.min(100, math.max(0, math.floor(pct + 0.5))) or 0
end

function iphone_is_charging(i)
	local b = get_idevice_battery(i)
	if b.BatteryIsCharging ~= nil then
		return b.BatteryIsCharging == "true"
	end
	local sb = get_smart_battery(i)
	if sb.IsCharging ~= nil then
		return sb.IsCharging == true
	end
	local ct = conky_iphone_charge_type(i)
	return ct == "Fast" or ct == "Trickle"
end

function conky_iphone_is_charging(i)
	return iphone_is_charging(i) and 1 or 0
end

function conky_iphone_battery_status(i)
	if not iphone_is_connected(i) then
		return "N/A"
	end
	local b = get_idevice_battery(i)
	if b.FullyCharged == "true" or tonumber(b.BatteryCurrentCapacity) == 100 then
		return tr("Full")
	elseif b.BatteryIsCharging == "true" then
		return tr("Charging")
	elseif b.ExternalConnected == "true" then
		return tr("Not Charging")
	end
	local ct = conky_iphone_charge_type(i)
	if ct == "Fast" or ct == "Trickle" then
		return tr("Charging")
	end
	return tr("Discharging")
end

function conky_iphone_battery_cycles(i)
	local sb = get_smart_battery(i)
	return tonumber(sb.CycleCount) or 0
end

function conky_iphone_battery_design_cap(i)
	local sb = get_smart_battery(i)
	local cap = tonumber(sb.DesignCapacity) or 0
	return tostring(cap) .. " mAh"
end

function conky_iphone_battery_full_cap(i)
	local sb = get_smart_battery(i)
	local cap = tonumber(sb.NominalChargeCapacity) or tonumber(sb.AppleRawMaxCapacity) or 0
	return tostring(cap) .. " mAh"
end

function conky_iphone_battery_health(i)
	local sb = get_smart_battery(i)
	local design = tonumber(sb.DesignCapacity) or 0
	local full = tonumber(sb.NominalChargeCapacity) or tonumber(sb.AppleRawMaxCapacity) or 0
	if design <= 0 or full <= 0 then
		return 0
	end
	return math.min(100, math.max(0, math.floor((full / design) * 100 + 0.5)))
end

function conky_iphone_battery_temp(i)
	local sb = get_smart_battery(i)
	local t = tonumber(sb.Temperature)
	if not t or t <= 0 then
		return "0.0 °C"
	end
	return string.format("%.1f °C", t / 100)
end

function conky_iphone_battery_voltage(i)
	local sb = get_smart_battery(i)
	local mv = tonumber(sb.Voltage)
	if not mv or mv <= 0 then
		return "0.00 V"
	end
	return string.format("%.2f V", mv / 1000)
end

function conky_iphone_battery_current(i)
	local sb = get_smart_battery(i)
	local ma = tonumber(sb.InstantAmperage)
	if not ma then
		return "0 mA"
	end
	if ma > 32767 and ma <= 65535 then
		ma = ma - 65536
	end
	return tostring(ma) .. " mA"
end

function conky_iphone_charger_watts(i)
	local sb = get_smart_battery(i)
	local w = tonumber(sb.Watts)
	if not w or w <= 0 then
		return "0 W"
	end
	return tostring(w) .. " W"
end

------------------------------------------------------------
-- 7. Storage / Disk Usage & Installed Apps Accessors
------------------------------------------------------------

local function get_disk_numbers(i)
	local d = get_idevice_disk(i)
	local total = tonumber(d.TotalDiskCapacity) or tonumber(d.TotalDataCapacity) or 0
	local data_total = tonumber(d.TotalDataCapacity) or total
	local data_avail = tonumber(d.TotalDataAvailable) or tonumber(d.AmountDataAvailable) or 0
	local used = (total > 0 and data_avail > 0 and total >= data_avail) and (total - data_avail)
		or ((data_total > 0 and data_total >= data_avail) and (data_total - data_avail) or 0)
	local perc = (total > 0) and math.min(100, math.max(0, math.floor((used / total) * 100 + 0.5))) or 0
	return total, used, data_avail, perc
end

function conky_iphone_storage_total_gb(i)
	local total = get_disk_numbers(i)
	return string.format("%.1f GB", to_gb_num(total))
end

function conky_iphone_storage_used_gb(i)
	local _, used = get_disk_numbers(i)
	return string.format("%.1f GB", to_gb_num(used))
end

function conky_iphone_storage_free_gb(i)
	local _, _, free = get_disk_numbers(i)
	return string.format("%.1f GB", to_gb_num(free))
end

function conky_iphone_storage_perc(i)
	local _, _, _, perc = get_disk_numbers(i)
	return perc
end

function conky_iphone_apps_count(i)
	local dev = get_dev(i)
	local udid = (dev and dev.udid ~= "") and dev.udid or conky_iphone_udid(i)
	if not dev or dev.udid == "" then
		local p = load_persisted_udid(udid).apps
		return (type(p) == "table" and tonumber(p.count)) or 0
	end
	return cached_iphone("iphone_apps_count_" .. dev.udid, 300, 15, function()
		local out = run_idevice_cmd("ideviceinstaller -u " .. dev.udid .. " list --user")
		if out == "" or out:find("^ERROR:") or out:find("Could not connect") then
			local p = load_persisted_udid(dev.udid).apps
			return (type(p) == "table" and tonumber(p.count)) or 0, false
		end
		local count = 0
		for line in out:gmatch("[^\r\n]+") do
			if not line:match("^Total:") and not line:match("^CFBundleIdentifier") and line:find(",") then
				count = count + 1
			end
		end
		if count > 0 then
			save_persisted_section(dev.udid, "apps", { count = count })
		end
		return count, count > 0
	end)
end
