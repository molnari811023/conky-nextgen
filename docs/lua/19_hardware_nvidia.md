# 19 — hardware_nvidia.lua

## Purpose
Detects NVIDIA GPU mode (via envycontrol) and reads GPU stats via `nvidia-smi` XML.

## Dependencies
- `14_hardware_core` (for XML cache: `xml_update`, `xml_find`, `xml_num`)

## Globals
| Name | Description |
|------|-------------|
| `GPU_MODE` | `"nvidia"`, `"intel"`, `"hybrid"`, or `"unknown"` |

## Functions
| Function | Description |
|----------|-------------|
| `conky_gpu_mode()` | GPU mode detection |
| `conky_nvidia_active()` | `"1"` if NVIDIA GPU active |
| `conky_intel_active()` | `"1"` if Intel only |
| `conky_update_nvidia_xml()` | Refresh `nvidia-smi` XML cache |

### GPU Stats
| Function | Returns |
|----------|---------|
| `conky_nv_gputemp()` | GPU temperature (°C) |
| `conky_nv_gpufreqcur()` | GPU clock (MHz) |
| `conky_nv_memfreqcur()` | Memory clock (MHz) |
| `conky_nv_gpuutil()` | GPU utilization (%) |
| `conky_nv_membwutil()` | Memory bandwidth util (%) |
| `conky_nv_videoutil()` | Video encoder util (%) |
| `conky_nv_memused()` | Used VRAM (MB) |
| `conky_nv_memfree()` | Free VRAM (MB) |
| `conky_nv_memmax()` | Total VRAM (MB) |
| `conky_nv_memutil()` | VRAM utilization (%) |
| `conky_nv_fanspeed()` | Fan speed (%) |
| `conky_nv_modelname()` | GPU model name |
| `conky_nv_driverversion()` | Driver version |
| `conky_nv_perflevelcur()` | Performance state |
