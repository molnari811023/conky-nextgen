--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--
-- draw/svg.lua — SVG rendering via external rsvg-convert
-- draw_svg(cr, opts) → { x, y, w, h }
--     Rasterize an SVG file to a cached PNG with the external `rsvg-convert`
--     tool (librsvg), then draw the PNG through draw_png. Returns the drawn
--     bounding box.
--
-- Why external conversion? librsvg registers the "RsvgHandle" GType in the
-- process-global GLib type table on first use. On a conky config reload the
-- Lua state is closed and Lua 5.5's loadlib.c dlcloses the loaded C modules
-- (librsvg.so and with it librsvg-2.so.2). The fresh copy of librsvg then
-- tries to register "RsvgHandle" again, hits the already-registered type and
-- panics/aborts conky. Running rsvg-convert in a separate process keeps
-- librsvg out of the conky process entirely, so reloads are safe.
--
-- Parameters:
--   x, y, w, h, path
--   rotate, shape = "circle", radius
--   alpha, tint = "#hex", tint_alpha
--
-- Cache: PNG files under tmp/svg_cache/ (+ PNG_CACHE surface cache)
--
-- Example:
--   draw[#draw+1] = {
--       type = "svg",
--       x = 30, y = 225, w = 28, h = 28,
--       path = "/usr/share/icons/breeze/places/24/folder-blue-symbolic.svg",
--   }
--}}}

-- The conversion cache dir is created lazily, only when a conversion runs.
local _SVG_CACHE_DIR = script_dir .. "tmp/svg_cache/"
local _SVG_CACHE_MKDIR = false

local function svg_hash(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + s:byte(i)) % 2147483647
    end
    return h
end

local function svg_to_png(path, w, h)
    w = math.max(1, math.floor(tonumber(w) or 32))
    h = math.max(1, math.floor(tonumber(h) or 32))

    local png = _SVG_CACHE_DIR .. svg_hash(path) .. "-" .. w .. "x" .. h .. ".png"

    if not _SVG_CACHE_MKDIR then
        local dir = _SVG_CACHE_DIR:sub(1, -2)
        if lfs and not lfs.attributes(dir) then
            os.execute(string.format("mkdir -p %q", dir))
        end
        _SVG_CACHE_MKDIR = true
    end

    if lfs and lfs.attributes(path) then
        local png_mtime = lfs.attributes(png, "modification")
        if png_mtime and png_mtime >= (lfs.attributes(path, "modification") or 0) then
            return png
        end
    end

    local cmd = string.format("rsvg-convert -w %d -h %d %q -o %q",
        w, h, path, png)
    local ok = os.execute(cmd)
    if not ok or not lfs.attributes(png, "modification") then
        return nil
    end

    PNG_CACHE = PNG_CACHE or {}
    PNG_CACHE[png] = nil

    return png
end

function draw_svg(cr, opts)
    if not conky_window or not opts or not opts.path then return nil end

    local png = svg_to_png(opts.path, opts.w, opts.h)
    if not png then return nil end

    return draw_png(cr, {
        x = opts.x,
        y = opts.y,
        width = math.floor(tonumber(opts.w) or 32),
        height = math.floor(tonumber(opts.h) or 32),
        path = png,
        alpha = opts.alpha,
        tint = opts.tint,
        tint_alpha = opts.tint_alpha,
        rotate = opts.rotate,
        shape = opts.shape,
        radius = opts.radius,
    })
end

function svg_free_all()
    PNG_CACHE = PNG_CACHE or {}
    for p, _ in pairs(PNG_CACHE) do
        if type(p) == "string" and p:find(_SVG_CACHE_DIR, 1, true) == 1 then
            PNG_CACHE[p] = nil
        end
    end
end
