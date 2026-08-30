--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/core/utils.lua — shared helpers: colors, gradients, numbers, safe access, I/O, name interpretation

A general-purpose utility library used across the widget set. Provides hex and
OKLab color conversion with cached, bounded-cache helpers; normalized and
perceptually-interpolated gradient stops plus cairo gradient pattern building;
number/suffix normalization and safe accessors (num/str/tbl with logging); a
rounded-rect path builder; a file reader; option-aware number formatting; and
auto-interpretation of widget name/value fields into callable Lua or Conky
expressions.
]]--

--{{{
-- ## Utils
--
-- Broad helper library. Named global functions include color conversion and
-- gradient utilities (hex_to_rgba, get_color_from_list, build_gradient_pattern),
-- a rounded-rectangle path builder, a bounded cache setter, a general defaults
-- merger, number normalization/formatting, a file reader, safe accessors that
-- log through conky_log, and the draw-value/name interpreters used by the draw
-- core. Lower-level conversions (OKLab, stop normalization, component caching)
-- are internal to the module.
--
-- **Exposed/global functions:**
-- - `cache_set(cache, key, value, max)` — store into a bounded cache, clearing it when over `max`
-- - `apply_defaults(cfg, defaults)` — merge tables, defaults filling missing keys
-- - `hex_to_rgba(hex, alpha)` — convert a hex color to r,g,b,a floats (0-1)
-- - `get_color_from_list(stops, t)` — interpolate gradient stops at t via OKLab
-- - `build_gradient_pattern(cr, stops, x1,y1,x2,y2)` — build a cairo linear gradient from sampled stops
-- - `rounded_rect_path(cr, x, y, w, h, r)` — append a rounded rectangle path
-- - `normalize_with_suffix(raw)` — parse a number with optional K/M/G suffix
-- - `format_value(v, opts)` — format a number with decimals/suffix/multiplier
-- - `round(v)` — round to nearest integer
-- - `read_file(path)` — read a file's contents ("" if missing), trimming trailing space
-- - `safe_num(v, name)` — coerce to a number, logging and defaulting to 0 on bad input
-- - `safe_str(v, name)` — coerce to a string, logging and defaulting to "N/A"
-- - `draw_get_value(m)` — resolve a widget's value to a plain string
-- - `interpret_name(name)` — interpret a name with "()" as Lua, otherwise Conky template
--
-- **Config/globals used:**
-- - `conky_log` — logging hook, used by the safe accessors
-- - `conky_parse` — Conky template expansion used by the Conky name interpreter
--}}}

--{{{
-- ═══ HELPER FUNCTIONS ═══
-- Color handling:
--   hex_to_rgba(hex, alpha)          → r, g, b, a (0-1)
--   hex_to_rgb_components(col)       → r, g, b (cached)
--   normalize_stops(stops)           → sorted/clamped/deduped stops
--   get_color_from_list(stops, t)    → r, g, b, a (OKLab interpolation)
--     Interpolate a gradient stop list at position t (0-1) and return
--     the rgba components (0-1 each). Uses OKLab interpolation for
--     perceptually even color transitions.
--   build_gradient_pattern(cr, stops, x1,y1, x2,y2) → cairo_pattern (OKLab)
--
-- Drawing:
--   rounded_rect_path(cr, x, y, w, h, r) — rounded rectangle path
--   apply_defaults(cfg, defaults)         → merged tables
--
-- Number conversion:
--   normalize_number(v)            → number (string/table handling)
--   normalize_with_suffix(raw)     → number (K/M/G suffix)
--
-- Safe functions:
--   safe_num(v, name)  → number (0 if nil/NaN/invalid)
--   safe_str(v, name)  → string ("N/A" if nil/empty)
--   safe_tbl(v, name)  → table  ({} if nil)
--
-- Auto-interpretation:
--   interpret_name(name) → { type, value, exec }
--     has "()" → Lua function (load)
--     else     → conky_parse
--   draw_get_value(m) → string (interpret_name/string/name-arg)
--     Resolve a widget's `value` field to a plain string: if it is a
--     function/expression ending in () it is called, otherwise it is
--     passed through conky_parse for template expansion.
--
-- Theme: see the THEMES block in widget.lua for palette, gradients, widget defaults
--
-- Usage:
--   local r,g,b,a = hex_to_rgba("#7aa2f7", 0.8)
--   local val = normalize_with_suffix("4.2G")  -- → 4509715660.8
--   safe_num(nil, "test")  -- → 0 + log
--   interpret_name("os.date('%H:%M')") → { type="lua", exec=fn }
--   interpret_name("${cpu}")           → { type="conky", exec=fn }
--}}}

-- ═══ BOUNDED CACHE ═══
-- Prevents unbounded growth: when the cache exceeds max entries,
-- it is cleared entirely (safe for keyed caches of fixed-size resources).

