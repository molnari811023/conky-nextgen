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
JSON_PATH = root .. '/tmp/'
os.setlocale('hu_HU.UTF-8', 'time')
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/?.lua'

lfs = require('lfs')
json = require('dkjson')
require('translate')
require('weather_core')
require('weather_current')
require('weather_units')

function conky_city_lat() return 48.20849 end
function conky_city_lon() return 16.37208 end

require('spaceweather')

local t = os.clock()
print('=== SPACE WEATHER ===')
print('conky_sw_kp:', conky_sw_kp())
print('conky_sw_kp_status:', conky_sw_kp_status())
print('conky_sw_g_scale:', conky_sw_g_scale())
print('conky_sw_wind_speed:', conky_sw_wind_speed())
print('conky_sw_bz:', conky_sw_bz())
print('conky_sw_xray_flux:', conky_sw_xray_flux())
print('conky_sw_xray_class:', conky_sw_xray_class())
print('conky_sw_xray_full:', conky_sw_xray_full())
print('conky_sw_sunspot:', conky_sw_sunspot())
print('conky_sw_aurora_pct:', conky_sw_aurora_pct())
local ac = conky_sw_alerts_count()
print('conky_sw_alerts_count:', ac)
for i = 1, math.max(1, ac) do
  print(string.format('  alert %d: severity=%s', i, conky_sw_alert_severity(i)))
  print('    message:', conky_sw_alert_message(i))
  if i >= 3 then break end
end
print('conky_sw_summary:', conky_sw_summary())
print('conky_kp_to_g_scale(5):', conky_kp_to_g_scale(5))
print('conky_kp_to_g_scale(8):', conky_kp_to_g_scale(8))
print('conky_xray_short_class(1e-6):', conky_xray_short_class(1e-6))
print('conky_xray_full_class(3.2e-5):', conky_xray_full_class(3.2e-5))
for kp = 0, 9 do
  print(string.format('  aurora vis at 48N Kp %d: %d%%', kp, conky_aurora_visibility_pct(kp, 48.2)))
end
print(string.format('[%.3fms]', (os.clock() - t) * 1000))
