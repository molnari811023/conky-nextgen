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
require('hardware_usb')

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
print('=== USB ===')
print('conky_has_usb:', conky_has_usb())
print('conky_usb_count:', conky_usb_count())
print('conky_usb_list:', dump(conky_usb_list()))
print('conky_usb_name(1):', conky_usb_name(1))
print('conky_usb_mount(1):', conky_usb_mount(1))
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
