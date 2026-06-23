# 15 — hardware_battery.lua

## Purpose
Battery health, wireless device battery (Bluetooth headset, mouse via UPower/KDE).

## Dependencies
- `14_hardware_core` (for `cached`, `pread`, `read_num`)

## Functions
| Function | Description |
|----------|-------------|
| `conky_battery_health_data()` | Battery wear level (%) |
| `conky_headset_info()` | Bluetooth headset battery |
| `conky_mouse_info()` | Mouse battery (Logitech HID++/UPower) |
| `conky_external_battery_list()` | All wireless devices with battery |
| `conky_external_battery_count()` | Number of wireless devices |
| `conky_external_battery_name(i)` | Device name by index |
| `conky_external_battery_charge(i)` | Device charge % by index |
| `get_battery_path()` | Auto-detect battery sysfs path |
| `is_plasma()` | Detect KDE Plasma environment |
