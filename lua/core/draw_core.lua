--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- core/draw_core.lua — Cairo, main loop, helper functions
-- Functions:
--   conky_core_main()          — Conky draw hook (lua_draw_hook_pre)
--     Entry point of the render loop. Called by Conky on every draw;
--     renders the whole `draw` list, applies the theme, resolves
--     views/groups and draw_me conditions. Do not call manually.
--   conky_cleanup()            — Conky shutdown
--     Shutdown hook; releases surfaces/patterns. Called by Conky on exit.
--   draw_allowed(view, group)  — element visibility check (view: string or list)
--     Whether an element should render in the current view/group.
--     `view` may be a string or a list of views.
--   init_groups(group_list)    — initialize groups
--     Register the group list (views + groups) once at startup.
--   compute_group_offsets(...) — compute group Y offsets
--     Lay out groups vertically; returns per-group Y offsets.
--   compute_group_height(...)  — compute group height
--     Measure the tallest element in each group.
--   modify_group_background(...)  — hover highlight
--     Temporarily restyle a group's background on hover.
--   restore_group_background(...) — hover restore
--     Restore a group's background after hover ends.
--
-- Auto-interpretation: string text/value → interpret_name table
-- Theme system: apply_theme() fills colors from the THEMES block in widget.lua
-- (done by draw_core, no need to call from main.lua)

------------------------------------------------------------
-- STATE
------------------------------------------------------------
--}}}

GROUP_VIEWS   = GROUP_VIEWS or {}
GROUP_OFFSETS = GROUP_OFFSETS or {}
HOVER_VIEW    = HOVER_VIEW or nil

current_view  = current_view or "main"

------------------------------------------------------------
-- CONDITIONAL DRAW (draw_me)
------------------------------------------------------------
-- draw_me can be (same logic as interpret_name for text/value):
--   boolean            → itself
--   string with "()"   → Lua expression (load), truthy = draw
--   string without "()"→ Conky template, conky_parse == "1" = draw
--   nil                → always draw
function evaluate_draw_me(draw_me)
    if draw_me == nil then return true end
    if type(draw_me) == "boolean" then return draw_me end

    if type(draw_me) == "function" then
        local r = draw_me()
        return r == true or r == 1 or r == "1"
    end

    if type(draw_me) == "string" then
        if draw_me:find("%(") and draw_me:find("%)") then
            local fn = load("return " .. draw_me)
            if fn then
                local r = fn()
                return r == true or r == 1 or r == "1"
            end
        else
            return conky_parse(draw_me) == "1"
        end
    end

    return true
end

------------------------------------------------------------
-- VIEW LOGIC
------------------------------------------------------------

local function view_contains(v, name)
    -- v can be a string or a list (multiple views per element)
    if type(v) == "table" then
        for _, vv in ipairs(v) do
            if vv == name then return true end
        end
        return false
    end
    return v == name
end

function draw_allowed(item_view, item_group)
    -- If the element specifies a view, draw only in that view
    if item_view then
        local matches = view_contains(item_view, current_view)
        if not matches and HOVER_VIEW then
            matches = view_contains(item_view, HOVER_VIEW)
        end
        if not matches then
            return false
        end
    end

    -- Grouped element: the group's views must also be checked
    if item_group then
        local gview = GROUP_VIEWS[item_group]
        if gview ~= nil then
            local found = false
            for _, gv in ipairs(gview) do
                if gv == current_view then
                    found = true; break
                end
            end
            if not found and current_view ~= "main" then return false end
        end
    end

    -- Group state: nil = hidden (draw_me false), non-nil = visible
    if item_group then
        local gname = item_group:match("^!(.+)$") or item_group
        local invert = item_group ~= gname
        local visible = GROUP_STATE[gname] ~= nil
        if (invert and visible) or (not invert and not visible) then
            return false
        end
    end

    return true
end

------------------------------------------------------------
-- GROUP HANDLING
------------------------------------------------------------

function init_groups(group_list)
    for _, g in ipairs(group_list) do
        GROUP_VIEWS[g.name] = g.views or {}
        register_group(g.name)
    end
end

------------------------------------------------------------
-- Group background override (hover highlight)
------------------------------------------------------------

local GROUP_ORIGINS = {}

function modify_group_background(group_name, overrides)
    if not group_name or not overrides then return end
    if not GROUP_ORIGINS[group_name] then
        GROUP_ORIGINS[group_name] = {}
    end

    for _, item in ipairs(draw) do
        if item.group == group_name and item.type == "background" then
            local key = tostring(item)
            if not GROUP_ORIGINS[group_name][key] then
                GROUP_ORIGINS[group_name][key] = {
                    bg = item.bg,
                    border = item.border,
                    border_width = item.border_width,
                }
            end
            for k, v in pairs(overrides) do
                item[k] = v
            end
        end
    end
end

function restore_group_background(group_name)
    if not group_name then return end
    local origins = GROUP_ORIGINS[group_name]
    if not origins then return end

    for _, item in ipairs(draw) do
        if item.group == group_name and item.type == "background" then
            local key = tostring(item)
            local orig = origins[key]
            if orig then
                item.bg = orig.bg
                item.border = orig.border
                item.border_width = orig.border_width
            end
        end
    end
    GROUP_ORIGINS[group_name] = nil
