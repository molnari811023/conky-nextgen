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
require('hardware_dmi')

local t = os.clock()
print('=== DMI ===')
print('conky_sys_vendor:', conky_sys_vendor())
print('conky_product_name:', conky_product_name())
print('conky_board_name:', conky_board_name())
print('conky_bios_version:', conky_bios_version())
print('conky_chassis_type_human:', conky_chassis_type_human())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