function cache_set(cache, key, value, max)
    if not cache then return value end
    max = max or 256
    if cache._count == nil then
        cache._count = 0
    end
    if cache[key] == nil then
        cache._count = cache._count + 1
    end
    if cache._count > max then
        for k in pairs(cache) do
            if k ~= "_count" then cache[k] = nil end
        end
        cache._count = 1
    end
    cache[key] = value
    return value
end

function apply_defaults(cfg, defaults)
    local out = {}
    for k, v in pairs(cfg) do
        out[k] = v
    end
    for k, v in pairs(defaults) do
        if out[k] == nil then
            out[k] = v
        end
    end
    return out
end

function hex_to_rgba(hex, alpha)
    hex = tostring(hex):gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return r, g, b, alpha or 1
end

local _hex_cache = {}
local function hex_to_rgb_components(col)
    local cached = _hex_cache[col]
    if cached then return cached[1], cached[2], cached[3] end
    local val = col
    if type(col) == "string" then
        val = tonumber(col:gsub("#", ""), 16)
    end
    local r = ((val >> 16) & 0xFF) / 255
    local g = ((val >> 8) & 0xFF) / 255
    local b = (val & 0xFF) / 255
    _hex_cache[col] = { r, g, b }
    return r, g, b
end

-- ═══ COLOR CONVERSIONS (OKLab) ═══
-- Perceptual color space: gamma-correct sRGB is a bad space to interpolate
-- in (muddy midpoints + banding on dark pairs). Stops are converted to OKLab,
-- interpolated there, then converted back.

local function srgb_to_linear(c)
    if c <= 0.04045 then
        return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
end

local function linear_to_srgb(c)
    if c <= 0.0031308 then
        return 12.92 * c
    end
    return 1.055 * (c ^ (1 / 2.4)) - 0.055
end

local function srgb_to_oklab(r, g, b)
    r, g, b = srgb_to_linear(r), srgb_to_linear(g), srgb_to_linear(b)
    local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = l ^ (1 / 3), m ^ (1 / 3), s ^ (1 / 3)
    local L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
    local a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    local bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return L, a, bb
end

local function oklab_to_srgb(L, a, bb)
    local l = L + 0.3963377774 * a + 0.2158037573 * bb
    local m = L - 0.1055613458 * a - 0.0638541728 * bb
    local s = L - 0.0894841775 * a - 1.2914855480 * bb
    l, m, s = l ^ 3, m ^ 3, s ^ 3
    local r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    local g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    local b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return linear_to_srgb(r), linear_to_srgb(g), linear_to_srgb(b)
end

local _oklab_cache = {}
local function hex_to_oklab(col)
    local cached = _oklab_cache[col]
    if cached then return cached[1], cached[2], cached[3] end
    local r, g, b = hex_to_rgb_components(col)
    local L, a, bb = srgb_to_oklab(r, g, b)
    _oklab_cache[col] = { L, a, bb }
    return L, a, bb
end

-- ═══ GRADIENT STOPS ═══

