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
