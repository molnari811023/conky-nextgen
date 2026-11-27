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
    slot_width    = 176,
    slot_height   = 30,
    icon_size     = 20,
    x_start       = 106,
    y             = 9,
    spacing       = 6,
    panel_height  = 48,
    font          = "Sans",
    font_size     = 11,
    title_max     = 19,
    icon_pos      = "left",     -- left|right
    -- display mode: "full" (icon+title), "icon" (icon only), "name" (title only)
    mode          = "full",
    fallback_icon = "application-default-icon",
    size_override = nil,
    states = {
        normal   = { bg = "#282c34", fg = "#eceff4", border = "#434c5e" },
        focus    = { bg = "#1f425c", fg = "#ffffff", border = "#3daee9" },
        urgent   = { bg = "#5c242b", fg = "#ffffff", border = "#ff626e" },
        minimize = { bg = "#1c1f24", fg = "#7c838e", border = "#2e3440" },
    },
    class_exclude = {
        ["conky.panel_conky"] = true,
        ["conky.start_menu_conky"] = true,
        ["start_menu_conky.start_menu_conky"] = true,
        ["start_menu_conky"] = true,
        ["conky.calendar_popup_conky"] = true,
        ["calendar_popup_conky.calendar_popup_conky"] = true,
        ["calendar_popup_conky"] = true,
        ["conky.conky"] = true,
        ["panel_conky.panel_conky"] = true,
        ["panel_conky"] = true,
        ["xfce4-notifyd.Xfce4-notifyd"] = true,
        ["xfce4-notifyd"] = true,
        ["dunst.Dunst"] = true,
        ["dunst"] = true,
        ["notify-osd.Notify-osd"] = true,
        ["notify-osd"] = true,
    },
}

TASKLIST = { wins = {}, by_id = {}, focused = 0, ready = false }

local IS_WAYLAND = (os.getenv("WAYLAND_DISPLAY") or "") ~= ""
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

--- Check if a window's class matches the excluded list or contains notify
local function is_excluded(w)
    if not w then return true end
    local k = w.klass
    if not k or k == "" then return true end
    if TASKLIST_CFG.class_exclude[k] then return true end
    local k_lower = k:lower()
    if TASKLIST_CFG.class_exclude[k_lower] then return true end
    for seg in k_lower:gmatch("[^%.]+") do
        if TASKLIST_CFG.class_exclude[seg] then return true end
        if seg:find("notify") then return true end
    end
    return false
end

--- Read the EWMH state atoms (active/hidden/urgent/…) and window type of one window.
-- @tparam number win the window id
-- @treturn table map of atom-name → true
local function window_state(win)
    local state = {}
    local p = io.popen("xprop -id " .. q(string.format("0x%x", win)) ..
                       " _NET_WM_STATE _NET_WM_WINDOW_TYPE 2>/dev/null")
    if not p then return state end
    local data = p:read("*a")
    p:close()
    if not data then return state end
    for atom in data:gmatch("_NET_WM_STATE_([A-Za-z0-9_]+)") do
        state[atom] = true
    end
    for wtype in data:gmatch("_NET_WM_WINDOW_TYPE_([A-Za-z0-9_]+)") do
        state["TYPE_" .. wtype] = true
    end
    return state
end

