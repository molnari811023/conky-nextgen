--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/core/draw_group.lua — group registration and per-group visibility

Provides register_group() to track groups in GROUP_REGISTRY and initialise
their GROUP_STATE, and check_group_visibility() which updates each group's
visible state (once per second) based on its optional draw_me condition.
]]--

--{{{
-- ## Draw Group
--
-- Manages the interactive group lifecycle. Each group is registered into
-- GROUP_REGISTRY and given an enabled GROUP_STATE entry. Once per second,
-- check_group_visibility() re-evaluates every group's draw_me condition to
-- toggle its GROUP_STATE between visible (true) and hidden (nil), which
-- drives the layout and rendering elsewhere.
--
-- **Exposed/global functions:**
-- - `register_group(name)` — register a group and ensure it starts visible
-- - `check_group_visibility()` — update group visibility from per-group draw_me (throttled to 1/sec)
--
-- **Config/globals used:**
-- - `GROUP_STATE`, `GROUP_REGISTRY` — group state and registration tables
-- - `_GROUPS` — the list of configured groups, each with `.name` and `.draw_me`
-- - `evaluate_draw_me` — collaborator that evaluates a draw_me condition
--}}}

GROUP_STATE       = GROUP_STATE or {}
GROUP_REGISTRY    = GROUP_REGISTRY or {}

------------------------------------------------------------
-- GROUP REGISTRATION
------------------------------------------------------------

function register_group(name)
    GROUP_REGISTRY[name] = true
    if GROUP_STATE[name] == nil then
        GROUP_STATE[name] = true
    end
end

------------------------------------------------------------
-- GROUP VISIBILITY — based on per-group draw_me
------------------------------------------------------------

local _last_vis_check = 0

function check_group_visibility()
    if not _GROUPS then return end
    local now = os.time()
    if now == _last_vis_check then return end
    _last_vis_check = now
    for _, g in ipairs(_GROUPS) do
        if g.draw_me ~= nil then
            if evaluate_draw_me(g.draw_me) then
                GROUP_STATE[g.name] = true
            else
                GROUP_STATE[g.name] = nil
            end
        end
    end
end
