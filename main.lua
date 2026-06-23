--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- main.lua — Entry point. Loads all modules, sets up paths and hooks.

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
require("1_translate")
require("2_colors")
require("3_watcher")

-- weather
require("4_weather_core")
require("5_weather_current")
require("6_weather_hourly")
require("7_weather_daily")
require("8_weather_air")
require("9_weather_sunmoon")
require("10_weather_units")
require("11_weather_alerts")

-- space weather (optional, comment out if not needed)
require("12_spaceweather")

-- hardware
require("13_processes")
require("14_hardware_core")
require("15_hardware_battery")
require("16_hardware_dmi")
require("17_hardware_info")
require("18_hardware_mtp")
require("19_hardware_nvidia")
require("20_hardware_network")
require("21_hardware_sensors")
require("22_hardware_usb")
require("23_hardware_processes")

-- drawing
require("24_draw_core")
require("25_draw_background")
require("26_draw_bar")
require("27_draw_graph")
require("28_draw_clock")
require("29_draw_rings")
require("30_hyphen")
require("31_draw_text")
require("32_draw_lines")
require("33_draw_calendar")
require("34_draw_image")
require("35_draw_layout")

-- widget definitions (draw = {}, layout = {})
require("36_widget")

function conky_cleanup()
	watcher.cleanup()
end

watcher.init("conky", script_dir .. "conky.conf", script_dir .. "lua/", { script_dir })
