--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/arch.lua — Arch Linux distribution-specific metrics: pacman install date, repo/AUR updates, package count.
]]--

-- 1. Arch telepítési dátum a pacman.log-ból
function conky_install_date_arch()
	return cached("arch_inst_dt", 86400, function()
		local dt = pread("head -n1 /var/log/pacman.log 2>/dev/null | cut -c 2-11")
		return (dt and dt ~= "") and dt or "N/A"
	end)
end

-- 2. Telepített pacman csomagok száma
function conky_packages_arch()
	return cached("arch_pkgs", 60, function()
		local count = pread("pacman -Q 2>/dev/null | wc -l")
		return (count and count ~= "") and count:gsub("%s+", "") or "0"
	end)
end

-- 3. Hivatalos repo és AUR frissítések száma (tmp/updates.txt-ből)
local tmp_dir = os.getenv("HOME") .. "/.conky/tmp/"
local updates_file = tmp_dir .. "updates.txt"

function conky_updates_repo()
	local s = read_file(updates_file)
	local n = tonumber(s:match("^(%d+)"))
	return tostring(n or 0) .. " " .. conky_get_tr((n == 1) and "package" or "packages")
end

function conky_updates_aur()
	local s = read_file(updates_file)
	local n = tonumber(s:match("%s(%d+)$"))
	return tostring(n or 0) .. " " .. conky_get_tr((n == 1) and "package" or "packages")
end
