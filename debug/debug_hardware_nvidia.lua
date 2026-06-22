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
require('hardware_nvidia')

local t = os.clock()
print('=== NVIDIA ===')
print('conky_gpu_mode:', conky_gpu_mode())
print('conky_nvidia_active:', conky_nvidia_active())
print('conky_intel_active:', conky_intel_active())
if conky_update_nvidia_xml then conky_update_nvidia_xml() end
print('conky_nv_gputemp:', conky_nv_gputemp())
print('conky_nv_gpufreqcur:', conky_nv_gpufreqcur())
print('conky_nv_gpuutil:', conky_nv_gpuutil())
print('conky_nv_memused:', conky_nv_memused())
print('conky_nv_memfree:', conky_nv_memfree())
print('conky_nv_memmax:', conky_nv_memmax())
print('conky_nv_memutil:', conky_nv_memutil())
print('conky_nv_fanspeed:', conky_nv_fanspeed())
print('conky_nv_modelname:', conky_nv_modelname())
print('conky_nv_driverversion:', conky_nv_driverversion())
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
