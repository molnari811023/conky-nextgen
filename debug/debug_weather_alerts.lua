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
require('translate')
require('weather_core')
require('weather_current')
require('weather_alerts')

local t = os.clock()
print('=== WEATHER ALERTS ===')
local count = alerts_count()
print('alerts_count:', count)
for i = 1, math.max(1, count) do
  print(string.format('--- alert %d ---', i))
  print('  event:',    alert_field(i, 'event'))
  print('  severity:', alert_field(i, 'severity'))
  print('  certainty:',alert_field(i, 'certainty'))
  print('  area:',     alert_field(i, 'area'))
  print('  title:',    alert_field(i, 'title'))
  print('  color:',    alert_field(i, 'color'))
  print('  onset:',    alert_field(i, 'onset'))
  print('  expires:',  alert_field(i, 'expires'))
  if i >= 3 then break end
end
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
