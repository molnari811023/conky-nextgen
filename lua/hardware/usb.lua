--[[[
lua/hardware/usb.lua — Mounted USB block device detection and enumeration via lsblk.
]]--
--{{{
-- ## USB Module
--
-- Parses `lsblk` output to find block devices whose transport is USB and
-- that are mounted under a user media directory. Returns device model
-- names and mount points. Results are cached for 3 seconds.
--
-- **Exposed/global functions:**
-- - `conky_usb_list()` — returns a sorted list of `{name, part, mount}` tables
-- - `conky_has_usb()` — returns 1 if any USB device is mounted, else 0
-- - `conky_usb_count()` — number of mounted USB devices
-- - `conky_usb_name(i)` — model name of the i-th USB device
-- - `conky_usb_mount(i)` — mount point of the i-th USB device
--
-- **Config/globals used:**
-- `cached()`, `pread()`, `starts_with()`, `get_root_device()` (all from core.lua), `os.getenv("USER")`
--}}}

function conky_usb_list()
	return cached("usb_detect", 3, function()
		local result = {}
		local user = os.getenv("USER") or ""
		local prefixes = {
			"/run/media/" .. user .. "/",
			"/media/" .. user .. "/",
			"/media/",
		}
		local out = pread([[lsblk -P -o NAME,PKNAME,MODEL,MOUNTPOINT,TRAN 2>/dev/null]])
		local map = {}
		for line in out:gmatch("[^\n]+") do
			local name = line:match('NAME="([^"]+)"')
			if name then
				map[name] = {
					parent = line:match('PKNAME="([^"]*)"'),
					model = line:match('MODEL="([^"]*)"'),
					mount = line:match('MOUNTPOINT="([^"]*)"'),
					tran = line:match('TRAN="([^"]*)"'),
				}
			end
		end
		for name, entry in pairs(map) do
			if entry.mount and entry.mount ~= "" then
				local is_media = false
				for _, p in ipairs(prefixes) do
					if starts_with(entry.mount, p) then
						is_media = true
						break
					end
				end
				if is_media then
					local root = get_root_device(map, name)
					if root and (root.tran == "usb" or entry.tran == "usb") then
						local label = (root.model ~= "" and root.model or "USB Device")
							:gsub("^%s+", "")
							:gsub("%s+$", "")
						table.insert(result, { name = label, part = name, mount = entry.mount })
					end
				end
			end
		end
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
