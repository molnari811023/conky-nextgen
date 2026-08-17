--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--
-- core/capture.lua — on-demand PNG export of the drawn surface
-- The NextGen Designer writes tmp/capture_request containing two lines:
--   <view name | ->
--   <output png path>
-- conky switches to that view (if needed), draws one frame, then saves the
-- whole surface to the requested PNG and removes the request on success.
-- Works on both X11 and Wayland: the surface is conky's own, so no external
-- screenshot tools are involved. On failure the request is kept and retried
-- on the next tick.

--{{{
--   capture_poll() — call before drawing
--     Reads tmp/capture_request; switches to the requested view.
--   capture_finish() — call after drawing
--     Writes the drawn surface to the requested PNG; removes the request
--     only when the file exists afterwards.
--}}}
--}}}

local _CAPTURE_REQUEST = script_dir .. "tmp/capture_request"

local _pending_path = nil

function capture_poll()
    _pending_path = nil
    if not lfs then return nil end
    if not lfs.attributes(_CAPTURE_REQUEST, "modification") then return nil end

    local f = io.open(_CAPTURE_REQUEST, "r")
    if not f then return nil end
    local view = f:read("*l")
    local path = f:read("*l")
    f:close()

    if not path or path == "" then return nil end

    if view and view ~= "-" and view ~= current_view then
        if switch_view then
            switch_view(view)
        end
    end

    _pending_path = path
    return path
end

function capture_finish()
    if not _pending_path then return end

    local cs = conky_surface()
    if cs then
        cairo_surface_write_to_png(cs, _pending_path)
        cairo_surface_flush(cs)
        if lfs.attributes(_pending_path, "modification") then
            os.remove(_CAPTURE_REQUEST)
            _pending_path = nil
        end
    end
end
