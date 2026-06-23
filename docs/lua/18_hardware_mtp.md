# 18 — hardware_mtp.lua

## Purpose
Detects MTP devices (phones, tablets) via KDE KIO or GVFS.

## Dependencies
- `14_hardware_core` (for `cached`, `pread`, `parse_num`)

## Functions
| Function | Description |
|----------|-------------|
| `conky_mtp_data()` | Device list (auto-detects KDE vs GVFS) |
| `conky_mtp_count()` | Number of MTP devices |
| `conky_mtp_perc(dev_idx, storage_idx)` | Storage usage % |

## Notes
- On KDE Plasma: uses `qdbus6` to query `kmtpd`
- On other DEs: uses `gio` (GVFS) to detect MTP mounts
- Caches for 5 seconds
