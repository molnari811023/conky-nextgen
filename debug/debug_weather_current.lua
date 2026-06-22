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

local t = os.clock()
print('=== CURRENT WEATHER ===')
print('conky_weather_current_time():', conky_weather_current_time())
print('conky_weather_current_temp():', conky_weather_current_temp())
print('conky_weather_current_humidity():', conky_weather_current_humidity())
print('conky_weather_current_apparent():', conky_weather_current_apparent())
print('conky_weather_current_is_day():', conky_weather_current_is_day())
print('conky_weather_current_precip():', conky_weather_current_precip())
print('conky_weather_current_snow():', conky_weather_current_snow())
print('conky_weather_current_code():', conky_weather_current_code())
print('conky_weather_current_clouds():', conky_weather_current_clouds())
print('conky_weather_current_pressure_msl():', conky_weather_current_pressure_msl())
print('conky_weather_current_surface_pressure():', conky_weather_current_surface_pressure())
print('conky_weather_current_visibility():', conky_weather_current_visibility())
print('conky_weather_current_uv():', conky_weather_current_uv())
print('conky_weather_current_radiation():', conky_weather_current_radiation())
print('conky_weather_current_wind_speed():', conky_weather_current_wind_speed())
print('conky_weather_current_wind_dir():', conky_weather_current_wind_dir())
print('conky_weather_current_wind_gust():', conky_weather_current_wind_gust())
print('conky_weather_current_dewpoint():', conky_weather_current_dewpoint())
print('conky_weather_current_precip_prob():', conky_weather_current_precip_prob())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
