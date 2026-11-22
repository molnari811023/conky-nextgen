--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/arch.lua — Arch Linux distribution-specific metrics: pacman install date, repo/AUR updates, package count.
]]--

-- 1. Arch installation date from pacman.log
function conky_install_date_arch()
	return cached("arch_inst_dt", 86400, function()
		local f = io.open("/var/log/pacman.log", "r")
		if f then
			local line = f:read("*l")
			f:close()
			local dt = line and line:match("^%[(%d%d%d%d%-%d%d%-%d%d)")
			if dt and dt ~= "" then return dt end
		end
		if lfs then
			local mtime = lfs.attributes("/etc/machine-id", "modification")
			if mtime then return os.date("%Y-%m-%d", mtime) end
		end
		return "N/A"
	end)
end

-- 2. Installed pacman package count (counted directly from /var/lib/pacman/local)
function conky_packages_arch()
	return cached("arch_pkgs", 60, function()
		if lfs and lfs.attributes("/var/lib/pacman/local", "mode") == "directory" then
			local count = 0
			for entry in lfs.dir("/var/lib/pacman/local") do
				if entry ~= "." and entry ~= ".." and entry ~= "ALPM_DB_VERSION" then
					count = count + 1
				end
			end
			return tostring(count)
		end
		return "0"
	end)
end

-- 3. Official repository and AUR update count (from updates.txt)
local function get_updates_file()
	local path = (JSON_PATH or "") .. "updates.txt"
	local f = io.open(path, "r")
	if f then f:close(); return path end
	return (os.getenv("HOME") or "/tmp") .. "/.conky/tmp/updates.txt"
end

function conky_updates_repo()
	local s = read_file(get_updates_file()) or ""
	local n = tonumber(s:match("^(%d+)")) or 0
	local word = (n == 1) and "package" or "packages"
	return tostring(n) .. " " .. ((conky_get_tr and conky_get_tr(word)) or word)
end

function conky_updates_aur()
	local s = read_file(get_updates_file()) or ""
	local n = tonumber(s:match("%s(%d+)$")) or 0
	local word = (n == 1) and "package" or "packages"
	return tostring(n) .. " " .. ((conky_get_tr and conky_get_tr(word)) or word)
end
