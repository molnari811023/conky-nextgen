--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- draw/image.lua — PNG rendering, crop, tint, rotation
-- Pattern matrix-based scaling (no cairo_scale on cr).
-- draw_png(cr, m) → { x, y, w, h }
--     Load a PNG file and paint it into the given width/height box.
--     Supports opacity (alpha), a flat tint color, rotation, a circle
--     clip shape, and cropping. Returns the drawn bounding box.
--
-- Parameters:
--   x, y, width, height, path, alpha, rotate
--   tint = "#hex", tint_alpha
--   shape = "circle", radius
--   crop = { x, y, w, h }
--   scale_mode = "bilinear"|"nearest"|"good"
--
-- Cache: PNG_CACHE
--
-- Example:
--   draw[#draw+1] = {
--       type = "image",
--       x = 238, y = 32, width = 24, height = 24,
--       path = "/usr/share/pixmaps/htop.png",
--       click = "konsole -e htop &",
--   }

-- Pre-allocated Cairo structs (reused every tick to avoid binding leak)
--}}}

local _img_mx1 = cairo_matrix_t:create()

PNG_CACHE = PNG_CACHE or {}

local function is_surface_valid(s)
    return s
        and cairo_surface_status(s) == 0
        and cairo_image_surface_get_width(s) > 0
        and cairo_image_surface_get_height(s) > 0
end

local PNG_DEFAULT = {
    x = 0, y = 0,
    width = nil,
    height = nil,
    path = nil,
    alpha = 1,
    tint = nil,
    tint_alpha = 1,
    rotate = 0,
    scale_mode = "bilinear",
    shape = nil,
    radius = 0,
    crop = nil,
}

function draw_png(cr, m)
    if not conky_window then return end
    if not m.path then return nil end

    -- resolve function / exec table path at draw time
    local path = m.path
    if type(path) == "table" and path.exec then path = path.exec()
    elseif type(path) == "function" then path = path() end
    if not path then return nil end
    m.path = path

    local c = apply_defaults(m, PNG_DEFAULT)

    local cached = PNG_CACHE[c.path]
    local reload = (not cached) or not is_surface_valid(cached.surface)
    if reload then
        local img = cairo_image_surface_create_from_png(c.path)
        if cairo_surface_status(img) == 0 then
            cache_set(PNG_CACHE, c.path, { surface = img }, 256)
        else
            cairo_surface_destroy(img)
            return
        end
    end

    local img = PNG_CACHE[c.path].surface
    local iw = cairo_image_surface_get_width(img)
    local ih = cairo_image_surface_get_height(img)
    if iw == 0 or ih == 0 then return end

    local crop_x = c.crop and (c.crop.x or 0) or 0
    local crop_y = c.crop and (c.crop.y or 0) or 0
    local sw = c.crop and (c.crop.w or (iw - crop_x)) or iw
    local sh = c.crop and (c.crop.h or (ih - crop_y)) or ih

    if c.width and not c.height then
        if sw > 0 then c.height = c.width * (sh / sw) end
    elseif c.height and not c.width then
        if sh > 0 then c.width = c.height * (sw / sh) end
    end
    local w = c.width or sw
    local h = c.height or sh

    -- 0/0 (or sw/0) in the pattern matrix would produce NaN and silently
    -- invalidate the pattern — bail out before touching the context.
    if not (w and w > 0) or not (h and h > 0) then
        return nil
    end

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

    local pat = cairo_pattern_create_for_surface(img)
    cairo_pattern_set_extend(pat, CAIRO_EXTEND_NONE)
    if c.scale_mode == "nearest" then
        cairo_pattern_set_filter(pat, CAIRO_FILTER_NEAREST)
    elseif c.scale_mode == "good" then
        cairo_pattern_set_filter(pat, CAIRO_FILTER_GOOD)
    else
        cairo_pattern_set_filter(pat, CAIRO_FILTER_BILINEAR)
    end

    local matrix = _img_mx1
    cairo_matrix_init_identity(matrix)
    cairo_matrix_translate(matrix, crop_x, crop_y)
    cairo_matrix_scale(matrix, sw / w, sh / h)
    cairo_pattern_set_matrix(pat, matrix)

    local alpha = tonumber(c.alpha)
    if not alpha then alpha = 1 end
    alpha = math.max(0, math.min(1, alpha))

    if c.tint then
        -- Flat tint: mask the tint through the image alpha ONLY, otherwise
        -- the original image + tinted layer overlap (ghosting/darkening).
        -- alpha is folded into the tint so opacity still applies.
        local r_t, g_t, b_t, a_t = hex_to_rgba(c.tint, (c.tint_alpha or 1) * alpha)
        cairo_set_source_rgba(cr, r_t, g_t, b_t, a_t)
        cairo_mask(cr, pat)
    else
        cairo_set_source(cr, pat)
        cairo_paint_with_alpha(cr, alpha)
    end

    cairo_pattern_destroy(pat)
    cairo_restore(cr)

    return { x = c.x, y = c.y, w = w, h = h }
end
