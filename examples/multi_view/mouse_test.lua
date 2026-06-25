-- mouse_test.lua — standalone minimal lua_mouse_hook test

require("cairo")
local ok, cx = pcall(require, "cairo_xlib")
if not ok then cx = _G end

local f = io.open("/tmp/conky_mouse_test.log", "w")
if f then f:write("lua loaded ok\n"); f:close() end

function conky_mouse_handler(event)
	local log = io.open("/tmp/conky_mouse_test.log", "a")
	if log then
		log:write("event: type=" .. tostring(event.type) .. " button=" .. tostring(event.button)
			.. " x=" .. tostring(event.x) .. " y=" .. tostring(event.y) .. "\n")
		log:close()
	end
end

function conky_core_main()
	if not conky_window then return end
	local updates = tonumber(conky_parse("${updates}")) or 0
	if updates < 3 then return end
	local w, h = conky_window.width, conky_window.height
	local cs = cx.cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, w, h)
	local cr = cairo_create(cs)

	cairo_set_source_rgba(cr, 0.1, 0.1, 0.18, 1)
	cairo_paint(cr)
	cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
	cairo_set_font_size(cr, 24)
	cairo_set_source_rgba(cr, 1, 1, 1, 1)
	cairo_move_to(cr, 50, 80)
	cairo_show_text(cr, "Click anywhere!")

	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end

function conky_cleanup()
end
