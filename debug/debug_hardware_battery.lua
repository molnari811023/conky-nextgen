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
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/?.lua'

lfs = require('lfs')
require('hardware_core')
require('hardware_battery')

local function dump(t, indent)
  indent = indent or 0
  if type(t) ~= 'table' then return tostring(t) end
  local lines = {}
  for k, v in pairs(t) do
    lines[#lines + 1] = string.format('%s=%s', tostring(k), dump(v, indent + 2))
  end
  return '{' .. table.concat(lines, ', ') .. '}'
end

local t = os.clock()
print('=== BATTERY ===')
print('get_battery_path():', get_battery_path())
print('conky_battery_health_data():', dump(conky_battery_health_data()))
print('conky_headset_info():', dump(conky_headset_info()))
print('conky_mouse_info():', dump(conky_mouse_info()))
print('conky_external_battery_list():', dump(conky_external_battery_list()))
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
