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
require('hardware_mtp')

local t = os.clock()
print('=== MTP ===')
print('conky_mtp_count:', conky_mtp_count())
print('conky_mtp_perc(1,1):', conky_mtp_perc(1, 1))
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
