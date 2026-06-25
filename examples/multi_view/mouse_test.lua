-- mouse_test.lua
-- Minimal test for lua_mouse_hook

local f = io.open("/tmp/conky_mouse_test.log", "w")
if f then
	f:write("lua loaded ok\n")
	f:close()
end

function conky_mouse_handler(event)
	local log = io.open("/tmp/conky_mouse_test.log", "a")
	if log then
		log:write("event fired: " .. tostring(event) .. "\n")
		for k, v in pairs(event) do
			log:write("  " .. k .. " = " .. tostring(v) .. "\n")
		end
		log:close()
	end
end

function conky_core_main()
	if not conky_window then return end

	local updates = tonumber(conky_parse("${updates}")) or 0
	if updates < 3 then return end

	local w = conky_window.width
	local h = conky_window.height
	local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, w, h)
	local cr = cairo_create(cs)

	cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
	cairo_set_font_size(cr, 20)
	cairo_set_source_rgba(cr, 1, 1, 1, 1)

	local log = io.open("/tmp/conky_mouse_test.log", "a")
	if log then
		log:write("draw frame\n")
		log:close()
	end

	cairo_move_to(cr, 50, 50)
	cairo_show_text(cr, "Click me!")

	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end

function conky_cleanup()
end
