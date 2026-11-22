#!/usr/bin/env lua
--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--[=[
debug/debug_antigravity.lua — standalone debug script that dumps Antigravity (AGY / Gemini CLI)
usage telemetry (model, active session, token usage, cache ratio, last turn stats, top tools).

Run it directly from the project root: `lua debug/debug_antigravity.lua`.
]=]

lfs = require('lfs')

local function get_root()
  local src = (debug.getinfo(1, 'S').source or arg[0]):match('@(.*)') or arg[0] or '.'
  local dir = src:match('^(.*[/\\])') or './'
  local cwd = lfs.currentdir()
  if lfs.chdir(dir .. '..') then
    local r = lfs.currentdir()
    lfs.chdir(cwd)
    return r
  end
  return cwd
end
local root = get_root()
package.path = './?.lua;' .. package.path .. ';' .. root .. '/lua/?.lua;' .. root .. '/lua/core/?.lua;' .. root .. '/lua/antigravity/?.lua'

conky_parse = function(s) return s end
conky_window = { width = 420, height = 1020 }
conky_log = function() end

script_dir      = root .. '/'
JSON_PATH       = script_dir .. 'tmp/'
ICON_BASE       = script_dir .. 'icons/'
json = require('dkjson')

require('core.utils')
require('core.translate')
require('antigravity.core')
require('antigravity.data')

local t0 = os.clock()
print('=== ANTIGRAVITY ENGINE & SESSION ===')
print('conky_antigravity_status():', conky_antigravity_status())
print('conky_antigravity_model():', conky_antigravity_model())
print('conky_antigravity_model_short():', conky_antigravity_model_short())
print('conky_antigravity_conversation_id():', conky_antigravity_conversation_id())
print('conky_antigravity_conversations_count():', conky_antigravity_conversations_count())
print('conky_antigravity_session_duration():', conky_antigravity_session_duration())
print('conky_antigravity_updated():', conky_antigravity_updated())

print('\n=== TOKEN TELEMETRY & PROMPT CACHE ===')
print('conky_antigravity_total_tokens():', conky_antigravity_total_tokens())
print('conky_antigravity_input_tokens():', conky_antigravity_input_tokens())
print('conky_antigravity_output_tokens():', conky_antigravity_output_tokens())
print('conky_antigravity_cache_tokens():', conky_antigravity_cache_tokens())
print('conky_antigravity_cache_ratio():', conky_antigravity_cache_ratio())

print('\n=== LAST TURN METRICS ===')
print('conky_antigravity_last_input():', conky_antigravity_last_input())
print('conky_antigravity_last_output():', conky_antigravity_last_output())
print('conky_antigravity_last_cache():', conky_antigravity_last_cache())
print('conky_antigravity_last_time():', conky_antigravity_last_time())

print('\n=== ACTIVITY & TOOL USAGE ===')
print('conky_antigravity_steps_count():', conky_antigravity_steps_count())
print('conky_antigravity_turns_count():', conky_antigravity_turns_count())
print('conky_antigravity_tools_count():', conky_antigravity_tools_count())
print('Top Tools:')
for i = 1, 6 do
  local t = conky_antigravity_top_tool_formatted(i)
  if t and t ~= "" then
    print(string.format('  [%d] %s', i, t))
  end
end

print(string.format('\n[TOTAL %.3fms]', (os.clock() - t0) * 1000))
