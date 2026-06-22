#!/usr/bin/env lua

local function get_root()
  local src = (debug.getinfo(1, 'S').source or arg[0]):match('@(.*)') or arg[0] or '.'
  local dir = src:match('^(.*[/\\])') or './'
  local p = io.popen('readlink -f "'..dir..'../" 2>/dev/null')
  local out = p and (p:read('*a') or ''):gsub('%s+$','') or dir..'../'
  if p then p:close() end
  return out
end
local root = get_root()
JSON_PATH = root .. '/tmp/'
os.setlocale('hu_HU.UTF-8', 'time')
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/?.lua'

lfs = require('lfs')
json = require('dkjson')
require('weather_core')
require('weather_current')
require('weather_hourly')
require('weather_air')

local t = os.clock()
print('=== AIR QUALITY CURRENT ===')
print('conky_air_current_pm10:', conky_air_current_pm10())
print('conky_air_current_pm25:', conky_air_current_pm25())
print('conky_air_current_co:', conky_air_current_co())
print('conky_air_current_o3:', conky_air_current_o3())
print('conky_air_current_no2:', conky_air_current_no2())
print('conky_air_current_so2:', conky_air_current_so2())
print('conky_air_current_dust:', conky_air_current_dust())
print('conky_air_current_eaqi:', conky_air_current_eaqi())
print('conky_air_current_usaqi:', conky_air_current_usaqi())
print('conky_air_current_alder:', conky_air_current_alder())
print('conky_air_current_birch:', conky_air_current_birch())
print('conky_air_current_grass:', conky_air_current_grass())
print('conky_air_current_mugwort:', conky_air_current_mugwort())
print('conky_air_current_olive:', conky_air_current_olive())
print('conky_air_current_ragweed:', conky_air_current_ragweed())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))

print('\n=== AIR QUALITY HOURLY ===')
t = os.clock()
for i = 1, 3 do
  print(string.format('--- hour %d ---', i))
  print('  pm10:', conky_air_hour_pm10(i))
  print('  pm25:', conky_air_hour_pm25(i))
  print('  co:', conky_air_hour_co(i))
  print('  o3:', conky_air_hour_o3(i))
  print('  no2:', conky_air_hour_no2(i))
  print('  so2:', conky_air_hour_so2(i))
  print('  dust:', conky_air_hour_dust(i))
  print('  eaqi:', conky_air_hour_eaqi(i))
  print('  usaqi:', conky_air_hour_usaqi(i))
end
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
