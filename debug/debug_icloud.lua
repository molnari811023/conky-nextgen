#!/usr/bin/env lua
--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--[=[
debug/debug_icloud.lua — standalone debug script that dumps the Apple iCloud
data layer (Storage quota & media breakdown, Find My devices, GPS coordinates,
reverse-geocoded street address, OSM street mini-map, Calendar & Reminders).

Run it directly with the system lua interpreter from the project root:
`lua debug/debug_icloud.lua`.
]=]

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

conky_parse = function(s) return s end
conky_window = { width = 420, height = 1020 }
conky_log = function() end

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
require('icloud.core')
require('icloud.data')

local t0 = os.clock()
print('=== ICLOUD STATUS & ACCOUNT ===')
print('conky_icloud_status():', conky_icloud_status())
print('conky_icloud_error():', conky_icloud_error())
print('conky_icloud_apple_id():', conky_icloud_apple_id())
print('conky_icloud_updated():', conky_icloud_updated())
print('conky_icloud_map_path():', conky_icloud_map_path())

print('\n=== ICLOUD STORAGE ===')
print('conky_icloud_storage_total_gb():', conky_icloud_storage_total_gb())
print('conky_icloud_storage_used_gb():', conky_icloud_storage_used_gb())
print('conky_icloud_storage_free_gb():', conky_icloud_storage_free_gb())
print('conky_icloud_storage_perc():', conky_icloud_storage_perc())
print('conky_icloud_media_count():', conky_icloud_media_count())
for i = 1, conky_icloud_media_count() do
  print(string.format('  [%d] %s (%s): %s | %s | %d%% | %s',
    i,
    conky_icloud_media_label(i),
    conky_icloud_media_key(i),
    conky_icloud_media_gb(i),
    conky_icloud_media_size(i),
    conky_icloud_media_perc(i),
    conky_icloud_media_color(i)
  ))
end

print('\n=== FIND MY DEVICES & GPS ADDRESS ===')
print('conky_icloud_device_count():', conky_icloud_device_count())
for i = 1, math.max(1, conky_icloud_device_count()) do
  print(string.format('  [%d] %s | %s (%s) | batt=%d%% (%s)',
    i,
    conky_icloud_device_name(i),
    conky_icloud_device_model(i),
    conky_icloud_device_class(i),
    conky_icloud_device_battery(i),
    conky_icloud_device_battery_status(i)
  ))
  print(string.format('      GPS: lat=%s lon=%s acc=%s (%s) updated=%s',
    tostring(conky_icloud_loc_lat(i)),
    tostring(conky_icloud_loc_lon(i)),
    tostring(conky_icloud_loc_accuracy(i)),
    conky_icloud_loc_type(i),
    conky_icloud_loc_updated(i)
  ))
  print(string.format('      Address: country=%s | postcode=%s | city=%s | district=%s | street=%s | nr=%s',
    conky_icloud_loc_country(i),
    conky_icloud_loc_postcode(i),
    conky_icloud_loc_city(i),
    conky_icloud_loc_district(i),
    conky_icloud_loc_street(i),
    conky_icloud_loc_house_number(i)
  ))
  print(string.format('      Formatted: street_full="%s" | short="%s"',
    conky_icloud_loc_street_full(i),
    conky_icloud_loc_short(i)
  ))
end

print('\n=== ICLOUD CALENDAR & REMINDERS ===')
print('conky_icloud_calendar_count():', conky_icloud_calendar_count())
for i = 1, math.min(5, conky_icloud_calendar_count()) do
  print(string.format('  [cal %d] %s | %s -> %s | %s',
    i,
    conky_icloud_calendar_title(i),
    conky_icloud_calendar_start(i),
    conky_icloud_calendar_end(i),
    conky_icloud_calendar_location(i)
  ))
end
print('conky_icloud_reminders_count():', conky_icloud_reminders_count())
for i = 1, math.min(5, conky_icloud_reminders_count()) do
  print(string.format('  [rem %d] [%s] %s (due: %s)',
    i,
    conky_icloud_reminder_list(i),
    conky_icloud_reminder_title(i),
    conky_icloud_reminder_due(i)
  ))
end

print(string.format('\n[TOTAL %.3fms]', (os.clock() - t0) * 1000))
