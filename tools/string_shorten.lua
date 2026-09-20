--[[[
tools/string_shorten.lua — ahol rövidíteni lehet a fordításokban?

Dev tool, standalone (nem kell conky). Végigolvassa a projekt
language/*.mo katalógusait és kimutatja:

  1. a leghosszabb fordításokat karakter-számmal (top lista),
  2. kulcsonként a leghosszabb fordítást (és mennyivel hosszabb az EN-nél),
     hogy meglássuk, hol "dagadtak" szét a nyelvek,
  3. a 30+ karakteres kulcsokat — ezek a rövidítés elsődleges jelöltjei.

Futtatás:  cd ~/.conky && lua tools/string_shorten.lua
]]--

local tool_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local project_dir = tool_dir .. "../"
local LANG_DIR = project_dir .. "language/"
local OUT_FILE = tool_dir .. "string_shorten.txt"

local lfs = require("lfs")

local function chars(s)
	local n = utf8.len(s)
	return n or #s
end

-- {{{ .mo minimal parser
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

local langs = {}
local iter, dir_obj, err = lfs.dir(LANG_DIR)
assert(iter, err)
for name in iter, dir_obj do
	if name:match("%.mo$") then
		local code = name:match("^(.*)%.mo$")
		local strings = {}
		if load_mo(LANG_DIR .. name, strings) then
			langs[code] = strings
		end
	end
end

local all_texts = {}        -- { hossz, nyelv, kulcs, szöveg }
local per_key = {}          -- kulcs -> { maxlen, lang, text }
local keys_30 = {}          -- kulcs -> { maxlen, lang, text }

for code, strings in pairs(langs) do
	for raw_k, txt in pairs(strings) do
		local k = raw_k
		if k == "" then k = "(fejléc)" end
		local n = chars(txt)
		if txt:len() > 0 and not txt:match("^%s*$") then
			all_texts[#all_texts + 1] = { n, code, k, txt }
		end
		local cur = per_key[k]
		if not cur or n > cur[1] then
			per_key[k] = { n, code, txt }
		end
		if k ~= "(fejléc)" then
			local c30 = keys_30[k]
			if not c30 or n > c30[1] then
				if n >= 30 then keys_30[k] = { n, code, txt } end
			end
		end
	end
end

table.sort(all_texts, function(a, b) return a[1] > b[1] end)

local lines = {}
lines[#lines + 1] = "string_shorten — hol lehet rövidíteni a fordításokban?"
lines[#lines + 1] = "nyelvek: " .. table.concat(langs and (function()
	local t = {}
	for c in pairs(langs) do t[#t + 1] = c end
	table.sort(t)
	return t
end)() or {}, ", ")
lines[#lines + 1] = ""

-- 1) top 40 leghosszabb fordítás
lines[#lines + 1] = "══ 1) A 40 LEGHOSSZABB FORDÍTÁS (karakter) ══"
for i = 1, math.min(40, #all_texts) do
	local n, c, k, txt = all_texts[i][1], all_texts[i][2], all_texts[i][3], all_texts[i][4]
	local shown = txt:gsub("\n", "\\n")
	if shown:len() > 78 then shown = shown:sub(1, 75) .. "…" end
	lines[#lines + 1] = string.format("%3d. %4d  %-6s %-24s %s", i, n, c, k, shown)
end

lines[#lines + 1] = ""
lines[#lines + 1] = "══ 2) A LEEGHOSSZABB (30+ karakteres) KULCSOK — rövidítés jelöltjei ══"
local ksorted = {}
for k, v in pairs(keys_30) do ksorted[#ksorted + 1] = { k, v[1] } end
table.sort(ksorted, function(a, b) return a[2] > b[2] end)
for _, e in ipairs(ksorted) do
	local k = e[1]
	local n, c, txt = keys_30[k][1], keys_30[k][2], keys_30[k][3]
	local shown = txt:gsub("\n", "\\n")
	if shown:len() > 78 then shown = shown:sub(1, 75) .. "…" end
	lines[#lines + 1] = string.format("%4d  %-6s %-24s %s", n, c, k, shown)
end

lines[#lines + 1] = ""
lines[#lines + 1] = "══ 3) MENNYIVEL HOSSZABB A LEGHOSSZABB AZ EN-NÉL (kulcsonként) ══"
local en = langs.en
local ratios = {}
for k, v in pairs(per_key) do
	if k ~= "(fejléc)" and en and en[k] then
		local enl = chars(en[k])
		if enl > 0 and v[1] > enl then
			ratios[#ratios + 1] = { k, v[1] - enl, v[1], enl, v[2] }
		end
	end
end
table.sort(ratios, function(a, b) return a[2] > b[2] end)
for i = 1, math.min(30, #ratios) do
	local e = ratios[i]
	local shown = per_key[e[1]][3]:gsub("\n", "\\n")
	if shown:len() > 60 then shown = shown:sub(1, 57) .. "…" end
	lines[#lines + 1] = string.format("+%4d  (max %4d vs en %4d)  %-6s %-24s %s",
		e[2], e[3], e[4], e[5], e[1], shown)
end

local txt = table.concat(lines, "\n") .. "\n"
print(txt)
local f = io.open(OUT_FILE, "w")
if f then f:write(txt); f:close() end
print(">>> mentve: " .. OUT_FILE)