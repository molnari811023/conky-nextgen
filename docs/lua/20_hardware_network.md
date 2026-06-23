# 20 — hardware_network.lua

## Purpose
WiFi interface detection, connection status, public IP (via ipinfo.io), ping stats.

## Dependencies
- `14_hardware_core` (for `cached`, `pread`, `read_file`)

## Functions
| Function | Description |
|----------|-------------|
| `conky_wifi_interface()` | Auto-detect wireless interface name |
| `conky_wifi_active()` | 1 if WiFi carrier is up |
| `conky_public_ip()` | Public IP address |
| `conky_public_city()` | Approximate city from IP |
| `conky_public_country()` | Country from IP |
| `conky_ping_avg()` | Average ping (ms, to 1.1.1.1) |
| `conky_ping_jitter()` | Ping jitter (max-min, ms) |
