--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Interactive Clipboard History popup widget (Wayland + X11)
--}}}

script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local root_dir = script_dir:gsub("/panel_systray/?$", "")
if root_dir == "" or root_dir == script_dir then
    root_dir = (os.getenv("HOME") or "/root") .. "/.conky"
end

package.path = package.path
    .. ";" .. script_dir .. "?.lua"
    .. ";" .. root_dir .. "/lua/?.lua"
    .. ";" .. root_dir .. "/lua/core/?.lua"
    .. ";" .. root_dir .. "/lua/draw/?.lua"

JSON_PATH = root_dir:match("^/usr") and ((os.getenv("HOME") or "/tmp") .. "/.conky/tmp/") or (root_dir .. "/tmp/")

draw = {}

THEMES = {
    theme = {
        palette = {
            bg_dark = "#1e2228",
            fg = "#fcfcfc",
            fg_dim = "#a1a9b1",
            blue = "#3daee9",
            red = "#da4453",
        },
        gradients = {},
        defaults = {
            background = {
                bg = { { 1, "#1e2228", 0.96 } },
                border = { { 1, "#3daee9", 0.85 } },
                border_width = 1.5,
            },
            text = {
                color = { { 1, "#fcfcfc", 1 } },
            },
        },
    },
}

DEFAULT_THEME = "theme"
_PADDING = 0
MODULE_PROFILE = "basic"

require("require")

local tr = _G.get_tr or function(s) return s end
local BACKEND_SH = script_dir .. "clip_backend.sh"
local VISIBLE_ROWS = 9

local CLIP_POPUP = {
    entries       = {},
    scroll_offset = 0,
    last_ts       = 0,
}

local function shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function refresh_clip_data(force)
    local now = os.time()
    if not force and CLIP_POPUP.last_ts > 0 and (now - CLIP_POPUP.last_ts < 1) then
        return
    end
    CLIP_POPUP.last_ts = now

    os.execute("bash " .. shell_quote(BACKEND_SH) .. " poll >/dev/null 2>&1")
    local items = {}
    local lf = io.popen("bash " .. shell_quote(BACKEND_SH) .. " list 2>/dev/null")
    if lf then
        for line in lf:lines() do
            local idx, prev = line:match("^(%d+)\t(.*)$")
            if idx then
                items[#items + 1] = { idx = tonumber(idx), preview = prev }
            end
        end
        lf:close()
    end
    CLIP_POPUP.entries = items
    local max_off = math.max(0, #items - VISIBLE_ROWS)
    if CLIP_POPUP.scroll_offset > max_off then
        CLIP_POPUP.scroll_offset = max_off
    end
end

refresh_clip_data(true)

local function scroll_up_fn()
    if CLIP_POPUP.scroll_offset > 0 then
        CLIP_POPUP.scroll_offset = CLIP_POPUP.scroll_offset - 1
    end
end

local function scroll_down_fn()
    local max_off = math.max(0, #CLIP_POPUP.entries - VISIBLE_ROWS)
    if CLIP_POPUP.scroll_offset < max_off then
        CLIP_POPUP.scroll_offset = CLIP_POPUP.scroll_offset + 1
    end
end

-- Outer popup background
draw[#draw + 1] = {
    type = "background",
    x = 0, y = 0, w = 360, h = 420, radius = 10,
    scroll_up = scroll_up_fn,
    scroll_down = scroll_down_fn,
    draw_me = function()
        refresh_clip_data(false)
        return true
    end,
}

-- Title
draw[#draw + 1] = {
    type = "text",
    x = 14, y = 14, font = "Sans", size = 13, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = function() return tr("Clipboard") end,
}

-- Clear button
draw[#draw + 1] = {
    type = "background",
    x = 246, y = 10, w = 68, h = 24, radius = 5,
    bg = { { 1, "#3b2328", 1 } }, border = { { 1, "#da4453", 0.85 } }, border_width = 1,
    click = function()
        os.execute("bash " .. shell_quote(BACKEND_SH) .. " clear >/dev/null 2>&1")
        refresh_clip_data(true)
    end,
}
draw[#draw + 1] = {
    type = "text",
    x = 280, y = 15, align = "center", font = "Sans", size = 10, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = function() return tr("Clear") end,
}

-- Close button
draw[#draw + 1] = {
    type = "background",
    x = 320, y = 10, w = 26, h = 24, radius = 5,
    bg = { { 1, "#3a252a", 1 } }, border = { { 1, "#da4453", 0.8 } }, border_width = 1,
    click = function()
        os.execute("pkill -f 'conky.*clip_popup\\.conf' >/dev/null 2>&1 &")
    end,
}
draw[#draw + 1] = {
    type = "text",
    x = 333, y = 15, align = "center", font = "Sans", size = 10, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = "X",
}

-- Empty state label
draw[#draw + 1] = {
    type = "text",
    x = 180, y = 190, align = "center", font = "Sans", size = 11,
    color = { { 1, "#a1a9b1", 0.85 } },
    draw_me = function() return #CLIP_POPUP.entries == 0 end,
    text = function() return tr("Clipboard history is empty") end,
}

-- Clipboard rows (windowed by scroll_offset)
for i = 1, VISIBLE_ROWS do
    local row_y = 46 + (i - 1) * 39
    local get_entry = function()
        return CLIP_POPUP.entries[CLIP_POPUP.scroll_offset + i]
    end
    local has_row = function() return get_entry() ~= nil end

    draw[#draw + 1] = {
        type = "background",
        x = 12, y = row_y, w = 336, h = 33, radius = 6,
        bg = { { 1, "#262b33", 0.95 } },
        border = { { 1, "#353c47", 1 } },
        border_width = 1,
        draw_me = has_row,
        scroll_up = scroll_up_fn,
        scroll_down = scroll_down_fn,
        click = function()
            local e = get_entry()
            if not e then return end
            os.execute("bash " .. shell_quote(BACKEND_SH) .. " copy " .. tostring(e.idx) .. " >/dev/null 2>&1")
            refresh_clip_data(true)
        end,
        rclick = function()
            local e = get_entry()
            if not e then return end
            os.execute("bash " .. shell_quote(BACKEND_SH) .. " delete " .. tostring(e.idx) .. " >/dev/null 2>&1")
            refresh_clip_data(true)
        end,
    }
    draw[#draw + 1] = {
        type = "text",
        x = 22, y = row_y + 10, font = "Sans", size = 10,
        color = { { 1, "#fcfcfc", 1 } },
        draw_me = has_row,
        text = function()
            local e = get_entry()
            if not e then return "" end
            local prefix = (e.idx == 1) and "* " or (tostring(e.idx) .. ". ")
            local s = prefix .. e.preview
            if #s > 38 then s = s:sub(1, 36) .. ".." end
            return s
        end,
    }
end

draw[#draw + 1] = {
    type = "text",
    x = 180, y = 403, align = "center", font = "Sans", size = 8,
    color = { { 1, "#a1a9b1", 0.8 } },
    draw_me = function() return #CLIP_POPUP.entries > VISIBLE_ROWS end,
    text = function()
        local total = #CLIP_POPUP.entries
        local first = CLIP_POPUP.scroll_offset + 1
        local last = math.min(total, CLIP_POPUP.scroll_offset + VISIBLE_ROWS)
        return string.format("%d-%d / %d", first, last, total)
    end,
}

_GROUPS = {}
_VIEWS = { { name = "main" } }
_MOUSE_ENABLED = true

init_groups(_GROUPS)
