# 14 — hardware_core.lua

## Purpose
Core utilities for all hardware modules: shell commands, file reads, caching, DMI, chassis map, NVIDIA XML parsing.

## Globals
| Name | Description |
|------|-------------|
| `static` | Persistent data table |

## Functions

### Utilities
| Function | Description |
|----------|-------------|
| `parse_num(v)` | Extract number from string |
| `starts_with(str, prefix)` | String prefix check |
| `dmi(field)` | Read DMI field from `/sys/class/dmi/id/` |
| `get_sensor_val(pattern)` | Parse sensor output with regex |
| `get_root_device(map, name)` | Walk device tree to find root |

### Cache
| Function | Description |
|----------|-------------|
| `cached(key, interval, f)` | Cache function result with TTL |

### System Calls
| Function | Description |
|----------|-------------|
| `pread(cmd)` | Run shell command (10s timeout) |
| `read_file(path)` | Read file content |
| `read_num(path)` | Read number from file |
| `has_cmd(cmd)` | Check if command exists |

### NVIDIA XML Cache
| Function | Description |
|----------|-------------|
| `xml_update(cmd, interval)` | Update XML cache |
| `xml_find(tag)` | Extract tag from cached XML |
| `xml_num(tag)` | Extract numeric value from tag |

### Updates
| Function | Description |
|----------|-------------|
| `conky_updates_repo()` | Repo package update count |
| `conky_updates_aur()` | AUR package update count |

Reads from `tmp/updates.txt` (written by `sh/updates.sh`).
