--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--}}}

--{{{
-- draw/arc.lua — Semicircle arc with progress dot or icon
-- draw_arc(cr, m) → { x, y, w, h }
--
-- Parameters:
--   cx, cy        — center of the semicircle
--   r             — radius
--   progress      — 0.0-1.0 position (left=0, top=0.5, right=1)
--   segments      — line segments (default 20)
--   arc_color     — arc line color
--   arc_alpha     — arc alpha (default 0.4)
--   arc_width     — arc line width (default 2)
--   dot_color     — color of progress dot
--   dot_radius    — radius of progress dot (default 4)
--   icon          — PNG path for first marker (replaces dot)
--   icon_size     — size of icon in px (default 24)
--   horizon       — draw horizon line (default true)
--   horizon_color — horizon line color
--   progress2     — second marker position (optional)
--   dot2_color    — second marker color
--   dot2_radius   — second marker radius
--   icon2         — PNG path for second marker (replaces dot2)
--   icon2_size    — size of icon2 in px (default 24)
--}}}

local ARC_DEFAULT = {
    cx = 0, cy = 0, r = 30,
    progress = 0,
    segments = 20,
    arc_color = "#a1a9b1",
    arc_alpha = 0.4,
    arc_width = 2,
    dot_color = "#3daee9",
    dot_radius = 4,
    icon = nil,
    icon_size = 24,
    horizon = true,
    horizon_color = "#4a4d52",
    progress2 = nil,
    dot2_color = nil,
    dot2_radius = 4,
    icon2 = nil,
    icon2_size = 24,
}

local function hex_to_rgb(hex)
    hex = tostring(hex):gsub("#", "")
    return tonumber(hex:sub(1, 2), 16) / 255,
           tonumber(hex:sub(3, 4), 16) / 255,
           tonumber(hex:sub(5, 6), 16) / 255
end

local function resolve_path(v)
    if type(v) == "string" and v:find("%(") then
        local fn = load("return " .. v)
        if fn then return tostring(fn() or "") end
    elseif type(v) == "function" then
        return tostring(v() or "")
    elseif type(v) == "table" and v.exec then
        return tostring(v.exec() or "")
    end
    return tostring(v or "")
end

local function resolve_num(v, def)
    if type(v) == "string" and v:find("%(") then
        local fn = load("return " .. v)
        if fn then return tonumber(fn()) or def end
    elseif type(v) == "function" then
        return tonumber(v()) or def
    end
    return tonumber(v) or def
end

local function draw_img(cr, path, px, py, size)
    if not path or path == "" then return end
    local img = cairo_image_surface_create_from_png(path)
    if not img then return end
    local status = cairo_surface_status(img)
    if status ~= 0 then cairo_surface_destroy(img); return end
    local iw = cairo_image_surface_get_width(img)
    local ih = cairo_image_surface_get_height(img)
    if iw <= 0 or ih <= 0 then cairo_surface_destroy(img); return end
    local scale = size / math.max(iw, ih)
    cairo_save(cr)
    cairo_translate(cr, px - (iw * scale) / 2, py - (ih * scale) / 2)
    cairo_scale(cr, scale, scale)
    cairo_set_source_surface(cr, img, 0, 0)
    cairo_paint(cr)
    cairo_restore(cr)
    cairo_surface_destroy(img)
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
    local p = resolve_num(cfg.progress, 0)
    if p < 0 then p = 0 end
    if p > 1 then p = 1 end

    local gy = tonumber(cfg.y) or 0
    cy = cy + gy

    local dr = tonumber(cfg.dot_radius) or 4
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

    local dot_angle = math.pi * (1 - p)
    local dot_x = cx + r * math.cos(dot_angle)
    local dot_y = cy - r * math.sin(dot_angle)

    local icon_path = resolve_path(cfg.icon)
    if icon_path ~= "" then
        draw_img(cr, icon_path, dot_x, dot_y, tonumber(cfg.icon_size) or 24)
    else
        local d_r, d_g, d_b = hex_to_rgb(cfg.dot_color)
        cairo_set_source_rgba(cr, d_r, d_g, d_b, 1)
        cairo_arc(cr, dot_x, dot_y, dr, 0, 2 * math.pi)
        cairo_fill(cr)
    end

    if cfg.progress2 then
        local p2 = resolve_num(cfg.progress2, 0)
        if p2 < 0 then p2 = 0 end
        if p2 > 1 then p2 = 1 end
        local a2 = math.pi * (1 - p2)
        local x2 = cx + r * math.cos(a2)
        local y2 = cy - r * math.sin(a2)
        local icon2_path = resolve_path(cfg.icon2)
        if icon2_path ~= "" then
            draw_img(cr, icon2_path, x2, y2, tonumber(cfg.icon2_size) or 24)
        elseif cfg.dot2_color then
            local d2r = tonumber(cfg.dot2_radius) or dr
            local d2_r, d2_g, d2_b = hex_to_rgb(cfg.dot2_color)
            cairo_set_source_rgba(cr, d2_r, d2_g, d2_b, 1)
            cairo_arc(cr, x2, y2, d2r, 0, 2 * math.pi)
            cairo_fill(cr)
        end
    end

    return { x = cx - r, y = cy - r, w = r * 2, h = r + dr }
end
