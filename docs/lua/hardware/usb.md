# 22 — hardware_usb.lua

## Purpose
Detects mounted USB storage devices.

## Dependencies
- `14_hardware_core` (for `cached`, `pread`, `starts_with`, `get_root_device`)

## Functions
| Function | Description |
|----------|-------------|
| `conky_usb_list()` | List of USB devices `{ name, part, mount }` |
| `conky_has_usb()` | 1 if any USB device is mounted |
| `conky_usb_count()` | Number of USB devices |
| `conky_usb_name(i)` | Device name by index |
| `conky_usb_mount(i)` | Mount point by index |
