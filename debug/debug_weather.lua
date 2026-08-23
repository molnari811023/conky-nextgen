#!/usr/bin/env lua

--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--}}}

--{{{
-- debug_weather.lua — Standalone debug dump for the weather modules.
-- Needs data JSONs in <root>/tmp/ (written by the bash backend).
-- Run:  lua debug/debug_weather.lua   (from the repo root or anywhere)
--}}}

local function get_root()
  local src = (debug.getinfo(1, 'S').source or arg[0]):match('@(.*)') or arg[0] or '.'
  local dir = src:match('^(.*[/\\])') or './'
  local p = io.popen('readlink -f "'..dir..'../" 2>/dev/null')
  local out = p and (p:read('*a') or ''):gsub('%s+$','') or dir..'../'
  if p then p:close() end
  return out
end
local root = get_root()
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/lua/core/?.lua;' .. root .. '/lua/hardware/?.lua;' .. root .. '/lua/weather/?.lua'

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
require('weather.core')
require('weather.weather_data')
require('weather.sun')
require('weather.moon')
require('weather.airquality')
require('weather.city')
require('weather.weather_icons')
require('weather.weather_translations')
require('weather.alerts')

local function dump(t, indent)
  indent = indent or 0
  if type(t) ~= 'table' then return tostring(t) end
  local lines = {}
  for k, v in pairs(t) do
    lines[#lines + 1] = string.format('%s=%s', tostring(k), dump(v, indent + 2))
  end
  return '{' .. table.concat(lines, ', ') .. '}'
end

local function dump_n(t, n)
  if type(t) ~= 'table' then return tostring(t) end
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local lines = {}
  for i, k in ipairs(keys) do
    if i > (n or 3) then
      lines[#lines + 1] = ('... +%d more'):format(#keys - i + 1)
      break
    end
    lines[#lines + 1] = string.format('%s=%s', tostring(k), dump(t[k], 2))
  end
  return '{' .. table.concat(lines, ', ') .. '}'
end

local t0 = os.clock()
local function sec(name)
  print()
  print('=== ' .. name .. ' ===')
  local t = os.clock()
  return function()
    print(string.format('[%.3fms]', (os.clock() - t) * 1000))
  end
end

local done = sec('CITY')
print('conky_city_name():', dump(conky_city_name()))
print('conky_city_country():', dump(conky_city_country()))
print('conky_city_timezone():', dump(conky_city_timezone()))
print('conky_city_lat():', dump(conky_city_lat()))
print('conky_city_lon():', dump(conky_city_lon()))
print('conky_city_postcode():', dump(conky_city_postcode(1)))
done()

done = sec('CURRENT')
print('cur_data():', dump(W.weather.current))
for _, f in ipairs({
  'conky_weather_cur_time', 'conky_weather_cur_interval',
  'conky_weather_cur_temp', 'conky_weather_cur_humidity',
  'conky_weather_cur_apparent', 'conky_weather_cur_is_day',
  'conky_weather_cur_precip', 'conky_weather_cur_rain',
  'conky_weather_cur_showers', 'conky_weather_cur_snow',
  'conky_weather_cur_code', 'conky_weather_cur_clouds',
  'conky_weather_cur_pressure', 'conky_weather_cur_surface',
  'conky_weather_cur_visibility', 'conky_weather_cur_uv',
  'conky_weather_cur_radiation', 'conky_weather_cur_wind_speed',
  'conky_weather_cur_wind_dir', 'conky_weather_cur_wind_gust',
  'conky_weather_cur_dewpoint',
}) do
  print(f .. '():', dump(_G[f]()))
end
done()

done = sec('CURRENT UNITS')

done = sec('HOURLY')
for i = 1, 3 do
  print('conky_weather_hour_time(' .. i .. '):', dump(conky_weather_hour_time(i)))
  print('  temp:', dump(conky_weather_hour_temp(i)),
        ' code:', dump(conky_weather_hour_code(i)),
        ' precip_prob:', dump(conky_weather_hour_precip_prob(i)),
        ' wind_speed:', dump(conky_weather_hour_wind_speed(i)))
end
done()

done = sec('DAILY')
for i = 1, 3 do
  print('conky_weather_day_time(' .. i .. '):', dump(conky_weather_day_time(i)))
  print('  temp_max:', dump(conky_weather_day_temp_max(i)),
        ' temp_min:', dump(conky_weather_day_temp_min(i)),
        ' sunrise:', dump(conky_weather_day_sunrise(i)),
        ' sunset:', dump(conky_weather_day_sunset(i)),
        ' uv:', dump(conky_weather_day_uv(i)),
        ' code:', dump(conky_weather_day_code(i)))
end
done()

done = sec('AIR QUALITY')
print('air_data():', dump(W.air.current))
for _, f in ipairs({
  'conky_air_cur_pm10', 'conky_air_cur_pm25', 'conky_air_cur_co',
  'conky_air_cur_o3', 'conky_air_cur_no2', 'conky_air_cur_so2',
  'conky_air_cur_dust', 'conky_air_cur_eaqi', 'conky_air_cur_usaqi',
  'conky_air_cur_alder', 'conky_air_cur_birch',
  'conky_air_cur_grass', 'conky_air_cur_mugwort',
  'conky_air_cur_olive', 'conky_air_cur_ragweed',
}) do
  print(f .. '():', dump(_G[f]()))
end
done()

done = sec('SUN / MOON')
print('sun_data():', dump(W.sun.properties))
print('conky_sun_rise_time():', dump(conky_sun_rise_time()))
print('conky_sun_set_time():', dump(conky_sun_set_time()))
print('conky_sun_noon_time():', dump(conky_sun_noon_time()))
print('conky_sun_x(560, 130):', dump(conky_sun_x(560, 130)))
print('conky_sun_y(175, 130):', dump(conky_sun_y(175, 130)))
print('need_to_draw_sun_icon():', dump(need_to_draw_sun_icon()))
print('moon_data():', dump(W.moon.properties))
print('conky_moon_rise_time():', dump(conky_moon_rise_time()))
print('conky_moon_set_time():', dump(conky_moon_set_time()))
print('conky_moon_phase():', dump(conky_moon_phase()))
print('conky_moon_x(560, 130):', dump(conky_moon_x(560, 130)))
print('conky_moon_y(175, 130):', dump(conky_moon_y(175, 130)))
print('need_to_draw_moon_icon():', dump(need_to_draw_moon_icon()))
print('conky_moon_phase_text():', dump(conky_moon_phase_text()))
done()

done = sec('CORE / ICONS')
print('conky_weather_code_text(0):', dump(conky_weather_code_text(0)))
print('conky_day_name(1):', dump(conky_day_name(1)))
print('conky_day_name_short(1):', dump(conky_day_name_short(1)))
print('conky_wind_direction_text(90):', dump(conky_wind_direction_text(90)))
print('conky_icon_current_weather():', dump(conky_icon_current_weather()))
print('conky_icon_day_weather(1):', dump(conky_icon_day_weather(1)))
print('conky_icon_hour_weather(1):', dump(conky_icon_hour_weather(1)))
print('conky_icon_moon():', dump(conky_icon_moon()))
done()

done = sec('ALERTS')
print('conky_update_alerts():', dump(conky_update_alerts()))
print('alerts_count():', dump(alerts_count()))
print('alerts_updated():', dump(alerts_updated()))
done()

print()
print(string.format('TOTAL: [%.3fms]', (os.clock() - t0) * 1000))
