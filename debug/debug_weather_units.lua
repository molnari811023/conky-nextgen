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
require('weather_daily')
require('weather_air')
require('weather_sunmoon')
require('weather_units')

local t = os.clock()
print('=== CITY ===')
print('conky_city_name:', conky_city_name())
print('conky_city_lat:', conky_city_lat())
print('conky_city_lon:', conky_city_lon())
print('conky_city_elevation:', conky_city_elevation())
print('conky_city_timezone:', conky_city_timezone())
print('conky_city_country:', conky_city_country())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))

print('\n=== UNITS ===')
t = os.clock()
print('conky_unit_cur_temp:', conky_unit_cur_temp())
print('conky_unit_cur_humidity:', conky_unit_cur_humidity())
print('conky_unit_cur_wind_speed:', conky_unit_cur_wind_speed())
print('conky_unit_hour_temp:', conky_unit_hour_temp())
print('conky_unit_day_temp_max:', conky_unit_day_temp_max())
print('conky_unit_day_temp_min:', conky_unit_day_temp_min())
print('conky_unit_day_time:', conky_unit_day_time())
print('conky_unit_day_code:', conky_unit_day_code())
print('conky_unit_day_sunrise:', conky_unit_day_sunrise())
print('conky_unit_day_sunset:', conky_unit_day_sunset())
print('conky_unit_day_daylight:', conky_unit_day_daylight())
print('conky_unit_day_sunshine:', conky_unit_day_sunshine())
print('conky_unit_day_uv:', conky_unit_day_uv())
print('conky_unit_day_precip_hours:', conky_unit_day_precip_hours())
print('conky_unit_air_cur_pm10:', conky_unit_air_cur_pm10())
print('conky_unit_air_cur_pm25:', conky_unit_air_cur_pm25())
print('conky_unit_air_cur_eaqi:', conky_unit_air_cur_eaqi())
print('conky_unit_air_hour_pm10:', conky_unit_air_hour_pm10())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
