--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
tasklist.lua — taskbar for the bottom panel: open windows as icon+title slots

Pull-based (no event loop): wmctrl -lx lists the client windows, xprop
reads the EWMH state (_NET_WM_STATE) of each. The AwesomeWM tasklist
semantics are mirrored:
  - only normal client windows (skip_taskbar / hidden / desktop-type win
    excluded, Conky panel+its tray excluded)
  - icon = the app's .desktop Icon name resolved through the icon theme
    (apps_by_wmclass + icon_resolve), drawn with draw_svg — no _NET_WM_ICON
    pixel parsing
  - per-window background colour by state: focused / urgent / minimized / normal
  - left click = activate + toggle minimize (wmctrl)

Layout: slots run from left to right above the systray. tasklist_install()
registers `TASKLIST_CFG.max_windows` concrete draw items (background + svg
icon + title text); tasklist_update() fills their x/y/w/h/bg/path/text/click
fields each frame, so both the draw pass and the mouse hit-test always see
concrete numbers.
]]--

--{{{
-- ## Tasklist widget
--
-- **Exposed/global functions:**
-- - `tasklist_install()` — creates the slot draw items (returns the count).
-- - `tasklist_update()` — rebuilds TASKLIST.wins and repaints every slot's
--   draw item fields (memoized per conky ${updates} tick).
-- - `TLW(n)` — slot n occupied? (draw_me for the registered draw items).
--
-- **Config/globals used:** `apps_by_wmclass()`, `icon_resolve()`, `draw`
-- (only via the widget root, not directly here).
--}}}
TASKLIST_CFG = {
    max_windows   = 24,
    slot_width    = 168,
    slot_height   = 26,
    icon_size     = 44,
    x_start       = 8,
    y             = 4,
    spacing       = 2,
    panel_height  = 48,          -- panel height (icon-mode slot fills this)
    font          = "Sans",
    font_size     = 11,
    title_max     = 20,
    icon_pos      = "left",     -- left|right
    -- display mode: "full" (icon+title), "icon" (icon only), "name" (title only)
    mode          = "icon",
    -- per-field size override (wins over the defaults above):
    --   size_override = { slot_width = 120, slot_height = 22,
    --                     icon_size = 14, font_size = 10, title_max = 16 }
    size_override = nil,
    states = {
        normal   = { bg = "#202326", fg = "#fcfcfc" },
        focus    = { bg = "#3daee9", fg = "#1b1d1f" },
        urgent   = { bg = "#ff626e", fg = "#1b1d1f" },
        minimize = { bg = "#31363c", fg = "#a1a9b1" },
    },
    class_exclude = {
        ["conky.panel_conky"] = true,
        ["conky.conky"] = true,
        ["panel_conky.panel_conky"] = true,
        ["panel_conky"] = true,
    },
}

TASKLIST = { wins = {}, by_id = {}, focused = 0, ready = false }

local TL_MAX   = TASKLIST_CFG.max_windows
local TL_XS    = TASKLIST_CFG.x_start
local TL_Y     = TASKLIST_CFG.y
local TL_YS    = TASKLIST_CFG.spacing

-- effective dimensions: defaults overridden by TASKLIST_CFG.size_override,
-- mode-aware slot sizing ("icon" resolves the slot around the icon).
local function cfg_val(key, dflt)
    local ov = TASKLIST_CFG.size_override
    if ov and ov[key] ~= nil then return ov[key] end
    return TASKLIST_CFG[key] ~= nil and TASKLIST_CFG[key] or dflt
end

local function eff_icon_size()  return cfg_val("icon_size", 18) end
local function eff_font_size()  return cfg_val("font_size", 11) end
local function eff_title_max()  return cfg_val("title_max", 20) end

local function eff_slot_size()
    local is = eff_icon_size()
    local mode = TASKLIST_CFG.mode or "full"
    if mode == "icon" then
        -- square slot == panel height → radius = w/2 renders a full circle
        local sq = cfg_val("panel_height", is + 8)
        return sq, sq
    end
    if mode == "name" then
        local w = cfg_val("slot_width", 168)
        local h = cfg_val("slot_height", 26)
        return w, h
    end
    return cfg_val("slot_width", 168), cfg_val("slot_height", 26)
end

local last_updates = -1

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function trim(s)
    if not s then return "" end
    return s:match("^%s*(.-)%s*$")
end

