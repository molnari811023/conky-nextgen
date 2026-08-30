--[[[
lua/core/capture.lua — one-shot PNG capture of a view, triggered by a request file

Reads a request from tmp/capture_request (view + output path), optionally
switches to the requested view (with a short settle delay), and after drawing
writes the conky surface to the requested PNG before removing the request.
]]--

--{{{
-- ## Capture Module
--
-- Provides callbacks around the draw cycle to export the rendered surface.
-- Before drawing, capture_poll() reads tmp/capture_request and may switch the
-- active view; after drawing, capture_finish() writes the surface to the
-- requested PNG and deletes the request file once it exists.
--
-- **Exposed/global functions:**
-- - `capture_poll()` — read capture request; optionally switch_view() to the
--   requested view and return the output path (or nil while settling frames)
-- - `capture_finish()` — write the current conky surface to the pending PNG
--   path and remove the request file once written
--
-- **Config/globals used:**
-- - `script_dir` — base directory for tmp/capture_request
-- - `lfs` — LuaFileSystem, to test for the request file's existence
-- - `switch_view` — external view switcher called to change the active view
-- - `current_view` — the currently active view, compared against requests
--}}}

--{{{
--   capture_poll() — call before drawing
--   Reads tmp/capture_request; switches to the requested view.
--   capture_finish() — call after drawing
--     Writes the drawn surface to the requested PNG; removes the request
--     only when the file exists afterwards.
--}}}

local _CAPTURE_REQUEST = script_dir .. "tmp/capture_request"

local _pending_path = nil
local _skip_frames = 0          -- delay after view switch for data to settle

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
        _skip_frames = 3          -- give top_mem / dynamic data 3 ticks to settle
    end

    if _skip_frames > 0 then
        _skip_frames = _skip_frames - 1
        return nil               -- don't capture yet
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
