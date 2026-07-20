local function get_root()
  local src = (debug.getinfo(1, "S").source or arg[0]):match("@(.*)") or arg[0] or "."
  local dir = src:match("^(.*[/\\])") or "./"
  local p = io.popen('readlink -f "' .. dir .. '../" 2>/dev/null')
  local out = p and (p:read("*a") or ""):gsub("%s+$","") or dir.."../"
  if p then p:close() end
  return out
end
local root = get_root()
JSON_PATH = root .. "tmp/"
ICON_BASE = root .. "icons/"
MOON_ICON_BASE = root .. "icons/moon/"
WIND_ICON_BASE = root .. "icons/wind/"
ICON_THEME = "default"
os.setlocale("hu_HU.UTF-8", "time")
package.path = "./?.lua;" .. package.path .. ";" .. root .. "/lua/?.lua;" .. root .. "/lua/core/?.lua;" .. root .. "/lua/draw/?.lua;" .. root .. "/lua/weather/?.lua;" .. root .. "/lua/hardware/?.lua;" .. root .. "/?.lua"

lfs = require("lfs")
json = require("dkjson")
require("core.translate")
require("core.colors")
require("weather.core")
require("weather.current")

print("JSON_PATH:", JSON_PATH)
print("root:", root)

local f = io.open(JSON_PATH .. "weather_data.json", "r")
if f then
  print("weather_data.json: EXISTS")
  f:close()
else
  print("weather_data.json: NOT FOUND at " .. JSON_PATH)
end

print("W:", W)
if W then
  print("W.weather.current.temperature_2m:", W.weather.current.temperature_2m)
  print("conky_weather_current_temp:", conky_weather_current_temp())
else
  print("W is nil")
  local rdata = conky_load_weather_data()
  print("conky_load_weather_data returned:", rdata)
end

os.remove("test_w.lua")
