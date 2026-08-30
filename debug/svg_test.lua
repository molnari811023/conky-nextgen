--[[[
debug/svg_test.lua — load / stress test for librsvg SVG rendering inside a
Conky draw loop: moving, rotating, clipped, size-series, alpha-series,
icon-cycle and 20-SVG stress renders of the Conky logo

Runs inside a live Conky session as the conky_svg_test_draw() draw function;
each call (every Conky update) exercises the whole set of rsvg + cairo
operations.
]]--

--{{{
-- ## SVG rendering stress test
--
-- Defines the conky_svg_test_draw() Conky draw callback which renders the
-- Conky logomark SVG through librsvg (rsvg_create_handle_from_file /
-- rsvg_render_document_at) in many transformation styles every update, to
-- stress-test SVG loading, caching and cairo compositing.
--
-- **What it does:**
-- - Requires the cairo and rsvg Lua bindings and points at the Conky logomark
--   SVG icon.
-- - Draws a sinusoidally moving and resizing SVG, a rotating + scaling SVG,
--   and a circle-clipped, pulsing SVG.
-- - Draws a 5-size series of SVGs and an alpha series rendered to an offscreen
--   image surface and painted with increasing alpha (i * 0.2).
-- - Cycles through 3 different scalable app icons per update.
-- - Stress-renders 20 small SVGs in a 2-row grid with sinusoidal sizing.
-- - Destroys the cairo context at the end of the draw; bails out if there is
--   no Conky window or surface.
--}}}

require("cairo")
require("rsvg")

local conky_icon = "/usr/share/icons/hicolor/scalable/apps/conky-logomark-violet.svg"

local tick = 0

function conky_svg_test_draw()
    if not conky_window then return end

    local surface = conky_surface()
    if not surface then return end
    local cr = cairo_create(surface)
    tick = tick + 1

    local t = tick * 0.05

    -- Mozgó SVG (sinus)
    local h = rsvg_create_handle_from_file(conky_icon)
    if h then
        local mx = 50 + math.sin(t) * 80
        local my = 50 + math.cos(t * 0.7) * 40
        local sz = 40 + math.sin(t * 0.3) * 15
        rsvg_render_document_at(h, cr, mx, my, sz, sz)
        rsvg_destroy_handle(h)
    end

    -- Forgó + méretező SVG
    h = rsvg_create_handle_from_file(conky_icon)
    if h then
        local cx, cy = 300, 80
        local sz2 = 30 + math.cos(t * 1.2) * 20
        cairo_save(cr)
        cairo_translate(cr, cx, cy)
        cairo_rotate(cr, t * 2)
        rsvg_render_document_at(h, cr, -sz2/2, -sz2/2, sz2, sz2)
        cairo_restore(cr)
        rsvg_destroy_handle(h)
    end

    -- Kör clip + méretváltozás
    h = rsvg_create_handle_from_file(conky_icon)
    if h then
        local r = 20 + math.sin(t * 0.8) * 15
        cairo_save(cr)
        cairo_arc(cr, 450, 80, r, 0, 2 * math.pi)
        cairo_clip(cr)
        rsvg_render_document_at(h, cr, 450 - r, 80 - r, r * 2, r * 2)
        cairo_restore(cr)
        rsvg_destroy_handle(h)
    end

    -- Méret sorozat: 5 különböző méretű SVG
    for i = 1, 5 do
        h = rsvg_create_handle_from_file(conky_icon)
        if h then
            local sz4 = 15 + i * 5 + math.sin(t + i) * 5
            local x4 = 30 + (i - 1) * 70
            rsvg_render_document_at(h, cr, x4, 180, sz4, sz4)
            rsvg_destroy_handle(h)
        end
    end

    -- Alpha sorozat
    for i = 1, 5 do
        h = rsvg_create_handle_from_file(conky_icon)
        if h then
            local tmp = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 40, 40)
            local tc = cairo_create(tmp)
            rsvg_render_document_at(h, tc, 0, 0, 40, 40)
            cairo_destroy(tc)
            local pat = cairo_pattern_create_for_surface(tmp)
            cairo_set_source(cr, pat)
            cairo_paint_with_alpha(cr, i * 0.2)
            cairo_pattern_destroy(pat)
            cairo_surface_destroy(tmp)
            rsvg_destroy_handle(h)
        end
    end

    -- Ikon csere
    local icons = {
        "/usr/share/icons/hicolor/scalable/apps/conky-logomark-violet.svg",
        "/usr/share/icons/hicolor/scalable/apps/spectacle.svg",
        "/usr/share/icons/hicolor/scalable/apps/htop.svg",
    }
    local idx = (tick % 3) + 1
    h = rsvg_create_handle_from_file(icons[idx])
    if h then
        rsvg_render_document_at(h, cr, 400, 180, 50, 50)
        rsvg_destroy_handle(h)
    end

    -- Stress: 20 kicsi SVG egyszerre
    for i = 1, 20 do
        h = rsvg_create_handle_from_file(conky_icon)
        if h then
            local sx = 30 + ((i - 1) % 10) * 50
            local sy = 250 + math.floor((i - 1) / 10) * 50
            local ss = 20 + math.sin(t + i * 0.5) * 8
            rsvg_render_document_at(h, cr, sx, sy, ss, ss)
            rsvg_destroy_handle(h)
        end
    end

    cairo_destroy(cr)
end
