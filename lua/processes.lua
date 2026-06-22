local lpeg = require("lpeg")
local P, S, R, C, Ct, Cg = lpeg.P, lpeg.S, lpeg.R, lpeg.C, lpeg.Ct, lpeg.Cg

local digit = R("09")
local ws = S(" \t")^1
local token = C((1 - S(" \t\n"))^1)

-- /proc/<PID>/stat grammar
-- pid (comm) state ppid pgrp session tty_nr tpgid flags
-- minflt cminflt majflt cmajflt utime stime cutime cstime
-- priority nice num_threads itrealvalue starttime ...
local stat_g = Ct(
	Cg(C(digit^1) / tonumber, "pid") * ws *
	P("(") * Cg(C((1 - P(")"))^0), "comm") * P(")") * ws *
	Cg(Ct(token * (ws * token)^0), "rest")
)

local function parse_stat(data)
	local r = stat_g:match(data)
	if not r then return nil end
	local rest = r.rest
	local function n(i) return tonumber(rest[i]) end
	return {
		pid = r.pid,
		comm = r.comm,
		utime = n(12) or 0,
		stime = n(13) or 0,
		starttime = n(20) or 0,
		state = rest[1] or "",
	}
end

-- /proc/stat CPU line grammar
-- cpu  user nice system idle iowait irq softirq steal guest guest_nice
local cpu_line = P("cpu") * ws * Ct(C(digit^1) / tonumber * (ws * C(digit^1) / tonumber)^0)

local function parse_cpu_stat(data)
	local r = cpu_line:match(data)
	if not r or #r < 4 then return nil end
	local total = 0
	for _, v in ipairs(r) do total = total + v end
	return { user = r[1], nice = r[2], system = r[3], idle = r[4], total = total }
end

-- /proc/meminfo: "MemTotal:  num kB" (anywhere in file)
local memtotal_g = (1 - P("MemTotal:"))^0 * P("MemTotal:") * ws * C(digit^1) / tonumber

-- /proc/<PID>/status: "VmRSS:  num kB" (anywhere in file)
local vmrss_g = (1 - P("VmRSS:"))^0 * P("VmRSS:") * ws * C(digit^1) / tonumber

local function parse_vmrss(data)
	return vmrss_g:match(data) or 0
end

local has_lfs = type(lfs) == "table"
local SKIP_KERNEL_THREADS = true -- skip kernel threads whose comm starts with '['

local function list_pids()
	local pids = {}
	if has_lfs and lfs then
		local ok = pcall(function()
			for entry in lfs.dir("/proc") do
				local pid = tonumber(entry)
				if pid then pids[#pids + 1] = pid end
			end
		end)
		if ok then return pids end
	end
	local f = io.popen("ls /proc 2>/dev/null")
	if not f then return pids end
	for line in f:lines() do
		local pid = tonumber(line)
		if pid then pids[#pids + 1] = pid end
	end
	f:close()
	return pids
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

-- module state
local procs = {}
procs.ttl = 0.5            -- seconds between scans, user-configurable (uses os.clock)
local prev_sample = nil  -- { time = os.time(), total_cpu = N, processes = { [pid] = { utime, stime } } }
local cached_results = { cpu = {}, mem = {} } -- { cpu = {{pid, comm, cpu, mem}, ...}, mem = {{pid, comm, cpu, mem}, ...} }
local cached_total_mem = 0
local cached_time = 0    -- os.time() wall clock; 0 = first call always runs
local PROFILE_THRESHOLD = 0.5  -- seconds; log if scan exceeds this

function procs.scan()
	local t0 = os.clock()
	local now = os.time()
	if now - cached_time < procs.ttl then return end
	cached_time = now

	-- system-wide data
	local cpu_data = parse_cpu_stat(read_file("/proc/stat") or "")
	local meminfo_data = read_file("/proc/meminfo") or ""
	local total_mem_kb = memtotal_g:match(meminfo_data) or 0
	cached_total_mem = total_mem_kb
	if not cpu_data then
		cached_results = { cpu = {}, mem = {} }
		prev_sample = nil
		return
	end

	-- scan processes
	local current = { time = now, total_cpu = cpu_data.total, processes = {} }
	local entries = {}
	local pids = list_pids()

	for _, pid in ipairs(pids) do
		local stat_data = read_file("/proc/" .. pid .. "/stat")
		if stat_data then
			local p = parse_stat(stat_data)
			if p and p.state ~= "Z" and p.state ~= "X" and not (SKIP_KERNEL_THREADS and p.comm and p.comm:sub(1,1) == "[") then
				local vmrss = 0
				local status_data = read_file("/proc/" .. pid .. "/status")
				if status_data then
					vmrss = parse_vmrss(status_data)
				end
				current.processes[pid] = { utime = p.utime, stime = p.stime, starttime = p.starttime }
				local cpu_pct = 0
				if prev_sample then
					local prev_p = prev_sample.processes[pid]
					if prev_p then
						local proc_delta = (p.utime - prev_p.utime) + (p.stime - prev_p.stime)
						local total_delta = cpu_data.total - prev_sample.total_cpu
						if total_delta > 0 then
							cpu_pct = (proc_delta / total_delta) * 100
						end
				end
			end
				local mem_pct = 0
				if total_mem_kb > 0 then
					mem_pct = (vmrss / total_mem_kb) * 100
				end
			entries[#entries + 1] = {
				pid = pid,
				comm = p.comm,
				cpu = math.floor(cpu_pct * 100 + 0.5) / 100,
				mem = math.floor(mem_pct * 100 + 0.5) / 100,
				vmrss_kb = vmrss,
			}
			end
		end
	end

	-- sort by cpu desc
	table.sort(entries, function(a, b) return a.cpu > b.cpu end)
	local cpu_top = {}
	for i = 1, #entries do
		cpu_top[i] = entries[i]
	end

	-- sort by mem desc
	table.sort(entries, function(a, b) return a.mem > b.mem end)
	local mem_top = {}
	for i = 1, #entries do
		mem_top[i] = entries[i]
	end

	cached_results = { cpu = cpu_top, mem = mem_top }
	prev_sample = current
	local elapsed = os.clock() - t0
	if elapsed > PROFILE_THRESHOLD then
		io.stderr:write(string.format("[procs] scan took %.3fs (%d pids, %d entries)\n", elapsed, #pids, #entries))
	end
end

function procs.top_cpu(n)
	procs.scan()
	n = n or 10
	local out = {}
	for i = 1, math.min(n, #cached_results.cpu) do
		out[i] = cached_results.cpu[i]
	end
	return out
end

function procs.top_mem(n)
	procs.scan()
	n = n or 10
	local out = {}
	for i = 1, math.min(n, #cached_results.mem) do
		out[i] = cached_results.mem[i]
	end
	return out
end

function procs.list()
	procs.scan()
	return cached_results.cpu
end

function procs.total_mem_kb()
	return cached_total_mem
end

return procs
