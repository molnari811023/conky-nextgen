# 23 — hardware_processes.lua

## Purpose
Provides `conky_top_*` functions for process monitoring. Uses the LPEG-based scanner from module 13 if available, falls back to Conky's built-in `${top name}` / `${top_mem name}`.

## Dependencies
- `13_processes` (optional, used if available)

## Functions
| Function | Description |
|----------|-------------|
| `conky_top_cpu_name(i)` | Process name by CPU rank |
| `conky_top_cpu_pid(i)` | PID |
| `conky_top_cpu_cpu(i)` | CPU usage (%) |
| `conky_top_cpu_mem(i)` | Memory usage (%) |
| `conky_top_cpu_vmrss(i)` | RSS memory (KiB/GiB) |
| `conky_top_mem_name(i)` | Process name by memory rank |
| `conky_top_mem_pid(i)` | PID |
| `conky_top_mem_cpu(i)` | CPU usage |
| `conky_top_mem_mem(i)` | Memory usage |
| `conky_top_mem_vmrss(i)` | RSS memory |
