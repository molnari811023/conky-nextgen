--[[[
lua/draw/hyphen.lua — TeX-style hyphenation engine for breaking words at soft-hyphen points

Loads a standard TeX .dic pattern file, caches the parsed result per path,
and exposes a break_word() function that returns byte offsets for valid breaks.
]]--

--{{{
-- ## Hyphen
--
-- Implements a TeX-compatible hyphenation algorithm. Pattern files are parsed
-- once and cached (with optional mtime-based invalidation via lfs). The
-- break_word() function applies all loaded patterns to a lowercased copy of
-- the input, respects LEFTHYPHENMIN/RIGHTHYPHENMIN constraints, and returns
-- break byte-offsets that map back into the original (possibly mixed-case) word.
--
-- **Exposed/global functions:**
-- - `hyphen.load(path)` — Parses and loads a TeX .dic hyphenation pattern file; returns `true` on success.
-- - `hyphen.break_word(word)` — Returns an array of byte-offset break points for the given word.
--
-- **Config/globals used:**
-- - `lfs` (optional) — LuaFileSystem used for mtime-based cache invalidation.
-- - `utf8` (optional) — lua-utf8 or builtin utf8 module for UTF-8 character iteration.
--}}}

local hyphen = {}
hyphen.patterns = {}
hyphen.min_left = 2
hyphen.min_right = 2
local cache = {}

-- prefer lua-utf8 library if installed, else builtin utf8
local utf8_ext
if package.searchpath("lua-utf8", package.path) then
	utf8_ext = require("lua-utf8")
elseif package.searchpath("utf8", package.path) then
	utf8_ext = require("utf8")
end
if type(utf8_ext) == "table" then
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
	if utf8_ext and utf8_ext.lower then
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
						-- multi-digit TeX levels (e.g. "a12b") accumulate:
						-- each digit is one char, so append instead of max()
						levels[byte_pos] = (levels[byte_pos] or 0) * 10 + n
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
			pos = padded:find(pat.text, pos, true)
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

	local low_chars = {}
	local padded_starts = {}
	local sum_p = 2
	for ch in iter_chars(low) do
		low_chars[#low_chars + 1] = ch
		padded_starts[#low_chars] = sum_p
		sum_p = sum_p + #ch
	end
	local char_count = #low_chars
	if char_count < 2 then return {} end

	-- Byte offsets of the ORIGINAL word's characters. The pattern matching runs
	-- on the lowercased string, but the returned break offsets must slice the
	-- original word — lowercasing can change byte length (e.g. İ → i + ◌),
	-- so offsets are re-derived from `word`, never from `low`.
	local orig_chars = {}
	local orig_starts = {}
	local orig_count = 0
	local sum_w = 1
	for ch in iter_chars(word) do
		orig_count = orig_count + 1
		orig_starts[orig_count] = sum_w
		orig_chars[orig_count] = ch
		sum_w = sum_w + #ch
	end

	local breaks = {}
	for char_idx = 1, char_count - 1 do
		local boundary_byte = padded_starts[char_idx] + #low_chars[char_idx]
		if points[boundary_byte] and points[boundary_byte] % 2 == 1 then
			if char_idx >= hyphen.min_left and char_count - char_idx >= hyphen.min_right then
				if char_idx <= orig_count then
					local end_byte = orig_starts[char_idx] + #orig_chars[char_idx] - 1
					breaks[#breaks + 1] = end_byte
				end
			end
		end
	end

	return breaks
end

return hyphen
