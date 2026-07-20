--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- draw/svg.lua — SVG rendering via Conky's built-in librsvg bindings
-- Handle cache, rotate, shape/radius clip, alpha, tint.

require("rsvg")

SVG_CACHE = SVG_CACHE or {}

if not rounded_rect_path then
    function rounded_rect_path(cr, x, y, w, h, r)
        r = math.min(r, w / 2, h / 2)
        cairo_new_sub_path(cr)
        cairo_arc(cr, x + w - r, y + r, r, -math.pi / 2, 0)
        cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi / 2)
        cairo_arc(cr, x + r, y + h - r, r, math.pi / 2, math.pi)
        cairo_arc(cr, x + r, y + r, r, math.pi, 3 * math.pi / 2)
        cairo_close_path(cr)
    end
end

function draw_svg(cr, opts)
    if not opts then return end
    local path = opts.path

    if not path and opts.icon then
        local size = opts.icon_size or opts.w or 48
        local theme = opts.icon_theme or XDG_ICON_THEME or "Papirus"
        path = icon_resolve(opts.icon, size, theme)
    end

    if not path then return end

    if not SVG_CACHE[path] then
        local ok, handle = pcall(rsvg_create_handle_from_file, path)
        if not ok or not handle then return end
        SVG_CACHE[path] = handle
    end
    local handle = SVG_CACHE[path]

    local ok_sz, ret_sz, iw, ih = pcall(rsvg_handle_get_intrinsic_size_in_pixels, handle)
    local has_sz = ok_sz and ret_sz and iw and iw > 0 and ih and ih > 0

    local w = opts.w
    local h = opts.h
    if not w and not h then
        w, h = 32, 32
    elseif w and not h then
        h = has_sz and (w * (ih / iw)) or w
    elseif h and not w then
        w = has_sz and (h * (iw / ih)) or h
    end

    local rotate = opts.rotate or 0
    local shape = opts.shape
    local radius = opts.radius or 0
    local alpha = opts.alpha
    local tint = opts.tint
    local need_temp = (alpha and alpha < 1) or tint

    cairo_save(cr)

    if opts.x or opts.y then
        cairo_translate(cr, opts.x or 0, opts.y or 0)
    end

    if rotate ~= 0 then
        cairo_translate(cr, w / 2, h / 2)
        cairo_rotate(cr, math.rad(rotate))
        cairo_translate(cr, -w / 2, -h / 2)
    end

    if shape == "circle" then
        local r = math.min(w, h) / 2
        cairo_arc(cr, w / 2, h / 2, r, 0, 2 * math.pi)
        cairo_clip(cr)
    elseif radius > 0 then
        rounded_rect_path(cr, 0, 0, w, h, radius)
        cairo_clip(cr)
    end

    if need_temp then
        local surf = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, w, h)
        local tmp_cr = cairo_create(surf)
        local vp = RsvgRectangle:create()
        if has_sz then
            cairo_scale(tmp_cr, w / iw, h / ih)
            vp:set(0, 0, iw, ih)
        else
            vp:set(0, 0, w, h)
        end
        rsvg_handle_render_document(handle, tmp_cr, vp)
        vp:destroy()
        cairo_destroy(tmp_cr)

        if tint then
            local r, g, b, a = hex_to_rgba(tint, opts.tint_alpha or 1)
            cairo_set_source_rgba(cr, r, g, b, a)
            cairo_mask_surface(cr, surf, 0, 0)
        else
            cairo_set_source_surface(cr, surf, 0, 0)
            cairo_paint_with_alpha(cr, alpha or 1)
        end

        cairo_surface_destroy(surf)
    else
        local vp = RsvgRectangle:create()
        if has_sz then
            cairo_scale(cr, w / iw, h / ih)
            vp:set(0, 0, iw, ih)
        else
            vp:set(0, 0, w, h)
        end
        local ok = rsvg_handle_render_document(handle, cr, vp)
        vp:destroy()
        if not ok then cairo_restore(cr) return end
    end

    cairo_restore(cr)
end

function svg_free(path)
    if SVG_CACHE[path] then
        rsvg_destroy_handle(SVG_CACHE[path])
        SVG_CACHE[path] = nil
    end
end

function svg_free_all()
    for path, handle in pairs(SVG_CACHE) do
        rsvg_destroy_handle(handle)
    end
    SVG_CACHE = {}
end
