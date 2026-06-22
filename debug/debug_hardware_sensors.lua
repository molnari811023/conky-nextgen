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
require('hardware_sensors')

local t = os.clock()
print('=== SENSORS ===')
print('conky_cpu_temp:', conky_cpu_temp())
print('conky_nvme_temp:', conky_nvme_temp())
print('conky_wifi_temp:', conky_wifi_temp())
print('conky_fan_speed(1):', conky_fan_speed(1))
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
