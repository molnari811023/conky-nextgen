--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/draw/lyrics.lua — synchronized lyrics block renderer (prev/current/next)

Draws a whole lyrics block in one draw item: a track header
(ARTIST — TITLE), a configurable number of dimmed previous lines, the
bright current line, dimmed following lines and a footer
(INDEX/TOTAL · mm:ss). Every lyric line is word-wrapped to opts.w, so
long lines never overflow the widget. Data comes from the
conky_lyrics_* provider functions (lua/songtext.lua reading
tmp/lyrics.json, written by lyrics_daemon.lua).
]]--

--{{{
-- ## Lyrics block
--
-- **Exposed/global functions:**
-- - `draw_lyrics(cr, opts)` — renders the lyrics block, returns `{x,y,w,h}`
--
-- **Item options (with defaults):**
-- - `x`, `y` — top-left corner (default 10, 10)
-- - `w` — wrap width / right edge for the footer (default 480)
-- - `font`, `size` — text font and size (default "Sans", 13)
-- - `prev`, `next` — how many previous/following lines to show (default 2)
-- - `header_color`, `current_color`, `prev_color`, `next_color`, `footer_color`
--
-- **Config/globals used:**
-- - `conky_lyrics_artist()`, `conky_lyrics_title()`, `conky_lyrics_prev()`,
--   `conky_lyrics_current()`, `conky_lyrics_next()`, `conky_lyrics_index()`,
--   `conky_lyrics_total()`, `conky_lyrics_position()`, `conky_lyrics_synced()`
-- - `build_gradient_pattern()`, `cairo_text_extents_t`
--}}}

local _text_ext = cairo_text_extents_t:create()
local _font_ext = cairo_font_extents_t:create()

local LYRICS_DEFAULT = {
	x = 10,
	y = 10,
	w = 480,
	font = "Sans",
	size = 13,
	prev = 2,
	next = 2,
	align = "left",
	line_gap = 3,
	header_color = { { 1, "#3daee9", 1 } },
	current_color = { { 1, "#fcfcfc", 1 } },
	prev_color = { { 1, "#a1a9b1", 0.8 } },
	next_color = { { 1, "#a1a9b1", 0.8 } },
	footer_color = { { 1, "#a1a9b1", 0.75 } },
}

