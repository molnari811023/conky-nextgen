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
ICON_BASE = root .. '/icons/'
MOON_ICON_BASE = root .. '/icons/moon/'
WIND_ICON_BASE = root .. '/icons/wind/'
ICON_THEME = 'default'
os.setlocale('hu_HU.UTF-8', 'time')
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/?.lua'

lfs = require('lfs')
json = require('dkjson')
require('translate')
require('colors')
require('weather_current')
require('weather_hourly')
require('weather_daily')
require('weather_sunmoon')

function conky_safe_cur(v) return v or 0 end
function conky_safe_hour(tbl, i) return (tbl and tbl[i]) or 0 end
function conky_safe_day(tbl, i) return (tbl and tbl[i]) or 0 end
function conky_safe_air(v) return v or 0 end
function conky_safe_moon(v) return v or 0 end
function conky_safe_sun(v) return v or 0 end
function conky_safe_city(v) return v or 0 end
function conky_city_lat() return 48.20849 end
function conky_city_lon() return 16.37208 end

require('weather_core')

local t = os.clock()
print('=== WEATHER CORE ===')
print('conky_read_j(weather_data):', type(conky_read_j(JSON_PATH .. 'weather_data.json')))
print('conky_round(3.14159):', conky_round(3.14159))
print('conky_round(3.14159,1):', conky_round(3.14159, 1))
print('conky_day_name(0):', conky_day_name(0))
print('conky_day_name_short(0):', conky_day_name_short(0))
print('conky_sun_progress():', conky_sun_progress())
print('conky_moon_progress():', conky_moon_progress())
print('conky_sun_arc_x(100,50):', conky_sun_arc_x(100, 50))
print('conky_sun_arc_y(100,50):', conky_sun_arc_y(100, 50))
print('conky_weather_code_text(0):', conky_weather_code_text(0))
print('conky_weather_code_text(61):', conky_weather_code_text(61))
print('conky_wind_direction_text(0):', conky_wind_direction_text(0))
print('conky_wind_direction_text(180):', conky_wind_direction_text(180))
print('conky_moon_phase_text():', conky_moon_phase_text())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))

print('\n=== ICONS ===')
t = os.clock()
print('conky_icon_current_weather():', conky_icon_current_weather())
print('conky_icon_hour_weather(1):', conky_icon_hour_weather(1))
print('conky_icon_day_weather(1):', conky_icon_day_weather(1))
print('conky_icon_moon():', conky_icon_moon())
print('conky_icon_current_wind():', conky_icon_current_wind())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
