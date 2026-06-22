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

local t = os.clock()
print('=== HARDWARE CORE ===')
print('has_cmd(ls):', has_cmd('ls'))
print('has_cmd(nonexistent):', has_cmd('nonexistent'))
print('read_file(/etc/hostname):', read_file('/etc/hostname'))
print('conky_updates_repo():', conky_updates_repo())
print('conky_updates_aur():', conky_updates_aur())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
