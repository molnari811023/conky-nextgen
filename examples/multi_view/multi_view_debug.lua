--[[
Multi-View Debug — writes mouse events to /tmp/conky_mouse.log
Run with: conky -c multi_view.conf -- lua_load = multi_view_debug.lua
--]]

local log = io.open("/tmp/conky_mouse.log", "w")
if log then
	log:write("conky_mouse_debug started\n")
	log:flush()
end

local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
package.path = package.path .. ";" .. script_dir .. "../../lua/?.lua"

require("cairo")
local ok, cairo_xlib = pcall(require, "cairo_xlib")
if not ok then
	cairo_xlib = setmetatable({}, {
		__index = function(_, k) return _G[k] end,
	})
end

require("24_draw_core")
require("25_draw_background")
require("28_draw_clock")
require("33_draw_calendar")
require("31_draw_text")
require("32_draw_lines")

local VIEWS = {
	{
		name = "Clock",
		draw = {
			{ type = "background", x = 10, y = 10, w = 380, h = 380, radius = 12,
				bg = { { 1, "#1a1a2e", 1 } }, border = { { 1, "#16213e", 1 } }, border_width = 1 },
			{ type = "clock", x = 200, y = 190, radius = 140,
				show_ticks = true, show_numbers = true, show_seconds = true, number_size = 16,
				bg = { { 0, "#0f3460", 1 }, { 1, "#1a1a2e", 1 } },
				border = { { 0, "#e94560", 0.6 }, { 1, "#533483", 0.6 } },
				tick_color = { { 0, "#ffffff", 0.8 }, { 1, "#cccccc", 0.8 } },
				number_color = { { 0, "#ffffff", 0.9 }, { 1, "#cccccc", 0.9 } },
				hour_color = { { 0, "#ffffff", 1 }, { 1, "#e0e0e0", 1 } },
				minute_color = { { 0, "#ffffff", 1 }, { 1, "#e0e0e0", 1 } },
				second_color = { { 0, "#e94560", 1 }, { 1, "#ff6b6b", 1 } },
				center_color = { { 0, "#e94560", 1 }, { 1, "#ff6b6b", 1 } }, center_radius = 6 },
		},
	},
	{
		name = "Calendar",
		draw = {
			{ type = "background", x = 10, y = 10, w = 380, h = 380, radius = 12,
				bg = { { 1, "#1a1a2e", 1 } }, border = { { 1, "#16213e", 1 } }, border_width = 1 },
			{ type = "calendar", x = 30, y = 20, cell_w = 46, row_h = 36,
				font = "Sans", size = 14, month_format = "year_month", show_weeknums = false,
				color_month = { { 0, "#e94560", 1 } },
				color_weekdays = { { 0, "#a0a0a0", 1 } },
				color_days = { { 0, "#ffffff", 0.9 }, { 1, "#cccccc", 0.9 } },
				color_today = { { 0, "#e94560", 1 }, { 1, "#ff6b6b", 1 } },
				color_outside = { { 0, "#444444", 0.4 } } },
		},
	},
}

local current_view = 1

function conky_mouse_handler(event)
	if not conky_window then return end

	if log then
		log:write("event type=" .. tostring(event.type) .. " button=" .. tostring(event.button)
			.. " x=" .. tostring(event.x) .. " y=" .. tostring(event.y)
			.. " w=" .. tostring(conky_window.width) .. " h=" .. tostring(conky_window.height) .. "\n")
		log:flush()
	end

	if event.type ~= "ButtonPress" and event.type ~= "ButtonRelease" then return end

	current_view = current_view + 1
	if current_view > #VIEWS then current_view = 1 end
end

function conky_core_main()
	if not conky_window then return end

	local updates = tonumber(conky_parse("${updates}")) or 0
	if updates < 3 then return end

	local w = conky_window.width
	local h = conky_window.height
	local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, w, h)
	local cr = cairo_create(cs)

	local items = VIEWS[current_view].draw
	if items then
		for _, item in ipairs(items) do
			cairo_save(cr)
			local fn = ({ background = draw_background, clock = draw_clock, calendar = draw_calendar })[item.type]
			if fn then pcall(fn, cr, item) end
			cairo_restore(cr)
		end
	end

	cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
	cairo_set_font_size(cr, 12)
	cairo_set_source_rgba(cr, 0.5, 0.5, 0.5, 0.6)
	local label = VIEWS[current_view].name .. "  [" .. current_view .. "/" .. #VIEWS .. "]"
	cairo_move_to(cr, 15, h - 10)
	cairo_show_text(cr, label)

	cairo_set_font_size(cr, 14)
	cairo_set_source_rgba(cr, 0.9, 0.3, 0.4, 0.7)
	local ext = cairo_text_extents_t:create()
	local tx = w / 2
	local ty = 24
	cairo_text_extents(cr, "click anywhere to switch", ext)
	cairo_move_to(cr, tx - ext.width / 2, ty)
	cairo_show_text(cr, "click anywhere to switch")

	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end

function conky_cleanup()
	if log then log:close() end
end
