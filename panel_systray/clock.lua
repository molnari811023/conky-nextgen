-- clock.lua — digital clock text widget for the bottom panel
--
-- Draws the current time (HH:MM by default) right-aligned at the panel's
-- right edge with a small padding. The systray sits to the LEFT of it; the
-- tray detects the clock's left edge itself (panel_systray padding config).
--
-- Config: CLOCK_CFG table at the top.
-- API: clock_install() — creates the draw item.

CLOCK_CFG = {
    enabled   = true,
    format    = "%H:%M",       -- os.date format
    font      = "Sans",
    size      = 12,
    color     = { { 1, "#fcfcfc", 1 } },
    right_pad = 8,             -- padding from the panel's right edge
    y_pad     = 0,             -- extra vertical nudge (positive = down)
    click_w   = 56,            -- clickable hitbox width around the clock
}

CLOCK_ITEM = CLOCK_ITEM or nil
CLOCK_HIT_ITEM = CLOCK_HIT_ITEM or nil

--- Right edge x for left-aligned text (panel width - padding).
local function clock_right()
    if not conky_window then return 8 end
    return conky_window.width - CLOCK_CFG.right_pad
end

--- Vertical position: (panel_height - clock_size) / 2 centers the text in the panel.
local function clock_y()
    if not conky_window then return 4 end
    local h = conky_window.height or 48
    local sz = CLOCK_CFG.size or 12
    return math.floor((h - sz) / 2) + (CLOCK_CFG.y_pad or 0)
end

function clock_install()
    if not CLOCK_CFG.enabled then return nil end
    if CLOCK_ITEM then return CLOCK_ITEM end

    local base_dir = script_dir or "/home/molnar/.conky/panel_systray/"
    local click_cmd = base_dir .. "toggle_calendar.sh &"

    -- Transparent clickable hitbox covering the right-aligned clock text
    CLOCK_HIT_ITEM = {
        type         = "background",
        x            = function() return clock_right() - CLOCK_CFG.click_w end,
        y            = 6,
        w            = CLOCK_CFG.click_w + CLOCK_CFG.right_pad,
        h            = 36,
        radius       = 6,
        bg           = { { 1, "#000000", 0 } },
        border_width = 0,
        click        = click_cmd,
        draw_me      = function()
            if not conky_window then return false end
            return CLOCK_CFG.enabled
        end,
    }
    draw[#draw + 1] = CLOCK_HIT_ITEM

    CLOCK_ITEM = {
        type  = "text",
        align = "right",       -- x is the right edge; text grows leftwards
        x     = function() return clock_right() end,
        y     = function() return clock_y() end,
        font  = CLOCK_CFG.font,
        size  = CLOCK_CFG.size,
        color = CLOCK_CFG.color,
        text  = function() return os.date(CLOCK_CFG.format) end,
        draw_me = function()
            if not conky_window then return false end
            return CLOCK_CFG.enabled
        end,
    }
    draw[#draw + 1] = CLOCK_ITEM

    return CLOCK_ITEM
end