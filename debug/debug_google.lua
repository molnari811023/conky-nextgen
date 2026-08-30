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
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/lua/core/?.lua;' .. root .. '/lua/hardware/?.lua;' .. root .. '/lua/weather/?.lua;' .. root .. '/lua/google/?.lua'

conky_parse = function(s) return s end
conky_window = { width = 420, height = 1020 }
conky_log = function() end

lfs = require('lfs')
script_dir      = root .. '/'
JSON_PATH       = script_dir .. 'tmp/'
ICON_BASE       = script_dir .. 'icons/'
ICON_THEME      = 'default'
XDG_ICON_THEME  = 'Papirus'
MOON_ICON_BASE  = script_dir .. 'icons/moon/'
WIND_ICON_BASE  = script_dir .. 'icons/wind/'
json = require('dkjson')

require('core.utils')
require('core.translate')
require('google.core')
require('google.data')

print('== GOOGLE ==')
print('unread        = ' .. conky_google_unread_count())
print('gmail count   = ' .. conky_google_gmail_count())
for i = 1, math.min(tonumber(conky_google_gmail_count()) or 0, 5) do
  if i <= #(load_google_data().gmail or {}) then
    print(('  [%d] %s | %s | %s | %s'):format(
      i,
      conky_google_gmail_from(i),
      conky_google_gmail_subject(i),
      conky_google_gmail_date(i),
      conky_google_gmail_label(i)
    ))
  end
end
print('calendar count = ' .. conky_google_calendar_count())
print('tasks count    = ' .. conky_google_tasks_count())
print('tasks list     = ' .. conky_google_tasks_list_title(1))
print('contacts count = ' .. conky_google_contacts_count())
for i = 1, math.min(tonumber(conky_google_contacts_count()) or 0, 10) do
  if i <= #(load_google_data().contacts or {}) then
    print(('  [%d] %s | %s'):format(i, conky_google_contacts_name(i), conky_google_contacts_phone(i)))
  end
end
print('drive count    = ' .. conky_google_drive_count())
for i = 1, math.min(tonumber(conky_google_drive_count()) or 0, 5) do
  if i <= #(load_google_data().drive or {}) then
    print(('  [%d] %s | %s'):format(i, conky_google_drive_name(i), conky_google_drive_filesize(i)))
  end
end
print('youtube count  = ' .. conky_google_youtube_count())
print('meet count     = ' .. conky_google_meet_count())
