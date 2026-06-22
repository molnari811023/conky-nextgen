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
require('processes')
require('hardware_processes')

local t = os.clock()
print('=== PROCESSES ===')
for i = 1, 5 do
  print(string.format('conky_top_cpu_name(%d): %s  cpu: %s  mem: %s  pid: %s',
    i, conky_top_cpu_name(i), conky_top_cpu_cpu(i), conky_top_cpu_mem(i), conky_top_cpu_pid(i)))
end
for i = 1, 5 do
  print(string.format('conky_top_mem_name(%d): %s  cpu: %s  mem: %s  pid: %s',
    i, conky_top_mem_name(i), conky_top_mem_cpu(i), conky_top_mem_mem(i), conky_top_mem_pid(i)))
end
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
