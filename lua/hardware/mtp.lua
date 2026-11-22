--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/mtp.lua — MTP device detection via sysfs (/sys/bus/usb/devices) and GVFS (/run/user/<uid>/gvfs).
]]--
--{{{
-- ## MTP Module
--
-- Detects MTP-connected devices directly from the filesystem without spawning
-- external shell commands: scans `/sys/bus/usb/devices/` for USB interfaces
-- advertising `"MTP"`, and checks `/run/user/<uid>/gvfs/` for `mtp:*` mounts.
-- Results are cached for 5 seconds.
--
-- **Exposed/global functions:**
-- - `conky_mtp_data()` — returns `{count, devices}` table with per-device info
-- - `conky_mtp_count()` — number of connected MTP devices
-- - `conky_mtp_perc(dev_idx, storage_idx)` — usage percentage for a specific storage volume
--
-- **Config/globals used:**
-- `cached()`, `read_file()`, `lfs`
--}}}

function conky_mtp_data()
	return cached("mtp_info", 5, function()
		local devices = {}
		local seen = {}

		if lfs and lfs.attributes("/sys/bus/usb/devices", "mode") == "directory" then
			for entry in lfs.dir("/sys/bus/usb/devices") do
				local dev_id = entry:match("^([^:]+):%d+%.%d+$")
				if dev_id and not seen[dev_id] then
					local iface_desc = read_file("/sys/bus/usb/devices/" .. entry .. "/interface")
					if iface_desc and iface_desc:lower():find("mtp") then
						seen[dev_id] = true
						local product = read_file("/sys/bus/usb/devices/" .. dev_id .. "/product")
						local name = (product and product ~= "") and product or "MTP Device"
						devices[#devices + 1] = {
							name = name,
							storages = {
								{ name = "Internal", max = 0, used = 0, perc = 0 },
							},
						}
					end
				end
			end
		end

		if #devices == 0 and lfs then
			local uid = lfs.attributes("/proc/self", "uid")
			if uid then
				local base = "/run/user/" .. tostring(uid) .. "/gvfs"
				if lfs.attributes(base, "mode") == "directory" then
					for entry in lfs.dir(base) do
						if entry:match("^mtp:") then
							local name = entry:gsub("^mtp:host=", ""):gsub("_", " ")
							devices[#devices + 1] = {
								name = (name ~= "" and name or "MTP Device"),
								storages = {
									{ name = "Internal", max = 0, used = 0, perc = 0 },
								},
							}
						end
					end
				end
			end
		end

		return { count = #devices, devices = devices }
	end)
end

function conky_mtp_count()
	return conky_mtp_data().count
end

function conky_mtp_perc(dev_idx, storage_idx)
	local d = conky_mtp_data().devices[tonumber(dev_idx) or 1]
	if not d then
		return 0
	end
	local s = d.storages[tonumber(storage_idx) or 1]
	return s and s.perc or 0
end
