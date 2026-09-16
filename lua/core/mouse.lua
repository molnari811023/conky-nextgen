--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/core/mouse.lua — mouse interaction: hit testing, hover tracking, click/scroll actions

Implements conky_on_mouse() as the single mouse event callback. It performs
hit testing against clickable items and the tracked set of visible groups,
tracks group hover enter/leave transitions, routes clicks (element, global,
or modifier+global) and scrolls (with Ctrl/Shift/Alt variants) to the
corresponding MOUSE_* action callbacks, and writes a debug log.
]]--

--{{{
-- ## Mouse
--
-- Conky mouse event handling. on_event() interprets each incoming event
-- (mouse_enter/leave, move, scroll, button_down/up): it detects group
-- hover changes, hit-tests items for click_view/click handling, and fires
-- global MOUSE_* actions where modifiers or unfilled elements apply. Left
-- clicks handled by an element on button_down are suppressed on button_up so
-- the global click does not also fire.
--
-- **Exposed/global functions:**
-- - `conky_on_mouse(event)` — callback entry point that dispatches to the internal handler
-- - `register_clickable_area(x, y, w, h, action)` — declare a Cairo-free clickable rectangle
-- - `conky_register_clickable_area("x,y,w,h", action)` — text-callable variant
--   (`${lua conky_register_clickable_area 0,0,100,100 view:main}`)
-- - `clear_clickable_areas()` — drop all registered clickable areas
--
-- **Clickable areas (Cairo-free):**
-- The draw-item/group machinery only exists for Cairo-drawn widgets. A plain
-- (text/Cairo-free) widget has no items to hit-test, so it registers explicit
-- rectangles via `register_clickable_area()`. They are window-relative and are
-- tested before the draw items, so the same `lua_mouse_hook` callback drives
-- both kinds of widgets.
--
-- `action` may be:
-- - a function(event) — called with the mouse event
-- - a string "view:<name>" — switches to that view
-- - a string "toggle:<name>" — toggles between <name> and the base view (_VIEWS[1])
-- - a plain string — executed as a shell command (os.execute)
--
-- **Config/globals used:**
-- - `GROUP_OFFSETS`, `draw`, `compute_group_height` — layout geometry for hit tracking
-- - `evaluate_draw_me`, `draw_allowed`, `switch_view` — visibility and view helpers
-- - `MOUSE_ENTER_ACTION`, `MOUSE_LEAVE_ACTION`,
--   `MOUSE_HOVER_IN_GROUP_ACTION`, `MOUSE_HOVER_LEAVE_GROUP_ACTION`,
--   `MOUSE_HOVER_IN_CONKY_WINDOW_ACTION` — enter/leave/hover callbacks
-- - `MOUSE_SCROLL_UP/DOWN/LEFT/RIGHT`, `MOUSE_CTRL_*`, `MOUSE_SHIFT_*`,
--   `MOUSE_ALT_*`, `MOUSE_CLICK_LEFT/RIGHT/MIDDLE/BACK/FORWARD`,
--   `MOUSE_CTRL_CLICK/SHIFT_CLICK/ALT_CLICK` — action callbacks
--}}}

local dbg_file = io.open("/tmp/conky_mouse.log", "w")

local last_hovered_group = nil

-- Clickable areas for Cairo-free widgets (window-relative rectangles).
local CLICKABLE_AREAS = {}

-- Left button press: if an element handled the click (click_view/click),
-- then on release the global MOUSE_CLICK_* must not fire too.
local left_down_handled = false

local function log(msg)
    if dbg_file then
        dbg_file:write(os.date("%H:%M:%S") .. " " .. msg .. "\n")
        dbg_file:flush()
    end
end

------------------------------------------------------------
-- Helper: invoke action callback
------------------------------------------------------------

local function call_action(action, event)
    if not action then return false end
    if type(action) == "function" then
        action(event)
    elseif type(action) == "string" then
        os.execute(action)
    end
    return true
end

------------------------------------------------------------
-- Determine group from mouse position
------------------------------------------------------------

local function get_group_at(ex, ey)
    for name, info in pairs(GROUP_OFFSETS) do
        if info.visible then
            local gy = info.y
            local gh = compute_group_height(name, draw)
            if ey >= gy and ey <= gy + gh then
                return name, gy
            end
        end
    end
    return nil, nil
end

------------------------------------------------------------
-- Hit testing
------------------------------------------------------------

