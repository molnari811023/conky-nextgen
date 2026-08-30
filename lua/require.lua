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
