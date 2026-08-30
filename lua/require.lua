--[[[
require.lua — central module loader for the ConkyNextGen engine

Single registration point for every module the engine needs: the
external Lua libraries (cairo, rsvg, imlib2, lfs, dkjson), the core
modules (theme, translation, drawing, capture, groups, mouse), the
weather, hardware and nowplaying modules, an optional google module
set and every draw.* renderer. A widget root file calls
require("require") right after setting package.path so the dependency
order stays in one place.
]]--

--{{{
-- ## Central module loader
--
-- Central require() hub (not a widget). Orders and registers all
-- engine modules: system libraries, core rendering, mouse handling,
-- weather data, hardware sensors, nowplaying, optional google data and
-- every draw.* renderer. The hyphen renderer is kept in the global
-- `hyphen`. The google modules are loaded under pcall so layouts that
-- lack the lua/google path entry stay unaffected.
--
-- **Exposed/global functions:**
-- (none defined; registers modules only)
--
-- **Config/globals used:**
-- `cairo`, `rsvg`, `imlib2`, `lfs`, `json` — bound system libraries
-- `hyphen` — draw.hyphen module exposed globally
-- `pcall(require, "google.core")` — optional google loading guard
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
-- The google modules need tmp/ JSONs (from sh/fetch_google.sh) and the
-- lua/google/?.lua path entry. Loaded with pcall so configs that don't
-- include that path (e.g. some secondary widgets) stay unaffected.
local ok_google, _ = pcall(require, "google.core")
if ok_google then
	require("google.data")
end

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
