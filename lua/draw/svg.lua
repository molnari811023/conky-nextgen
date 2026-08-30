local _SVG_DEFAULT = {
    x = 0, y = 0,
    w = 32, h = 32,
    path = nil,
    alpha = 1,
    tint = nil,
    tint_alpha = 1,
    rotate = 0,
    shape = nil,
    radius = 0,
}

local _svg_handles = {}

local function svg_get_handle(path)
    if _svg_handles[path] then return _svg_handles[path] end
    local handle = rsvg_create_handle_from_file(path)
    if not handle then return nil end
    _svg_handles[path] = handle
    return handle
end

function draw_svg(cr, opts)
    if not conky_window or not opts or not opts.path then return nil end

    local path = opts.path
    if type(path) == "table" and path.exec then path = path.exec()
    elseif type(path) == "function" then path = path() end
    if not path then return nil end

    if type(opts.x) == "function" then opts.x = opts.x() end
    if type(opts.y) == "function" then opts.y = opts.y() end

    local c = apply_defaults(opts, _SVG_DEFAULT)
    local w = math.floor(tonumber(c.w) or 32)
    local h = math.floor(tonumber(c.h) or 32)
    if w <= 0 or h <= 0 then return nil end

    local handle = svg_get_handle(path)
    if not handle then return nil end

    cairo_save(cr)
    cairo_translate(cr, c.x, c.y)

    if c.rotate and c.rotate ~= 0 then
        cairo_translate(cr, w / 2, h / 2)
        cairo_rotate(cr, math.rad(c.rotate))
        cairo_translate(cr, -w / 2, -h / 2)
    end

    if c.shape == "circle" then
        local r = math.min(w, h) / 2
        cairo_arc(cr, w / 2, h / 2, r, 0, 2 * math.pi)
        cairo_clip(cr)
    elseif c.radius and c.radius > 0 then
        rounded_rect_path(cr, 0, 0, w, h, c.radius)
        cairo_clip(cr)
    end

    rsvg_render_document_at(handle, cr, 0, 0, w, h)

    local alpha = tonumber(c.alpha)
    if not alpha then alpha = 1 end
    alpha = math.max(0, math.min(1, alpha))

    if c.tint then
        local r_t, g_t, b_t, a_t = hex_to_rgba(c.tint, (c.tint_alpha or 1) * alpha)
        cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE)
        cairo_set_source_rgba(cr, r_t, g_t, b_t, a_t)
        cairo_paint_with_alpha(cr, alpha)
        cairo_set_operator(cr, CAIRO_OPERATOR_OVER)
    elseif alpha < 1 then
        cairo_paint_with_alpha(cr, alpha)
    end

    cairo_restore(cr)

    return { x = c.x, y = c.y, w = w, h = h }
end

function svg_free_all()
    for path, handle in pairs(_svg_handles) do
        rsvg_destroy_handle(handle)
    end
    _svg_handles = {}
end
