--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- mouse_actions.lua — Mouse event action functions
-- switch_view(v)            — switch to a view (global function)
-- view_toggle(v)            — toggle between a view and the previous one
-- on_hover_group(event)     — hover highlight: white border, 3px
-- on_leave_group(event)     — restore group background
--
-- Left click: hit_test → click_view / click
-- Mouse leave: restore main view
--
-- Configurable in widget.lua (edited by the designer):
--   MOUSE_HOVER_IN_GROUP_ACTION = on_hover_group
--   MOUSE_HOVER_LEAVE_GROUP_ACTION = on_leave_group
--   MOUSE_LEAVE_ACTION = function() switch_view("main") end
--}}}

function switch_view(v)
    if not v then return end
    current_view = v
end

local _previous_view = "main"

function view_toggle(v)
    if not v then return end
    if current_view == v then
        switch_view(_previous_view or "main")
    else
        _previous_view = current_view
        switch_view(v)
    end
end

function on_hover_group(event)
    if event.group then
        modify_group_background(event.group, {
            border = { { 1, "#ffffff", 0.9 } },
            border_width = 3,
        })
    end
end

function on_leave_group(event)
    if event.group then
        restore_group_background(event.group)
    end
end
