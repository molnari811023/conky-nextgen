--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/hardware/info.lua — Hardware identification: CPU model, NVMe model, and OS install date.
]]--
--{{{
-- ## Info Module
--
-- Returns human-readable hardware identifiers. CPU and NVMe names are
-- read from sysfs/proc and cached for a full day. The Arch Linux install
-- date is extracted once from `pacman.log` and stored in `static`.
--
-- **Exposed/global functions:**
-- - `conky_cpu_name()` — cleaned-up CPU model name (symbols and filler words stripped)
-- - `conky_nvme_model()` — NVMe drive model string
-- - `conky_install_date()` — first line of pacman.log (Arch install date)
--
-- **Config/globals used:**
-- `static` (from core.lua), `read_file()`, `cached()`, `pread()`
--}}}

function conky_cpu_name()
    return cached("cpu_model", 86400, function()
        local name = read_file("/proc/cpuinfo"):match("model name%s+:%s+(.-)\n") or "Unknown CPU"
        return name:gsub("[™®]", "")
            :gsub("%(R%)", "")
            :gsub("%(TM%)", "")
            :gsub("CPU", "")
            :gsub("Processor", "")
            :gsub("%s+", " ")
            :gsub("^%s+", "")
            :gsub("%s+$", "")
    end)
end

function conky_nvme_model()
    return cached("nvme_model", 86400, function()
        local v = read_file("/sys/class/nvme/nvme0/model")
        return (v ~= "") and v or "Unknown NVMe"
    end)
end

function conky_install_date()
	if static.inst_dt then
		return static.inst_dt
	end
	-- Arch Linux: pacman.log
	local dt = pread("head -n1 /var/log/pacman.log 2>/dev/null | cut -c 2-11")
	if dt and dt ~= "" then
		static.inst_dt = dt
		return static.inst_dt
	end
	-- Ubuntu / Debian: dpkg.log (debootstrap / initial install)
	dt = pread("head -n1 /var/log/dpkg.log 2>/dev/null | awk '{print $1}'")
	if dt and dt ~= "" then
		static.inst_dt = dt
		return static.inst_dt
	end
	-- Fallback: /etc/machine-id timestamp
	dt = pread("ls -ld --time-style=+%Y-%m-%d /etc/machine-id 2>/dev/null | awk '{print $6}'")
	static.inst_dt = (dt and dt ~= "") and dt or "N/A"
	return static.inst_dt
end

function conky_uptime_fmt()
	local f = io.open("/proc/uptime", "r")
	local sec = f and tonumber(f:read("*a"):match("^(%d+%.?%d*)")) or 0
	if f then f:close() end
	local total = math.floor(sec)
	local h = math.floor(total / 3600)
	local m = math.floor((total % 3600) / 60)
	local hr = conky_get_tr("hour_short")
	local mn = conky_get_tr("minute_short")
	if h > 0 then
		if m > 0 then return h .. hr .. " " .. m .. mn end
		return h .. hr
	end
	if m > 0 then return m .. mn end
	return "0" .. mn
end
