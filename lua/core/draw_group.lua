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

GROUP_STATE          = GROUP_STATE or {}
GROUP_REGISTRY       = GROUP_REGISTRY or {}
GROUP_EXPANDED       = GROUP_EXPANDED or {}
GROUP_MANUAL_OFFSETS = GROUP_MANUAL_OFFSETS or {}

------------------------------------------------------------
-- GROUP REGISTRATION
------------------------------------------------------------

function register_group(name)
    GROUP_REGISTRY[name] = true
    if GROUP_STATE[name] == nil then
        GROUP_STATE[name] = true
    end
    if GROUP_EXPANDED[name] == nil then
        GROUP_EXPANDED[name] = true
    end
end

------------------------------------------------------------
-- GROUP EXPAND / COLLAPSE
------------------------------------------------------------

function is_group_expanded(name)
    if not name then return true end
    return GROUP_EXPANDED[name] ~= false
end

function expand_group(name)
    if not name then return end
    GROUP_EXPANDED[name] = true
end

function collapse_group(name)
    if not name then return end
    GROUP_EXPANDED[name] = false
end

function toggle_group_expand(name)
    if not name then return end
    GROUP_EXPANDED[name] = not is_group_expanded(name)
    return GROUP_EXPANDED[name]
end

------------------------------------------------------------
-- GROUP MANUAL OFFSET & REORDERING
------------------------------------------------------------

function set_group_offset(name, dx, dy)
    if not name then return end
    local cur = GROUP_MANUAL_OFFSETS[name] or { x = 0, y = 0 }
    GROUP_MANUAL_OFFSETS[name] = {
        x = (cur.x or 0) + (dx or 0),
        y = (cur.y or 0) + (dy or 0),
    }
end

function reset_group_offset(name)
    if not name then
        GROUP_MANUAL_OFFSETS = {}
    else
        GROUP_MANUAL_OFFSETS[name] = nil
    end
end

function reorder_group(name, delta_slots)
    if not name or not _GROUPS or delta_slots == 0 then return false end
    local idx = nil
    for i, g in ipairs(_GROUPS) do
        if g.name == name then idx = i; break end
    end
    if not idx then return false end
    local target = math.max(1, math.min(#_GROUPS, idx + delta_slots))
    if target == idx then return false end
    local entry = table.remove(_GROUPS, idx)
    table.insert(_GROUPS, target, entry)
    return true
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
