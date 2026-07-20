# 17 — hardware_info.lua

## Purpose
CPU model, NVMe model, system install date.

## Dependencies
- `14_hardware_core` (for `cached`, `pread`, `read_file`)

## Functions
| Function | Description |
|----------|-------------|
| `conky_cpu_name()` | CPU model name (cleaned) |
| `conky_nvme_model()` | NVMe drive model |
| `conky_install_date()` | OS install date (from `/var/log/pacman.log`) |
