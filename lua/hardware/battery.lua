--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/battery.lua — Battery and external-device charge monitoring via sysfs, UPower, and BlueZ/D-Bus.
]]--
--{{{
-- ## Battery Module
--
-- Reads internal battery health from sysfs, and detects Bluetooth headset
-- and HID++ mouse battery levels via UPower or KDE Plasma's BlueZ D-Bus
-- interface. All queries are cached to avoid rapid repeated I/O.
--
-- **Exposed/global functions:**
-- - `conky_battery_health_data()` — returns internal battery health as a percentage (0–100), or nil
-- - `conky_headset_info()` — returns `{name, pct}` table for a connected Bluetooth headset
-- - `conky_mouse_info()` — returns `{name, pct}` table for a HID++ mouse via UPower
-- - `conky_external_battery_list()` — combined list of headset and mouse battery entries
-- - `conky_external_battery_count()` — number of detected external battery devices
-- - `conky_external_battery_name(i)` — name of the i-th external device
-- - `conky_external_battery_charge(i)` — charge percentage of the i-th external device
--}}}

local function get_battery_path()
	return cached("main_battery_path", 3600, function()
		if lfs then
			for entry in lfs.dir("/sys/class/power_supply") do
				if entry ~= "." and entry ~= ".." then
					local t = read_file("/sys/class/power_supply/" .. entry .. "/type")
					if t and t:find("Battery") then
						return "/sys/class/power_supply/" .. entry .. "/"
					end
				end
			end
		else
			local h = io.popen("ls /sys/class/power_supply/")
			if h then
				for line in (h:read("*a") or ""):gmatch("[^\n]+") do
					local t = read_file("/sys/class/power_supply/" .. line .. "/type")
					if t and t:find("Battery") then
						h:close()
						return "/sys/class/power_supply/" .. line .. "/"
					end
				end
				h:close()
			end
		end
		return "/sys/class/power_supply/BAT0/"
	end)
end

local function is_plasma()
	return cached("is_plasma_env", 3600, function()
		local xdg = (os.getenv("XDG_CURRENT_DESKTOP") or ""):lower()
		if xdg:match("kde") or xdg:match("plasma") then
			return true
		end
		if os.getenv("KDE_FULL_SESSION") == "true" then
			return true
		end
		return pread("pgrep plasmashell") ~= ""
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

local function get_headset_plasma()
	local dev = pread(
		"dbus-send --system --dest=org.bluez --print-reply / org.freedesktop.DBus.ObjectManager.GetManagedObjects "
			.. "| grep -oP '/org/bluez/hci0/dev_[A-F0-9_]+' | head -n 1"
	)
	if dev == "" then
		return nil
	end
	local name = pread("qdbus6 --system org.bluez " .. dev .. " org.bluez.Device1.Name 2>/dev/null")
	local batt = pread(
		"dbus-send --system --print-reply --dest=org.bluez "
			.. dev
			.. " org.freedesktop.DBus.Properties.Get string:'org.bluez.Battery1' string:'Percentage' 2>/dev/null "
			.. "| grep variant | awk '{print $3}'"
	)
	local pct = batt:match("(%d+)")
	return pct and { name = (name ~= "" and name or "Headset"), pct = tonumber(pct) } or nil
end

local function get_device_upower(filter)
	local path = pread("upower -e | grep -i '" .. filter .. "' | head -n 1")
	if path == "" then
		return nil
	end
	local res = pread("upower -i " .. path)
	local pct = res:match("percentage:%s+(%d+)%%")
	local model = res:match("model:%s+(.-)\n") or filter
	return pct and { name = model, pct = tonumber(pct) } or nil
end

function conky_headset_info()
	return cached("headset_info", 10, function()
		if is_plasma() then
			local h = get_headset_plasma()
			if h then
				return h
			end
		end
		return get_device_upower("headset\\|headphone")
	end)
end

function conky_mouse_info()
	return cached("mouse_info", 10, function()
		return get_device_upower("hidpp")
	end)
end

function conky_external_battery_list()
	local devices = {}
	local m = conky_mouse_info()
	if m then
		table.insert(devices, m)
	end
	local h = conky_headset_info()
	if h then
		table.insert(devices, h)
	end
	return devices
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
