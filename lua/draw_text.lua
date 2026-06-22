-- TEXTS
--{{{
local TEXT_DEFAULT = {
	x = 0,
	y = 0,
	font = "Sans",
	size = 14,
	slant = "normal",
	weight = "normal",
	align = "left",
	text = "",
	color = {
		{ 0.0, 0xFFFFFF, 1 },
		{ 1.0, 0xCCCCCC, 1 },
	},
	wrap_width = nil,
	wrap_dic = nil,
}
function normalize_text(cfg)
	if not cfg or not cfg.text then
		return nil
	end
	local txt = conky_parse(cfg.text)
	if not txt or txt == "" then
		return nil
	end
	return txt
end

function draw_text(cr, opts)
	if not opts or not draw_allowed(opts.draw_me) or not conky_window then
		return
	end
	local cfg = {}
	for k, v in pairs(TEXT_DEFAULT) do
		cfg[k] = v
	end
	for k, v in pairs(opts) do
		cfg[k] = v
	end
	if type(cfg.color) ~= "table" or #cfg.color == 0 then
		cfg.color = TEXT_DEFAULT.color
	end
	local txt = normalize_text(cfg)
	if not txt then
		return
	end
	local slant = (cfg.slant == "italic") and CAIRO_FONT_SLANT_ITALIC or CAIRO_FONT_SLANT_NORMAL
	local weight = (cfg.weight == "bold") and CAIRO_FONT_WEIGHT_BOLD or CAIRO_FONT_WEIGHT_NORMAL
	cairo_select_font_face(cr, cfg.font, slant, weight)
	cairo_set_font_size(cr, cfg.size)
	local x = cfg.x
	local y = cfg.y
	if x == "center" then
		x = conky_window.width / 2
	end
	if y == "center" then
		y = conky_window.height / 2
	end

	if cfg.wrap_width and cfg.wrap_width > 0 then
		local line_height
		local ok, fe = pcall(function()
			local obj = cairo_font_extents_t:create()
			cairo_font_extents(cr, obj)
			return obj.height * 1.2
		end)
		if ok then
			line_height = fe
		else
			line_height = cfg.size * 1.4
		end

		local hyph
		if cfg.wrap_dic then
			hyph = require("hyphen")
			local ok = hyph.load(cfg.wrap_dic)
			if not ok then hyph = nil end
		end

		local words = {}
		for w in txt:gmatch("%S+") do
			words[#words + 1] = w
		end

		local lines = {}
		local current = ""
		for _, word in ipairs(words) do
			local test_line = (#current == 0) and word or current .. " " .. word
			local te = cairo_text_extents_t:create()
			cairo_text_extents(cr, test_line, te)
			if te.width <= cfg.wrap_width then
				current = test_line
			else
				if #current > 0 then
					lines[#lines + 1] = current
				end
				local we = cairo_text_extents_t:create()
				cairo_text_extents(cr, word, we)
				if we.width > cfg.wrap_width and hyph then
					current = ""
					local remaining = word
					while #remaining > 0 do
						local we2 = cairo_text_extents_t:create()
						cairo_text_extents(cr, remaining, we2)
						if we2.width <= cfg.wrap_width then
							current = remaining
							break
						end
						local breaks = hyph.break_word(remaining)
						local best_bp
						if breaks and #breaks > 0 then
							best_bp = breaks[1]
							for _, bp in ipairs(breaks) do
								local prefix = remaining:sub(1, bp) .. "-"
								local pe = cairo_text_extents_t:create()
								cairo_text_extents(cr, prefix, pe)
								if pe.width <= cfg.wrap_width then
									best_bp = bp
								else
									break
								end
							end
							local pe = cairo_text_extents_t:create()
							cairo_text_extents(cr, remaining:sub(1, best_bp) .. "-", pe)
							if pe.width > cfg.wrap_width then
								best_bp = nil
							end
						end
						if best_bp then
							local prefix = remaining:sub(1, best_bp) .. "-"
							lines[#lines + 1] = prefix
							remaining = remaining:sub(best_bp + 1)
						else
							local b_idx = 0
							local byte_pos = 0
							for ch in remaining:gmatch(utf8.charpattern) do
								byte_pos = byte_pos + #ch
								local test_part = remaining:sub(1, byte_pos) .. "-"
								local pe = cairo_text_extents_t:create()
								cairo_text_extents(cr, test_part, pe)
								if pe.width <= cfg.wrap_width then
									b_idx = byte_pos
								else
									break
								end
							end
							if b_idx > 0 then
								lines[#lines + 1] = remaining:sub(1, b_idx) .. "-"
								remaining = remaining:sub(b_idx + 1)
							else
								current = remaining
								break
							end
						end
					end
				else
					current = word
				end
			end
		end
		if #current > 0 then
			lines[#lines + 1] = current
		end

		local total_h = #lines * line_height
		local draw_y
		if cfg.y == "center" then
			draw_y = y - total_h / 2
		else
			draw_y = y
		end

		for _, line in ipairs(lines) do
			local le = cairo_text_extents_t:create()
			cairo_text_extents(cr, line, le)
			local line_x = x
			if cfg.align == "center" then
				line_x = x - le.width / 2
			elseif cfg.align == "right" then
				line_x = x - le.width
			end
			local line_y = draw_y - le.y_bearing
			local pat = cairo_pattern_create_linear(line_x, line_y, line_x + le.width, line_y)
			for _, stop in ipairs(cfg.color) do
				local pos, hex, alpha = stop[1], stop[2], stop[3]
				local r, g, b, a = hex_to_rgba(hex, alpha)
				cairo_pattern_add_color_stop_rgba(pat, pos, r, g, b, a)
			end
			cairo_set_source(cr, pat)
			cairo_pattern_destroy(pat)
			cairo_move_to(cr, line_x, line_y)
			cairo_show_text(cr, line)
			draw_y = draw_y + line_height
		end
	else
		local ext = cairo_text_extents_t:create()
		cairo_text_extents(cr, txt, ext)
		if cfg.align == "center" then
			x = x - ext.width / 2
		elseif cfg.align == "right" then
			x = x - ext.width
		end
		y = y - ext.y_bearing
		local pat = cairo_pattern_create_linear(x, y, x + ext.width, y)
		for _, stop in ipairs(cfg.color) do
			local pos, hex, alpha = stop[1], stop[2], stop[3]
			local r, g, b, a = hex_to_rgba(hex, alpha)
			cairo_pattern_add_color_stop_rgba(pat, pos, r, g, b, a)
		end
		cairo_set_source(cr, pat)
		cairo_pattern_destroy(pat)
		cairo_move_to(cr, x, y)
		cairo_show_text(cr, txt)
	end
end

--}}}
