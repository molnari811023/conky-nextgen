--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[=[
lua/antigravity/data.lua — Antigravity usage telemetry accessors for the Conky widget layer.
Exposes `conky_antigravity_*` functions for Model, Session, Tokens, Steps, Turns, Tools, and Cache Hit Ratio.
]=]
--{{{
-- ## Antigravity Dashboard — Data Accessors
--
-- Reads the parsed Antigravity JSON (loaded by `lua/antigravity/core.lua` via
-- `load_antigravity_data()`) and exposes `conky_antigravity_*` accessors:
--
-- - **Status & Model:** `conky_antigravity_status()`, `conky_antigravity_model()`,
--   `conky_antigravity_model_short()`, `conky_antigravity_conversation_id()`,
--   `conky_antigravity_updated()`
-- - **Tokens:** `conky_antigravity_total_tokens()`, `conky_antigravity_input_tokens()`,
--   `conky_antigravity_output_tokens()`, `conky_antigravity_cache_tokens()`,
--   `conky_antigravity_cache_ratio()`, `conky_antigravity_cache_ratio_raw()`
-- - **Last Turn:** `conky_antigravity_last_input()`, `conky_antigravity_last_output()`,
--   `conky_antigravity_last_cache()`, `conky_antigravity_last_time()`
-- - **Steps & Activity:** `conky_antigravity_steps_count()`, `conky_antigravity_turns_count()`,
--   `conky_antigravity_tools_count()`, `conky_antigravity_session_duration()`,
--   `conky_antigravity_conversations_count()`
-- - **Top Tools:** `conky_antigravity_top_tool_name(i)`, `conky_antigravity_top_tool_count(i)`,
--   `conky_antigravity_top_tool_formatted(i)`
--}}}

local function agy_root()
	return load_antigravity_data() or {}
end

local function agy_tokens_raw()
	local t = agy_root().tokens
	return type(t) == "table" and t or {}
end

local function agy_last_turn_raw()
	local l = agy_root().last_turn
	return type(l) == "table" and l or {}
end

local function agy_session_raw()
	local s = agy_root().session
	return type(s) == "table" and s or {}
end

local function agy_top_tools_raw()
	local tt = agy_root().top_tools
	return type(tt) == "table" and tt or {}
end

------------------------------------------------------------
-- 1. Status, Model & Conversation
------------------------------------------------------------

function antigravity_is_ready()
	return agy_root().status == "ok"
end

function conky_antigravity_is_ready()
	return antigravity_is_ready() and 1 or 0
end

function conky_antigravity_status()
	local st = agy_root().status
	return (st and st ~= "") and st or "not_installed"
end

function conky_antigravity_model()
	local m = agy_root().current_model
	return (m and m ~= "") and m or "N/A"
end

function conky_antigravity_model_short()
	local m = agy_root().current_model_short
	return (m and m ~= "") and m or conky_antigravity_model()
end

function conky_antigravity_conversation_id()
	local id = agy_root().active_conversation
	return (id and id ~= "") and id or "N/A"
end

function conky_antigravity_conversation_short()
	local id = conky_antigravity_conversation_id()
	if id and #id > 8 then
		return id:sub(1, 8) .. "…"
	end
	return id
end

function conky_antigravity_updated()
	local u = agy_root().updated_str
	return (u and u ~= "") and u or "N/A"
end

------------------------------------------------------------
-- 2. Token Telemetry & Prompt Cache Ratio
------------------------------------------------------------

function conky_antigravity_total_tokens()
	local t = agy_tokens_raw().total_formatted
	return (t and t ~= "") and t or "0"
end

function conky_antigravity_total_tokens_raw()
	return tonumber(agy_tokens_raw().total) or 0
end

function conky_antigravity_input_tokens()
	local t = agy_tokens_raw().input_formatted
	return (t and t ~= "") and t or "0"
end

function conky_antigravity_input_tokens_raw()
	return tonumber(agy_tokens_raw().input) or 0
end

function conky_antigravity_output_tokens()
	local t = agy_tokens_raw().output_formatted
	return (t and t ~= "") and t or "0"
end

function conky_antigravity_output_tokens_raw()
	return tonumber(agy_tokens_raw().output) or 0
end

function conky_antigravity_cache_tokens()
	local t = agy_tokens_raw().cache_read_formatted
	return (t and t ~= "") and t or "0"
end

function conky_antigravity_cache_tokens_raw()
	return tonumber(agy_tokens_raw().cache_read) or 0
end

function conky_antigravity_cache_ratio()
	local r = tonumber(agy_tokens_raw().cache_ratio) or 0
	return string.format("%.1f%%", r)
end

function conky_antigravity_cache_ratio_raw()
	local r = tonumber(agy_tokens_raw().cache_ratio) or 0
	return math.min(100, math.max(0, math.floor(r + 0.5)))
end

------------------------------------------------------------
-- 3. Last Turn Telemetry
------------------------------------------------------------

function conky_antigravity_last_input()
	local t = agy_last_turn_raw().input_formatted
	return (t and t ~= "") and t or "0"
end

function conky_antigravity_last_output()
	local t = agy_last_turn_raw().output_formatted
	return (t and t ~= "") and t or "0"
end

function conky_antigravity_last_cache()
	local t = agy_last_turn_raw().cache_read_formatted
	return (t and t ~= "") and t or "0"
end

function conky_antigravity_last_time()
	local t = agy_last_turn_raw().time
	if t and t ~= "" then
		-- Extract HH:MM:SS from ISO timestamp
		local hms = t:match("T(%d+:%d+:%d+)")
		if hms then return hms end
		return t
	end
	return "N/A"
end

------------------------------------------------------------
-- 4. Steps, User Turns & Tools Breakdown
------------------------------------------------------------

function conky_antigravity_steps_count()
	return tonumber(agy_root().steps) or 0
end

function conky_antigravity_turns_count()
	return tonumber(agy_root().turns) or 0
end

function conky_antigravity_tools_count()
	return tonumber(agy_root().tool_calls_total) or 0
end

function conky_antigravity_session_duration()
	local d = agy_session_raw().duration_str
	return (d and d ~= "") and d or "0p"
end

function conky_antigravity_conversations_count()
	return tonumber(agy_session_raw().conversations_count) or 0
end

function conky_antigravity_top_tool_name(i)
	local item = agy_top_tools_raw()[tonumber(i) or 1] or {}
	return (item.name and item.name ~= "") and item.name or ""
end

function conky_antigravity_top_tool_count(i)
	local item = agy_top_tools_raw()[tonumber(i) or 1] or {}
	return tonumber(item.count) or 0
end

function conky_antigravity_top_tool_formatted(i)
	local item = agy_top_tools_raw()[tonumber(i) or 1]
	if not item or not item.name then return "" end
	return string.format("%s: %d", item.name, item.count or 0)
end
