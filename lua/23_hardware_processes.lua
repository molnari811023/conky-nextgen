--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 23_hardware_processes.lua — Top CPU/mem process list for Conky
-- Uses 13_processes if available, falls back to ${top} parsing.
local processes_ok, processes = pcall(require, "processes")
if not processes_ok then processes = nil end

local function top_val(which, i, field, fallback)
	if not processes then
		return fallback
	end
	local top = which(i)
	return (top[i] and top[i][field]) or fallback
end

function conky_top_cpu_name(i)
	if not processes then
		local raw = conky_parse(string.format("${top name %d}", i))
		return (raw and raw ~= "") and (raw:match("([^/]+)$") or raw) or "N/A"
	end
	local top = processes.top_cpu(i)
	return (top[i] and top[i].comm) or "N/A"
end

function conky_top_cpu_pid(i)
	return top_val(processes.top_cpu, i, "pid", 0)
end

function conky_top_cpu_cpu(i)
	return top_val(processes.top_cpu, i, "cpu", 0)
end

function conky_top_cpu_mem(i)
	return top_val(processes.top_cpu, i, "mem", 0)
end

function conky_top_mem_name(i)
	if not processes then
		local raw = conky_parse(string.format("${top_mem name %d}", i))
		return (raw and raw ~= "") and (raw:match("([^/]+)$") or raw) or "N/A"
	end
	local top = processes.top_mem(i)
	return (top[i] and top[i].comm) or "N/A"
end

function conky_top_mem_pid(i)
	return top_val(processes.top_mem, i, "pid", 0)
end

function conky_top_mem_cpu(i)
	return top_val(processes.top_mem, i, "cpu", 0)
end

function conky_top_mem_mem(i)
	return top_val(processes.top_mem, i, "mem", 0)
end

local function fmt_mem_kb(kb)
	if not kb then return "0 KiB" end
	if kb >= 1000 then
		return string.format("%.2f GiB", kb / 1048576)
	end
	return kb .. " KiB"
end

function conky_top_mem_vmrss(i)
	if not processes then return "" end
	local top = processes.top_mem(i)
	return (top[i] and fmt_mem_kb(top[i].vmrss_kb)) or ""
end

function conky_top_cpu_vmrss(i)
	if not processes then return "" end
	local top = processes.top_cpu(i)
	return (top[i] and fmt_mem_kb(top[i].vmrss_kb)) or ""
end
--}}}
