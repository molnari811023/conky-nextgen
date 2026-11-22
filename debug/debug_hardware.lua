#!/usr/bin/env lua
--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--[[[
debug/debug_hardware.lua — standalone debug script that dumps the hardware
information layer (package updates, DMI, CPU, sensors, battery, network, MTP,
USB) with per-section timing

Run it directly with the system lua interpreter from the project root:
`lua debug/debug_hardware.lua`. It stubs out the Conky environment, loads the
hardware modules, then prints the result of every accessor grouped by theme
with section timings.
]]--

--{{{
-- ## Hardware data dump
--
-- Loads the hardware module tree (core, dmi, info, arch, ubuntu, sensors,
-- battery, network, mtp, usb) outside of Conky and prints each exported
-- accessor through a recursive dump() helper, so nested tables are
-- pretty-printed too. Every section is bracketed by a timing helper that
-- reports elapsed milliseconds.
--
-- **What it does:**
-- - Bootstraps the Conky stubs and config globals using pure Lua/LFS paths.
-- - CORE: dumps conky_updates_repo() and conky_updates_aur().
-- - DMI: dumps vendor/product/board/bios/chassis accessors.
-- - INFO: dumps OS name, desktop session, CPU name/count, NVMe model,
--   install date and formatted uptime.
-- - ARCH / UBUNTU: dumps distro-specific package and install-date accessors.
-- - SENSORS: dumps CPU/core temps, NVMe and Wi-Fi temps, fan speeds.
-- - BATTERY: dumps battery path, percent, status, remaining time, health
--   data, headset/mouse info and the external battery list.
-- - NETWORK: dumps Wi-Fi and Ethernet interface/state, active interface,
--   public IP/city/country and ping stats.
-- - MTP: dumps MTP device count, data and storage usage percentage.
-- - USB: dumps USB present/count/list plus per-entry name and mount.
-- - Prints TOTAL elapsed time.
--}}}

lfs = require('lfs')

local function get_root()
  local src = (debug.getinfo(1, 'S').source or arg[0]):match('@(.*)') or arg[0] or '.'
  local dir = src:match('^(.*[/\\])') or './'
  local cwd = lfs.currentdir()
  if lfs.chdir(dir .. '..') then
    local r = lfs.currentdir()
    lfs.chdir(cwd)
    return r
  end
  return cwd
end
local root = get_root()
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/lua/core/?.lua;' .. root .. '/lua/hardware/?.lua;' .. root .. '/lua/weather/?.lua;' .. root .. '/lua/icloud/?.lua'

-- Conky stubs (data modules only touch these; nothing is swallowed)
conky_parse = function(s) return s end
conky_window = { width = 420, height = 1020 }
conky_log = function() end

-- Config globals — formerly from settings.lua / the top of widget.lua.
-- widget.lua now also runs the Conky bootstrap (require("require") loads the
-- Cairo draw modules), so it cannot be loaded here; set the paths directly.
script_dir      = root .. '/'
JSON_PATH       = script_dir .. 'tmp/'
ICON_BASE       = script_dir .. 'icons/'
ICON_THEME      = 'default'
XDG_ICON_THEME  = 'Papirus'
MOON_ICON_BASE  = script_dir .. 'icons/moon/'
WIND_ICON_BASE  = script_dir .. 'icons/wind/'
json = require('dkjson')

require('core.utils')
require('core.translate')
require('hardware.core')
require('hardware.dmi')
require('hardware.info')
require('hardware.arch')
require('hardware.ubuntu')
require('hardware.sensors')
require('hardware.battery')
require('hardware.network')
require('hardware.mtp')
require('hardware.usb')
require('hardware.iphone')
require('hardware.tether')
require('icloud.core')
require('icloud.data')

local function dump(t, indent)
  indent = indent or 0
  if type(t) ~= 'table' then return tostring(t) end
  local lines = {}
  for k, v in pairs(t) do
    lines[#lines + 1] = string.format('%s=%s', tostring(k), dump(v, indent + 2))
  end
  return '{' .. table.concat(lines, ', ') .. '}'
end

local t0 = os.clock()
local function sec(name)
  print()
  print('=== ' .. name .. ' ===')
  local t = os.clock()
  return function()
    print(string.format('[%.3fms]', (os.clock() - t) * 1000))
  end
end

local done = sec('CORE')
print('conky_updates_repo():', dump(conky_updates_repo()))
print('conky_updates_aur():',  dump(conky_updates_aur()))
done()

done = sec('DMI')
for _, f in ipairs({
  'conky_sys_vendor', 'conky_product_name', 'conky_product_family',
  'conky_product_sku', 'conky_board_name', 'conky_board_vendor',
  'conky_board_version', 'conky_bios_vendor', 'conky_bios_version',
  'conky_bios_date', 'conky_bios_release', 'conky_chassis_vendor',
  'conky_chassis_type', 'conky_chassis_type_human',
}) do
  print(f .. '():', dump(_G[f]()))
end
done()

done = sec('INFO')
print('conky_os_name():', dump(conky_os_name()))
print('conky_desktop_session():', dump(conky_desktop_session()))
print('conky_cpu_name():', dump(conky_cpu_name()))
print('conky_cpu_count():', dump(conky_cpu_count()))
print('conky_nvme_model():', dump(conky_nvme_model()))
print('conky_install_date():', dump(conky_install_date()))
print('conky_uptime_fmt():', dump(conky_uptime_fmt()))
done()

done = sec('ARCH / UBUNTU')
print('conky_install_date_arch():', dump(conky_install_date_arch()))
print('conky_packages_arch():', dump(conky_packages_arch()))
print('conky_install_date_ubuntu():', dump(conky_install_date_ubuntu()))
print('conky_packages_ubuntu():', dump(conky_packages_ubuntu()))
print('conky_ubuntu_release():', dump(conky_ubuntu_release()))
done()

done = sec('SENSORS')
print('conky_cpu_temp():', dump(conky_cpu_temp()))
for i = 0, 5 do
  print('conky_cpu_core_temp(' .. i .. '):', dump(conky_cpu_core_temp(i)))
end
print('conky_nvme_temp():', dump(conky_nvme_temp()))
print('conky_wifi_temp():', dump(conky_wifi_temp()))
for i = 1, 3 do
  print('conky_fan_speed(' .. i .. '):', dump(conky_fan_speed(i)))
end
done()

done = sec('BATTERY')
print('conky_battery_path():', dump(conky_battery_path()))
print('conky_battery_percent():', dump(conky_battery_percent()))
print('conky_battery_status():', dump(conky_battery_status()))
print('conky_battery_time():', dump(conky_battery_time()))
print('conky_battery_health_data():', dump(conky_battery_health_data()))
print('conky_headset_info():', dump(conky_headset_info()))
print('conky_mouse_info():', dump(conky_mouse_info()))
print('conky_external_battery_list():', dump(conky_external_battery_list()))
print('conky_external_battery_count():', dump(conky_external_battery_count()))
for i = 1, conky_external_battery_count() or 0 do
  print('conky_external_battery_name(' .. i .. '):', dump(conky_external_battery_name(i)))
  print('conky_external_battery_charge(' .. i .. '):', dump(conky_external_battery_charge(i)))
end
done()

done = sec('NETWORK')
print('conky_wifi_interface():', dump(conky_wifi_interface()))
print('conky_wifi_active():', dump(conky_wifi_active()))
print('conky_ethernet_interface():', dump(conky_ethernet_interface()))
print('conky_ethernet_active():', dump(conky_ethernet_active()))
print('conky_active_iface():', dump(conky_active_iface()))
print('conky_public_ip():', dump(conky_public_ip()))
print('conky_public_city():', dump(conky_public_city()))
print('conky_public_country():', dump(conky_public_country()))
print('conky_ping_avg():', dump(conky_ping_avg()))
print('conky_ping_jitter():', dump(conky_ping_jitter()))
done()

done = sec('MTP')
print('conky_mtp_count():', dump(conky_mtp_count()))
print('conky_mtp_data():', dump(conky_mtp_data()))
print('conky_mtp_perc(1, 1):', dump(conky_mtp_perc(1, 1)))
done()

done = sec('USB')
print('conky_has_usb():', dump(conky_has_usb()))
print('conky_usb_count():', dump(conky_usb_count()))
print('conky_usb_list():', dump(conky_usb_list()))
for i = 1, 3 do
  print('conky_usb_name(' .. i .. '):', dump(conky_usb_name(i)))
  print('conky_usb_mount(' .. i .. '):', dump(conky_usb_mount(i)))
end
done()

done = sec('IPHONE (USB / SYSFS / LIBIMOBILEDEVICE / GVFS)')
print('conky_iphone_count():', dump(conky_iphone_count()))
print('conky_iphone_list():', dump(conky_iphone_list()))
print('iphone_is_connected(1):', dump(iphone_is_connected(1)))
print('iphone_is_connected(2):', dump(iphone_is_connected(2)))
print('conky_iphone_is_connected(1):', dump(conky_iphone_is_connected(1)))
print('iphone_is_paired(1):', dump(iphone_is_paired(1)))
print('conky_iphone_port(1):', dump(conky_iphone_port(1)))
print('get_iphone_usb_path(1):', dump(get_iphone_usb_path(1)))
print('conky_iphone_udid(1):', dump(conky_iphone_udid(1)))
print('conky_iphone_serial(1):', dump(conky_iphone_serial(1)))
print('conky_iphone_name(1):', dump(conky_iphone_name(1)))
print('conky_iphone_product_type(1):', dump(conky_iphone_product_type(1)))
print('conky_iphone_model(1):', dump(conky_iphone_model(1)))
print('conky_iphone_model_number(1):', dump(conky_iphone_model_number(1)))
print('conky_iphone_hw_model(1):', dump(conky_iphone_hw_model(1)))
print('conky_iphone_cpu_arch(1):', dump(conky_iphone_cpu_arch(1)))
print('conky_iphone_ios_version(1):', dump(conky_iphone_ios_version(1)))
print('conky_iphone_build_version(1):', dump(conky_iphone_build_version(1)))
print('conky_iphone_ios_full(1):', dump(conky_iphone_ios_full(1)))
print('conky_iphone_imei(1):', dump(conky_iphone_imei(1)))
print('conky_iphone_phone_number(1):', dump(conky_iphone_phone_number(1)))
print('conky_iphone_sim_status(1):', dump(conky_iphone_sim_status(1)))
print('conky_iphone_wifi_mac(1):', dump(conky_iphone_wifi_mac(1)))
print('conky_iphone_bt_mac(1):', dump(conky_iphone_bt_mac(1)))
print('conky_iphone_usb_speed(1):', dump(conky_iphone_usb_speed(1)))
print('conky_iphone_usb_version(1):', dump(conky_iphone_usb_version(1)))
print('conky_iphone_usb_max_power(1):', dump(conky_iphone_usb_max_power(1)))
print('conky_iphone_usb_power_status(1):', dump(conky_iphone_usb_power_status(1)))
print('conky_iphone_connected_time(1):', dump(conky_iphone_connected_time(1)))
print('conky_iphone_charge_type(1):', dump(conky_iphone_charge_type(1)))
print('iphone_is_fastcharging(1):', dump(iphone_is_fastcharging(1)))
print('conky_iphone_battery_perc(1):', dump(conky_iphone_battery_perc(1)))
print('iphone_is_charging(1):', dump(iphone_is_charging(1)))
print('conky_iphone_battery_status(1):', dump(conky_iphone_battery_status(1)))
print('conky_iphone_battery_cycles(1):', dump(conky_iphone_battery_cycles(1)))
print('conky_iphone_battery_design_cap(1):', dump(conky_iphone_battery_design_cap(1)))
print('conky_iphone_battery_full_cap(1):', dump(conky_iphone_battery_full_cap(1)))
print('conky_iphone_battery_health(1):', dump(conky_iphone_battery_health(1)))
print('conky_iphone_battery_temp(1):', dump(conky_iphone_battery_temp(1)))
print('conky_iphone_battery_voltage(1):', dump(conky_iphone_battery_voltage(1)))
print('conky_iphone_battery_current(1):', dump(conky_iphone_battery_current(1)))
print('conky_iphone_charger_watts(1):', dump(conky_iphone_charger_watts(1)))
print('conky_iphone_storage_total_gb(1):', dump(conky_iphone_storage_total_gb(1)))
print('conky_iphone_storage_used_gb(1):', dump(conky_iphone_storage_used_gb(1)))
print('conky_iphone_storage_free_gb(1):', dump(conky_iphone_storage_free_gb(1)))
print('conky_iphone_storage_perc(1):', dump(conky_iphone_storage_perc(1)))
print('conky_iphone_apps_count(1):', dump(conky_iphone_apps_count(1)))
print('conky_iphone_tether_iface(1):', dump(conky_iphone_tether_iface(1)))
print('iphone_tether_active(1):', dump(iphone_tether_active(1)))
print('conky_iphone_tether_state(1):', dump(conky_iphone_tether_state(1)))
print('conky_iphone_tether_mac(1):', dump(conky_iphone_tether_mac(1)))
print('conky_iphone_tether_rx(1):', dump(conky_iphone_tether_rx(1)))
print('conky_iphone_tether_rx_unit(1):', dump(conky_iphone_tether_rx_unit(1)))
print('conky_iphone_tether_tx(1):', dump(conky_iphone_tether_tx(1)))
print('conky_iphone_tether_tx_unit(1):', dump(conky_iphone_tether_tx_unit(1)))
print('conky_iphone_mount_path(1):', dump(conky_iphone_mount_path(1)))
print('conky_iphone_mount_type(1):', dump(conky_iphone_mount_type(1)))
print('conky_iphone_gvfs_path(1):', dump(conky_iphone_gvfs_path(1)))
print('iphone_is_mounted(1):', dump(iphone_is_mounted(1)))
done()

done = sec('TETHER (DAEMON / BLUETOOTH / CONTINUITY)')
print('tether_running():', dump(tether_running()))
print('tether_bt_connected():', dump(tether_bt_connected()))
print('conky_tether_bt_name():', dump(conky_tether_bt_name()))
print('conky_tether_bt_mac():', dump(conky_tether_bt_mac()))
print('conky_tether_battery_perc():', dump(conky_tether_battery_perc()))
print('tether_wifi_connected():', dump(tether_wifi_connected()))
print('tether_le_connected():', dump(tether_le_connected()))
print('iphone_any_connected(1):', dump(iphone_any_connected(1)))
print('conky_tether_conn_type(1):', dump(conky_tether_conn_type(1)))
print('conky_tether_wifi_ip():', dump(conky_tether_wifi_ip()))
print('tether_clipboard_sync():', dump(tether_clipboard_sync()))
print('tether_ancs_active():', dump(tether_ancs_active()))
print('tether_map_active():', dump(tether_map_active()))
print('tether_pbap_active():', dump(tether_pbap_active()))
print('conky_tether_notifications_count():', dump(conky_tether_notifications_count()))
print('conky_tether_last_notif_app(1):', dump(conky_tether_last_notif_app(1)))
print('conky_tether_last_notif_title(1):', dump(conky_tether_last_notif_title(1)))
print('conky_tether_threads_count():', dump(conky_tether_threads_count()))
print('conky_tether_unread_messages():', dump(conky_tether_unread_messages()))
print('conky_tether_msg_sender(1):', dump(conky_tether_msg_sender(1)))
print('conky_tether_msg_time(1):', dump(conky_tether_msg_time(1)))
print('conky_tether_msg_preview(1):', dump(conky_tether_msg_preview(1)))
print('conky_tether_operator():', dump(conky_tether_operator()))
print('conky_tether_signal_bars():', dump(conky_tether_signal_bars()))
print('conky_tether_active_calls():', dump(conky_tether_active_calls()))
print('conky_tether_call_history_count():', dump(conky_tether_call_history_count()))
print('conky_tether_missed_calls_count():', dump(conky_tether_missed_calls_count()))
print('conky_tether_last_call_name(1):', dump(conky_tether_last_call_name(1)))
print('conky_tether_last_call_type(1):', dump(conky_tether_last_call_type(1)))
print('conky_tether_last_call_time(1):', dump(conky_tether_last_call_time(1)))
print('conky_tether_contacts_count():', dump(conky_tether_contacts_count()))
print('conky_tether_contact_name(1):', dump(conky_tether_contact_name(1)))
print('conky_tether_contact_phone(1):', dump(conky_tether_contact_phone(1)))
print('tether_airpods_connected():', dump(tether_airpods_connected()))
print('conky_tether_airpods_name():', dump(conky_tether_airpods_name()))
print('conky_tether_airpods_left():', dump(conky_tether_airpods_left()))
print('conky_tether_airpods_right():', dump(conky_tether_airpods_right()))
print('conky_tether_airpods_case():', dump(conky_tether_airpods_case()))
done()

print()
print(string.format('TOTAL: [%.3fms]', (os.clock() - t0) * 1000))
