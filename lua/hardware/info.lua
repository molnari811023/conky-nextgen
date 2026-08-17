--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- hardware/info.lua — CPU model, NVMe model, OS install date
-- Callable from Conky:
--   conky_cpu_name()      → string ("Intel Core i7-6700HQ")
--     CPU model name from /proc/cpuinfo, cleaned of the "CPU" and
--     "Processor" words and trademark symbols (24h cache).
--   conky_nvme_model()    → string ("Samsung SSD 970 EVO")
--     NVMe drive model from sysfs (24h cache), or "No NVMe" when absent.
--   conky_install_date()  → string ("2023-01-15")
--     Date the OS was installed, from the filesystem birth time of
--     /var/log (24h cache).
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
