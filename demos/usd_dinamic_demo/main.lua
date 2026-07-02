local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local project_dir = script_dir .. "../../"



lfs = require("lfs")
json = require("dkjson")

package.path = package.path .. ";" .. project_dir .. "lua/?.lua;" .. project_dir .. "demos/?.lua"

require("helpers")
require("24_draw_core")
require("25_draw_background")
require("14_hardware_core")
require("22_hardware_usb")
require("26_draw_bar")
require("31_draw_text")
require("35_draw_layout")
require("widget")

function usb_disk_usage(mount)
	local out = pread([[df "]] .. mount .. [[" 2>/dev/null | tail -1]])
	if not out or out == "" then return 0 end
	local pct = out:match("(%d+)%%")
	return tonumber(pct) or 0
end

function conky_dynamic_padding()
	local usb_list = conky_usb_list()
	if #usb_list == 0 then
		return ""
	end
	local layout = {}
	for i = 1, #usb_list do
		table.insert(layout, { name = "usb" .. i, enabled = true, height = 60 })
	end
	DynamicLayout.compute(layout, 10)
	return ("\n"):rep(math.ceil((_G.y_end_dynamic + 10) / 14))
end

conky_core_main = function()
	if not conky_window then return end
	local w, h = conky_window.width, conky_window.height
	local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, w, h)
	local cr = cairo_create(cs)

	local usb_list = conky_usb_list()
	local draw = {}

	table.insert(draw, { type = "text", text = "USB dinamic demo", x = 20, y = 20,
		size = 16, weight = "bold", draw_me = #usb_list > 0,
		color = { { 1, "#ffffff", 1 } } })
	table.insert(draw, { type = "text", text = "(" .. #usb_list .. " device detected)", x = 20, y = 45,
		size = 11, draw_me = #usb_list > 0,
		color = { { 1, "#aaaaaa", 1 } } })

	local layout = {}
	for i, usb in ipairs(usb_list) do
		local name = "usb" .. i
		table.insert(layout, { name = name, enabled = true, height = 60 })
		table.insert(draw, { type = "text", name = name, x = 25, y = 5,
			text = usb.name .. "  " .. usb.mount, size = 12,
			color = { { 1, "#ffffff", 1 } } })
		table.insert(draw, { type = "bar", name = name, x = 25, y = 23,
			width = 350, height = 8, value = usb_disk_usage(usb.mount), max = 100,
			bg = { { 1, "#333333", 1 } },
			fg = { { 0, "#00ff88", 1 }, { 0.5, "#ffcc00", 1 }, { 1, "#ff0044", 1 } } })
	end
	DynamicLayout.compute(layout, 80)

	pcall(draw_background, cr, { type = "background", x = 0, y = 0, w = 0, h = 0, radius = 12,
		draw_me = #usb_list > 0,
		bg = { { 1, "#141618", 0.95 } } })

	for _, item in ipairs(draw) do
		cairo_save(cr)
		local slot_y = _G["y_start_" .. (item.name or "")] or 0
		local abs_y = slot_y + (item.y or 0)
		local fn = ({
			text = function() item.y = abs_y; draw_text(cr, item) end,
			bar = function() draw_bar_modules(cr, item, abs_y) end,
		})[item.type]
		if fn then pcall(fn) end
		cairo_restore(cr)
	end

	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end