-- Escape a shell argument for wmctrl/xprop calls
local function q(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

--- Cheap percent-free update guard: run once per conky update tick.
local function changed()
    local u = tonumber(conky_parse("${updates}")) or -1
    if u == last_updates then return false end
    last_updates = u
    return true
end

--- Parse one line of `wmctrl -lx` output.
-- @tparam string line e.g. "0x2c00099  0 ghostty.com.mitchellh.ghostty  molnarc OpenCode"
-- @treturn table|nil { win, desktop, klass, title }
local function parse_wmctrl_line(line)
    local winhex, desktop, klass, host, title =
        line:match("^(0x%x+)%s+(%-?%d+)%s+(%S+)%s+([^%s]+)%s+(.*)$")
    if not winhex then return nil end
    return {
        win     = tonumber(winhex),
        desktop = tonumber(desktop),
        klass   = klass,
        title   = trim(title),
    }
end

--- Read the EWMH state atoms (active/hidden/urgent/…) of one window.
-- @tparam number win the window id
-- @treturn table map of atom-name → true
local function window_state(win)
    local state = {}
    local p = io.popen("xprop -id " .. q(string.format("0x%x", win)) ..
                       " _NET_WM_STATE 2>/dev/null")
    if not p then return state end
    local data = p:read("*a")
    p:close()
    if not data then return state end
    for atom in data:gmatch("_NET_WM_STATE_([A-Za-z]+)") do
        state[atom] = true
    end
    return state
end

--- Rebuild the effective window list from wmctrl + xprop, then repaint
-- every registered slot's draw item fields. Runs at most once per conky
-- ${updates} tick (TLW() calls it from every slot's draw_me).
function tasklist_update()
    if not changed() then return TASKLIST end
    if not draw or #draw == 0 then return TASKLIST end

    local wins, by_id = {}, {}
    local p = io.popen("wmctrl -lx 2>/dev/null")
    if p then
        for line in p:lines() do
            local w = parse_wmctrl_line(line)
            if w then
                local excl = w.klass and TASKLIST_CFG.class_exclude[w.klass]
                if not excl and w.title ~= "" then
                    wins[#wins + 1] = w
                    by_id[w.win] = w
                end
            end
        end
        p:close()
    end

    -- active window id from the root window
    local active = 0
    local pr = io.popen("xprop -root _NET_ACTIVE_WINDOW 2>/dev/null")
    if pr then
        local data = pr:read("*a")
        pr:close()
        if data then
            active = tonumber(data:match("window id #%s*(0x%x+)")) or 0
        end
    end

    local tab = {}
    for i = 1, math.min(#wins, TL_MAX) do
        local w = wins[i]
        local st = window_state(w.win)
        tab[i] = {
            win      = w.win,
            title    = w.title,
            klass    = w.klass,
            app      = apps_by_wmclass(w.klass),
            state    = st,
            active   = (w.win == active),
        }
    end

    TASKLIST.wins    = tab
    TASKLIST.by_id   = by_id
    TASKLIST.focused = active
    TASKLIST.ready   = true

    tasklist_paint()
    return TASKLIST
end

--- The draw items created by tasklist_install(), one table per slot.
TASKLIST.slots = TASKLIST.slots or {}

--- Repaint every source slot from TASKLIST.wins (concrete fields).
function tasklist_paint()
    local mode = TASKLIST_CFG.mode or "full"
    local is = eff_icon_size()
    local fs = eff_font_size()
    local sw, sh = eff_slot_size()
    for i = 1, TL_MAX do
        local s = TASKLIST.slots[i]
        if not s then break end
        local w = TASKLIST.wins[i]
        local x = TL_XS + (i - 1) * (sw + TL_YS)
        local st = w and slot_state(w) or "normal"
        local y = (mode == "icon") and TL_Y + ((TASKLIST_CFG.panel_height or sh) - sh) / 2 or TL_Y

        s.bg.x   = x
        s.bg.y   = y
        s.bg.w   = sw
        s.bg.h   = sh
        s.bg.bg  = { { 1, TASKLIST_CFG.states[st].bg, 1 } }
        s.bg.radius = (mode == "icon") and sw / 2 or nil
        s.bg.click = w and TL_CLICK_STR(w) or nil

        local icon_path = w and slot_icon(w) or nil
        local show_icon = (mode ~= "name") and icon_path
        local show_text = (mode ~= "icon") and w ~= nil
        local ipos = TASKLIST_CFG.icon_pos or "left"

        if show_icon then
            local iy = y + (sh - is) / 2
            if mode == "icon" then
                s.icon.x = x + (sw - is) / 2
                s.icon.y = iy
            elseif ipos == "right" then
                s.icon.x = x + sw - is - 5
                s.icon.y = iy
            else
                s.icon.x = x + 5
                s.icon.y = iy
            end
            s.icon.path = icon_path
            s.icon.type = icon_path:match("%.svg$") and "svg" or "image"
            s.icon.w    = is
            s.icon.h    = is
            s.icon.click = s.bg.click
        else
            s.icon.path = nil
        end

        if show_text then
            local title = slot_title(w)
            local tx
            if show_icon then
                if mode == "icon" then
                    tx = x + 6
                elseif ipos == "right" then
                    tx = x + 6
                else
                    tx = x + is + 10
                end
            else
                tx = x + 6
            end
            s.text.x    = tx
            s.text.y    = y + (sh - fs) / 2 - 1
            s.text.font = TASKLIST_CFG.font
            s.text.size = fs
            s.text.text = title
            s.text.color = { { 1, TASKLIST_CFG.states[st].fg, 1 } }
            s.text.click = s.bg.click
        else
            s.text.text = nil
        end
    end
end

--- Window present at slot n? (draw_me — also refreshes the list once/tick)
function TLW(n)
    tasklist_update()
    return TASKLIST.wins[n] ~= nil
end

--- Slot visual state from a single window entry.
function slot_state(w)
    if not w then return "normal" end
    if w.state.HIDDEN then
        if w.state.URGENT then return "urgent" end
        return "minimize"
    end
    if w.active then return "focus" end
    if w.state.URGENT then return "urgent" end
    return "normal"
end

--- Icon name lookup + theme resolution for one window entry.
-- Candidate order: .desktop Icon (via apps_by_wmclass), then the class
-- part of instance.class (reverse-DNS: "com.mitchellh.ghostty"), then the
-- instance, then the last dotted part as a catch-all. The first one that
-- exists in the theme is returned.
function slot_icon(w)
    if not w then return nil end
    local klass = w.klass or ""
    local instance, class_part = klass:match("^([^%.]+)%.(.+)$")
    local candidates = {}
    if w.app and w.app.icon and w.app.icon ~= "" then
        candidates[#candidates + 1] = w.app.icon
    end
    local seen = {}
    local function push(name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            candidates[#candidates + 1] = name
        end
    end
    push(class_part)
    push(instance)
    push(klass:match("[^%.]+$"))
    if #candidates == 0 then return nil end
    for _, name in ipairs(candidates) do
        local path = icon_resolve(name, eff_icon_size(), XDG_ICON_THEME or "Papirus")
        if path then return path end
    end
    return nil
end

--- Window title, trimmed to the slot width.
function slot_title(w)
    if not w then return "" end
    local t = w.title or ""
    local maxc = eff_title_max()
    if #t > maxc then t = t:sub(1, maxc - 1) .. "…" end
    return t
end

--- Shell-safe wmctrl activate/minimize action for one window.
function TL_CLICK_STR(w)
    local win = string.format("0x%x", w.win)
    if w.state.HIDDEN then
        return "wmctrl -i -a " .. win
    end
    -- focused: toggle minimize; normal: activate
    if w.active then
        return "wmctrl -i -r " .. win .. " -b add,hidden"
    end
    return "wmctrl -i -a " .. win
end

--- Register the tasklist slot draw items into the global `draw` list.
-- Each slot paints a background strip, an SVG icon and a title; all three
-- share the same click action and are skipped by draw_me when the window
-- count shrinks below the slot index.
-- @treturn number the number of slots registered
function tasklist_install()
    if TASKLIST.installed then return #TASKLIST.slots end
    for i = 1, TL_MAX do
        local s = { bg = {}, icon = {}, text = {} }
        s.bg.type = "background"
        s.icon.type = "svg"
        s.text.type = "text"
        s.bg.draw_me = function() return TLW(i) end
        s.icon.draw_me = function()
            return TLW(i) and TASKLIST_CFG.mode ~= "name"
        end
        s.text.draw_me = function()
            return TLW(i) and TASKLIST_CFG.mode ~= "icon"
        end
        draw[#draw + 1] = s.bg
        draw[#draw + 1] = s.icon
        draw[#draw + 1] = s.text
        TASKLIST.slots[i] = s
    end
    TASKLIST.installed = true
    tasklist_update()
    return #TASKLIST.slots
end