end

local function infer_item_height(item)
    if item.h and item.h > 0 then return item.h end
    if item.height and item.height > 0 then return item.height end
    local t = item.type
    if t == "clock" then return (item.radius or 60) + 10 end
    if t == "ring" then return (item.radius or 50) + 10 end
    if t == "bar" then return (item.height or 12) + 6 end
    if t == "graph" then return (item.height or 40) + 6 end
    if t == "calendar" then return (item.row_h or 20) * 9 + 30 end
    if t == "text" then return (item.size or 12) * 1.6 + 4 end
    if t == "image" then return 48 end
    if t == "svg" then return (item.h or 48) end
    if t == "background" then return 0 end
    if t == "line" then return 10 end
    if t == "arc" then return (item.r or 30) end
    return 30
end

function compute_group_height(group_name, draw_list)
    local max_y = 0
    for _, item in ipairs(draw_list) do
        if item.group == group_name then
            if not evaluate_draw_me(item.draw_me) then goto continue end
            local item_view = item.view or "main"
            if view_contains(item_view, current_view) then
                local ih = infer_item_height(item)
                local iy = item.y or 0
                if iy + ih > max_y then max_y = iy + ih end
            end
            ::continue::
        end
    end
    return max_y
end

local function compute_group_offsets(group_list, draw_list, padding)
    padding = padding or 10
    local offset = 0
    GROUP_OFFSETS = {}

    for _, g in ipairs(group_list) do
        local name = g.name
        local views = GROUP_VIEWS[name]

        local visible
        if GROUP_STATE[name] == nil then
            visible = false
        elseif current_view == "main" then
            visible = true
        elseif views then
            visible = false
            for _, v in ipairs(views) do
                if v == current_view then
                    visible = true; break
                end
            end
        else
            visible = false
        end

        GROUP_OFFSETS[name] = { y = offset, visible = visible, height = 0 }

        if visible then
            local h = compute_group_height(name, draw_list)
            GROUP_OFFSETS[name].height = h
            if h > 0 then
                offset = offset + h + padding
            end
        end
    end
end

------------------------------------------------------------
-- DRAWING
------------------------------------------------------------

local DRAW_DISPATCH = nil

-- Overridable no-op: the NextGen Designer's preview helper (a second
-- lua_load file, sh/designer/live_clear.lua) replaces this to clear the
-- surface each frame. On X11 an ARGB window keeps the previous frame, so
-- moved/shrunk items would leave permanent ghosts; the deployed config
-- keeps this no-op and is unaffected.
function clear_surface(cr) end

function conky_core_main()
    if not conky_window then return end

    local updates = tonumber(conky_parse("${updates}")) or 0
    if updates < 3 then return end

    if capture_poll then capture_poll() end

    local cs = conky_surface()

    if not draw or #draw == 0 then
        if cs and capture_finish then capture_finish() end
        return
    end
    if not _GROUPS then
        if cs and capture_finish then capture_finish() end
        return
    end

    check_group_visibility()
    compute_group_offsets(_GROUPS, draw, _PADDING or 10)

    if not cs then return end
    local cr = cairo_create(cs)

    clear_surface(cr)

    if not DRAW_DISPATCH then
        DRAW_DISPATCH = {
            background = draw_background,
            line       = draw_line_modules,
            text       = draw_text,
            bar        = conky_draw_bar_modules,
            ring       = draw_one_ring,
            image      = draw_png,
            svg        = draw_svg,
            graph      = draw_graph,
            calendar   = draw_calendar,
            clock      = draw_clock,
            arc        = draw_arc,
        }
    end

    for _, item in ipairs(draw) do
        if not evaluate_draw_me(item.draw_me) then goto continue end
        if not draw_allowed(item.view, item.group) then goto continue end

        local gname = item.group
        if gname and GROUP_OFFSETS[gname] and not GROUP_OFFSETS[gname].visible then goto continue end

        -- APPLY THEME: gradient name → stops, missing colors
        apply_theme(item)

        -- AUTO-INTERPRET: string fields → interpret_name table
        if type(item.text) == "string" then
            item.text = interpret_name(item.text)
        end
        if type(item.value) == "string" then
            item.value = interpret_name(item.value)
        end

        local group_offset_y = GROUP_OFFSETS[gname] and GROUP_OFFSETS[gname].y or 0

        local saved_x, saved_y = item.x, item.y
        if type(item.x) == "function" then item.x = item.x() end
        if type(item.y) == "function" then item.y = item.y() end
        item.y = (item.y or 0) + group_offset_y

        local fn = DRAW_DISPATCH[item.type]
        if fn then fn(cr, item) end

        item.x, item.y = saved_x, saved_y

        ::continue::
    end

    if capture_finish then capture_finish() end

    cairo_destroy(cr)
end

function conky_cleanup()
    if svg_free_all then
        svg_free_all()
    end
end
