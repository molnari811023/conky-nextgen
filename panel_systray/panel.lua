--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
panel.lua — bottom panel widget: full-width bar hosting the systray
and a clickable SVG test area.

Bootstraps the NextGen engine (require("require")) like the other
widget roots, registers draw items: a background strip, a static test
SVG that runs "notify-send hello" on left click (mouse.lua hit test +
call_action), and the systray host marker. The systray itself
(panel_systray C binary) reparents into this Conky window.

The click wiring needs the engine's mouse module (lua_mouse_hook =
'conky_on_mouse') — a raw conky.text has no such events.
]]--

--{{{
-- ## Bottom panel widget
--
-- Full-width (1920) bar at the bottom of the screen. Draws a subtle
-- background strip, a test SVG with a notify-send click action and a
-- status line. The systray host window marker confirms where the
-- panel_systray child should sit.
--
-- **Draw items registered:**
-- - `background` — the strip behind everything
-- - `svg` — conky logomark, `click = "notify-send hello"` (left-click test)
-- - `text` — simple status text
--
-- **Config/globals used:**
-- `script_dir`, `package.path`, `JSON_PATH`, `draw`, `THEMES`,
-- `DEFAULT_THEME`, `_GROUPS`, `_VIEWS`, `_MOUSE_ENABLED`,
-- `require("require")`, `init_groups(_GROUPS)`
--}}}

------------------------------------------------------------
-- Global paths / config
------------------------------------------------------------
script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "?.lua"
    .. ";" .. script_dir .. "../lua/?.lua"
    .. ";" .. script_dir .. "../lua/core/?.lua"
    .. ";" .. script_dir .. "../lua/draw/?.lua"
    .. ";" .. script_dir .. "../lua/weather/?.lua"
    .. ";" .. script_dir .. "../lua/hardware/?.lua"

JSON_PATH      = script_dir .. "../tmp/"

draw = {}

ICON_BASE      = script_dir .. "../icons/"
ICON_THEME     = "default"
MOON_ICON_BASE = script_dir .. "../icons/moon/"
WIND_ICON_BASE = script_dir .. "../icons/wind/"

THEMES = {
    theme = {
        palette = {
            bg_dark = "#202326",
            bg_mid = "#292c30",
            bg_light = "#31363c",
            fg = "#fcfcfc",
            fg_dim = "#a1a9b1",
            blue = "#3daee9",
        },
        gradients = {
            border_subtle = { { 1, "#a1a9b1", 0.6 } },
        },
        defaults = {
            background = {
                bg = { { 1, "#202326", 0.9 } },
                border = { { 1, "#4a4d52", 1 } },
                border_width = 2,
            },
            text = {
                color = { { 1, "#fcfcfc", 1 } },
            },
        },
    },
}

DEFAULT_THEME = "theme"
_PADDING = 0

require("require")
require("apps")
require("tasklist")
require("clock")

draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 0,
}
tasklist_install()

clock_install()

_GROUPS = {
}

_VIEWS = {
    { name = "main" },
}

_MOUSE_ENABLED = true

init_groups(_GROUPS)