local function hit_test(ex, ey)
    -- clickable areas first (Cairo-free widgets have no draw items)
    for i = #CLICKABLE_AREAS, 1, -1 do
        local a = CLICKABLE_AREAS[i]
        if ex >= a.x and ex <= a.x + a.w and ey >= a.y and ey <= a.y + a.h then
            return { click_view = a.click_view, click = a.click, toggle_view = a.toggle_view }
        end
    end

    for i = #draw, 1, -1 do
        local item = draw[i]

        if item.click or item.click_view then
            if not evaluate_draw_me(item.draw_me) then goto continue end
            if not draw_allowed(item.view, item.group) then goto continue end

            local gname = item.group
            local gy = GROUP_OFFSETS[gname] and GROUP_OFFSETS[gname].y or 0

            local ix = item.x or 0
            local iy = (item.y or 0) + gy
            local iw = item.w or item.width or 100
            local ih = item.h or item.height or (item.radius and item.radius * 2) or 20
            if item.type == "background" then
                if (item.w or item.width) == 0 and conky_window then iw = conky_window.width end
                if (item.h or item.height or 0) == 0 then
                    ih = (GROUP_OFFSETS[gname] and GROUP_OFFSETS[gname].height) or ih
                end
            end

            if ex >= ix and ex <= ix + iw and ey >= iy and ey <= iy + ih then
                return item
            end
        end
        ::continue::
    end
    return nil
end

------------------------------------------------------------
-- Scroll handling (with modifiers)
------------------------------------------------------------

local function handle_scroll(event)
    local dir = event.direction
    local mods = event.mods or {}

    if mods.control then
        if dir == "up"    then return call_action(MOUSE_CTRL_SCROLL_UP, event) end
        if dir == "down"  then return call_action(MOUSE_CTRL_SCROLL_DOWN, event) end
    elseif mods.shift then
        if dir == "up"    then return call_action(MOUSE_SHIFT_SCROLL_UP, event) end
        if dir == "down"  then return call_action(MOUSE_SHIFT_SCROLL_DOWN, event) end
    elseif mods.alt then
        if dir == "up"    then return call_action(MOUSE_ALT_SCROLL_UP, event) end
        if dir == "down"  then return call_action(MOUSE_ALT_SCROLL_DOWN, event) end
    end

    if dir == "up"    then return call_action(MOUSE_SCROLL_UP, event) end
    if dir == "down"  then return call_action(MOUSE_SCROLL_DOWN, event) end
    if dir == "left"  then return call_action(MOUSE_SCROLL_LEFT, event) end
    if dir == "right" then return call_action(MOUSE_SCROLL_RIGHT, event) end
    return false
end

------------------------------------------------------------
-- Left click (hit test)
------------------------------------------------------------

local function handle_left_click(event)
    local item = hit_test(event.x, event.y)
    if item then
        if item.toggle_view then
            local base = (_VIEWS and _VIEWS[1] and _VIEWS[1].name) or "main"
            local nextv = (current_view == item.toggle_view) and base or item.toggle_view
            log("toggle view to: " .. tostring(nextv))
            switch_view(nextv)
            return true
        elseif item.click_view then
            log("switching view to: " .. tostring(item.click_view))
            switch_view(item.click_view)
            return true
        elseif item.click then
            log("running click action")
            call_action(item.click, event)
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- Global click handling (click not on an element)
------------------------------------------------------------

local function handle_global_click(event)
    local mods = event.mods or {}

    if mods.control then
        return call_action(MOUSE_CTRL_CLICK, event)
    elseif mods.shift then
        return call_action(MOUSE_SHIFT_CLICK, event)
    elseif mods.alt then
        return call_action(MOUSE_ALT_CLICK, event)
    end

    local btn = event.button
    if btn == "left"    then return call_action(MOUSE_CLICK_LEFT, event) end
    if btn == "right"   then return call_action(MOUSE_CLICK_RIGHT, event) end
    if btn == "middle"  then return call_action(MOUSE_CLICK_MIDDLE, event) end
    if btn == "back"    then return call_action(MOUSE_CLICK_BACK, event) end
    if btn == "forward" then return call_action(MOUSE_CLICK_FORWARD, event) end
    return false
end

------------------------------------------------------------
-- Event handling
------------------------------------------------------------