local function hex(color)
	if type(color) ~= "table" then return "#fcfcfc" end
	local first = color[1] or color[#color]
	if type(first) ~= "table" then return "#fcfcfc" end
	return first[2] or "#fcfcfc"
end

-- Word-wrap txt to width; returns a list of visual line strings.
local function visual_lines(cr, txt, width)
	local out = {}
	local words = {}
	for w in txt:gmatch("%S+") do
		words[#words + 1] = w
	end
	local current = ""
	for _, word in ipairs(words) do
		local test_line = (#current == 0) and word or current .. " " .. word
		local te = _text_ext
		cairo_text_extents(cr, test_line, te)
		if te.width <= width then
			current = test_line
		else
			if #current > 0 then
				out[#out + 1] = current
			end
			local we = _text_ext
			cairo_text_extents(cr, word, we)
			if we.width > width then
				local remaining = word
				while #remaining > 0 do
					local bp, pos = 0, 0
					for ch in remaining:gmatch(utf8.charpattern) do
						pos = pos + #ch
						local pe = _text_ext
						cairo_text_extents(cr, remaining:sub(1, pos), pe)
						if pe.width <= width then bp = pos else break end
					end
					if bp > 0 then
						out[#out + 1] = remaining:sub(1, bp)
						remaining = remaining:sub(bp + 1)
					else
						out[#out + 1] = remaining
						break
					end
				end
				current = ""
			else
				current = word
			end
		end
	end
	if #current > 0 then
		out[#out + 1] = current
	end
	return out
end

-- Draw one line at baseline y. x is the anchor: left edge for
-- align=left, centre for align=center, right edge for align=right
-- (same semantics as lua/draw/text.lua). Returns the line width.
local function draw_line(cr, x, baseline_y, txt, stops, align)
	local te = _text_ext
	cairo_text_extents(cr, txt, te)
	local lx = x
	if align == "center" then
		lx = x - te.width / 2
	elseif align == "right" then
		lx = x - te.width
	end
	local pat = build_gradient_pattern(cr, stops, lx, baseline_y, lx + te.width, baseline_y)
	cairo_set_source(cr, pat)
	cairo_pattern_destroy(pat)
	cairo_move_to(cr, lx, baseline_y)
	cairo_show_text(cr, txt)
	return te.width
end

local function split_lines(s)
	if not s or s == "" then return {} end
	local t = {}
	for l in (s .. "\n"):gmatch("([^\n]*)\n") do
		if l ~= "" then t[#t + 1] = l end
	end
	return t
end

local function with_alpha(stops, alpha)
	if #stops == 0 then return { { 1, "#fcfcfc", 1 } } end
	local out = {}
	for _, stop in ipairs(stops) do
		local hex = (type(stop) == "table") and stop[2] or "#fcfcfc"
		out[#out + 1] = { 1, hex, alpha }
	end
	return out
end

function draw_lyrics(cr, opts)
	if not opts or not conky_window then return end

	local cfg = {}
	for k, v in pairs(LYRICS_DEFAULT) do cfg[k] = v end
	for k, v in pairs(opts) do cfg[k] = v end

	cairo_select_font_face(cr, cfg.font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
	cairo_set_font_size(cr, cfg.size)

	local fe = _font_ext
	cairo_font_extents(cr, fe)
	local line_h = fe.height * 1.25

	local artist = conky_lyrics_artist()
	local title = conky_lyrics_title()
	local current = conky_lyrics_current()
	local prev_lines = split_lines(conky_lyrics_prev())
	local next_lines = split_lines(conky_lyrics_next())
	local index = tonumber(conky_lyrics_index()) or 0
	local total = tonumber(conky_lyrics_total()) or 0
	local position = conky_lyrics_position()
	local status = conky_lyrics_status()

	-- Respect the requested prev/next counts
	if #prev_lines > cfg.prev then
		local start = #prev_lines - cfg.prev + 1
		local kept = {}
		for i = start, #prev_lines do kept[#kept + 1] = prev_lines[i] end
		prev_lines = kept
	end
	if #next_lines > cfg.next then
		local kept = {}
		for i = 1, cfg.next do
			if next_lines[i] then kept[#kept + 1] = next_lines[i] end
		end
		next_lines = kept
	end

	local h = 0
	local top = cfg.y
	local left = cfg.x
	local right = cfg.x + cfg.w

	-- Horizontal anchor per alignment (mirrors lua/draw/text.lua)
	local anchor
	if cfg.align == "center" then
		anchor = (left + right) / 2
	elseif cfg.align == "right" then
		anchor = right
	else
		anchor = left
	end

	-- Header: ARTIST — TITLE
	local header = ""
	if artist ~= "" or title ~= "" then
		header = artist .. " — " .. title
	end
	if #header > 0 then
		for _, line in ipairs(visual_lines(cr, header, cfg.w)) do
			local te = _text_ext
			cairo_text_extents(cr, line, te)
			draw_line(cr, anchor, top - te.y_bearing, line, cfg.header_color, cfg.align)
			top = top + line_h
			h = top - cfg.y
		end
		top = top + cfg.line_gap
		h = top - cfg.y
	end

	-- Previous lines (dim, fading further back)
	local pn = #prev_lines
	for i, line in ipairs(prev_lines) do
		local dist = pn - i
		local alpha = math.max(0.35, 0.9 - dist * 0.2)
		local stops = with_alpha(cfg.prev_color, alpha)
		for _, wrapped in ipairs(visual_lines(cr, line, cfg.w)) do
			local te = _text_ext
			cairo_text_extents(cr, wrapped, te)
			draw_line(cr, anchor, top - te.y_bearing, wrapped, stops, cfg.align)
			top = top + line_h
			h = top - cfg.y
		end
	end
	top = top + cfg.line_gap
	h = top - cfg.y

	-- Current line (bright)
	if #current > 0 then
		for _, wrapped in ipairs(visual_lines(cr, current, cfg.w)) do
			local te = _text_ext
			cairo_text_extents(cr, wrapped, te)
			draw_line(cr, anchor, top - te.y_bearing, wrapped, cfg.current_color, cfg.align)
			top = top + line_h
			h = top - cfg.y
		end
	end
	top = top + cfg.line_gap
	h = top - cfg.y

	-- Next lines (dim, fading further ahead)
	for i, line in ipairs(next_lines) do
		local dist = i - 1
		local alpha = math.max(0.35, 0.9 - dist * 0.2)
		local stops = with_alpha(cfg.next_color, alpha)
		for _, wrapped in ipairs(visual_lines(cr, line, cfg.w)) do
			local te = _text_ext
			cairo_text_extents(cr, wrapped, te)
			draw_line(cr, anchor, top - te.y_bearing, wrapped, stops, cfg.align)
			top = top + line_h
			h = top - cfg.y
		end
	end

	-- Footer: INDEX/TOTAL · POSITION (right aligned)
	local footer = ""
	if total > 0 then
		footer = index .. "/" .. total .. " · " .. position
	elseif #header > 0 and status == "Loading" then
		footer = "· · ·"
	elseif #header > 0 and current == "" then
		footer = "nincs szinkronizált dalszöveg"
	end
	if #footer > 0 then
		local te = _text_ext
		cairo_text_extents(cr, footer, te)
		draw_line(cr, right, top - te.y_bearing, footer, cfg.footer_color, "right")
		cairo_move_to(cr, 0, 0)
	end

	return { x = cfg.x, y = cfg.y, w = cfg.w, h = h }
end