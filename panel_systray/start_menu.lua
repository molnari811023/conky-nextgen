--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Dynamic Start Menu popup widget driven by lua/apps.lua
--}}}
--[[[
start_menu.lua — Application launcher popup menu for the bottom panel.

Groups installed desktop applications from `apps_list()` into XDG categories.
Left column displays categories (hover or click switches active category);
right column displays applications in the selected category (mouse wheel
scrolls when a category has more apps than category rows).
Automatically exits when the pointer leaves the popup window (`MOUSE_LEAVE_ACTION`)
or after launching an application.
]]--

script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "?.lua"
    .. ";" .. script_dir .. "../lua/?.lua"
    .. ";" .. script_dir .. "../lua/core/?.lua"
    .. ";" .. script_dir .. "../lua/draw/?.lua"

JSON_PATH      = script_dir:match("^/usr") and ((os.getenv("HOME") or "/tmp") .. "/.conky/tmp/") or (script_dir .. "../tmp/")

draw = {}

ICON_BASE      = script_dir .. "../icons/"
ICON_THEME     = "default"
XDG_ICON_THEME = "breeze-dark"
MODULE_PROFILE = "basic"
_PADDING       = 0

THEMES = {
    theme = {
        palette = {
            bg_dark  = "#202326",
            bg_mid   = "#292c30",
            bg_light = "#31363c",
            fg       = "#fcfcfc",
            fg_dim   = "#a1a9b1",
            blue     = "#3daee9",
        },
        gradients = {
            border_subtle = { { 1, "#a1a9b1", 0.6 } },
        },
        defaults = {
            background = {
                bg = { { 1, "#202326", 0.96 } },
                border = { { 1, "#3daee9", 0.75 } },
                border_width = 1.5,
            },
            text = {
                color = { { 1, "#fcfcfc", 1 } },
            },
        },
    },
}

DEFAULT_THEME = "theme"

require("require")
require("apps")

------------------------------------------------------------
-- Start Menu configuration & layout metrics
--   label_mode:
--     "name"         -> Application Name (e.g. "Konsole")
--     "generic"      -> GenericName if available, else Name (e.g. "Terminál")
--     "name_generic" -> "Name (GenericName)" (e.g. "Konsole (Terminál)")
--     "generic_name" -> "GenericName (Name)" (e.g. "Terminál (Konsole)")
------------------------------------------------------------
START_MENU_CFG = {
    label_mode = "name_generic",
}

local ICON_SIZE = 22
local ROW_PAD   = 14
local ROW_H     = ICON_SIZE + ROW_PAD -- 36 px
local PAD_X     = 10
local PAD_Y     = 10
local CAT_W     = 176
local COL_GAP   = 10
local APP_W     = 244
local FOOTER_H  = 40

local MAIN_CATEGORIES = {
    AudioVideo  = "Multimedia",
    Audio       = "Multimedia",
    Video       = "Multimedia",
    Development = "Development",
    Education   = "Education",
    Game        = "Games",
    Graphics    = "Graphics",
    Network     = "Network",
    Office      = "Office",
    Science     = "Science",
    Settings    = "Settings",
    System      = "System",
    Utility     = "Utilities",
}

local CATEGORY_ICONS = {
    Development = "applications-development",
    Education   = "applications-education",
    Games       = "applications-games",
    Graphics    = "applications-graphics",
    Multimedia  = "applications-multimedia",
    Network     = "applications-internet",
    Office      = "applications-office",
    Science     = "applications-science",
    Settings    = "preferences-system",
    System      = "applications-system",
    Utilities   = "applications-utilities",
    Other       = "applications-other",
}

--- UTF-8 safe string truncation.
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

local function resolve_any_icon(icon_name, fallback_name)
    local themes = { XDG_ICON_THEME or "breeze-dark", "breeze", "Adwaita", "AdwaitaLegacy", "oxygen", "hicolor" }
    if icon_name and icon_name ~= "" then
        if icon_name:sub(1, 1) == "/" then
            local f = io.open(icon_name, "r")
            if f then f:close(); return icon_name end
        end
        for _, tname in ipairs(themes) do
            local p = icon_resolve(icon_name, ICON_SIZE, tname)
            if p then return p end
        end
    end
    if fallback_name then
        for _, tname in ipairs(themes) do
            local p = icon_resolve(fallback_name, ICON_SIZE, tname)
            if p then return p end
        end
    end
    return icon_resolve("application-x-executable", ICON_SIZE, "breeze-dark")
end

------------------------------------------------------------
-- Build categories & sorted apps from apps_list()
------------------------------------------------------------
local function build_menu_tree()
    local by_cat = {}
    local cat_names = {}

    for _, app in ipairs(apps_list()) do
        local cat_name = "Other"
        for _, c in ipairs(app.categories or {}) do
            if MAIN_CATEGORIES[c] then
                cat_name = MAIN_CATEGORIES[c]
                break
            end
        end
        if not by_cat[cat_name] then
            by_cat[cat_name] = {}
            cat_names[#cat_names + 1] = cat_name
        end
        by_cat[cat_name][#by_cat[cat_name] + 1] = app
    end

    table.sort(cat_names)

    local tree = {}
    for _, cname in ipairs(cat_names) do
        local apps = by_cat[cname]
        for _, a in ipairs(apps) do
            a.display_label = apps_display_name(a, START_MENU_CFG.label_mode)
            a.resolved_icon = a.icon_path or resolve_any_icon(a.icon, "application-x-executable")
        end
        table.sort(apps, function(a, b)
            return (a.display_label or a.name or ""):lower() < (b.display_label or b.name or ""):lower()
        end)
        tree[#tree + 1] = {
            id    = cname,
            name  = apps_category_label(cname),
            icon  = resolve_any_icon(CATEGORY_ICONS[cname], "applications-other"),
            apps  = apps,
        }
    end
    table.sort(tree, function(a, b)
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    return tree
end

local MENU_TREE = build_menu_tree()
local NUM_CATS  = math.max(1, #MENU_TREE)
local MENU_W    = PAD_X * 2 + CAT_W + COL_GAP + APP_W
local MENU_H    = PAD_Y * 2 + NUM_CATS * ROW_H + FOOTER_H

local active_cat_idx = 1
local scroll_offset  = 0
local hovered_app_slot = nil
local pointer_entered = false

local cat_rows  = {}
local app_slots = {}

local function refresh_menu_slots()

    -- 1. Update category rows (left column)
    for i = 1, NUM_CATS do
        local row = cat_rows[i]
        local cat = MENU_TREE[i]
        if row and cat then
            local is_active = (i == active_cat_idx)
            row.bg.bg = { { 1, is_active and "#1f425c" or "#292c30", is_active and 0.96 or 0.78 } }
            row.bg.border = { { 1, is_active and "#3daee9" or "#3b4048", is_active and 0.95 or 0.45 } }
            row.bg.border_width = is_active and 1.5 or 1.0
            row.text.weight = is_active and "bold" or "normal"
            row.text.color = { { 1, is_active and "#ffffff" or "#dde2e8", 1 } }
            row.count.color = { { 1, is_active and "#3daee9" or "#8e96a0", 1 } }
        end
    end

    -- 2. Update application slots (right column) for active category
    local cat = MENU_TREE[active_cat_idx]
    local apps = (cat and cat.apps) or {}
    local max_scroll = math.max(0, #apps - NUM_CATS)
    if scroll_offset > max_scroll then scroll_offset = max_scroll end
    if scroll_offset < 0 then scroll_offset = 0 end

    for s = 1, NUM_CATS do
        local slot = app_slots[s]
        local app_idx = scroll_offset + s
        local app = apps[app_idx]
        if slot then
            slot.app = app
            if app then
                local is_hov = (hovered_app_slot == s)
                slot.bg.bg = { { 1, is_hov and "#1f425c" or "#26292e", is_hov and 0.95 or 0.72 } }
                slot.bg.border = { { 1, is_hov and "#3daee9" or "#363b42", is_hov and 0.90 or 0.40 } }
                slot.bg.border_width = is_hov and 1.4 or 1.0

                local ipath = app.resolved_icon
                slot.icon.path   = ipath
                slot.icon.type   = (ipath and ipath:match("%.svg$")) and "svg" or "image"
                slot.icon.w      = ICON_SIZE
                slot.icon.h      = ICON_SIZE
                slot.icon.width  = ICON_SIZE
                slot.icon.height = ICON_SIZE

                local raw_label = apps_display_name(app, START_MENU_CFG.label_mode)
                local label = utf8_truncate(raw_label, 25)
                slot.text.text   = function() return label end
                slot.text.weight = is_hov and "bold" or "normal"
                slot.text.color  = { { 1, is_hov and "#ffffff" or "#eceff4", 1 } }
            else
                slot.icon.path = nil
                slot.text.text = nil
            end
        end
    end
end

local function launch_app(app)
    if not app or not app.command then return end
    if app.terminal then
        os.execute("konsole -e " .. app.command .. " >/dev/null 2>&1 &")
    else
        os.execute(app.command .. " >/dev/null 2>&1 &")
    end
    os.exit(0)
end

------------------------------------------------------------
-- Build draw items
------------------------------------------------------------

-- Outer popup frame
draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = MENU_W,
    h = MENU_H,
    radius = 10,
    bg = { { 1, "#1e2124", 0.96 } },
    border = { { 1, "#3daee9", 0.80 } },
    border_width = 1.5,
}

-- Vertical separator between Categories and Applications
draw[#draw + 1] = {
    type = "background",
    x = PAD_X + CAT_W + math.floor(COL_GAP / 2),
    y = PAD_Y,
    w = 1,
    h = NUM_CATS * ROW_H - 4,
    radius = 0,
    bg = { { 1, "#3b4048", 0.7 } },
    border_width = 0,
}

-- Left column: Categories
for i = 1, NUM_CATS do
    local cat = MENU_TREE[i]
    local ry = PAD_Y + (i - 1) * ROW_H
    local rh = ROW_H - 4
    local iy = ry + math.floor((rh - ICON_SIZE) / 2)
    local ty = ry + math.floor((rh - 11) / 2) - 1

    local function select_cat()
        pointer_entered = true
        if active_cat_idx ~= i then
            active_cat_idx = i
            scroll_offset = 0
            hovered_app_slot = nil
            refresh_menu_slots()

        end
    end

    local row_bg = {
        type = "background",
        x = PAD_X,
        y = ry,
        w = CAT_W,
        h = rh,
        radius = 6,
        hover = select_cat,
        click = select_cat,
    }
    local row_icon = {
        type = "svg",
        x = PAD_X + 8,
        y = iy,
        w = ICON_SIZE,
        h = ICON_SIZE,
        width = ICON_SIZE,
        height = ICON_SIZE,
        path = cat and cat.icon or nil,
    }
    if row_icon.path and not row_icon.path:match("%.svg$") then
        row_icon.type = "image"
    end

    local cat_title = cat and cat.name or ""
    local row_text = {
        type = "text",
        x = PAD_X + ICON_SIZE + 16,
        y = ty,
        font = "Sans",
        size = 11,
        text = function() return cat_title end,
    }

    local count_label = cat and string.format("%d ›", #(cat.apps or {})) or ""
    local row_count = {
        type = "text",
        x = PAD_X + CAT_W - 10,
        y = ty,
        font = "Sans",
        size = 10,
        align = "right",
        text = function() return count_label end,
    }

    draw[#draw + 1] = row_bg
    draw[#draw + 1] = row_icon
    draw[#draw + 1] = row_text
    draw[#draw + 1] = row_count

    cat_rows[i] = { bg = row_bg, icon = row_icon, text = row_text, count = row_count }
end

-- Right column: Application slots (1..NUM_CATS)
local app_x = PAD_X + CAT_W + COL_GAP
for s = 1, NUM_CATS do
    local ry = PAD_Y + (s - 1) * ROW_H
    local rh = ROW_H - 4
    local iy = ry + math.floor((rh - ICON_SIZE) / 2)
    local ty = ry + math.floor((rh - 11) / 2) - 1

    local slot = { app = nil }

    local function on_slot_hover()
        pointer_entered = true
        if hovered_app_slot ~= s then
            hovered_app_slot = s
            refresh_menu_slots()

        end
    end

    local function on_slot_click()
        if slot.app then
            launch_app(slot.app)
        end
    end

    local function slot_visible()
        return slot.app ~= nil
    end

    slot.bg = {
        type = "background",
        x = app_x,
        y = ry,
        w = APP_W,
        h = rh,
        radius = 6,
        draw_me = slot_visible,
        hover = on_slot_hover,
        click = on_slot_click,
    }
    slot.icon = {
        type = "svg",
        x = app_x + 8,
        y = iy,
        w = ICON_SIZE,
        h = ICON_SIZE,
        width = ICON_SIZE,
        height = ICON_SIZE,
        draw_me = slot_visible,
    }
    slot.text = {
        type = "text",
        x = app_x + ICON_SIZE + 16,
        y = ty,
        font = "Sans",
        size = 11,
        draw_me = slot_visible,
    }

    draw[#draw + 1] = slot.bg
    draw[#draw + 1] = slot.icon
    draw[#draw + 1] = slot.text

    app_slots[s] = slot
end

refresh_menu_slots()

------------------------------------------------------------
-- Bottom Session / Power bar
------------------------------------------------------------
local footer_sep_y = PAD_Y + NUM_CATS * ROW_H + 4
draw[#draw + 1] = {
    type = "background",
    x = PAD_X,
    y = footer_sep_y,
    w = MENU_W - PAD_X * 2,
    h = 1,
    radius = 0,
    bg = { { 1, "#3b4048", 0.7 } },
    border_width = 0,
}

local SESSION_BTNS = {
    { id = "Lock",     icon = "system-lock-screen", accent = "#3daee9", cmd = "(swaylock -f 2>/dev/null || loginctl lock-session) >/dev/null 2>&1 &" },
    { id = "Logout",   icon = "system-log-out",     accent = "#f67400", cmd = "(swaymsg exit 2>/dev/null || hyprctl dispatch exit 2>/dev/null || loginctl terminate-session \"${XDG_SESSION_ID:-self}\") >/dev/null 2>&1 &" },
    { id = "Suspend",  icon = "system-suspend",     accent = "#27ae60", cmd = "systemctl suspend >/dev/null 2>&1 &" },
    { id = "Reboot",   icon = "system-reboot",      accent = "#f67400", cmd = "systemctl reboot >/dev/null 2>&1 &" },
    { id = "Shutdown", icon = "system-shutdown",    accent = "#da4453", cmd = "systemctl poweroff >/dev/null 2>&1 &" },
}

local s_gap   = 6
local s_avail = MENU_W - PAD_X * 2 - (#SESSION_BTNS - 1) * s_gap
local s_btn_w = math.floor(s_avail / #SESSION_BTNS)
local s_btn_h = 28
local s_btn_y = footer_sep_y + 8
local s_icon_sz = 16

for idx, sb in ipairs(SESSION_BTNS) do
    local bx = PAD_X + (idx - 1) * (s_btn_w + s_gap)
    local label = conky_get_tr and conky_get_tr(sb.id) or sb.id
    local ipath = resolve_any_icon(sb.icon, "system-shutdown")

    local function run_session()
        os.execute(sb.cmd)
        os.exit(0)
    end

    local btn_bg = {
        type = "background",
        x = bx,
        y = s_btn_y,
        w = s_btn_w,
        h = s_btn_h,
        radius = 6,
        bg = { { 1, "#26292e", 0.85 } },
        border = { { 1, "#3b4048", 0.55 } },
        border_width = 1,
        click = run_session,
    }
    btn_bg.hover = function()
        pointer_entered = true
        btn_bg.bg = { { 1, "#1f425c", 0.95 } }
        btn_bg.border = { { 1, sb.accent, 0.95 } }
        btn_bg.border_width = 1.4
    end
    btn_bg.leave = function()
        btn_bg.bg = { { 1, "#26292e", 0.85 } }
        btn_bg.border = { { 1, "#3b4048", 0.55 } }
        btn_bg.border_width = 1
    end
    draw[#draw + 1] = btn_bg

    if ipath then
        draw[#draw + 1] = {
            type = ipath:match("%.svg$") and "svg" or "image",
            x = bx + 6,
            y = s_btn_y + math.floor((s_btn_h - s_icon_sz) / 2),
            w = s_icon_sz,
            h = s_icon_sz,
            width = s_icon_sz,
            height = s_icon_sz,
            path = ipath,
        }
    end

    draw[#draw + 1] = {
        type = "text",
        x = bx + 6 + s_icon_sz + 4,
        y = s_btn_y + math.floor((s_btn_h - 10) / 2) - 1,
        font = "Sans",
        size = 10,
        color = { { 1, "#eceff4", 1 } },
        text = function() return utf8_truncate(label, 8) end,
    }
end


------------------------------------------------------------
-- Mouse actions: scroll & auto-close on mouse leave
------------------------------------------------------------
MOUSE_ENTER_ACTION = function()
    pointer_entered = true
end

MOUSE_HOVER_IN_CONKY_WINDOW_ACTION = function()
    pointer_entered = true
end

MOUSE_LEAVE_ACTION = function()
    if pointer_entered then
        os.exit(0)
    end
end

local LABEL_MODES = { "name", "generic", "name_generic", "generic_name" }

MOUSE_CLICK_RIGHT = function()
    pointer_entered = true
    local cur = START_MENU_CFG.label_mode or "name"
    local next_mode = LABEL_MODES[1]
    for idx, m in ipairs(LABEL_MODES) do
        if m == cur then
            next_mode = LABEL_MODES[(idx % #LABEL_MODES) + 1]
            break
        end
    end
    START_MENU_CFG.label_mode = next_mode
    refresh_menu_slots()

end

MOUSE_SCROLL_UP = function()
    pointer_entered = true
    if scroll_offset > 0 then
        scroll_offset = scroll_offset - 1
        refresh_menu_slots()

    end
end

MOUSE_SCROLL_DOWN = function()
    pointer_entered = true
    local cat = MENU_TREE[active_cat_idx]
    local apps = (cat and cat.apps) or {}
    if scroll_offset < math.max(0, #apps - NUM_CATS) then
        scroll_offset = scroll_offset + 1
        refresh_menu_slots()

    end
end

_GROUPS = {}
_VIEWS = {
    { name = "main" },
}
_MOUSE_ENABLED = true

init_groups(_GROUPS)
