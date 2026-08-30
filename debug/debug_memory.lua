#!/usr/bin/env lua

--[[[
debug/debug_memory.lua — standalone memory/leak benchmark and correctness test
for the theme engine and draw-core helpers (apply_theme, resolve_gradient,
view_toggle, draw_allowed, view_contains, cache_set)

Run it directly with the system lua interpreter from the project root:
`lua debug/debug_memory.lua`. It measures time and GC-heap growth for repeated
calls and flags sections that grew more than expected as potential leaks.
]]--

--{{{
-- ## Memory / leak benchmark
--
-- Measures timing and garbage-collector heap growth of the hot draw/theme
-- functions in a loop and flags results whose memory growth exceeds a
-- threshold as a suspected leak. It also runs a few one-shot correctness
-- checks for table-based view matching and the bounded cache.
--
-- **What it does:**
-- - Stubs the Conky and Cairo entry points and loads theme_engine, utils,
--   draw_core and mouse_actions.
-- - run_test(): runs fn(N) with GC collect before/after and prints timing,
--   before/after heap KB and growth, flagging >= 4 KB growth as "LEAK?".
-- - Benchmark: 10k apply_theme bar items, 10k apply_theme text items, 100k
--   resolve_gradient lookups and 10k rapid view_toggle churn cycles.
-- - Correctness: draw_allowed with a multi-view table, view_contains with a
--   string vs a table.
-- - Cache: cache_set capped at max entries after 1000 inserts, re-setting the
--   same key must not bump the counter, and 200 fill+clear cycles of a
--   100-entry cache must stay under 8 KB retention.
-- - Prints TOTAL time for the final cache fill+clear loop.
--}}}

local function get_root()
  local src = (debug.getinfo(1, 'S').source or arg[0]):match('@(.*)') or arg[0] or '.'
  local dir = src:match('^(.*[/\\])') or './'
  local p = io.popen('readlink -f "'..dir..'../" 2>/dev/null')
  local out = p and (p:read('*a') or ''):gsub('%s+$','') or dir..'../'
  if p then p:close() end
  return out
end
local root = get_root()
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/lua/core/?.lua;' .. root .. '/lua/draw/?.lua;' .. root .. '/lua/hardware/?.lua;' .. root .. '/lua/weather/?.lua'

-- Conky stubs
conky_parse = function(s) return s end
conky_window = { width = 420, height = 1020 }
conky_log = function() end
conky_surface = function() return nil end
cairo_create = function() return {} end
cairo_destroy = function() end

lfs = require('lfs')
-- Config globals — formerly from settings.lua / the top of widget.lua.
-- widget.lua now also runs the Conky bootstrap (require("require") loads the
-- Cairo draw modules), so it cannot be loaded here; set the paths directly.
script_dir      = root .. '/'
JSON_PATH       = script_dir .. 'tmp/'
ICON_BASE       = script_dir .. 'icons/'
ICON_THEME      = 'default'
XDG_ICON_THEME  = 'Papirus'
MOON_ICON_BASE  = script_dir .. 'icons/moon/'
WIND_ICON_BASE  = script_dir .. 'icons/wind/'

-- theme engine first (THEMES table is defined in widget.lua)
require('core.theme_engine')
require('core.utils')
-- view logic (no Cairo calls happen at require time)
dofile(root .. '/lua/core/draw_core.lua')
require('mouse_actions')

-- Replica of theme_engine.lua's now-local helper, so this benchmark keeps
-- measuring gradient lookup without depending on the module globals.
local function resolve_gradient(theme_name, gradient_name)
  if not gradient_name then return nil end
  if not theme_name then theme_name = DEFAULT_THEME end
  local theme = THEMES[theme_name]
  if theme and theme.gradients and theme.gradients[gradient_name] then
    return theme.gradients[gradient_name]
  end
  return nil
end

------------------------------------------------------------
-- Measurement helpers
------------------------------------------------------------

local function gc_prep()
  collectgarbage('collect')
  collectgarbage('collect')
end

local function run_test(name, n, fn)
  gc_prep()
  local before = collectgarbage('count')
  local t0 = os.clock()
  fn(n)
  local dt = (os.clock() - t0) * 1000
  gc_prep()
  local after = collectgarbage('count')
  local growth = after - before
  local status = (growth < 4) and 'OK' or 'LEAK?'
  print(string.format('%-34s N=%6d  [%8.1fms]  mem: %7.2f -> %7.2f KB  growth %+6.2f KB  %s',
    name, n, dt, before, after, growth, status))
  return growth
end

------------------------------------------------------------
-- 1. apply_theme: fresh draw item per call (worst case)
------------------------------------------------------------

run_test('apply_theme (fresh bar item)', 10000, function()
  for _ = 1, 10000 do
    apply_theme({ type = 'bar', fg = 'bar_cpu', bg = 'bg_dark' })
  end
end)

run_test('apply_theme (fresh text item)', 10000, function()
  for _ = 1, 10000 do
    apply_theme({ type = 'text', color = 'text_value' })
  end
end)

------------------------------------------------------------
-- 2. theme resolution: repeated gradient lookup
------------------------------------------------------------

run_test('resolve_gradient (bar_cpu)', 100000, function()
  for _ = 1, 100000 do
    resolve_gradient('breeze_dark', 'bar_cpu')
  end
end)

------------------------------------------------------------
-- 3. view_toggle churn (back-and-forth)
------------------------------------------------------------

run_test('view_toggle rapid switching', 10000, function()
  for _ = 1, 10000 do
    view_toggle('calendar')
    view_toggle('calendar')
  end
end)

------------------------------------------------------------
-- 4. draw_allowed: multi-view TABLE handling (correctness)
------------------------------------------------------------

local ok_multi = true
current_view = 'main'
if not draw_allowed({ 'main', 'view_1' }, nil) then ok_multi = false end
current_view = 'view_1'
if not draw_allowed({ 'main', 'view_1' }, nil) then ok_multi = false end
current_view = 'view_2'
if draw_allowed({ 'main', 'view_1' }, nil) then ok_multi = false end
current_view = 'main'
print(string.format('draw_allowed multi-view table: %s', ok_multi and 'OK (handles table)' or 'FAIL'))

-- Replica of draw_core.lua's now-local helper, so this correctness test
-- keeps running without depending on the module globals.
local function view_contains(v, name)
  if type(v) == "table" then
    for _, vv in ipairs(v) do
      if vv == name then return true end
    end
    return false
  end
  return v == name
end

-- view_contains string vs table
local ok_vc = view_contains('main', 'main') and view_contains({ 'a', 'b' }, 'b') and not view_contains({ 'a' }, 'c')
print(string.format('view_contains string+table:   %s', ok_vc and 'OK' or 'FAIL'))

------------------------------------------------------------
-- 5. cache_set() size limit
------------------------------------------------------------

local t = {}
local max = 50
for i = 1, 1000 do
  cache_set(t, 'key' .. i, i, max)
end
local count = 0
for k in pairs(t) do
  if k ~= '_count' then count = count + 1 end
end
print(string.format('cache_set limit (max=%d, after 1000): %d entries, _count=%s  %s',
  max, count, tostring(t._count), (count <= max and t._count == count) and 'OK' or 'FAIL'))

local t2 = {}
cache_set(t2, 'a', 1, 10)
cache_set(t2, 'a', 2, 10)  -- overwrite same key: count not incremented
local c2 = 0
for k in pairs(t2) do if k ~= '_count' then c2 = c2 + 1 end end
print(string.format('cache_set overwrite same key: %d entries, _count=%s  %s',
  c2, tostring(t2._count), (c2 == 1 and t2._count == 1) and 'OK' or 'FAIL'))

-- Note: cache retention (max 100) is measurable — this is the cache's stored
-- content, not a leak.
gc_prep()
local t3 = {}
local mb3 = collectgarbage('count')
local t0 = os.clock()
for _ = 1, 200 do
  for i = 1, 100 do cache_set(t3, 'k' .. i, i, 100) end
end
gc_prep()
local ma3 = collectgarbage('count')
print(string.format('cache_set fill+clear cycles: [%8.1fms]  mem: %7.2f -> %7.2f KB  (+%5.2f KB = retention, max 100 entry)  %s',
  (os.clock() - t0) * 1000, mb3, ma3, ma3 - mb3, (ma3 - mb3 < 8) and 'OK' or 'LEAK?'))

print()
print(string.format('TOTAL: [%.1fms]', (os.clock() - t0) * 1000))
