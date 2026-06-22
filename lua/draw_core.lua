--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
]]

-- ensure module path is available
local script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
package.path = package.path .. ";" .. script_dir .. "?.lua"

require("cairo")
local status, cairo_xlib = pcall(require, "cairo_xlib")
if not status then
	cairo_xlib = setmetatable({}, {
		__index = function(_, k)
			return _G[k]
		end,
	})
end

-- COMMON
--{{{

function draw_allowed(f)
	if f == nil or f == true then
		return true
	end
	if f == false then
		return false
	end
	if type(f) == "function" then
		local ok, r = pcall(f)
		return ok and (r == 1 or r == true or r == "1")
	end
	local s = tostring(f)
	if s:match("%$") then
		return conky_parse(s) == "1"
	end
	return s == "1"
end

function normalize_number(v)
	if v == nil then
		return 0
	end
	if type(v) == "number" then
		return v
	end
	if type(v) == "table" then
		return 0
	end
	local s = tostring(v):gsub(",", ".")
	local n = tonumber(s:match("([%d%.]+)"))
	return n or 0
end

function normalize_with_suffix(raw)
	if not raw then
		return 0
	end
	local s = tostring(raw):lower():gsub("%s+", "")
	local num = normalize_number(s)
	local suf = s:match("([kmg])$")
	if suf == "k" then
		return num * 1024
	end
	if suf == "m" then
		return num * 1024 ^ 2
	end
	if suf == "g" then
		return num * 1024 ^ 3
	end
	return num
end

function hex_to_rgba(hex, alpha)
	hex = tostring(hex):gsub("#", "")
	local r = tonumber(hex:sub(1, 2), 16) / 255
	local g = tonumber(hex:sub(3, 4), 16) / 255
	local b = tonumber(hex:sub(5, 6), 16) / 255
	return r, g, b, alpha or 1
end

function hex_to_rgb_components(col)
	if type(col) == "string" then
		col = tonumber(col:gsub("#", ""), 16)
	end
	local r = (col >> 16) & 0xFF
	local g = (col >> 8) & 0xFF
	local b = col & 0xFF
	return r / 255, g / 255, b / 255
end

function get_color_from_list(stops, t)
	if #stops == 1 then
		local _, col, a = stops[1][1], stops[1][2], stops[1][3]
		local r, g, b = hex_to_rgb_components(col)
		return r, g, b, a
	end
	for i = 1, #stops - 1 do
		local p1, col1, a1 = stops[i][1], stops[i][2], stops[i][3]
		local p2, col2, a2 = stops[i + 1][1], stops[i + 1][2], stops[i + 1][3]
		if t >= p1 and t <= p2 then
			local k = (t - p1) / (p2 - p1)
			local r1, g1, b1 = hex_to_rgb_components(col1)
			local r2, g2, b2 = hex_to_rgb_components(col2)
			local r = r1 + (r2 - r1) * k
			local g = g1 + (g2 - g1) * k
			local b = b1 + (b2 - b1) * k
			local a = a1 + (a2 - a1) * k
			return r, g, b, a
		end
	end
	local _, col, a = stops[#stops][1], stops[#stops][2], stops[#stops][3]
	local r, g, b = hex_to_rgb_components(col)
	return r, g, b, a
end

--}}}
-- MAIN
--{{{

function conky_core_main()
	if not conky_window then
		return
	end

	watcher.check()
	watcher.arm_reload()
	conky_update_nvidia_xml()
	conky_load_weather_data()
	conky_update_alerts()

	local updates = tonumber(conky_parse("${updates}")) or 0
	if updates < 3 then
		return
	end
	local w = conky_window.width
	local h = conky_window.height
	local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, w, h)
	local cr = cairo_create(cs)
	
	if layout and #layout > 0 then
		DynamicLayout.compute(layout, 0)
	end
	
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
			if fn then
				pcall(fn, cr, item)
			end
			cairo_restore(cr)
		end
	end
	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end

--}}}
