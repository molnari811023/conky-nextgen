--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/ubuntu.lua — Ubuntu distribution-specific metrics: dpkg install date, APT/Security updates, package count, release name.
]]--

-- 1. Installation date on Ubuntu (debootstrap or standard installation)
function conky_install_date_ubuntu()
	return cached("ubuntu_inst_dt", 86400, function()
		-- For debootstrap systems: earliest entry in dpkg.log
		local f = io.open("/var/log/dpkg.log", "r")
		if f then
			local line = f:read("*l")
			f:close()
			local dt = line and line:match("^(%d%d%d%d%-%d%d%-%d%d)")
			if dt and dt ~= "" then return dt end
		end

		-- Fallback: machine-id timestamp via lfs
		if lfs then
			local mtime = lfs.attributes("/etc/machine-id", "modification")
			if mtime then return os.date("%Y-%m-%d", mtime) end
		end
		return "N/A"
	end)
end

-- 2. Installed package count (from /var/lib/dpkg/status)
function conky_packages_ubuntu()
	return cached("ubuntu_pkgs", 60, function()
		local f = io.open("/var/lib/dpkg/status", "r")
		if not f then return "0" end
		local count = 0
		for line in f:lines() do
			if line == "Status: install ok installed" then
				count = count + 1
			end
		end
		f:close()
		return tostring(count)
	end)
end

-- 3. Ubuntu distribution release name (via /etc/os-release)
function conky_ubuntu_release()
	return cached("ubuntu_rel", 86400, function()
		local osrel = read_file("/etc/os-release")
		local name = osrel:match('PRETTY_NAME="([^"]+)"') or osrel:match("PRETTY_NAME=([^\n]+)")
		return (name and name ~= "") and name or "Ubuntu"
	end)
end

-- 4. Read APT and Security updates (from updates.txt)
-- Fetch script output format: <total_updates> <security_updates>
local function get_updates_file()
	local path = (JSON_PATH or "") .. "updates.txt"
	local f = io.open(path, "r")
	if f then f:close(); return path end
	return (os.getenv("HOME") or "/tmp") .. "/.conky/tmp/updates.txt"
end

function conky_updates_apt()
	local s = read_file(get_updates_file()) or ""
	local n = tonumber(s:match("^(%d+)")) or 0
	local word = (n == 1) and "package" or "packages"
	return tostring(n) .. " " .. ((conky_get_tr and conky_get_tr(word)) or word)
end

function conky_updates_security()
	local s = read_file(get_updates_file()) or ""
	local n = tonumber(s:match("%s(%d+)$")) or 0
	local word = (n == 1) and "package" or "packages"
	return tostring(n) .. " " .. ((conky_get_tr and conky_get_tr(word)) or word)
end
