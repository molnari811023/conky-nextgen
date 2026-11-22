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
-- - `conky_cpu_count()` — number of logical online CPUs (from sysfs `/sys/devices/system/cpu/online`)
-- - `conky_nvme_model()` — NVMe drive model string
-- - `conky_install_date()` — OS install date (from pacman.log, dpkg.log, or /etc/machine-id)
-- - `conky_os_name()` — OS PRETTY_NAME from `/etc/os-release`
-- - `conky_desktop_session()` — desktop session / windowing system from environment
-- - `conky_uptime_fmt()` — formatted uptime from `/proc/uptime`
--
-- **Config/globals used:**
-- `static` (from core.lua), `read_file()`, `cached()`, `lfs`
--}}}

function conky_cpu_count()
	return cached("cpu_count", 86400, function()
		local online = read_file("/sys/devices/system/cpu/online")
		if online and online ~= "" then
			local total = 0
			for part in online:gmatch("[^,]+") do
				local a, b = part:match("^(%d+)%-(%d+)$")
				if a and b then
					total = total + (tonumber(b) - tonumber(a) + 1)
				elseif part:match("^%d+$") then
					total = total + 1
				end
			end
			if total > 0 then
				return total
			end
		end
		local count = 0
		local cpuinfo = read_file("/proc/cpuinfo") or ""
		for _ in cpuinfo:gmatch("processor%s*:") do
			count = count + 1
		end
		return (count > 0) and count or 4
	end)
end

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

local function read_first_line(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local line = f:read("*l")
	f:close()
	return line
end

function conky_install_date()
	if static.inst_dt then
		return static.inst_dt
	end
	-- Arch Linux: pacman.log ("[YYYY-MM-DD...")
	local line = read_first_line("/var/log/pacman.log")
	local dt = line and line:match("^%[(%d%d%d%d%-%d%d%-%d%d)")
	if dt and dt ~= "" then
		static.inst_dt = dt
		return static.inst_dt
	end
	-- Ubuntu / Debian: dpkg.log ("YYYY-MM-DD ...")
	line = read_first_line("/var/log/dpkg.log")
	dt = line and line:match("^(%d%d%d%d%-%d%d%-%d%d)")
	if dt and dt ~= "" then
		static.inst_dt = dt
		return static.inst_dt
	end
	-- Fallback: /etc/machine-id timestamp via lfs
	if lfs then
		local mtime = lfs.attributes("/etc/machine-id", "modification")
		if mtime then
			static.inst_dt = os.date("%Y-%m-%d", mtime)
			return static.inst_dt
		end
	end
	static.inst_dt = "N/A"
	return static.inst_dt
end

function conky_os_name()
	return cached("os_pretty_name", 86400, function()
		local osrel = read_file("/etc/os-release")
		local name = osrel:match('PRETTY_NAME="([^"]+)"') or osrel:match("PRETTY_NAME=([^\n]+)")
		return (name and name ~= "") and name or "Linux"
	end)
end

function conky_desktop_session()
	return cached("desktop_session_str", 3600, function()
		local de = os.getenv("XDG_SESSION_DESKTOP")
			or os.getenv("DESKTOP_SESSION")
			or os.getenv("XDG_CURRENT_DESKTOP")
			or ""
		de = de:match("([^/]+)$") or de
		de = de:gsub("%.desktop$", "")
		local st = os.getenv("XDG_SESSION_TYPE") or ""
		if de ~= "" and st ~= "" then
			return de .. "/" .. st
		end
		return (de ~= "" and de) or (st ~= "" and st) or "N/A"
	end)
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
