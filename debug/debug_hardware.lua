#!/usr/bin/env lua

--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- debug_hardware.lua — Standalone debug dump for the hardware modules.
-- Run:  lua debug/debug_hardware.lua   (from the repo root or anywhere)
--}}}

local function get_root()
  local src = (debug.getinfo(1, 'S').source or arg[0]):match('@(.*)') or arg[0] or '.'
  local dir = src:match('^(.*[/\\])') or './'
  local p = io.popen('readlink -f "'..dir..'../" 2>/dev/null')
  local out = p and (p:read('*a') or ''):gsub('%s+$','') or dir..'../'
  if p then p:close() end
  return out
end
local root = get_root()
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/lua/core/?.lua;' .. root .. '/lua/hardware/?.lua;' .. root .. '/lua/weather/?.lua'

-- Conky stubs (data modules only touch these; nothing is swallowed)
conky_parse = function(s) return s end
conky_window = { width = 420, height = 1020 }
conky_log = function() end

lfs = require('lfs')
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
require('hardware.core')     -- cached()/pread() helpers first
require('hardware.dmi')
require('hardware.info')
require('hardware.sensors')
require('hardware.battery')
require('hardware.network')
require('hardware.mtp')
require('hardware.usb')

-- Replica of battery.lua's now-local helper, so this debug dump keeps
-- probing the internal battery path without depending on the module globals.
local function get_battery_path()
  return cached('main_battery_path', 3600, function()
    for entry in lfs.dir('/sys/class/power_supply') do
      if entry ~= '.' and entry ~= '..' then
        local t = read_file('/sys/class/power_supply/' .. entry .. '/type')
        if t and t:find('Battery') then
          return '/sys/class/power_supply/' .. entry .. '/'
        end
      end
    end
    return '/sys/class/power_supply/BAT0/'
  end)
end

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
print('conky_cpu_name():', dump(conky_cpu_name()))
print('conky_nvme_model():', dump(conky_nvme_model()))
print('conky_install_date():', dump(conky_install_date()))
done()

done = sec('SENSORS')
print('conky_cpu_temp():', dump(conky_cpu_temp()))
for i = 0, 3 do
  print('conky_cpu_core_temp(' .. i .. '):', dump(conky_cpu_core_temp(i)))
end
print('conky_nvme_temp():', dump(conky_nvme_temp()))
print('conky_wifi_temp():', dump(conky_wifi_temp()))
for i = 1, 3 do
  print('conky_fan_speed(' .. i .. '):', dump(conky_fan_speed(i)))
end
done()

done = sec('BATTERY')
print('get_battery_path():', dump(get_battery_path()))
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

print()
print(string.format('TOTAL: [%.3fms]', (os.clock() - t0) * 1000))
