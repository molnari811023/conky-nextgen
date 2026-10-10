-- Compact Google dashboard for the NextGen Designer.

script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"
    .. ";" .. script_dir .. "lua/google/?.lua"

JSON_PATH = script_dir .. "tmp/"
draw = {}

THEMES = {
    theme = {
        palette = {
            bg = "#202326",
            fg = "#f4f7fb",
            dim = "#9aa6b2",
            accent = "#5cc8ff",
            green = "#65d391",
            yellow = "#f5bd5c",
        },
        defaults = {
            background = {
                bg = { { 1, "#151d2b", 1 } },
                border = { { 0.00, "#8899EE", 1 }, { 0.50, "#ece5ff", 1 }, { 1.00, "#8899EE", 1 } },
                border_width = 2,
            },
            text = {
                color = { { 1, "#f4f7fb", 1 } },
            },
        },
    },
}

DEFAULT_THEME = "theme"
_PADDING = 8

local function open_gmail_click(idx)
    return function()
        local id = conky_google_gmail_id(idx)
        if not id or id == "" then return end
        local safe_id = id:gsub("'", "'\\''")
        os.execute("/usr/bin/bash '" .. script_dir .. "sh/gog_open_mail.sh' '" .. safe_id .. "' &")
    end
end

local function text(x, y, value, size, color, weight, max_width, click, opts)
    local h = (size or 11) + 6
    local item = {
        type = "text",
        x = x,
        y = y,
        w = max_width or 200,
        h = h,
        font = "Sans",
        size = size or 11,
        text = value,
        color = { { 1, color or "#f4f7fb", 1 } },
        weight = weight or "normal",
        max_width = max_width,
        click = click,
    }
    if opts then
        for k, v in pairs(opts) do item[k] = v end
    end
    draw[#draw + 1] = item
    return item
end

-- Opens a plain URL in the default browser (app-launcher icons in the
-- "apps" view: no thread/message id involved, unlike open_gmail_click).
local function open_url_click(url)
    return function()
        os.execute("/usr/bin/xdg-open '" .. url .. "' &")
    end
end

-- Panel height covers both views. The "apps" view now has 3 rows of
-- icons (9 apps), which need more vertical room than the original
-- 2-row/340px panel — see google.conf, minimum_height must match.
draw[#draw + 1] = {
    type = "background",
    x = 0,
    y = 0,
    w = 430,
    h = 340,
    radius = 10,
}

draw[#draw + 1] = {
    type = "image",
    x = 12,
    y = 14,
    height = 28,
    path = "icons/google/Google_logo.png",
    view = "main",
}

text(115, 14, "dashboard", 18, "#5cc8ff", "bold", nil, nil, { view = "main" })

-- "Apps" tab, top-right: click to switch to the "apps" launcher view.
-- The background provides the clickable pill; the label on top is
-- purely visual (hit_test checks items back-to-front, so the
-- background's click_view still fires when the label itself is
-- clicked, since the label has no click/click_view of its own).
draw[#draw + 1] = {
    type = "background",
    view = "main",
    x = 364,
    y = 10,
    w = 54,
    h = 22,
    radius = 10,
    bg = { { 1, "#2a3a4a", 0.6 } },
    border = { { 1, "#5cc8ff", 0.5 } },
    border_width = 1,
    click_view = "apps",
}
draw[#draw + 1] = {
    type = "image",
    x = 12,
    y = 14,
    height = 28,
    path = "icons/google/Google_logo.png",
    view = "apps",
}
text(391, 12, "Apps", 11, "#5cc8ff", "bold", nil, nil, { view = "main", align = "center" })

text(12, 47,
    "Gmail  ${lua conky_google_gmail_count}   Calendar  ${lua conky_google_calendar_count}   Tasks  ${lua conky_google_tasks_count}",
    10, "#9aa6b2", nil, 406, nil, { view = "main" })
text(12, 65,
    "Contacts  ${lua conky_google_contacts_count}   Drive  ${lua conky_google_drive_count}   YouTube  ${lua conky_google_youtube_count}   Meet  ${lua conky_google_meet_count}",
    10, "#9aa6b2", nil, 406, nil, { view = "main" })

text(12, 91, "MAIL", 10, "#5cc8ff", "bold", nil, nil, { view = "main" })
text(50, 91, "${lua conky_google_unread_count} unread", 10, "#65d391", "bold", nil, nil, { view = "main" })
text(120, 91, "click on mail to open in browser", 10, "#f5bd5c", "bold", nil, nil, { view = "main" })

text(12, 108, "${lua conky_google_gmail_from 1}: ${lua conky_google_gmail_subject 1}", 10, nil, nil, 406,
    open_gmail_click(1), { view = "main" })
text(12, 124, "${lua conky_google_gmail_from 2}: ${lua conky_google_gmail_subject 2}", 10, nil, nil, 406,
    open_gmail_click(2), { view = "main" })
text(12, 140, "${lua conky_google_gmail_from 3}: ${lua conky_google_gmail_subject 3}", 10, nil, nil, 406,
    open_gmail_click(3), { view = "main" })
text(12, 156, "${lua conky_google_gmail_from 4}: ${lua conky_google_gmail_subject 4}", 10, nil, nil, 406,
    open_gmail_click(4), { view = "main" })
text(12, 172, "${lua conky_google_gmail_from 5}: ${lua conky_google_gmail_subject 5}", 10, nil, nil, 406,
    open_gmail_click(5), { view = "main" })
text(12, 188, "${lua conky_google_gmail_from 6}: ${lua conky_google_gmail_subject 6}", 10, nil, nil, 406,
    open_gmail_click(6), { view = "main" })
text(12, 204, "${lua conky_google_gmail_from 7}: ${lua conky_google_gmail_subject 7}", 10, nil, nil, 406,
    open_gmail_click(7), { view = "main" })
text(12, 220, "${lua conky_google_gmail_from 8}: ${lua conky_google_gmail_subject 8}", 10, nil, nil, 406,
    open_gmail_click(8), { view = "main" })

local tasks_x, tasks_y = 12, 260
text(tasks_x, tasks_y, "TASKS", 9, "#65d391", "bold", nil, nil, { view = "main" })
text(tasks_x, tasks_y + 17, "${lua conky_google_tasks_title 1}", 10, nil, nil, 195, nil, { view = "main" })
text(tasks_x, tasks_y + 33, "${lua conky_google_tasks_title 2}", 10, nil, nil, 195, nil, { view = "main" })
text(tasks_x, tasks_y + 49, "${lua conky_google_tasks_title 3}", 10, nil, nil, 195, nil, { view = "main" })

local agenda_x, agenda_y = 218, 260
text(agenda_x, agenda_y, "CALENDAR", 9, "#f5bd5c", "bold", nil, nil, { view = "main" })
text(agenda_x, agenda_y + 17, "${lua conky_google_calendar_start 1}  ${lua conky_google_calendar_summary 1}", 10, nil,
    nil, 200, nil, { view = "main" })
text(agenda_x, agenda_y + 33, "${lua conky_google_calendar_start 2}  ${lua conky_google_calendar_summary 2}", 10, nil,
    nil, 200, nil, { view = "main" })
text(agenda_x, agenda_y + 49, "${lua conky_google_calendar_start 3}  ${lua conky_google_calendar_summary 3}", 10, nil,
    nil, 200, nil, { view = "main" })

------------------------------------------------------------
-- "apps" view: Google app launcher grid (3 columns x 3 rows)
------------------------------------------------------------

text(114, 14, "apps", 18, "#5cc8ff", "bold", nil, nil, { view = "apps" })

-- "Dashboard" tab, top-right: click to return to the "main" view.
draw[#draw + 1] = {
    type = "background",
    view = "apps",
    x = 340,
    y = 10,
    w = 78,
    h = 22,
    radius = 10,
    bg = { { 1, "#2a3a4a", 0.6 } },
    border = { { 1, "#5cc8ff", 0.5 } },
    border_width = 1,
    click_view = "main",
}
text(379, 12, "Dashboard", 11, "#5cc8ff", "bold", nil, nil, { view = "apps", align = "center" })

local APPS = {
    { label = "Gmail",     icon = "icons/google/mail.png",      url = "https://mail.google.com" },
    { label = "Drive",     icon = "icons/google/drive.png",     url = "https://drive.google.com" },
    { label = "Calendar",  icon = "icons/google/calendar.png",  url = "https://calendar.google.com" },
    { label = "Photos",    icon = "icons/google/photos.png",    url = "https://photos.google.com" },
    { label = "Search",    icon = "icons/google/search.png",    url = "https://www.google.com" },
    { label = "YouTube",   icon = "icons/google/youtube.png",   url = "https://www.youtube.com" },
    { label = "Maps",      icon = "icons/google/maps.png",      url = "https://www.google.com/maps" },
    { label = "Translate", icon = "icons/google/translate.png", url = "https://translate.google.com" },
    { label = "Gemini",    icon = "icons/google/gemini.png",    url = "https://gemini.google.com" },
}

-- 3 columns x 3 rows. Row spacing (100px) gives icon(48) + gap(8) +
-- label(~14) + ~30px breathing room before the next row.
local APPS_COL_X = { 95, 215, 335 }  -- column centers
local APPS_ROW_Y = { 65, 160, 255 }  -- icon top y per row
local APPS_ICON_SIZE = 48

for i, app in ipairs(APPS) do
    local col = ((i - 1) % 3) + 1
    local row = math.floor((i - 1) / 3) + 1
    local center_x = APPS_COL_X[col]
    local icon_y = APPS_ROW_Y[row]

    draw[#draw + 1] = {
        type = "image",
        view = "apps",
        x = center_x - APPS_ICON_SIZE / 2,
        y = icon_y,
        width = APPS_ICON_SIZE,
        height = APPS_ICON_SIZE,
        path = app.icon,
        click = open_url_click(app.url),
    }

    text(center_x, icon_y + APPS_ICON_SIZE + 8, app.label, 10, "#f4f7fb", nil, nil, nil,
        { view = "apps", align = "center" })
end

_GROUPS = {}
_VIEWS = {
    { name = "main" },
    { name = "apps" },
}

_MOUSE_ENABLED = true
MOUSE_CLICK_LEFT = function() view_toggle("apps") end

-- Refresh Google data without blocking Conky's draw loop.
local GOOGLE_FETCH_INTERVAL = 900
local last_google_fetch = 0

function conky_google_update()
    local now = os.time()
    if now - last_google_fetch >= GOOGLE_FETCH_INTERVAL then
        last_google_fetch = now
        os.execute("/usr/bin/bash '" .. script_dir .. "sh/fetch_google.sh' >/dev/null 2>&1 &")
    end
    return ""
end

require("require")
init_groups(_GROUPS)