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
require('hardware_network')

local t = os.clock()
print('=== NETWORK ===')
print('conky_wifi_interface:', conky_wifi_interface())
print('conky_wifi_active:', conky_wifi_active())
print('conky_wifi_temp:', conky_wifi_temp())
print('conky_public_ip:', conky_public_ip())
print('conky_public_city:', conky_public_city())
print('conky_public_country:', conky_public_country())
print('conky_ping_avg:', conky_ping_avg())
print('conky_ping_jitter:', conky_ping_jitter())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