-- Sort stops by position, clamp to [0,1], merge duplicate positions
-- (keeps the later stop). Fixes out-of-order/overlapping gradients such as
-- bg = { {0.5, ...}, {1.0, ...}, {0.0, ...} }.
local function normalize_stops(stops)
    local out = {}
    if type(stops) ~= "table" then
        return { { 0, "#ffffff", 1 } }
    end
    for _, s in ipairs(stops) do
        local pos, col, a = s[1], s[2], s[3]
        if type(pos) == "number" and type(col) == "string" then
            out[#out + 1] = { math.max(0, math.min(1, pos)), col, a or 1 }
        end
    end
    table.sort(out, function(x, y) return x[1] < y[1] end)
    local merged = {}
    for _, s in ipairs(out) do
        local n = #merged
        if n > 0 and merged[n][1] == s[1] then
            merged[n] = s
        else
            merged[#merged + 1] = s
        end
    end
    if #merged == 0 then
        return { { 0, "#ffffff", 1 } }
    end
    return merged
end

function get_color_from_list(stops, t)
    local s = normalize_stops(stops)
    if #s == 1 then
        local col, a = s[1][2], s[1][3]
        local r, g, b = hex_to_rgb_components(col)
        return r, g, b, a
    end
    for i = 1, #s - 1 do
        local p1, col1, a1 = s[i][1], s[i][2], s[i][3]
        local p2, col2, a2 = s[i + 1][1], s[i + 1][2], s[i + 1][3]
        if t >= p1 and t <= p2 then
            local k = (t - p1) / (p2 - p1)
            local L1, aL1, bL1 = hex_to_oklab(col1)
            local L2, aL2, bL2 = hex_to_oklab(col2)
            local L = L1 + (L2 - L1) * k
            local ac = aL1 + (aL2 - aL1) * k
            local bc = bL1 + (bL2 - bL1) * k
            local r, g, b = oklab_to_srgb(L, ac, bc)
            return r, g, b, a1 + (a2 - a1) * k
        end
    end
    local _, col, a = s[#s][1], s[#s][2], s[#s][3]
    local r, g, b = hex_to_rgb_components(col)
    return r, g, b, a
end

-- Rebuild a cairo gradient from perceptual (OKLab) samples. Cairo only
-- interpolates in sRGB; pre-sampling in OKLab gives smooth, band-free
-- midpoints. Also applies normalize_stops (ordering fix).
local GRADIENT_SAMPLES = 256

function build_gradient_pattern(cr, stops, x1, y1, x2, y2)
    local pat = cairo_pattern_create_linear(x1, y1, x2, y2)
    local s = normalize_stops(stops)
    if #s == 1 then
        local col, a = s[1][2], s[1][3]
        local r, g, b = hex_to_rgb_components(col)
        cairo_pattern_add_color_stop_rgba(pat, 0, r, g, b, a)
        cairo_pattern_add_color_stop_rgba(pat, 1, r, g, b, a)
        return pat
    end
    for i = 0, GRADIENT_SAMPLES do
        local t = i / GRADIENT_SAMPLES
        local r, g, b, a = get_color_from_list(s, t)
        cairo_pattern_add_color_stop_rgba(pat, t, r, g, b, a)
    end
    return pat
end

function rounded_rect_path(cr, x, y, w, h, r)
    r = math.min(r, w / 2, h / 2)
    cairo_new_sub_path(cr)
    cairo_arc(cr, x + w - r, y + r, r, -math.pi / 2, 0)
    cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi / 2)
    cairo_arc(cr, x + r, y + h - r, r, math.pi / 2, math.pi)
    cairo_arc(cr, x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cairo_close_path(cr)
end

local function normalize_number(v)
    if v == nil then return 0 end
    if type(v) == "number" then return v end
    if type(v) == "table" then return 0 end
    local s = tostring(v):gsub(",", ".")
    return tonumber(s:match("([%d%.]+)")) or 0
end

function normalize_with_suffix(raw)
    if not raw then return 0 end
    local s = tostring(raw):lower():gsub("%s+", "")
    local num = normalize_number(s)
    local suf = s:match("([kmg])$")
    if suf == "k" then return num * 1024 end
    if suf == "m" then return num * 1024 ^ 2 end
    if suf == "g" then return num * 1024 ^ 3 end
    return num
end

function format_value(v, opts)
    opts = opts or {}
    local decimals = opts.decimals or 0
    local suffix = opts.suffix or ""
    local multiplier = opts.multiplier or 1
    local n = safe_num(v, "format_value") * multiplier
    if decimals == 0 then
        n = round(n)
        return tostring(n) .. suffix
    end
    local fmt = "%." .. tostring(decimals) .. "f"
    return string.format(fmt, n) .. suffix
end

-- ═══ NUMBER HELPERS ═══

function round(v)
    if not v or type(v) ~= "number" then return 0 end
    return v >= 0 and math.floor(v + 0.5) or math.ceil(v - 0.5)
end

-- ═══ FILE I/O ═══

function read_file(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local out = f:read("*a") or ""
    f:close()
    return out:gsub("%s+$", "")
end

-- ═══ SAFE FUNCTIONS ═══

local function _safe_log(msg)
    if conky_log then conky_log(msg) end
end

function safe_num(v, name)
    if v == nil then
        _safe_log("missing num: " .. tostring(name))
        return 0
    end
    if type(v) == "number" then
        if v ~= v then
            _safe_log("NaN num: " .. tostring(name))
            return 0
        end
        return v
    end
    local n = tonumber((tostring(v):gsub(",", ".")))
    if not n then
        _safe_log("invalid num: " .. tostring(name) .. " = " .. tostring(v))
        return 0
    end
    return n
end

function safe_str(v, name)
    if v == nil or v == "" then
        _safe_log("missing str: " .. tostring(name))
        return "N/A"
    end
    return tostring(v)
end

local function safe_tbl(v, name)
    if v == nil then
        _safe_log("missing tbl: " .. tostring(name))
        return {}
    end
    return v
end

function draw_get_value(m)
    -- interpret_name table
    if type(m.value) == "table" and m.value.exec then
        return tostring(m.value.exec() or "")
    end
    -- plain string
    if type(m.value) == "string" then
        return m.value
    end
    -- fallback: name + arg → Conky variable
    if m.name then
        local var = "${" .. m.name .. (m.arg and " " .. m.arg or "") .. "}"
        return conky_parse(var)
    end
    return ""
end

-- ═══ AUTO-INTERPRET NAME ═══
-- () → Lua function (load)
-- everything else → conky_parse (handles ${} and plain text)

function interpret_name(name)
    if not name or name == "" then
        return { type = "text", value = "", exec = function() return "" end }
    end

    -- 1) Lua function (contains parentheses) → load
    if name:find("%(") and name:find("%)") then
        local fn = load("return " .. name)
        if fn then
            return {
                type = "lua",
                value = name,
                exec = fn,
            }
        end
    end

    -- 2) Everything else → conky_parse (Conky handles it)
    return {
        type = "conky",
        value = name,
        exec = function() return conky_parse(name) end,
    }
end
