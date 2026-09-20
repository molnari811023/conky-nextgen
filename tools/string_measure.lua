--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
tools/string_measure.lua — measurer: which language produces the longest string?

Dev tool, runs INSIDE Conky (cairo bindings live only there). Reads every
language/*.mo catalog in the project root, measures each key's pixel width
with cairo_text_extents() in the configured font/size and writes a report
next to this script. Run it with:

    cd ~/.conky
    conky -c tools/string_measure.conf  # exits after the first frame
    cat tools/string_measure.txt

The measurement happens in the first draw hook (the only point where the
Conky Lua state has a working cairo context). If KEYS is left empty, every
key present in any catalog is measured.
]]--

local tool_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local project_dir = tool_dir .. "../"

-- ═══ MEASURE CONFIG ═══
local FONT      = "Mono"     -- measure with this family
local FONT_SIZE = 13         -- measure with this size
local OUT       = tool_dir .. "string_measure.txt"
local KEYS      = {}         -- {} = measure all keys found in the catalogs
-- ═══════════════════════

local LANG_DIR = project_dir .. "language/"

local lfs = require("lfs")
cairo = require("cairo")

-- {{{ .mo minimal parser (same layout as lua/core/translate.lua)
local function load_mo(path, into)
	local f = io.open(path, "rb")
	if not f then return false end
	local data = f:read("*all")
	f:close()
	local magic = data:byte(1) | (data:byte(2) << 8) | (data:byte(3) << 16) | (data:byte(4) << 24)
	if magic ~= 0x950412de then return false end
	local num   = data:byte(9) | (data:byte(10) << 8) | (data:byte(11) << 16) | (data:byte(12) << 24)
	local o_off = data:byte(13) | (data:byte(14) << 8) | (data:byte(15) << 16) | (data:byte(16) << 24)
	local t_off = data:byte(17) | (data:byte(18) << 8) | (data:byte(19) << 16) | (data:byte(20) << 24)
	for i = 0, num - 1 do
		local base = o_off + i * 8
		local o_len = data:byte(base+1) | (data:byte(base+2) << 8) | (data:byte(base+3) << 16) | (data:byte(base+4) << 24)
		local o_pos = data:byte(base+5) | (data:byte(base+6) << 8) | (data:byte(base+7) << 16) | (data:byte(base+8) << 24)
		local key = data:sub(o_pos+1, o_pos + o_len)
		base = t_off + i * 8
		local t_len = data:byte(base+1) | (data:byte(base+2) << 8) | (data:byte(base+3) << 16) | (data:byte(base+4) << 24)
		local t_pos = data:byte(base+5) | (data:byte(base+6) << 8) | (data:byte(base+7) << 16) | (data:byte(base+8) << 24)
		into[key] = data:sub(t_pos+1, t_pos + t_len)
	end
	return true
end
-- }}}

-- {{{ load catalogs (module load time — no cairo needed yet)
local langs = {}
local lang_keys = {}
local iter, dir_obj, err = lfs.dir(LANG_DIR)
assert(iter, err)
for name in iter, dir_obj do
	if name:match("%.mo$") then
		local code = name:match("^(.*)%.mo$")
		local strings = {}
		if load_mo(LANG_DIR .. name, strings) then
			langs[code] = strings
			for k in pairs(strings) do lang_keys[k] = true end
		end
	end
end
-- }}}

-- {{{ target key list
local keys = {}
if #KEYS > 0 then
	for _, k in ipairs(KEYS) do
		if k ~= "" then keys[k] = true end
	end
else
	for k in pairs(lang_keys) do
		if k ~= "" then keys[k] = true end
	end
end
-- }}}

local _done = false

function conky_string_measure_main()
	if _done then return end
	_done = true

	local lines = {}

	local cs = conky_surface()
	local cr = cs and cairo_create(cs)
	if not cr then
		local fo = io.open(OUT, "w")
		if fo then fo:write("cairo nem elérhető\n"); fo:close() end
		return
	end

	cairo_select_font_face(cr, FONT, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
	cairo_set_font_size(cr, FONT_SIZE)
	local ext = cairo_text_extents_t:create()

	local measured = {}
	for k in pairs(keys) do
		local widths = {}
		for code, tbl in pairs(langs) do
			local txt = tbl[k]
			if txt == nil and langs.en then txt = langs.en[k] end
			if txt == nil or txt == "" then txt = k end
			cairo_text_extents(cr, txt, ext)
			widths[code] = math.floor(ext.width + 0.5)
		end
		measured[k] = widths
	end
	cairo_destroy(cr)

	local lang_list = {}
	for code in pairs(langs) do lang_list[#lang_list + 1] = code end
	table.sort(lang_list)

	lines[#lines + 1] = "string_measure — Conky NextGen"
	lines[#lines + 1] = "font: " .. FONT .. " | size: " .. FONT_SIZE .. "px"
	lines[#lines + 1] = "nyelvek (" .. #lang_list .. "): " .. table.concat(lang_list, ", ")
	lines[#lines + 1] = ""
	lines[#lines + 1] = "FELHASZNÁLT SZÉLESSÉG = a leghosszabb fordítás + kb. 8% ráhagyás"
	lines[#lines + 1] = ""

	local winners = {}
	local key_order = {}
	for k in pairs(measured) do key_order[#key_order + 1] = k end
	table.sort(key_order)

	for _, k in ipairs(key_order) do
		local w = measured[k]
		local sorted = {}
		for code, px in pairs(w) do sorted[#sorted + 1] = { code, px } end
		table.sort(sorted, function(a, b) return a[2] > b[2] end)
		local top = sorted[1]
		local longest_w = top and top[2] or 0
		if top then winners[top[1]] = (winners[top[1]] or 0) + 1 end

		local line = string.format("%-24s %5d px   %-5s |", k, longest_w, top and top[1] or "-")
		for _, e in ipairs(sorted) do
			line = line .. string.format(" %s:%3d", e[1], e[2])
		end
		lines[#lines + 1] = line
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "LEGGYAKRABBAN A LEGHOSSZABB NYELV:"
	local wsorted = {}
	for code, n in pairs(winners) do wsorted[#wsorted + 1] = { code, n } end
	table.sort(wsorted, function(a, b) return a[2] > b[2] end)
	for _, e in ipairs(wsorted) do
		lines[#lines + 1] = string.format("  %-6s %d kulcs", e[1], e[2])
	end

	local fo = io.open(OUT, "w")
	if fo then
		fo:write(table.concat(lines, "\n") .. "\n")
		fo:close()
	end
end