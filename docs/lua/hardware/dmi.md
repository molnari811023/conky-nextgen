# 16 — hardware_dmi.lua

## Purpose
System DMI information: vendor, product, board, BIOS, chassis.

## Dependencies
- `14_hardware_core` (for `dmi`, `chassis_map`)

## Functions
| Function | Returns |
|----------|---------|
| `conky_sys_vendor()` | System vendor |
| `conky_product_name()` | Product name |
| `conky_product_family()` | Product family |
| `conky_product_sku()` | Product SKU |
| `conky_board_name()` | Motherboard name |
| `conky_board_vendor()` | Motherboard vendor |
| `conky_board_version()` | Motherboard version |
| `conky_bios_vendor()` | BIOS vendor |
| `conky_bios_version()` | BIOS version |
| `conky_bios_date()` | BIOS date |
| `conky_bios_release()` | BIOS release |
| `conky_chassis_vendor()` | Chassis vendor |
| `conky_chassis_type()` | Chassis type code |
| `conky_chassis_type_human()` | Chassis type description |
