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
		local dt = pread("head -n1 /var/log/dpkg.log 2>/dev/null | awk '{print $1}'")
		if dt and dt ~= "" then return dt end

		-- Fallback: machine-id or root filesystem timestamp
		local fb = pread("ls -ld --time-style=+%Y-%m-%d /etc/machine-id 2>/dev/null | awk '{print $6}'")
		return (fb and fb ~= "") and fb or "N/A"
	end)
end

-- 2. Installed package count (dpkg)
function conky_packages_ubuntu()
	return cached("ubuntu_pkgs", 60, function()
		local count = pread("dpkg-query -f '.\\n' -W 2>/dev/null | wc -l")
		return (count and count ~= "") and count:gsub("%s+", "") or "0"
	end)
end

-- 3. Ubuntu distribution release name (via /etc/os-release)
function conky_ubuntu_release()
	return cached("ubuntu_rel", 86400, function()
		local name = pread([[grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d'=' -f2 | tr -d '"']])
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
	local s = read_file(get_updates_file())
	local n = tonumber(s:match("^(%d+)"))
	return tostring(n or 0) .. " " .. conky_get_tr((n == 1) and "package" or "packages")
end

function conky_updates_security()
	local s = read_file(get_updates_file())
	local n = tonumber(s:match("%s(%d+)$"))
	return tostring(n or 0) .. " " .. conky_get_tr((n == 1) and "package" or "packages")
end