--- Rebuild the effective window list from wmctrl + xprop, then repaint
-- every registered slot's draw item fields. Runs at most once per conky
-- ${updates} tick (TLW() calls it from every slot's draw_me).
function tasklist_update()
    if not changed() then return TASKLIST end
    if not draw or #draw == 0 then return TASKLIST end

    if IS_WAYLAND then
        local runtime_dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
        local tsv_path = runtime_dir .. "/conky_wayland_tasklist.tsv"
        local f = io.open(tsv_path, "r")
        local tab, by_id = {}, {}
        local active = 0
        if f then
            for line in f:lines() do
                local id_str, app_id, state_str, icon_png, title =
                    line:match("^([^\t]+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$")
                local wid = tonumber(id_str)
                if wid then
                    local dummy_w = { win = wid, klass = app_id, title = trim(title) }
                    if not is_excluded(dummy_w) then
                        local is_act = (state_str == "focus")
                        if is_act then active = wid end
                        local entry = {
                            win      = wid,
                            title    = dummy_w.title,
                            klass    = app_id,
                            app      = apps_by_wmclass(app_id),
                            icon_png = (icon_png ~= "" and icon_png or nil),
                            state    = {
                                HIDDEN = (state_str == "minimize"),
                                URGENT = (state_str == "urgent"),
                            },
                            active   = is_act,
                        }
                        tab[#tab + 1] = entry
                        by_id[wid] = entry
                        if #tab >= TL_MAX then break end
                    end
                end
            end
            f:close()
        end

        TASKLIST.wins    = tab
        TASKLIST.by_id   = by_id
        TASKLIST.focused = active
        TASKLIST.ready   = true
        tasklist_paint()
        return TASKLIST
    end

    local wins = {}
    local p = io.popen("wmctrl -lx 2>/dev/null")
    if p then
        for line in p:lines() do
            local w = parse_wmctrl_line(line)
            if w and not is_excluded(w) and w.title ~= "" then
                wins[#wins + 1] = w
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

    local tab, by_id = {}, {}
    for i = 1, #wins do
        local w = wins[i]
        local st = window_state(w.win)
        local skip = st.SKIP_TASKBAR or st.TYPE_NOTIFICATION or st.TYPE_DOCK or
                     st.TYPE_DESKTOP or st.TYPE_SPLASH or st.TYPE_TOOLTIP or
                     st.TYPE_POPUP_MENU
        if not skip then
            local entry = {
                win      = w.win,
                title    = w.title,
                klass    = w.klass,
                app      = apps_by_wmclass(w.klass),
                state    = st,
                active   = (w.win == active),
            }
            tab[#tab + 1] = entry
            by_id[w.win] = entry
            if #tab >= TL_MAX then break end
        end
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
    local xs = cfg_val("x_start", 12)
    local ys = cfg_val("spacing", 6)
    for i = 1, TL_MAX do
        local s = TASKLIST.slots[i]
        if not s then break end
        local w = TASKLIST.wins[i]
        local x = xs + (i - 1) * (sw + ys)
        local st = w and slot_state(w) or "normal"
        local ph = TASKLIST_CFG.panel_height or 48
        local y = math.floor((ph - sh) / 2)

        s.bg.x   = x
        s.bg.y   = y
        s.bg.w   = sw
        s.bg.h   = sh
        s.bg.bg  = { { 1, TASKLIST_CFG.states[st].bg, (st == "minimize") and 0.65 or 0.92 } }
        s.bg.border = { { 1, TASKLIST_CFG.states[st].border or "#3daee9", (st == "focus") and 0.95 or 0.55 } }
        s.bg.border_width = (st == "focus") and 1.5 or 1.0
        s.bg.radius = (mode == "icon") and sw / 2 or 6
        s.bg.click  = w and TL_CLICK_STR(w) or nil
        s.bg.mclick = w and TL_MCLICK_STR(w) or nil

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
            s.icon.path   = icon_path
            s.icon.type   = icon_path:match("%.svg$") and "svg" or "image"
            s.icon.w      = is
            s.icon.h      = is
            s.icon.width  = is
            s.icon.height = is
            s.icon.click  = s.bg.click
            s.icon.mclick = s.bg.mclick
        else
            s.icon.path   = nil
            s.icon.click  = nil
            s.icon.mclick = nil
            s.icon.w      = 0
            s.icon.h      = 0
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
            s.text.x      = tx
            s.text.y      = y + math.floor((sh - fs) / 2) - 1
            s.text.font   = TASKLIST_CFG.font
            s.text.size   = fs
            s.text.weight = (st == "focus") and "bold" or "normal"
            s.text.slant  = (st == "minimize") and "italic" or "normal"
            s.text.text   = function() return title end
            s.text.color  = { { 1, TASKLIST_CFG.states[st].fg, 1 } }
            s.text.click  = s.bg.click
            s.text.mclick = s.bg.mclick
        else
            s.text.text   = nil
            s.text.click  = nil
            s.text.mclick = nil
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
    local candidates = {}
    local seen = {}
    local function push(name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            candidates[#candidates + 1] = name
        end
    end

    if w.app and w.app.icon and w.app.icon ~= "" then
        push(w.app.icon)
    end

    -- Reverse-DNS instance: "nl.hjdskes.gcolor3" from "nl.hjdskes.gcolor3.Gcolor3"
    local instance_part = klass:match("^(.-)%.[^%.]+$")
    if instance_part then
        push(instance_part)
        push(instance_part:lower())
    end

    -- Reverse-DNS class: "com.mitchellh.ghostty" from "ghostty.com.mitchellh.ghostty"
    local class_part = klass:match("^[^%.]+%.(.+)$")
    if class_part then
        push(class_part)
        push(class_part:lower())
    end

    -- First segment (instance if simple)
    local first = klass:match("^([^%.]+)")
    if first then push(first); push(first:lower()) end

    -- Last segment (class if simple)
    local last = klass:match("[^%.]+$")
    if last then push(last); push(last:lower()) end

    -- Full wmclass
    push(klass)
    push(klass:lower())

    -- Each dot-separated segment
    for p in klass:gmatch("[^%.]+") do
        push(p)
        push(p:lower())
    end

    local themes = { XDG_ICON_THEME or "Papirus", "breeze", "breeze-dark", "Adwaita", "AdwaitaLegacy", "oxygen", "hicolor" }
    for _, tname in ipairs(themes) do
        for _, name in ipairs(candidates) do
            local path = icon_resolve(name, eff_icon_size(), tname)
            if path then return path end
        end
    end

    if w.icon_png and w.icon_png ~= "" then
        local f = io.open(w.icon_png, "r")
        if f then
            f:close()
            return w.icon_png
        end
    end

    local fallbacks = {}
    if TASKLIST_CFG.fallback_icon then
        fallbacks[#fallbacks + 1] = TASKLIST_CFG.fallback_icon
    end
    fallbacks[#fallbacks + 1] = "application-default-icon"
    fallbacks[#fallbacks + 1] = "application-x-executable"
    fallbacks[#fallbacks + 1] = "application-x-generic"

    for _, tname in ipairs(themes) do
        for _, name in ipairs(fallbacks) do
            local path = icon_resolve(name, eff_icon_size(), tname)
            if path then return path end
        end
    end
    return nil
end

--- UTF-8 safe string truncation so multi-byte characters (ő, ű, —) are never split mid-byte.
local function utf8_truncate(str, max_chars)
    if not str then return "" end
    local count = 0
    local byte_idx = 1
    local len = #str
    while byte_idx <= len do
        count = count + 1
        if count > max_chars then
            return str:sub(1, byte_idx - 1) .. "…"
        end
        local c = str:byte(byte_idx)
        if c < 0x80 then
            byte_idx = byte_idx + 1
        elseif c < 0xE0 then
            byte_idx = byte_idx + 2
        elseif c < 0xF0 then
            byte_idx = byte_idx + 3
        else
            byte_idx = byte_idx + 4
        end
    end
    return str
end

--- Window title, trimmed to the slot width.
function slot_title(w)
    if not w then return "" end
    local t = w.title or ""
    return utf8_truncate(t, eff_title_max())
end

--- Shell-safe wmctrl (X11) or panel_systray --click (Wayland) activate/minimize action.
function TL_CLICK_STR(w)
    if IS_WAYLAND then
        local dir = script_dir or "/home/molnar/.conky/panel_systray/"
        return string.format("%spanel_systray --click %d 1 &", dir, w.win)
    end
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

--- Shell-safe middle-click close action (Wayland panel_systray --click <id> 2 or X11 wmctrl -i -c).
function TL_MCLICK_STR(w)
    if IS_WAYLAND then
        local dir = script_dir or "/home/molnar/.conky/panel_systray/"
        return string.format("%spanel_systray --click %d 2 &", dir, w.win)
    end
    return "wmctrl -i -c " .. string.format("0x%x", w.win)
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