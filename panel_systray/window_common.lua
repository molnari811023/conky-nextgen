-- window_common.lua — Shared Wayland / X11 window configuration helper for
-- panel.conf, start_menu.conf, and calendar_popup.conf.
--
-- On Wayland (layer-shell / compositor rules), 'panel' and 'normal' +
-- undecorated work natively.
-- On X11 (e.g. Openbox without a compositor), 'override' without the
-- 'undecorated' hint ensures the Conky window is borderless, stays above,
-- and receives all mouse events properly.

local M = {}

M.is_wayland = (os.getenv("WAYLAND_DISPLAY") or "") ~= ""

function M.apply(cfg, role)
    cfg.own_window       = true
    cfg.own_window_color = '#0000'

    if M.is_wayland then
        if role == "panel" then
            cfg.own_window_type  = 'panel'
            cfg.own_window_hints = 'undecorated,sticky,skip_taskbar,skip_pager'
            cfg.alignment        = 'bottom_left'
        else
            cfg.own_window_type  = 'normal'
            cfg.own_window_hints = 'undecorated,sticky,above,skip_taskbar,skip_pager'
        end
    else
        if role == "popup" then
            -- Floating managed window (no undecorated hint so X11 WMs still deliver mouse events,
            -- and tiling WMs like i3 place it in the floating layer above tiled windows)
            cfg.own_window_type  = 'normal'
            cfg.own_window_hints = 'above,sticky,skip_taskbar,skip_pager'
        else
            cfg.own_window_type  = 'override'
            cfg.own_window_hints = 'above,sticky,skip_taskbar,skip_pager'
            cfg.alignment        = 'bottom_middle'
        end
    end

    if role == "popup" then
        cfg.gap_y = M.is_wayland and 6 or 54
    end

    return cfg
end

return M
