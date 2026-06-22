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
require('weather_sunmoon')
require('weather_daily')

local t = os.clock()
print('=== DAILY WEATHER ===')
for i = 1, 7 do
  print(string.format('--- day %d ---', i))
  print('  time:', conky_weather_day_time(i))
  print('  code:', conky_weather_day_code(i))
  print('  temp_max:', conky_weather_day_temp_max(i))
  print('  temp_min:', conky_weather_day_temp_min(i))
  print('  sunrise:', conky_weather_day_sunrise(i))
  print('  sunset:', conky_weather_day_sunset(i))
  print('  daylight:', conky_weather_day_daylight(i))
  print('  sunshine:', conky_weather_day_sunshine(i))
  print('  uv:', conky_weather_day_uv(i))
  print('  precip_hours:', conky_weather_day_precip_hours(i))
end
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
