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

JSON_PATH      = script_dir:match("^/usr") and ((os.getenv("HOME") or "/tmp") .. "/.conky/tmp/") or (script_dir .. "../tmp/")

draw = {}

ICON_BASE      = script_dir .. "../icons/"
ICON_THEME     = "default"
XDG_ICON_THEME = "breeze-dark"
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
MODULE_PROFILE = "basic"

require("require")
require("apps")
require("tasklist")
require("battery")
require("clock")

draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = 0,
    h = 0,
    radius = 0,
}

-- Start Menu button configuration:
--   icon:       freedesktop icon name (e.g. "start-here-kde", "applications-all",
--               "distributor-logo-archlinux") or full path to a custom .svg/.png
--   show_label: true = show icon + label ("Start"), false = icon only
--   label:      button text when show_label = true
START_BTN_CFG = {
    x          = 8,
    y          = 9,
    h          = 30,
    icon_size  = 20,
    icon       = "start-here-kde",
    show_label = false,
    label      = "Start",
    w_full     = 88,
    w_icon     = 34,
    spacing    = 8,
}

local function resolve_start_icon(name, sz)
    if not name or name == "" then return nil end
    if name:sub(1, 1) == "/" then
        local f = io.open(name, "r")
        if f then f:close(); return name end
    end
    return icon_resolve(name, sz, XDG_ICON_THEME)
        or icon_resolve("start-here-kde", sz, XDG_ICON_THEME)
        or icon_resolve("applications-all", sz, XDG_ICON_THEME)
end

local start_cmd  = script_dir .. "toggle_start_menu.sh &"
local start_icon = resolve_start_icon(START_BTN_CFG.icon, START_BTN_CFG.icon_size)

local start_bg_item   = { type = "background", radius = 6, bg = { { 1, "#1f425c", 0.95 } }, border = { { 1, "#3daee9", 0.95 } }, border_width = 1.5, click = start_cmd }
local start_icon_item = { type = (start_icon and start_icon:match("%.svg$")) and "svg" or "image", path = start_icon }
local start_text_item = { type = "text", font = "Sans", size = 11, weight = "bold", color = { { 1, "#ffffff", 1 } }, text = function() return START_BTN_CFG.label or "Start" end }

local function start_btn_paint()
    local sw = START_BTN_CFG.show_label and START_BTN_CFG.w_full or START_BTN_CFG.w_icon
    TASKLIST_CFG.x_start = START_BTN_CFG.x + sw + START_BTN_CFG.spacing

    start_bg_item.x = START_BTN_CFG.x
    start_bg_item.y = START_BTN_CFG.y
    start_bg_item.w = sw
    start_bg_item.h = START_BTN_CFG.h

    start_icon_item.x = START_BTN_CFG.show_label
        and (START_BTN_CFG.x + 8)
        or (START_BTN_CFG.x + math.floor((sw - START_BTN_CFG.icon_size) / 2))
    start_icon_item.y = START_BTN_CFG.y + math.floor((START_BTN_CFG.h - START_BTN_CFG.icon_size) / 2)
    start_icon_item.w = START_BTN_CFG.icon_size
    start_icon_item.h = START_BTN_CFG.icon_size
    start_icon_item.width  = START_BTN_CFG.icon_size
    start_icon_item.height = START_BTN_CFG.icon_size

    start_text_item.x = START_BTN_CFG.x + START_BTN_CFG.icon_size + 14
    start_text_item.y = START_BTN_CFG.y + math.floor((START_BTN_CFG.h - 11) / 2) - 1
    start_text_item.draw_me = function() return START_BTN_CFG.show_label == true end
end

start_bg_item.rclick = function()
    START_BTN_CFG.show_label = not START_BTN_CFG.show_label
    start_btn_paint()
    tasklist_paint()
end

start_btn_paint()

draw[#draw + 1] = start_bg_item
if start_icon then
    draw[#draw + 1] = start_icon_item
end
draw[#draw + 1] = start_text_item

tasklist_install()

battery_install()

clock_install()

_GROUPS = {
}

_VIEWS = {
    { name = "main" },
}

_MOUSE_ENABLED = true

init_groups(_GROUPS)