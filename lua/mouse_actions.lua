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
