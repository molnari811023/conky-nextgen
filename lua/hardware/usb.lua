--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/usb.lua — Mounted USB block device detection and enumeration via /proc/mounts and /sys/class/block.
]]--
--{{{
-- ## USB Module
--
-- Reads `/proc/mounts` and `/sys/class/block/` symlinks to find block devices
-- whose transport is USB and that are mounted under a user media directory.
-- Returns device model names and mount points. Results are cached for 3 seconds.
--
-- **Exposed/global functions:**
-- - `conky_usb_list()` — returns a sorted list of `{name, part, mount}` tables
-- - `conky_has_usb()` — returns 1 if any USB device is mounted, else 0
-- - `conky_usb_count()` — number of mounted USB devices
-- - `conky_usb_name(i)` — model name of the i-th USB device
-- - `conky_usb_mount(i)` — mount point of the i-th USB device
--
-- **Config/globals used:**
-- `cached()`, `read_file()`, `starts_with()`, `lfs`, `os.getenv("USER")`
--}}}

local function unescape_mount_path(s)
	return (s:gsub("\\(%d%d%d)", function(oct)
		local n = tonumber(oct, 8)
		return n and string.char(n) or oct
	end))
end

function conky_usb_list()
	return cached("usb_detect", 3, function()
		local result = {}
		local user = os.getenv("USER") or ""
		local prefixes = {
			"/run/media/" .. user .. "/",
			"/media/" .. user .. "/",
			"/media/",
		}
		local f = io.open("/proc/mounts", "r")
		if not f then
			return result
		end
		local seen = {}
		for line in f:lines() do
			local part, raw_mount = line:match("^/dev/(%S+)%s+(%S+)")
			if part and raw_mount and not seen[part] then
				local mount = unescape_mount_path(raw_mount)
				local is_media = false
				for _, p in ipairs(prefixes) do
					if starts_with(mount, p) then
						is_media = true
						break
					end
				end
				if is_media and lfs then
					local target = lfs.symlinkattributes("/sys/class/block/" .. part, "target")
					if target and target:find("/usb") then
						seen[part] = true
						local disk = target:match("/block/([^/]+)/")
							or target:match("/block/([^/]+)$")
							or part
						local model = read_file("/sys/class/block/" .. disk .. "/device/model")
						local label = (model ~= "" and model or "USB Device")
							:gsub("^%s+", "")
							:gsub("%s+$", "")
						table.insert(result, { name = label, part = part, mount = mount })
					end
				end
			end
		end
		f:close()
		table.sort(result, function(a, b)
			return a.part < b.part
		end)
		return result
	end)
end

function conky_has_usb()
	return (#conky_usb_list() > 0) and 1 or 0
end
function conky_usb_count()
	return #conky_usb_list()
end

function conky_usb_name(i)
	local idx = tonumber(i) or 1
	local list = conky_usb_list()
	if not list or #list < idx then
		return ""
	end
	return list[idx].name
end

function conky_usb_mount(i)
	local idx = tonumber(i) or 1
	local list = conky_usb_list()
	if not list or #list < idx then
		return ""
	end
	return list[idx].mount
end
