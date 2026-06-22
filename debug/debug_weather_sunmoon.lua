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

local function safe(fn, ...)
  local ok, r = pcall(fn, ...)
  return ok and r or '<error: ' .. tostring(r) .. '>'
end

local t = os.clock()
print('=== SUN ===')
print('conky_sun_rise_time:', safe(conky_sun_rise_time))
print('conky_sun_rise_azimuth:', safe(conky_sun_rise_azimuth))
print('conky_sun_set_time:', safe(conky_sun_set_time))
print('conky_sun_set_azimuth:', safe(conky_sun_set_azimuth))
print('conky_sun_noon_time:', safe(conky_sun_noon_time))
print('conky_sun_noon_elevation:', safe(conky_sun_noon_elevation))
print('conky_sun_midnight_time:', safe(conky_sun_midnight_time))
print('conky_sun_midnight_elevation:', safe(conky_sun_midnight_elevation))
print(string.format('[%.3fms]', (os.clock() - t) * 1000))

print('\n=== MOON ===')
t = os.clock()
print('conky_moon_phase:', safe(conky_moon_phase))
print('conky_moon_rise_time:', safe(conky_moon_rise_time))
print('conky_moon_rise_azimuth:', safe(conky_moon_rise_azimuth))
print('conky_moon_set_time:', safe(conky_moon_set_time))
print('conky_moon_set_azimuth:', safe(conky_moon_set_azimuth))
print('conky_moon_high_time:', safe(conky_moon_high_time))
print('conky_moon_high_elevation:', safe(conky_moon_high_elevation))
print('conky_moon_low_time:', safe(conky_moon_low_time))
print('conky_moon_low_elevation:', safe(conky_moon_low_elevation))
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
