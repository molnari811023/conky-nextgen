# 21 — hardware_sensors.lua

## Purpose
Reads hardware sensor data via `lm-sensors`.

## Dependencies
- `14_hardware_core` (for `cached`, `pread`, `get_sensor_val`)

## Functions
| Function | Returns |
|----------|---------|
| `conky_cpu_temp()` | CPU package temperature |
| `conky_cpu_core_temp(core)` | Specific core temperature |
| `conky_nvme_temp()` | NVMe SSD temperature |
| `conky_wifi_temp()` | WiFi chipset temperature |
| `conky_fan_speed(index)` | Fan speed (RPM) |
