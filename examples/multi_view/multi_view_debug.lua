--[[
Multi-View Debug — writes mouse events to /tmp/conky_mouse.log
--]]

require("cairo")
local ok, cx = pcall(require, "cairo_xlib")
if not ok then cx = _G end

local f = io.open("/tmp/conky_mouse.log", "w")
if f then f:write("lua loaded ok\n"); f:close() end

local VIEWS = {
	{
		name = "Clock",
		draw = function(cr, w, h)
			local cx, cy, r = w / 2, h / 2 - 10, math.min(w, h) / 2 - 30
			for i = 0, 360 do
				local t = i / 360
				local rr = (1 - t) * 0.06 + t * 0.1
				local gg = (1 - t) * 0.2 + t * 0.16
				local bb = (1 - t) * 0.38 + t * 0.18
				cairo_set_source_rgba(cr, rr, gg, bb, 1)
				cairo_move_to(cr, cx, cy)
				cairo_arc(cr, cx, cy, r, math.rad(i), math.rad(i + 1))
				cairo_fill(cr)
			end
			cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
			cairo_set_font_size(cr, 16)
			for i = 1, 12 do
				local a = (i / 12) * 2 * math.pi
				local nx = cx + math.sin(a) * (r * 0.78)
				local ny = cy - math.cos(a) * (r * 0.78)
				cairo_set_source_rgba(cr, 1, 1, 1, 0.9)
				local ext = cairo_text_extents_t:create()
				cairo_text_extents(cr, tostring(i), ext)
				cairo_move_to(cr, nx - ext.width / 2, ny + ext.height / 2)
				cairo_show_text(cr, tostring(i))
			end
			local hh, mm, ss = tonumber(os.date("%I")), tonumber(os.date("%M")), tonumber(os.date("%S"))
			local ha = ((hh % 12) / 12 + mm / 720) * 2 * math.pi
			local ma = (mm / 60) * 2 * math.pi
			local function hand(ang, len, wdt, r, g, b)
				cairo_set_line_width(cr, wdt)
				cairo_set_source_rgba(cr, r, g, b, 1)
				cairo_move_to(cr, cx, cy)
				cairo_line_to(cr, cx + math.sin(ang) * len, cy - math.cos(ang) * len)
				cairo_stroke(cr)
			end
			hand(ha, r * 0.5, 4, 1, 1, 1)
			hand(ma, r * 0.7, 3, 1, 1, 1)
			hand((ss / 60) * 2 * math.pi, r * 0.85, 1, 0.91, 0.27, 0.38)
			cairo_set_source_rgba(cr, 0.91, 0.27, 0.38, 1)
			cairo_arc(cr, cx, cy, 5, 0, 2 * math.pi)
			cairo_fill(cr)
		end,
	},
	{
		name = "Calendar",
		draw = function(cr, w, h)
			local now = os.date("*t")
			local wd = tonumber(os.date("%w", os.time({ year = now.year, month = now.month, day = 1 }))) - 1
			if wd < 0 then wd = 6 end
			local dim = os.date("*t", os.time({ year = now.year, month = now.month + 1, day = 0 })).day
			local pdim = os.date("*t", os.time({ year = now.year, month = now.month, day = 0 })).day
			local cw, rh, x0, y0 = 44, 36, 30, 60

			cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
			cairo_set_font_size(cr, 20)
			cairo_set_source_rgba(cr, 0.91, 0.27, 0.38, 1)
			local mn = os.date("%Y %B")
			local ext = cairo_text_extents_t:create()
			cairo_text_extents(cr, mn, ext)
			cairo_move_to(cr, w / 2 - ext.width / 2, 35)
			cairo_show_text(cr, mn)

			cairo_set_font_size(cr, 13)
			cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
			local dnames = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" }
			for i = 0, 6 do
				cairo_set_source_rgba(cr, 0.7, 0.7, 0.7, 0.8)
				cairo_text_extents(cr, dnames[i + 1], ext)
				cairo_move_to(cr, x0 + i * cw + cw / 2 - ext.width / 2, y0 - 10)
				cairo_show_text(cr, dnames[i + 1])
			end

			local row, col, d = 0, 0, 1
			local function draw_day(n, r, g, b, a, bold)
				if bold then cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD)
				else cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL) end
				cairo_set_source_rgba(cr, r, g, b, a)
				cairo_text_extents(cr, tostring(n), ext)
				cairo_move_to(cr, x0 + col * cw + cw / 2 - ext.width / 2, y0 + row * rh + ext.height / 2)
				cairo_show_text(cr, tostring(n))
			end
			for i = 0, wd - 1 do
				col = i; draw_day(pdim - wd + i + 1, 0.3, 0.3, 0.3, 0.5, false)
			end
			col = wd
			while d <= dim do
				if col == 7 then col = 0; row = row + 1 end
				if d == now.day then draw_day(d, 0.91, 0.27, 0.38, 1, true)
				else draw_day(d, 1, 1, 1, 0.9, false) end
				d = d + 1; col = col + 1
			end
			local nd = 1
			while col < 7 do
				draw_day(nd, 0.3, 0.3, 0.3, 0.5, false)
				nd = nd + 1; col = col + 1
			end
		end,
	},
}

local current_view = 1

function conky_mouse_handler(event)
	local log = io.open("/tmp/conky_mouse.log", "a")
	if log then
		log:write("event: type=" .. tostring(event.type) .. " button=" .. tostring(event.button)
			.. " x=" .. tostring(event.x) .. " y=" .. tostring(event.y) .. "\n")
		log:close()
	end
	if not conky_window then return end
	current_view = current_view + 1
	if current_view > #VIEWS then current_view = 1 end
end

function conky_core_main()
	if not conky_window then return end
	local updates = tonumber(conky_parse("${updates}")) or 0
	if updates < 3 then return end
	local w, h = conky_window.width, conky_window.height
	local cs = cx.cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, w, h)
	local cr = cairo_create(cs)

	cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
	cairo_set_source_rgba(cr, 0.1, 0.1, 0.18, 1)
	cairo_paint(cr)

	VIEWS[current_view].draw(cr, w, h)

	cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
	cairo_set_font_size(cr, 12)
	cairo_set_source_rgba(cr, 0.5, 0.5, 0.5, 0.6)
	local lbl = VIEWS[current_view].name .. "  [" .. current_view .. "/" .. #VIEWS .. "]"
	cairo_move_to(cr, 15, h - 10)
	cairo_show_text(cr, lbl)

	cairo_destroy(cr)
	cairo_surface_destroy(cs)
end

function conky_cleanup()
end
