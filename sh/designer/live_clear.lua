-- live_clear.lua — NextGen Designer preview helper (X11 only)
--
-- The designer appends this file to the PREVIEW conky's lua_load line while
-- it manages the widget on X11 (see _preview_conf in main.py). It must come
-- AFTER the widget lua file. The deployed .conf never references this file.
--
-- On X11 an ARGB conky window keeps the previous frame, so moved or shrunk
-- items would leave permanent ghosts (semi-transparent panels can never
-- cover the pixels beneath them). Wayland's compositor already clears the
-- buffer, hence this helper is only needed on X11.
--
-- It overrides the no-op `clear_surface(cr)` hook from draw_core.lua with a
-- real clear that runs on the SAME cairo context the widget draws with.
--
-- IMPORTANT: this file must NOT call require("cairo") nor create its own
-- cairo context — both break conky's Lua drawing entirely when done from a
-- second lua_load file. The clear below reuses the `cr` that draw_core's
-- conky_core_main() already created.

function clear_surface(cr)
    cairo_save(cr)
    cairo_set_operator(cr, 0) -- CAIRO_OPERATOR_CLEAR
    cairo_paint(cr)
    cairo_restore(cr)
end
