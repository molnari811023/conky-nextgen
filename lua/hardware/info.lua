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
	static.inst_dt = pread("head -n1 /var/log/pacman.log | cut -c 2-11")
	return static.inst_dt ~= "" and static.inst_dt or "N/A"
end
