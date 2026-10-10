--{{{
--  Conky NextGen Framework (fork)
--  by wim66
--}}}

--{{{
-- draw/spectrum.lua — audio spectrum bars with falling peak-hold markers
-- draw_spectrum(cr, opts) → { x, y, w, h }
--     Draws `num_bars` vertical bars, bottom-anchored within the given
--     box, animated with attack/release easing, each with an optional
--     peak-hold cap that jumps up instantly and falls back down slowly
--     (peak_decay per frame) independently of the main bar.
--
-- Parameters:
--   x, y, width, height       — bounding box the bars fill
--   num_bars, bar_gap, bar_corner_radius
--   attack, release           — 0..1 easing rate toward a new target
--   peak_hold (bool), peak_decay, peak_cap_height, peak_color
--   color_low, color_mid, color_high — amplitude color ramp (hex strings)
--   values                    — function() → array of num_bars numbers,
--                                each 0..100 (e.g. cava's raw range)
--
-- State (each bar's eased level + peak) is kept ON the item table
-- itself (opts._smoothed / opts._peak), evolving frame to frame. This
-- is intentional persistent animation state, not the "resolve once,
-- freeze forever" bug fixed earlier in image.lua/svg.lua — that bug
-- replaced a FUNCTION with its one-time result; here `values` is still
-- called fresh every single frame, never overwritten, and only the
-- eased/peak numbers (genuinely meant to evolve) persist between calls.
--
-- Example:
--   draw[#draw+1] = {
--       type = "spectrum",
--       x = 10, y = 10, width = 320, height = 90,
--       num_bars = 12,
--       values = function() return my_current_bar_values end,
--   }
--}}}

local SPECTRUM_DEFAULT = {
    num_bars = 12,
    bar_gap = 6,
    bar_corner_radius = 3,
    attack = 0.55,
    release = 0.18,
    peak_hold = true,
    peak_decay = 1.2,
    peak_cap_height = 2,
    color_low = "#4de6bf",
    color_mid = "#f2d94d",
    color_high = "#f24d59",
    peak_color = "#ffffff",
}

local function hex_rgb(hex)
    hex = tostring(hex):gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return r / 255, g / 255, b / 255
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

-- pct: 0..100 amplitude → interpolated RGB across the 3-color ramp
local function amp_color(pct, low, mid, high)
    local lr, lg, lb = hex_rgb(low)
    local mr, mg, mb = hex_rgb(mid)
    local hr, hg, hb = hex_rgb(high)
    if pct < 50 then
        local t = pct / 50
        return lerp(lr, mr, t), lerp(lg, mg, t), lerp(lb, mb, t)
    else
        local t = (pct - 50) / 50
        return lerp(mr, hr, t), lerp(mg, hg, t), lerp(mb, hb, t)
    end
end

function draw_spectrum(cr, opts)
    if not conky_window or not opts then return end

    local c = {}
    for k, v in pairs(SPECTRUM_DEFAULT) do c[k] = v end
    for k, v in pairs(opts) do c[k] = v end

    local n = c.num_bars
    local bar_w = (c.width - (n - 1) * c.bar_gap) / n
    if bar_w <= 0 or n < 1 then return end

    -- Resolve targets fresh into a LOCAL array every call — never
    -- write anything back into opts.values itself (see header comment).
    local targets = {}
    if type(c.values) == "function" then
        local ok, result = pcall(c.values)
        if ok and type(result) == "table" then targets = result end
    end

    -- Per-item animation state: intentionally persisted ON opts, keyed
    -- privately (leading underscore) so it doesn't collide with any
    -- real option name.
    opts._smoothed = opts._smoothed or {}
    opts._peak = opts._peak or {}
    local smoothed, peak = opts._smoothed, opts._peak

    for i = 1, n do
        local target = targets[i] or 0
        local current = smoothed[i] or 0
        local rate = (target > current) and c.attack or c.release
        current = current + (target - current) * rate
        smoothed[i] = current

        if c.peak_hold then
            local p = peak[i] or 0
            if current >= p then
                p = current
            else
                p = math.max(current, p - c.peak_decay)
            end
            peak[i] = p
        end
    end

    for i = 1, n do
        local bx = c.x + (i - 1) * (bar_w + c.bar_gap)
        local amp = math.max(0, math.min(100, smoothed[i] or 0))
        local bar_h = math.max(2, c.height * (amp / 100))
        local by = c.y + c.height - bar_h

        local red, green, blue = amp_color(amp, c.color_low, c.color_mid, c.color_high)
        cairo_set_source_rgba(cr, red, green, blue, 1)
        rounded_rect_path(cr, bx, by, bar_w, bar_h, c.bar_corner_radius)
        cairo_fill(cr)

        if c.peak_hold then
            local p = peak[i] or 0
            if p > amp + 1 then
                local py = c.y + c.height - (c.height * (p / 100))
                local pr, pg, pb = hex_rgb(c.peak_color)
                cairo_set_source_rgba(cr, pr, pg, pb, 0.9)
                cairo_rectangle(cr, bx, py, bar_w, c.peak_cap_height)
                cairo_fill(cr)
            end
        end
    end

    return { x = c.x, y = c.y, w = c.width, h = c.height }
end