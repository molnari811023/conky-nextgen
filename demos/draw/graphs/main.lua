local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local project_dir = script_dir .. "../../../"

JSON_PATH = project_dir .. "tmp/"
STRINGS_MO_PATH = project_dir .. "language/en.mo"
ICON_BASE = project_dir .. "icons/"
ICON_THEME = "default"

lfs = require("lfs")
json = require("dkjson")

package.path = package.path .. ";" .. project_dir .. "lua/?.lua;" .. project_dir .. "demos/?.lua"

require("helpers")
require("24_draw_core")
require("25_draw_background")
require("27_draw_graph")
require("31_draw_text")
require("widget")
demo_override_core_main()
