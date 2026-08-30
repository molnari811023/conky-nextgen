--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- require.lua — Central module loader
-- Load order (important!):
-- 1. C libraries: cairo, rsvg, imlib2, lfs, dkjson
-- 2. Core: theme_engine (themes come from the THEMES block in widget.lua),
--    translate, utils, draw_core, mouse_actions, mouse
-- 4. Hardware: core, battery, dmi, info, mtp, network, sensors, usb
-- 5. Extra: nowplaying
-- 6. Google: core (loader) + data (accessors)
-- 7. Draw: icon_theme, hyphen, background, text, bar, graph, image, svg, clock, calendar, lines, rings
--
-- Debug files are in debug/ folder:
--   debug/debug_weather.lua    — weather module dump (requires tmp/ data)
--   debug/debug_hardware.lua   — hardware module dump (real values)
--}}}

cairo = require("cairo")
rsvg = require("rsvg")
imlib2 = require("imlib2")
lfs = require("lfs")
json = require("dkjson")

-- ═══ CORE ═══
require("core.theme_engine")
require("core.translate")
require("core.utils")
require("core.draw_core")
require("core.capture")
require("core.draw_group")
require("mouse_actions")
require("core.mouse")

-- ═══ WEATHER ═══
require("weather.core")
require("weather.weather_data")
require("weather.sun")
require("weather.moon")
require("weather.airquality")
require("weather.city")
require("weather.weather_icons")
require("weather.weather_translations")
require("weather.alerts")

-- ═══ HARDWARE ═══
require("hardware.core")
require("hardware.battery")
require("hardware.dmi")
require("hardware.info")
require("hardware.mtp")
require("hardware.network")
require("hardware.sensors")
require("hardware.usb")

-- ═══ EXTRAS ═══
require("nowplaying")

-- ═══ GOOGLE ═══
require("google.core")
require("google.data")

-- ═══ DRAW MODULES ═══
require("draw.icon_theme")
hyphen = require("draw.hyphen")
require("draw.background")
require("draw.text")
require("draw.bar")
require("draw.graph")
require("draw.image")
require("draw.svg")
require("draw.clock")
require("draw.calendar")
require("draw.lines")
require("draw.rings")
require("draw.arc")
