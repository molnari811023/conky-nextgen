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
    y_pad     = -1,            -- extra vertical nudge (positive = down)
}

CLOCK_ITEM = CLOCK_ITEM or nil

--- Right edge x for left-aligned text (panel width - padding).
local function clock_right()
    if not conky_window then return 8 end
    return conky_window.width - CLOCK_CFG.right_pad
end

--- Vertical baseline: centers the text inside the panel height.
local function clock_y()
    if not conky_window then return 4 end
    local h = conky_window.height or 48
    -- baseline where the glyph center sits in the middle of the panel
    return math.floor(h / 2) + CLOCK_CFG.y_pad
end

function clock_install()
    if not CLOCK_CFG.enabled then return nil end
    if CLOCK_ITEM then return CLOCK_ITEM end

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