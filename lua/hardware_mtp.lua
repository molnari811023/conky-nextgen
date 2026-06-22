--{{{ MTP
function kde_mtp_info()
	return cached("kde_mtp_info", 5, function()
		local data = { count = 0, devices = {} }
		local devs = pread("qdbus6 --literal org.kde.kiod6 /modules/kmtpd org.kde.kmtp.Daemon.listDevices 2>/dev/null")
		if devs == "" then
			return data
		end
		for dev in devs:gmatch("(/modules/kmtpd/device%d+)") do
			data.count = data.count + 1
			local name =
				pread([[kioclient ls mtp:/ 2>/dev/null | grep -v "^\." | grep "[a-zA-Z0-9]" | head -n 1]]):gsub(
					"[\r\n]+",
					""
				)
			if name == "" then
				name = "MTP Device"
			end
			local device = { name = name, storages = {} }
			local storages_raw =
				pread("qdbus6 --literal org.kde.kiod6 " .. dev .. " org.kde.kmtp.Device.listStorages 2>/dev/null")
			for storage in storages_raw:gmatch("/modules/kmtpd/device%d+/(storage%d+)") do
				if storage then
					local base = dev .. "/" .. storage
					local max = parse_num(
						pread("qdbus6 org.kde.kiod6 " .. base .. " org.kde.kmtp.Storage.maxCapacity 2>/dev/null")
					)
					local free = parse_num(
						pread("qdbus6 org.kde.kiod6 " .. base .. " org.kde.kmtp.Storage.freeSpaceInBytes 2>/dev/null")
					)
					local used = max - free
					table.insert(device.storages, {
						name = storage,
						max = max,
						used = used,
						perc = (max > 0) and math.floor((used / max) * 100) or 0,
					})
				end
			end
			table.insert(data.devices, device)
		end
		return data
	end)
end

function gvfs_mtp_info()
	return cached("gvfs_mtp_info", 5, function()
		local uid = pread("id -u")
		local base = "/run/user/" .. uid .. "/gvfs/"
		local list = pread("ls " .. base .. " 2>/dev/null")
		local devices = {}
		for mtp in list:gmatch("[^\n]+") do
			if mtp:match("^mtp:") then
				local info = pread(
					"timeout 2 gio info -a 'filesystem::size,filesystem::free' '" .. base .. mtp .. "' 2>/dev/null"
				)
				local total = tonumber(info:match("size:%s+(%d+)")) or 0
				local free = tonumber(info:match("free:%s+(%d+)")) or 0
				local used = total - free
				table.insert(devices, {
					name = mtp:gsub("mtp:host=", ""):gsub("_", " "),
					storages = {
						{
							name = "Internal",
							max = total,
							used = used,
							perc = (total > 0) and math.floor((used * 100) / total) or 0,
						},
					},
				})
			end
		end
		return { count = #devices, devices = devices }
	end)
end

function conky_mtp_data()
	local desktop = (os.getenv("XDG_CURRENT_DESKTOP") or ""):lower()
	local plasma = desktop:match("kde") or desktop:match("plasma")
	return plasma and kde_mtp_info() or gvfs_mtp_info()
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
--}}}
