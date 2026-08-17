--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- hardware/battery.lua — Battery health, Bluetooth headset, mouse battery
-- Callable from Conky:
--   conky_battery_health_data()      → number (0-100, battery health)
--     Percentage of the battery's current capacity vs. its designed
--     capacity. Reads /sys/class/power_supply (1h cache). Use directly
--     in a bar/ring widget for a health gauge.
--   conky_headset_info()             → { name, pct } | nil
--     Info about a connected Bluetooth headset: table with `name` and
--     `pct`, or nil when none is connected. Queried via D-Bus (KDE Plasma
--     or UPower). Good for an "in-ear" percentage indicator.
--   conky_mouse_info()               → { name, pct } | nil
--     Same shape as headset_info but for a wireless mouse. Returns nil
--     when no such device is found.
--   conky_external_battery_list()    → { {name, pct}, ... }
--     List of every detachable battery detected via UPower, each entry
--     being { name, pct }. Empty table when nothing is attached.
--   conky_external_battery_count()   → number
--     How many external batteries are present (0 when none).
--   conky_external_battery_name(i)   → string
--     Display name of the i-th external battery (1-based).
--   conky_external_battery_charge(i) → number (0-100)
--     Charge percentage of the i-th external battery (1-based).
--
-- Helper functions:
--   get_battery_path()     → "/sys/class/power_supply/BAT0/"
--     Path of the main (internal) battery in sysfs, auto-detected.
--   is_plasma()            → bool (KDE Plasma detection)
--     True when running under KDE Plasma (used to pick the D-Bus path).
--   get_headset_plasma()   → { name, pct } | nil (D-Bus)
--     D-Bus lookup of a Bluetooth headset under Plasma.
--   get_device_upower(filter) → { name, pct } | nil
--     Generic UPower device lookup with a name filter; used for both the
--     headset and the mouse query.

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
		if design == 0 then
			design = read_num(base .. "energy_full_design")
			full = read_num(base .. "energy_full")
		end
		return (design > 0) and math.floor((full / design) * 100) or 0
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
	return list[idx].name or ""
end

function conky_external_battery_charge(i)
	local idx = tonumber(i) or 1
	local list = conky_external_battery_list()
	if not list or #list < idx then
		return 0
	end
	return list[idx].pct or 0
end
