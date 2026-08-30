--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
mouse_actions.lua — view-switching and hover helpers (support module)

Support module loaded by the engine (via require.lua). It defines the
global functions that widget layouts bind to mouse events: switching
between widget views and highlighting / restoring group backgrounds
when the pointer enters or leaves a group.
]]--

--{{{
-- ## Mouse actions support module
--
-- Not a standalone widget. Provides global view-switching and hover
-- callbacks: switch_view sets the current view, view_toggle flips
-- between two views while remembering the previous one, and the
-- hover/leave handlers temporarily highlight the border of the group
-- under the pointer.
--
-- **Exposed/global functions:**
-- - `switch_view(v)` — sets the global current_view
-- - `view_toggle(v)` — toggles to v, or back to the previous view
-- - `on_hover_group(event)` — highlights the group border on hover
-- - `on_leave_group(event)` — restores the group background on leave
--
-- **Config/globals used:**
-- `current_view` and `_previous_view` (module-local) — view state
-- `modify_group_background()` / `restore_group_background()` — group styling helpers
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
