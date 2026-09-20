--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
require.lua — central module loader for the ConkyNextGen engine

Single registration point for the profile-selected engine modules: the
external Lua libraries (cairo, rsvg, imlib2, lfs, dkjson), the core
modules (theme, translation, drawing, capture, groups, mouse), the
weather, hardware, media and Google modules, plus every draw.* renderer.
A widget root file sets MODULE_PROFILE before calling
require("require") right after setting package.path so the dependency
order stays in one place.
]]--

--{{{
-- ## Central module loader
--
-- Central require() hub (not a widget). Every profile loads system
-- libraries, core rendering, mouse handling and every draw renderer. The
-- selected MODULE_PROFILE additionally loads only its required data modules;
-- each require remains strict and fails immediately on a missing dependency.
--
-- **Exposed/global functions:**
-- (none defined; registers modules only)
--
-- **Config/globals used:**
-- `cairo`, `rsvg`, `imlib2`, `lfs`, `json` — bound system libraries
-- `hyphen` — draw.hyphen module exposed globally
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

local MODULE_PROFILES = {
    basic = {},
    weather = {
        "weather.core", "weather.weather_data", "weather.sun", "weather.moon",
        "weather.airquality", "weather.city", "weather.weather_icons",
        "weather.weather_translations", "weather.alerts",
    },
    system = {
        "hardware.core", "hardware.battery", "hardware.dmi", "hardware.info",
        "hardware.mtp", "hardware.network", "hardware.sensors", "hardware.usb",
    },
    media = { "nowplaying", "songtext" },
    panel = {
        "hardware.core", "hardware.battery", "hardware.dmi", "hardware.info",
        "hardware.mtp", "hardware.network", "hardware.sensors", "hardware.usb",
    },
    google = { "google.core", "google.data" },
    full = {
        "weather.core", "weather.weather_data", "weather.sun", "weather.moon",
        "weather.airquality", "weather.city", "weather.weather_icons",
        "weather.weather_translations", "weather.alerts",
        "hardware.core", "hardware.battery", "hardware.dmi", "hardware.info",
        "hardware.mtp", "hardware.network", "hardware.sensors", "hardware.usb",
        "nowplaying", "songtext", "google.core", "google.data",
    },
}

local selected_profiles = MODULE_PROFILE or "full"
if type(selected_profiles) == "string" then
    selected_profiles = { selected_profiles }
end

assert(type(selected_profiles) == "table" and #selected_profiles > 0,
    "MODULE_PROFILE must be a profile name or a non-empty profile list")
if #selected_profiles > 1 then
    for _, profile in ipairs(selected_profiles) do
        assert(profile ~= "full", "The full profile cannot be combined with other profiles")
    end
end

local loaded_modules = {}
for _, profile in ipairs(selected_profiles) do
    assert(type(profile) == "string", "MODULE_PROFILE entries must be strings")
    local modules = assert(MODULE_PROFILES[profile], "Unknown MODULE_PROFILE: " .. profile)
    for _, module in ipairs(modules) do
        if not loaded_modules[module] then
            require(module)
            loaded_modules[module] = true
        end
    end
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
require("draw.lyrics")
