--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 30_hyphen.lua — Pure Lua hyphenation via LibreOffice .dic patterns
-- Loaded by 31_draw_text for automatic word hyphenation in wrapped text.

local hyphen = {}
hyphen.patterns = {}
hyphen.min_left = 2
hyphen.min_right = 2
local cache = {}

-- prefer lua-utf8 library if installed, else builtin utf8
local has_utf8_ext, utf8_ext = pcall(require, "lua-utf8")
if not has_utf8_ext then
	has_utf8_ext, utf8_ext = pcall(require, "utf8")
end
if has_utf8_ext and type(utf8_ext) == "table" then
	utf8 = utf8_ext
end

local has_utf8 = type(utf8) == "table" and type(utf8.charpattern) == "string"
local has_lfs = type(lfs) == "table"

local function iter_chars(s)
	if has_utf8 then
		return s:gmatch(utf8.charpattern)
	end
	return s:gmatch(".")
end

local function utf8_lower(s)
	if has_utf8_ext and utf8_ext.lower then
		return utf8_ext.lower(s)
	end
	local out = {}
	for ch in iter_chars(s) do
		out[#out + 1] = ch:lower()
	end
	return table.concat(out)
end

function hyphen.load(path)
	if not path then return false, "no path" end

	-- try to use cached parsed dictionary (check mtime if lfs available)
	local cached = cache[path]
	local mtime = nil
	if has_lfs and lfs then
		local attrs = lfs.attributes(path)
		mtime = attrs and attrs.modification
	end
	if cached then
		if cached.mtime and mtime and cached.mtime == mtime then
			hyphen.patterns = cached.patterns
			hyphen.min_left = cached.min_left
			hyphen.min_right = cached.min_right
			return true
		elseif not cached.mtime then
			hyphen.patterns = cached.patterns
			hyphen.min_left = cached.min_left
			hyphen.min_right = cached.min_right
			return true
		end
	end

	local f = io.open(path, "r")
	if not f then return false, "cannot open " .. path end

	local patterns = {}
	local min_left = 2
	local min_right = 2
	for ln_raw in f:lines() do
		local ln = ln_raw:gsub("^%s*(.-)%s*$", "%1")
		if ln ~= "" and not ln:match("^%%") and not ln:match("^UTF") then
			-- support both plain and COMPOUND-prefixed variants (some .dic files)
			local min = ln:match("COMPOUNDLEFTHYPHENMIN (%d+)") or ln:match("LEFTHYPHENMIN (%d+)")
			if min then min_left = tonumber(min) end
			local minr = ln:match("COMPOUNDRIGHTHYPHENMIN (%d+)") or ln:match("RIGHTHYPHENMIN (%d+)")
			if minr then min_right = tonumber(minr) end

			if not min and not minr then
				local chars = {}
				local levels = {}
				local byte_pos = 0
				for ch in iter_chars(ln) do
					local n = tonumber(ch)
					if n then
						levels[byte_pos] = math.max(levels[byte_pos] or 0, n)
					else
						byte_pos = byte_pos + #ch
						chars[#chars + 1] = ch
					end
				end
				if #chars > 0 then
					patterns[#patterns + 1] = {
						text = table.concat(chars),
						levels = levels,
					}
				end
			end
		end
	end
	f:close()

	-- cache parsed result
	cache[path] = { patterns = patterns, min_left = min_left, min_right = min_right, mtime = mtime }

	-- set active patterns
	hyphen.patterns = patterns
	hyphen.min_left = min_left
	hyphen.min_right = min_right
	return true
end

function hyphen.break_word(word)
	if #hyphen.patterns == 0 then return {} end

	local low = utf8_lower(word)
	local padded = "." .. low .. "."
	local n = #padded
	local points = {}
	for i = 1, n do points[i] = 0 end

	for _, pat in ipairs(hyphen.patterns) do
		local pos = 1
		while true do
			pos = padded:find(pat.text, pos)
			if not pos then break end
			for after_idx, lvl in pairs(pat.levels) do
				local bp = pos + after_idx
				if bp <= n and lvl > points[bp] then
					points[bp] = lvl
				end
			end
			pos = pos + 1
		end
	end

	local chars = {}
	local padded_starts = {}
	local word_starts = {}
	local sum_p = 2
	local sum_w = 1
	for ch in iter_chars(low) do
		chars[#chars + 1] = ch
		padded_starts[#chars] = sum_p
		word_starts[#chars] = sum_w
		sum_p = sum_p + #ch
		sum_w = sum_w + #ch
	end
	local char_count = #chars
	if char_count < 2 then return {} end

	local breaks = {}
	for char_idx = 1, char_count - 1 do
		local boundary_byte = padded_starts[char_idx] + #chars[char_idx]
		if points[boundary_byte] and points[boundary_byte] % 2 == 1 then
			if char_idx >= hyphen.min_left and char_count - char_idx >= hyphen.min_right then
				local end_byte = word_starts[char_idx] + #chars[char_idx] - 1
				breaks[#breaks + 1] = end_byte
			end
		end
	end

	return breaks
end

local function utf8_sub(s, byte_start, byte_end)
	if type(utf8) ~= "table" or not utf8.offset then
		return s:sub(byte_start, byte_end)
	end
	local len = #s
	if not byte_start or byte_start < 1 then byte_start = 1 end
	if byte_start > len then return "" end
	local p = utf8.offset(s, 0, byte_start)
	byte_start = p or 1
	if byte_end then
		if byte_end >= len then byte_end = len end
		local p2 = utf8.offset(s, 0, byte_end + 1)
		byte_end = (p2 and p2 - 1) or len
	end
	return s:sub(byte_start, byte_end)
end

function hyphen.insert_hyphens(word)
	local breaks = hyphen.break_word(word)
	if #breaks == 0 then return word end

	local parts = {}
	local prev = 1
	for _, end_byte in ipairs(breaks) do
		parts[#parts + 1] = utf8_sub(word, prev, end_byte)
		prev = end_byte + 1
	end
	parts[#parts + 1] = utf8_sub(word, prev)
	return table.concat(parts, "-")
end

return hyphen
