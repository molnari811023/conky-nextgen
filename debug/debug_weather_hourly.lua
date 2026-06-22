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

local t = os.clock()
print('=== HOURLY WEATHER ===')
for i = 1, 6 do
  print(string.format('--- hour %d ---', i))
  print('  time:', conky_weather_hour_time(i))
  print('  temp:', conky_weather_hour_temp(i))
  print('  humidity:', conky_weather_hour_humidity(i))
  print('  dewpoint:', conky_weather_hour_dewpoint(i))
  print('  apparent:', conky_weather_hour_apparent(i))
  print('  precip_prob:', conky_weather_hour_precip_prob(i))
  print('  precip:', conky_weather_hour_precip(i))
  print('  snow:', conky_weather_hour_snow(i))
  print('  code:', conky_weather_hour_code(i))
  print('  clouds:', conky_weather_hour_clouds(i))
  print('  wind_speed:', conky_weather_hour_wind_speed(i))
  print('  wind_dir:', conky_weather_hour_wind_dir(i))
  print('  wind_gust:', conky_weather_hour_wind_gust(i))
  print('  uv:', conky_weather_hour_uv(i))
  print('  is_day:', conky_weather_hour_is_day(i))
end
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
