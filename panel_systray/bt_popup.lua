--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Interactive Bluetooth popup widget (BlueZ bluetoothctl)
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
            green = "#27ae60",
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
local BACKEND_SH = script_dir .. "bt_backend.sh"
local VISIBLE_ROWS = 8

local BT_POPUP = {
    available     = false,
    powered       = false,
    count         = 0,
    name          = "",
    devices       = {},
    scroll_offset = 0,
    last_ts       = 0,
}

local function shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function refresh_bt_data(force)
    local now = os.time()
    if not force and BT_POPUP.last_ts > 0 and (now - BT_POPUP.last_ts < 2) then
        return
    end
    BT_POPUP.last_ts = now

    local f = io.popen("bash " .. shell_quote(BACKEND_SH) .. " status 2>/dev/null")
    if f then
        local line = f:read("*l") or ""
        f:close()
        local avail, pwr, cnt, cname = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
        if avail then
            BT_POPUP.available = (avail == "1")
            BT_POPUP.powered   = (pwr == "1")
            BT_POPUP.count     = tonumber(cnt) or 0
            BT_POPUP.name      = cname or ""
        end
    end

    local devs = {}
    local lf = io.popen("bash " .. shell_quote(BACKEND_SH) .. " list 2>/dev/null")
    if lf then
        for line in lf:lines() do
            local mac, name, conn, paired = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
            if mac then
                devs[#devs + 1] = {
                    mac       = mac,
                    name      = name,
                    connected = (conn == "1"),
                    paired    = (paired == "1"),
                }
            end
        end
        lf:close()
    end
    BT_POPUP.devices = devs
    local max_off = math.max(0, #devs - VISIBLE_ROWS)
    if BT_POPUP.scroll_offset > max_off then
        BT_POPUP.scroll_offset = max_off
    end
end

refresh_bt_data(true)

local function scroll_up_fn()
    if BT_POPUP.scroll_offset > 0 then
        BT_POPUP.scroll_offset = BT_POPUP.scroll_offset - 1
    end
end

local function scroll_down_fn()
    local max_off = math.max(0, #BT_POPUP.devices - VISIBLE_ROWS)
    if BT_POPUP.scroll_offset < max_off then
        BT_POPUP.scroll_offset = BT_POPUP.scroll_offset + 1
    end
end

-- Outer popup background
draw[#draw + 1] = {
    type = "background",
    x = 0, y = 0, w = 360, h = 420, radius = 10,
    scroll_up = scroll_up_fn,
    scroll_down = scroll_down_fn,
    draw_me = function()
        refresh_bt_data(false)
        return true
    end,
}

-- Title
draw[#draw + 1] = {
    type = "text",
    x = 14, y = 14, font = "Sans", size = 13, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = function() return tr("Bluetooth") end,
}

-- Power toggle button
draw[#draw + 1] = {
    type = "background",
    x = 200, y = 10, w = 52, h = 24, radius = 5,
    bg = { { 1, "#2b313a", 1 } }, border = { { 1, "#4a5260", 1 } }, border_width = 1,
    click = function()
        os.execute("bash " .. shell_quote(BACKEND_SH) .. " toggle >/dev/null 2>&1")
        refresh_bt_data(true)
    end,
}
draw[#draw + 1] = {
    type = "text",
    x = 226, y = 15, align = "center", font = "Sans", size = 10, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = function() return BT_POPUP.powered and tr("ON") or tr("OFF") end,
}

-- Scan button
draw[#draw + 1] = {
    type = "background",
    x = 258, y = 10, w = 56, h = 24, radius = 5,
    bg = { { 1, "#1f425c", 1 } }, border = { { 1, "#3daee9", 0.9 } }, border_width = 1,
    click = function()
        os.execute("bash " .. shell_quote(BACKEND_SH) .. " scan >/dev/null 2>&1 &")
        refresh_bt_data(true)
    end,
}
draw[#draw + 1] = {
    type = "text",
    x = 286, y = 15, align = "center", font = "Sans", size = 10, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = function() return tr("Scan") end,
}

-- Close button
draw[#draw + 1] = {
    type = "background",
    x = 320, y = 10, w = 26, h = 24, radius = 5,
    bg = { { 1, "#3a252a", 1 } }, border = { { 1, "#da4453", 0.8 } }, border_width = 1,
    click = function()
        os.execute("pkill -f 'conky.*bt_popup\\.conf' >/dev/null 2>&1 &")
    end,
}
draw[#draw + 1] = {
    type = "text",
    x = 333, y = 15, align = "center", font = "Sans", size = 10, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = "X",
}

-- Status banner
draw[#draw + 1] = {
    type = "background",
    x = 12, y = 44, w = 336, h = 40, radius = 6,
    bg = { { 1, "#252a32", 1 } }, border = { { 1, "#39404d", 1 } }, border_width = 1,
}
draw[#draw + 1] = {
    type = "text",
    x = 22, y = 57, font = "Sans", size = 10, weight = "bold",
    color = { { 1, "#3daee9", 1 } },
    text = function()
        if not BT_POPUP.available then return tr("No Bluetooth adapter") end
        if not BT_POPUP.powered then return tr("Bluetooth is turned off") end
        if BT_POPUP.count > 0 then
            return tr("Connected") .. ": " .. BT_POPUP.name
        end
        return tr("Disconnected")
    end,
}

-- Device rows (windowed by scroll_offset)
for i = 1, VISIBLE_ROWS do
    local row_y = 94 + (i - 1) * 38
    local get_dev = function()
        return BT_POPUP.devices[BT_POPUP.scroll_offset + i]
    end
    local has_row = function() return get_dev() ~= nil end

    draw[#draw + 1] = {
        type = "background",
        x = 12, y = row_y, w = 336, h = 32, radius = 6,
        bg = { { 1, "#262b33", 0.95 } },
        border = { { 1, "#353c47", 1 } },
        border_width = 1,
        draw_me = has_row,
        scroll_up = scroll_up_fn,
        scroll_down = scroll_down_fn,
        click = function()
            local dev = get_dev()
            if not dev then return end
            local act = dev.connected and "disconnect" or "connect"
            os.execute("bash " .. shell_quote(BACKEND_SH) .. " " .. act .. " " .. shell_quote(dev.mac) .. " >/dev/null 2>&1 &")
        end,
        rclick = function()
            local dev = get_dev()
            if not dev then return end
            os.execute("bash " .. shell_quote(BACKEND_SH) .. " remove " .. shell_quote(dev.mac) .. " >/dev/null 2>&1 &")
            refresh_bt_data(true)
        end,
    }
    draw[#draw + 1] = {
        type = "text",
        x = 22, y = row_y + 9, font = "Sans", size = 10, weight = "bold",
        color = { { 1, "#fcfcfc", 1 } },
        draw_me = has_row,
        text = function()
            local dev = get_dev()
            if not dev then return "" end
            local prefix = dev.connected and "* " or ""
            local s = prefix .. dev.name
            if #s > 26 then s = s:sub(1, 24) .. ".." end
            return s
        end,
    }
    draw[#draw + 1] = {
        type = "text",
        x = 336, y = row_y + 9, align = "right", font = "Mono", size = 9,
        color = { { 1, "#a1a9b1", 1 } },
        draw_me = has_row,
        text = function()
            local dev = get_dev()
            if not dev then return "" end
            if dev.connected then return tr("Connected") end
            if dev.paired then return tr("Paired") end
            return dev.mac
        end,
    }
end

draw[#draw + 1] = {
    type = "text",
    x = 180, y = 403, align = "center", font = "Sans", size = 8,
    color = { { 1, "#a1a9b1", 0.8 } },
    draw_me = function() return #BT_POPUP.devices > VISIBLE_ROWS end,
    text = function()
        local total = #BT_POPUP.devices
        local first = BT_POPUP.scroll_offset + 1
        local last = math.min(total, BT_POPUP.scroll_offset + VISIBLE_ROWS)
        return string.format("%d-%d / %d", first, last, total)
    end,
}

_GROUPS = {}
_VIEWS = { { name = "main" } }
_MOUSE_ENABLED = true

init_groups(_GROUPS)
