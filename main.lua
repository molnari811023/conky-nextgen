--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
]]

local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
JSON_PATH = script_dir .. "tmp/"
STRINGS_MO_PATH = script_dir .. "language/en.mo"
ICON_BASE = script_dir .. "icons/"
ICON_THEME = "default"
MOON_ICON_BASE = script_dir .. "icons/moon/"
WIND_ICON_BASE = script_dir .. "icons/wind/"

lfs = require("lfs")
json = require("dkjson")

os.setlocale("hu_HU.UTF-8", "time")

package.path = package.path .. ";" .. script_dir .. "lua/?.lua;" .. script_dir .. "?.lua"

-- basics
require("translate")
require("colors")
require("watcher")

-- weather
require("weather_core")
require("weather_current")
require("weather_hourly")
require("weather_daily")
require("weather_air")
require("weather_sunmoon")
require("weather_units")
require("weather_alerts")

-- space weather (optional, comment out if not needed)
require("spaceweather")

-- hardware
require("processes")
require("hardware_core")
require("hardware_battery")
require("hardware_dmi")
require("hardware_info")
require("hardware_mtp")
require("hardware_nvidia")
require("hardware_network")
require("hardware_sensors")
require("hardware_usb")
require("hardware_processes")

-- drawing
require("draw_core")
require("draw_background")
require("draw_bar")
require("draw_graph")
require("draw_clock")
require("draw_rings")
require("hyphen")
require("draw_text")
require("draw_lines")
require("draw_calendar")
require("draw_image")
require("draw_layout")

-- widget definitions (draw = {}, layout = {})
require("widget")

function conky_cleanup()
	watcher.cleanup()
end

watcher.init("conky", script_dir .. "conky.conf", script_dir .. "lua/", { script_dir })