local function on_event(event)
    if not event then return false end

    log("event: type=" .. tostring(event.type) .. " button=" .. tostring(event.button) ..
        " x=" .. tostring(event.x) .. " y=" .. tostring(event.y) ..
        " dir=" .. tostring(event.direction) ..
        " mods=" .. tostring(event.mods and "yes" or "no"))

    -- dump mods if present
    if event.mods then
        local m = event.mods
        log("  mods: shift=" .. tostring(m.shift) .. " ctrl=" .. tostring(m.control) ..
            " alt=" .. tostring(m.alt) .. " super=" .. tostring(m.super))
    end

    --------------------------------------------------------
    -- mouse_enter
    --------------------------------------------------------
    if event.type == "mouse_enter" then
        call_action(MOUSE_ENTER_ACTION, event)
        call_action(MOUSE_HOVER_IN_CONKY_WINDOW_ACTION, event)
        return false
    end

    --------------------------------------------------------
    -- mouse_leave
    --------------------------------------------------------
    if event.type == "mouse_leave" then
        if last_hovered_group then
            event.group = last_hovered_group
            call_action(MOUSE_HOVER_LEAVE_GROUP_ACTION, event)
        end
        call_action(MOUSE_LEAVE_ACTION, event)
        last_hovered_group = nil
        return false
    end

    --------------------------------------------------------
    -- mouse_move
    --------------------------------------------------------
    if event.type == "mouse_move" then
        local new_group = get_group_at(event.x, event.y)
        if new_group ~= last_hovered_group then
            if last_hovered_group then
                event.group = last_hovered_group
                call_action(MOUSE_HOVER_LEAVE_GROUP_ACTION, event)
            end
            last_hovered_group = new_group
            if new_group then
                event.group = new_group
                call_action(MOUSE_HOVER_IN_GROUP_ACTION, event)
            end
        end
        return false
    end

    --------------------------------------------------------
    -- mouse_scroll
    --------------------------------------------------------
    if event.type == "mouse_scroll" then
        return handle_scroll(event)
    end

    --------------------------------------------------------
    -- button_down
    --------------------------------------------------------
    if event.type == "button_down" then
        local mods = event.mods or {}
        local has_mod = mods.control or mods.shift or mods.alt or mods.super

        -- modifier + click → global action (priority)
        if has_mod then
            return handle_global_click(event)
        end

        -- left click → element hit test
        if event.button == "left" then
            left_down_handled = handle_left_click(event)
            return left_down_handled
        end

        -- other button → global action
        return handle_global_click(event)
    end

    --------------------------------------------------------
    -- button_up (right, middle, back, forward → global click)
    --------------------------------------------------------
    if event.type == "button_up" then
        if event.button == "left" then
            local handled = left_down_handled
            left_down_handled = false
            -- element already handled the left click (button_down) → do not fire globally
            if handled then return false end
            return handle_global_click(event)
        end
        return handle_global_click(event)
    end

    return false
end

------------------------------------------------------------
-- Conky callback
------------------------------------------------------------

function conky_on_mouse(event)
    return on_event(event)
end

------------------------------------------------------------
-- Clickable areas (Cairo-free interaction)
------------------------------------------------------------

function register_clickable_area(x, y, w, h, action)
    local a = { x = x, y = y, w = w, h = h }
    if type(action) == "table" then
        a.click_view = action.click_view
        a.click = action.click
    elseif type(action) == "function" then
        a.click = action
    elseif type(action) == "string" then
        local name = action:match("^toggle:(.+)$")
        if name then
            a.toggle_view = name
        else
            name = action:match("^view:(.+)$")
            if name then
                a.click_view = name
            else
                a.click = action
            end
        end
    end
    CLICKABLE_AREAS[#CLICKABLE_AREAS + 1] = a
end

-- Text-callable variant: ${lua conky_register_clickable_area 0,0,100,100 view:main}
-- The rect arrives as a single "x,y,w,h" string because ${lua} splits args
-- on spaces and passes them as strings. Any extra args are rejoined into a
-- shell command (e.g. ${lua conky_register_clickable_area 0,0,100,100 notify-send hello}).
function conky_register_clickable_area(rect, ...)
    if type(rect) ~= "string" then
        return ""
    end
    local x, y, w, h = rect:match("^(%-?%d+),%s*(%-?%d+),%s*(%-?%d+),%s*(%-?%d+)$")
    if not x then
        return ""
    end
    local args = { ... }
    local action
    if args[1] and (args[1]:match("^toggle:") or args[1]:match("^view:")) then
        action = args[1]
        args = nil
    end
    register_clickable_area(tonumber(x), tonumber(y), tonumber(w), tonumber(h), action or (args and #args > 0 and table.concat(args, " ") or nil))
    return ""
end

function clear_clickable_areas()
    CLICKABLE_AREAS = {}
end

-- text-callable alias: ${lua conky_clear_clickable_areas}
function conky_clear_clickable_areas()
    clear_clickable_areas()
    return ""
end
