--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/core/translate.lua — gettext-style string translation from GNU .mo catalogs

Loads GNU .mo message catalogs for the active locale (resolved from LANG /
LC_ALL / LC_MESSAGES, falling back to English) plus the English catalog as a
guaranteed fallback, sets the time locale from LC_TIME/LANG, and exposes a
conky_get_tr() lookup plus a backward-compatible get_tr alias.
]]--

--{{{
-- ## Translate
--
-- Translation support for widget strings. Binary GNU .mo catalogs are parsed
-- for the detected locale (and English as a fallback when different). The
-- process time locale is also set up from LC_TIME/LANG. Exposes conky_get_tr
-- for msgid lookup (mo → en → msgid itself) and a get_tr alias used by older
-- widgets.
--
-- **Exposed/global functions:**
-- - `conky_get_tr(msgid)` — return the translated string for msgid, else the msgid itself
-- - `get_tr(msgid)` — backward-compatible alias of conky_get_tr
--
-- **Config/globals used:**
-- - `STRINGS_MO_PATH` — path to the active .mo catalog (auto-resolved if unset)
-- - `script_dir` — base directory for the language/*.mo catalogs
-- - `LANG`, `LC_ALL`, `LC_MESSAGES`, `LC_TIME` — environment for locale detection
--}}}

local mo_strings = {}
local en_strings = {}
local function load_mo(path, into)
	local f = io.open(path, "rb")
	if not f then return end
	local data = f:read("*all")
	f:close()
	local magic = data:byte(1) | (data:byte(2) << 8) | (data:byte(3) << 16) | (data:byte(4) << 24)
	if magic ~= 0x950412de then return end
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
end

if not STRINGS_MO_PATH then
	-- Resolve the locale here (not in settings.lua) — it is a translation
	-- concern. widget.lua only provides script_dir.
	local lang_raw = os.getenv("LANG") or os.getenv("LC_ALL") or os.getenv("LC_MESSAGES") or "en"
	local lang_code = lang_raw:sub(1, 2):lower()
	local lang_path = script_dir .. "language/" .. lang_code .. ".mo"
	local f = io.open(lang_path, "rb")
	if f then
		f:close()
		STRINGS_MO_PATH = lang_path
	else
		STRINGS_MO_PATH = script_dir .. "language/en.mo"
	end
end

-- Time locale: resolve from the system, not hardcoded. os.setlocale() needs
-- an installed locale, so try full → encoding-stripped → short code → "C".
local time_raw = os.getenv("LC_TIME") or os.getenv("LC_ALL") or os.getenv("LANG")
if time_raw and time_raw ~= "" then
	if os.setlocale(time_raw, "time") then
		-- ok, installed as-is
	else
		local base = time_raw:match("^([^%.]+)")
		if base and os.setlocale(base, "time") then
			-- ok, without the encoding part
		else
			local short = base and base:match("^([^_]+)")
			if not (short and os.setlocale(short, "time")) then
				os.setlocale("C", "time")
			end
		end
	end
end

if STRINGS_MO_PATH then
	load_mo(STRINGS_MO_PATH, mo_strings)
	-- English is the guaranteed complete fallback. Only load it when the
	-- active language is not English itself.
	local en_path = STRINGS_MO_PATH:gsub("[^/]*%.mo$", "en.mo")
	if en_path ~= STRINGS_MO_PATH then
		load_mo(en_path, en_strings)
	end
end

if not conky_get_tr then
	function conky_get_tr(msgid)
		local s = mo_strings[msgid]
		if s ~= nil and s ~= "" then return s end
		s = en_strings[msgid]
		if s ~= nil and s ~= "" then return s end
		return msgid or ""
	end
end

-- Backward-compatible alias (older widgets use get_tr(...))
get_tr = conky_get_tr

return true
