--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- main.lua — Entry point. Loads all modules, sets up paths and hooks.

local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
JSON_PATH = script_dir .. "tmp/"
ICON_BASE = script_dir .. "icons/"
ICON_THEME = "default"
XDG_ICON_THEME = "Papirus"
MOON_ICON_BASE = script_dir .. "icons/moon/"
WIND_ICON_BASE = script_dir .. "icons/wind/"

lfs = require("lfs")
json = require("dkjson")

os.setlocale("hu_HU.UTF-8", "time")

package.path = package.path .. ";" .. script_dir .. "lua/?.lua;" .. script_dir .. "lua/core/?.lua;" .. script_dir .. "lua/draw/?.lua;" .. script_dir .. "lua/weather/?.lua;" .. script_dir .. "lua/hardware/?.lua"

local lang_raw = os.getenv("LANG") or os.getenv("LC_ALL") or os.getenv("LC_MESSAGES") or "en"
local lang_code = lang_raw:sub(1, 2):lower()
local lang_path = script_dir .. "language/" .. lang_code .. ".mo"
local f = io.open(lang_path, "rb")
if f then
	f:close()
	STRINGS_MO_PATH = lang_path
else
	STRINGS_MO_PATH = script_dir .. "language/en.mo"
end

-- ═══ CORE — alap modulok ═══
require("core.translate")
require("core.colors")

-- ═══ WEATHER — időjárás ═══
require("weather.core")
require("weather.current")
require("weather.hourly")
require("weather.daily")
require("weather.air")
require("weather.sunmoon")
require("weather.units")
require("weather.alerts")
require("weather.spaceweather")

-- ═══ HARDWARE — hardver információk ═══
require("hardware.processes")
require("hardware.core")
require("hardware.battery")
require("hardware.dmi")
require("hardware.info")
require("hardware.mtp")
require("hardware.network")
require("hardware.sensors")
require("hardware.usb")
require("hardware.processes_extra")

-- ═══ EXTRÁK ═══
local ok, nowplaying = pcall(require, "nowplaying")

-- ═══ CLIPBOARD ═══
require("core.clipboard")

-- ═══ DRAWING CORE — függőségi sorrendben ═══
require("core.draw_core")     -- Cairo init, állapot, segédfüggvények, conky_core_main
require("core.draw_group")    -- GROUP_STATE, toggle, register, visibility
require("core.draw_input")    -- Registry-k, click/scroll akciók, build_draw
require("core.draw_context")  -- Context menü
require("core.draw_mouse")    -- Mouse event handler

-- ═══ DRAW MODULOK — rajzolási típusok ═══
require("draw.background")
require("draw.bar")
require("draw.graph")
require("draw.clock")
require("draw.rings")
require("draw.hyphen")
require("draw.text")
require("draw.lines")
require("draw.calendar")
require("draw.image")
require("draw.icon_theme")
require("draw.svg")

-- ═══ LAYOUT + WIDGET ═══
require("draw_layout")
require("widget")

function conky_cleanup()
end
