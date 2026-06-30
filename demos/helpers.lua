-- Demo data generators — shared across all demos

function conky_demo_sine()
	return math.floor(50 + 45 * math.sin(os.clock() * 1.5) + 0.5)
end

function conky_demo_ramp()
	return math.floor(((os.clock() * 10) % 10) / 10 * 100 + 0.5)
end

function conky_demo_random()
	math.randomseed(os.time() + math.floor(os.clock() * 1000))
	return math.random(5, 95)
end

-- Install a minimal conky_core_main for demos (no watcher/data deps)
-- Call this at the end of demo main.lua, after all module requires.
function demo_override_core_main()
	conky_core_main = function()
		if not conky_window then return end
		local w, h = conky_window.width, conky_window.height
		local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, w, h)
		local cr = cairo_create(cs)
		if draw then
			for _, item in ipairs(draw) do
				cairo_save(cr)
				local fn = ({
					background = draw_background,
					line = draw_line_modules,
					text = draw_text,
					bar = function() draw_bar_modules(cr, item, item.y) end,
					ring = draw_one_ring,
					image = draw_png,
					graph = draw_graph,
					calendar = draw_calendar,
					clock = draw_clock,
				})[item.type]
				if fn then pcall(fn, cr, item) end
				cairo_restore(cr)
			end
		end
		cairo_destroy(cr)
		cairo_surface_destroy(cs)
	end
end


