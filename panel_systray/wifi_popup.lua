--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Interactive Wi-Fi popup widget (nmcli + iwd auto-detect)
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
local BACKEND_SH = script_dir .. "wifi_backend.sh"
local VISIBLE_ROWS = 8

local POPUP_STATE = {
    backend       = "none",
    powered       = false,
    connected     = false,
    ssid          = "",
    signal        = 0,
    ip            = "",
    networks      = {},
    scroll_offset = 0,
    last_ts       = 0,
}

local function shell_quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function refresh_wifi_data(force)
    local now = os.time()
    if not force and POPUP_STATE.last_ts > 0 and (now - POPUP_STATE.last_ts < 2) then
        return
    end
    POPUP_STATE.last_ts = now

    local f = io.popen("bash " .. shell_quote(BACKEND_SH) .. " status 2>/dev/null")
    if f then
        local line = f:read("*l") or ""
        f:close()
        local b, pwr, conn, ssid, sig, ip = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)")
        if b then
            POPUP_STATE.backend   = b
            POPUP_STATE.powered   = (pwr == "1")
            POPUP_STATE.connected = (conn == "1")
            POPUP_STATE.ssid      = ssid or ""
            POPUP_STATE.signal    = tonumber(sig) or 0
            POPUP_STATE.ip        = ip or ""
        end
    end

    local nets = {}
    if POPUP_STATE.powered then
        local lf = io.popen("bash " .. shell_quote(BACKEND_SH) .. " list 2>/dev/null")
        if lf then
            for line in lf:lines() do
                local nssid, nsig, nsec, nconn = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)$")
                if nssid then
                    nets[#nets + 1] = {
                        ssid      = nssid,
                        signal    = tonumber(nsig) or 0,
                        security  = nsec,
                        connected = (nconn == "1"),
                    }
                end
            end
            lf:close()
        end
    end
    POPUP_STATE.networks = nets
    local max_off = math.max(0, #nets - VISIBLE_ROWS)
    if POPUP_STATE.scroll_offset > max_off then
        POPUP_STATE.scroll_offset = max_off
    end
end

refresh_wifi_data(true)
-- Trigger a fresh background scan whenever the popup opens
os.execute("bash " .. shell_quote(BACKEND_SH) .. " scan >/dev/null 2>&1 &")

local function scroll_up_fn()
    if POPUP_STATE.scroll_offset > 0 then
        POPUP_STATE.scroll_offset = POPUP_STATE.scroll_offset - 1
    end
end

local function scroll_down_fn()
    local max_off = math.max(0, #POPUP_STATE.networks - VISIBLE_ROWS)
    if POPUP_STATE.scroll_offset < max_off then
        POPUP_STATE.scroll_offset = POPUP_STATE.scroll_offset + 1
    end
end

-- Outer popup background (also handles mouse-wheel scrolling over the list)
draw[#draw + 1] = {
    type = "background",
    x = 0, y = 0, w = 360, h = 420, radius = 10,
    scroll_up = scroll_up_fn,
    scroll_down = scroll_down_fn,
    draw_me = function()
        refresh_wifi_data(false)
        return true
    end,
}

-- Title
draw[#draw + 1] = {
    type = "text",
    x = 14, y = 14, font = "Sans", size = 13, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = function()
        return tr("Wi-Fi Networks") .. " (" .. POPUP_STATE.backend .. ")"
    end,
}

-- Power toggle button
draw[#draw + 1] = {
    type = "background",
    x = 200, y = 10, w = 52, h = 24, radius = 5,
    bg = { { 1, "#2b313a", 1 } }, border = { { 1, "#4a5260", 1 } }, border_width = 1,
    click = function()
        os.execute("bash " .. shell_quote(BACKEND_SH) .. " toggle >/dev/null 2>&1")
        refresh_wifi_data(true)
    end,
}
draw[#draw + 1] = {
    type = "text",
    x = 226, y = 15, align = "center", font = "Sans", size = 10, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = function() return POPUP_STATE.powered and tr("ON") or tr("OFF") end,
}

-- Scan button
draw[#draw + 1] = {
    type = "background",
    x = 258, y = 10, w = 56, h = 24, radius = 5,
    bg = { { 1, "#1f425c", 1 } }, border = { { 1, "#3daee9", 0.9 } }, border_width = 1,
    click = function()
        os.execute("bash " .. shell_quote(BACKEND_SH) .. " scan >/dev/null 2>&1 &")
        refresh_wifi_data(true)
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
        os.execute("pkill -f 'conky.*wifi_popup\\.conf' >/dev/null 2>&1 &")
    end,
}
draw[#draw + 1] = {
    type = "text",
    x = 333, y = 15, align = "center", font = "Sans", size = 10, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    text = "X",
}

-- Active connection status banner
draw[#draw + 1] = {
    type = "background",
    x = 12, y = 44, w = 336, h = 44, radius = 6,
    bg = { { 1, "#252a32", 1 } }, border = { { 1, "#39404d", 1 } }, border_width = 1,
}
draw[#draw + 1] = {
    type = "text",
    x = 22, y = 51, font = "Sans", size = 11, weight = "bold",
    color = { { 1, "#27ae60", 1 } },
    text = function()
        if not POPUP_STATE.powered then return tr("Wi-Fi is turned off") end
        if POPUP_STATE.connected then return tr("Connected") .. ": " .. POPUP_STATE.ssid end
        return tr("Disconnected")
    end,
}
draw[#draw + 1] = {
    type = "text",
    x = 22, y = 69, font = "Sans", size = 9,
    color = { { 1, "#a1a9b1", 1 } },
    text = function()
        if not POPUP_STATE.connected then return "" end
        local ip = (POPUP_STATE.ip ~= "") and ("IP: " .. POPUP_STATE.ip .. "  ·  ") or ""
        return ip .. string.format("%d%%", POPUP_STATE.signal)
    end,
}
draw[#draw + 1] = {
    type = "background",
    x = 256, y = 53, w = 82, h = 26, radius = 5,
    bg = { { 1, "#3b2328", 1 } }, border = { { 1, "#da4453", 0.85 } }, border_width = 1,
    draw_me = function() return POPUP_STATE.connected end,
    click = function()
        os.execute("bash " .. shell_quote(BACKEND_SH) .. " disconnect >/dev/null 2>&1")
        refresh_wifi_data(true)
    end,
}
draw[#draw + 1] = {
    type = "text",
    x = 297, y = 59, align = "center", font = "Sans", size = 9, weight = "bold",
    color = { { 1, "#fcfcfc", 1 } },
    draw_me = function() return POPUP_STATE.connected end,
    text = function() return tr("Disconnect") end,
}

-- Network rows (windowed by POPUP_STATE.scroll_offset)
for i = 1, VISIBLE_ROWS do
    local row_y = 98 + (i - 1) * 38
    local get_net = function()
        return POPUP_STATE.networks[POPUP_STATE.scroll_offset + i]
    end
    local has_row = function() return get_net() ~= nil end

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
            local net = get_net()
            if not net then return end
            os.execute("bash " .. shell_quote(BACKEND_SH) .. " connect "
                .. shell_quote(net.ssid) .. " " .. shell_quote(net.security) .. " >/dev/null 2>&1 &")
        end,
        rclick = function()
            local net = get_net()
            if not net then return end
            os.execute("bash " .. shell_quote(BACKEND_SH) .. " forget "
                .. shell_quote(net.ssid) .. " >/dev/null 2>&1 &")
            refresh_wifi_data(true)
        end,
    }
    draw[#draw + 1] = {
        type = "text",
        x = 22, y = row_y + 9, font = "Sans", size = 10, weight = "bold",
        color = { { 1, "#fcfcfc", 1 } },
        draw_me = has_row,
        text = function()
            local net = get_net()
            if not net then return "" end
            local prefix = net.connected and "* " or ""
            local s = prefix .. net.ssid
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
            local net = get_net()
            if not net then return "" end
            local lock = (net.security == "open") and "open" or "lock"
            return string.format("%s  %3d%%", lock, net.signal)
        end,
    }
end

-- Scroll position footer when there are more networks than VISIBLE_ROWS
draw[#draw + 1] = {
    type = "text",
    x = 180, y = 403, align = "center", font = "Sans", size = 8,
    color = { { 1, "#a1a9b1", 0.8 } },
    draw_me = function() return #POPUP_STATE.networks > VISIBLE_ROWS end,
    text = function()
        local total = #POPUP_STATE.networks
        local first = POPUP_STATE.scroll_offset + 1
        local last = math.min(total, POPUP_STATE.scroll_offset + VISIBLE_ROWS)
        return string.format("%d-%d / %d", first, last, total)
    end,
}

_GROUPS = {}
_VIEWS = { { name = "main" } }
_MOUSE_ENABLED = true

init_groups(_GROUPS)
