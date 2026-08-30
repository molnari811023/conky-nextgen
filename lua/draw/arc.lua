local ARC_DEFAULT = {
    cx = 0, cy = 0, r = 30,
    segments = 20,
    arc_color = "#a1a9b1",
    arc_alpha = 0.4,
    arc_width = 2,
    horizon = true,
    horizon_color = "#4a4d52",
}

local function hex_to_rgb(hex)
    hex = tostring(hex):gsub("#", "")
    return tonumber(hex:sub(1, 2), 16) / 255,
           tonumber(hex:sub(3, 4), 16) / 255,
           tonumber(hex:sub(5, 6), 16) / 255
end

function draw_arc(cr, m)
    if not conky_window then return end

    local cfg = {}
    for k, v in pairs(ARC_DEFAULT) do cfg[k] = v end
    for k, v in pairs(m) do cfg[k] = v end

    local cx = tonumber(cfg.cx) or 0
    local cy = tonumber(cfg.cy) or 0
    local r = tonumber(cfg.r) or 30
    local seg = tonumber(cfg.segments) or 20

    local gy = tonumber(cfg.y) or 0
    cy = cy + gy

    local a_r, a_g, a_b = hex_to_rgb(cfg.arc_color)
    local a_a = tonumber(cfg.arc_alpha) or 0.4

    if cfg.horizon then
        local h_r, h_g, h_b = hex_to_rgb(cfg.horizon_color)
        cairo_set_line_width(cr, 1)
        cairo_set_source_rgba(cr, h_r, h_g, h_b, 0.6)
        cairo_move_to(cr, cx - r, cy)
        cairo_line_to(cr, cx + r, cy)
        cairo_stroke(cr)
    end

    cairo_set_line_width(cr, tonumber(cfg.arc_width) or 2)
    cairo_set_source_rgba(cr, a_r, a_g, a_b, a_a)
    cairo_set_dash(cr, {}, 0, 0)

    for s = 0, seg - 1 do
        local a1 = math.pi * (1 - s / seg)
        local a2 = math.pi * (1 - (s + 1) / seg)
        local x1 = cx + r * math.cos(a1)
        local y1 = cy - r * math.sin(a1)
        local x2 = cx + r * math.cos(a2)
        local y2 = cy - r * math.sin(a2)
        if s == 0 then cairo_move_to(cr, x1, y1) end
        cairo_line_to(cr, x2, y2)
    end
    cairo_stroke(cr)

    return { x = cx - r, y = cy - r, w = r * 2, h = r }
end
