--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/battery.lua — Battery and external-device charge monitoring via sysfs (/sys/class/power_supply/).
]]--
--{{{
-- ## Battery Module
--
-- Reads internal battery state, remaining time, percentage, and health directly
-- from `/sys/class/power_supply/BAT*`, filtering out peripheral batteries
-- (`scope == "Device"`, such as `apple_mfi_fastcharge_*` or HID++ mice).
-- External device batteries (HID++ mouse, Bluetooth headset/peripherals) are
-- also read directly from `/sys/class/power_supply/` (`scope == "Device"`).
--
-- **Exposed/global functions:**
-- - `conky_battery_path()` / `get_battery_path()` — returns sysfs path of the main system battery
-- - `conky_battery_percent()` — returns internal battery capacity (0–100)
-- - `conky_battery_status()` — returns translated battery status string
-- - `conky_battery_time()` — returns formatted remaining charge/discharge time
-- - `conky_battery_health_data()` — returns internal battery health as a percentage (0–100), or nil
-- - `conky_headset_info()` — returns `{name, pct}` table for a connected headset battery in sysfs
-- - `conky_mouse_info()` — returns `{name, pct}` table for a connected mouse battery in sysfs
-- - `conky_external_battery_list()` — list of connected peripheral batteries (`{name, pct}`)
-- - `conky_external_battery_count()` — number of detected external battery devices
-- - `conky_external_battery_name(i)` — name of the i-th external device
-- - `conky_external_battery_charge(i)` — charge percentage of the i-th external device
--}}}

local function is_system_battery(entry)
	local base = "/sys/class/power_supply/" .. entry
	local t = read_file(base .. "/type")
	if not (t and t:find("Battery")) then
		return false
	end
	local scope = read_file(base .. "/scope")
	if scope and scope:find("Device") then
		return false
	end
	return true
end

function get_battery_path()
	return cached("main_battery_path", 3600, function()
		local fallback
		if lfs and lfs.attributes("/sys/class/power_supply", "mode") == "directory" then
			for entry in lfs.dir("/sys/class/power_supply") do
				if entry ~= "." and entry ~= ".." and is_system_battery(entry) then
					if entry:match("^BAT") then
						return "/sys/class/power_supply/" .. entry .. "/"
					end
					fallback = fallback or ("/sys/class/power_supply/" .. entry .. "/")
				end
			end
		end
		return fallback or "/sys/class/power_supply/BAT0/"
	end)
end

conky_battery_path = get_battery_path

function conky_battery_percent()
	return cached("battery_percent", 5, function()
		return read_num(get_battery_path() .. "capacity") or 0
	end)
end

function conky_battery_health_data()
	return cached("battery_health", 3600, function()
		local base = get_battery_path()
		local design = read_num(base .. "charge_full_design")
		local full = read_num(base .. "charge_full")
		if not design or design == 0 then
			design = read_num(base .. "energy_full_design")
			full = read_num(base .. "energy_full")
		end
		if not design or design == 0 then return nil end
		return math.floor((full / design) * 100)
	end)
end

function conky_battery_status()
	local s = cached("battery_status", 5, function()
		return read_file(get_battery_path() .. "status") or ""
	end)
	if s == "" then return "" end
	local key
	if s == "Full" then
		key = "Full"
	elseif s == "Charging" then
		key = "Charging"
	elseif s == "Discharging" then
		key = "Discharging"
	elseif s:lower() == "not charging" then
		key = "Not Charging"
	else
		key = "Unknown"
	end
	return conky_get_tr(key)
end

function conky_battery_time()
	local sec = cached("battery_time_sec", 5, function()
		local base = get_battery_path()
		local st = read_file(base .. "status")
		local now = read_num(base .. "charge_now") or read_num(base .. "energy_now")
		local full = read_num(base .. "charge_full") or read_num(base .. "energy_full")
		local rate = read_num(base .. "current_now") or read_num(base .. "power_now")
		if now and rate and rate > 0 then
			if st == "Discharging" then
				return math.floor((now * 3600) / rate)
			elseif st == "Charging" and full and full > now then
				return math.floor(((full - now) * 3600) / rate)
			end
		end
		return nil
	end)
	if not sec or sec <= 0 then return "" end
	local h = string.format("%02d", math.floor(sec / 3600))
	local m = string.format("%02d", math.floor((sec % 3600) / 60))
	local s = string.format("%02d", sec % 60)
	return h .. conky_get_tr("hour_short")
		.. " " .. m .. conky_get_tr("minute_short")
		.. " " .. s .. conky_get_tr("second_short")
end

local function is_mouse_device(entry_lc, model_lc)
	return entry_lc:find("hidpp") ~= nil
		or entry_lc:find("mouse") ~= nil
		or model_lc:find("mouse") ~= nil
		or model_lc:find("mx ") ~= nil
		or model_lc:find("deathadder") ~= nil
		or model_lc:find("viper") ~= nil
		or model_lc:find("basilisk") ~= nil
end

local function get_sysfs_device_batteries()
	return cached("sysfs_device_batteries", 10, function()
		local result = { all = {}, mouse = nil, headset = nil }
		if not lfs or lfs.attributes("/sys/class/power_supply", "mode") ~= "directory" then
			return result
		end
		local entries = {}
		for entry in lfs.dir("/sys/class/power_supply") do
			if entry ~= "." and entry ~= ".." and not entry:lower():find("apple_mfi") then
				entries[#entries + 1] = entry
			end
		end
		table.sort(entries)
		for _, entry in ipairs(entries) do
			local base = "/sys/class/power_supply/" .. entry .. "/"
			local scope = read_file(base .. "scope")
			local pct = read_num(base .. "capacity")
			if scope == "Device" and pct then
				local model = read_file(base .. "model_name")
				local entry_lc = entry:lower()
				local model_lc = (model or ""):lower()
				local is_mouse = is_mouse_device(entry_lc, model_lc)
				local item = {
					name = (model ~= "" and model or (is_mouse and "Mouse" or "Headset")),
					pct = pct,
				}
				result.all[#result.all + 1] = item
				if is_mouse and not result.mouse then
					result.mouse = item
				elseif not is_mouse and not result.headset then
					result.headset = item
				end
			end
		end
		return result
	end)
end

function conky_headset_info()
	return get_sysfs_device_batteries().headset
end

function conky_mouse_info()
	return get_sysfs_device_batteries().mouse
end

function conky_external_battery_list()
	return get_sysfs_device_batteries().all
end

function conky_external_battery_count()
	return #conky_external_battery_list()
end

function conky_external_battery_name(i)
	local idx = tonumber(i) or 1
	local list = conky_external_battery_list()
	if not list or #list < idx then
		return ""
	end
	return list[idx].name
end

function conky_external_battery_charge(i)
	local idx = tonumber(i) or 1
	local list = conky_external_battery_list()
	if not list or #list < idx then
		return 0
	end
	return list[idx].pct
end
