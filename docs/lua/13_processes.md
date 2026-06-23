# 13 — processes.lua

## Purpose
Scans `/proc` for process information: CPU usage, memory usage. Uses LPEG for fast parsing.

## Dependencies
- `lpeg` library

## Globals
| Name | Description |
|------|-------------|
| `procs.ttl` | Scan interval (seconds). Default: 0.5 |

## Functions
| Function | Description |
|----------|-------------|
| `procs.scan()` | Run scan (no-op if within TTL) |
| `procs.top_cpu(n)` | Top N processes by CPU usage |
| `procs.top_mem(n)` | Top N processes by memory usage |
| `procs.list()` | All processes sorted by CPU |
| `procs.total_mem_kb()` | Total system memory (kB) |

Each process entry: `{ pid, comm, cpu, mem, vmrss_kb }`
