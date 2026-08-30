--[[[
lua/draw/text.lua — Draws styled text with alignment, word-wrapping, and optional hyphenation

Text sources may be plain strings, functions, or exec-tables evaluated at draw
time. Conky ${...} syntax is parsed via conky_parse before rendering.
]]--

--{{{
-- ## Text
--
-- Renders a single text string or multi-line word-wrapped block onto the Cairo
-- context. Supports left/centre/right alignment, italic/bold slant/weight, and
-- a gradient colour applied per-line. When wrap_width is set, long words are
-- hyphenated using the hyphen module if a dictionary path is provided.
--
-- **Exposed/global functions:**
-- - `draw_text(cr, opts)` — Draws styled text (single or wrapped) and returns `{x, y, w, h}`.
--
-- **Config/globals used:**
-- - `conky_window` — checked for early-exit guard; centre alignment references its width/height.
-- - `conky_parse()` — expands Conky `${...}` substitution syntax in text strings.
-- - `build_gradient_pattern()` — creates a Cairo linear gradient from a color-stop list.
-- - `hyphen` — used for word-break hyphenation when `wrap_dic` is supplied.
--}}}

local _text_ext = cairo_text_extents_t:create()
local _font_ext = cairo_font_extents_t:create()

local TEXT_DEFAULT = {
	x = 0,
	y = 0,
	font = "Sans",
	size = 14,
	slant = "normal",
	weight = "normal",
	align = "left",
	text = "",
	wrap_width = nil,
	wrap_dic = nil,
	-- color: provided by the theme via apply_theme()
}
local function normalize_text(cfg)
	if not cfg or not cfg.text then
		return nil
	end
	local raw = cfg.text
	-- interpret_name table → exec at draw time
	if type(raw) == "table" and raw.exec then
		local result = raw.exec()
		if result then
			return tostring(result)
		end
		return nil
	end
	-- legacy compat: function() return X end
	if type(raw) == "function" then
		local result = raw()
		if result then
			return tostring(result)
		end
		return nil
	end
	-- plain text → conky_parse (Conky handles it)
	if not raw or raw == "" then
		return nil
	end
	return conky_parse(raw)
end

function draw_text(cr, opts)
	if not opts or not conky_window then
		return
	end
	-- must resolve defaults before draw_allowed (needs cfg.x, cfg.y etc.)
	local cfg = {}
	for k, v in pairs(TEXT_DEFAULT) do
		cfg[k] = v
	end
	for k, v in pairs(opts) do
		cfg[k] = v
	end
	if type(cfg.color) ~= "table" or #cfg.color == 0 then
		cfg.color = { { 1, "#a9b1d6", 1 } }
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

	local text_w, text_h = 0, 0
	if cfg.wrap_width and cfg.wrap_width > 0 then
		local line_height
		local obj = _font_ext
		cairo_font_extents(cr, obj)
		line_height = obj.height * 1.2

		local hyph
		if cfg.wrap_dic then
			hyph = hyphen
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
			local te = _text_ext
			cairo_text_extents(cr, test_line, te)
			if te.width <= cfg.wrap_width then
				current = test_line
			else
				if #current > 0 then
					lines[#lines + 1] = current
				end
				local we = _text_ext
				cairo_text_extents(cr, word, we)
				if we.width > cfg.wrap_width and hyph then
					current = ""
					local remaining = word
					while #remaining > 0 do
						local we2 = _text_ext
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
								local pe = _text_ext
								cairo_text_extents(cr, prefix, pe)
								if pe.width <= cfg.wrap_width then
									best_bp = bp
								else
									break
								end
							end
							local pe = _text_ext
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
								local pe = _text_ext
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
		text_w = cfg.wrap_width
		text_h = total_h
		local draw_y
		if cfg.y == "center" then
			draw_y = y - total_h / 2
		else
			draw_y = y
		end

		for _, line in ipairs(lines) do
			local le = _text_ext
			cairo_text_extents(cr, line, le)
			local line_x = x
			if cfg.align == "center" then
				line_x = x - le.width / 2
			elseif cfg.align == "right" then
				line_x = x - le.width
			end
			local line_y = draw_y - le.y_bearing
			local pat = build_gradient_pattern(cr, cfg.color, line_x, line_y, line_x + le.width, line_y)
			cairo_set_source(cr, pat)
			cairo_pattern_destroy(pat)
			cairo_move_to(cr, line_x, line_y)
			cairo_show_text(cr, line)
			draw_y = draw_y + line_height
		end
	else
		local ext = _text_ext
		cairo_text_extents(cr, txt, ext)
		text_w = ext.width
		text_h = ext.height
		if cfg.align == "center" then
			x = x - ext.width / 2
		elseif cfg.align == "right" then
			x = x - ext.width
		end
		y = y - ext.y_bearing
		local pat = build_gradient_pattern(cr, cfg.color, x, y, x + ext.width, y)
		cairo_set_source(cr, pat)
		cairo_pattern_destroy(pat)
		cairo_move_to(cr, x, y)
		cairo_show_text(cr, txt)
	end
	return { x = cfg.x, y = cfg.y, w = text_w, h = text_h }
end
