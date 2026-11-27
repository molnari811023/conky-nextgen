--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/core/plasma.lua — KDE Plasma color palette loader (~/.config/kdeglobals)

Reads KDE Plasma colors from $HOME/.config/kdeglobals using pure Lua and
LuaFileSystem (lfs) mtime tracking. The file is only re-parsed when its
modification timestamp changes.

Exposes:
- `PLASMA` — normalized { r, g, b, a } color tables (0..1)
- `PLASMA_HEX` — "#rrggbb" hex strings matching PLASMA keys
- `THEMES.plasma` — Conky NextGen theme table (palette, gradients, defaults)
- `check_plasma_theme_update()` / `check_theme_update()` — mtime-checked reload
]]--

PLASMA = PLASMA or {}
PLASMA_HEX = PLASMA_HEX or {}
THEMES = THEMES or {}

local _last_mtime = nil
local _loaded = false

local function parse_rgb(str, alpha)
    local r, g, b = str:match("(%d+),(%d+),(%d+)")
    if not r then
        return { 1, 1, 1, alpha or 1 }, "#ffffff"
    end
    local ri, gi, bi = tonumber(r), tonumber(g), tonumber(b)
    local hex = string.format("#%02x%02x%02x", ri, gi, bi)
    return { ri / 255, gi / 255, bi / 255, alpha or 1 }, hex
end

local function set_color(key, rgba, hex)
    PLASMA[key] = rgba
    PLASMA_HEX[key] = hex
end

local function rebuild_plasma_theme()
    local bg_panel  = PLASMA_HEX.bg_panel  or "#202326"
    local bg_widget = PLASMA_HEX.bg_widget or "#1b1e20"
    local bg_alt    = PLASMA_HEX.bg_alt    or "#31363c"
    local text_main = PLASMA_HEX.text_main or "#fcfcfc"
    local text_dim  = PLASMA_HEX.text_dim  or "#a1a9b1"
    local accent    = PLASMA_HEX.accent    or "#3daee9"
    local neutral   = PLASMA_HEX.neutral   or "#f67400"
    local link      = PLASMA_HEX.link      or "#2980b9"
    local positive  = PLASMA_HEX.positive  or "#27ae60"
    local negative  = PLASMA_HEX.negative  or "#da4453"
    local border    = PLASMA_HEX.border    or bg_alt

    THEMES.plasma = {
        palette = {
            bg_dark  = bg_panel,
            bg_mid   = bg_widget,
            bg_light = bg_alt,
            fg       = text_main,
            fg_dim   = text_dim,
            blue     = accent,
            green    = positive,
            yellow   = neutral,
            red      = negative,
            link     = link,
        },
        gradients = {
            text_value    = { { 1, positive, 1 } },
            bar_cpu       = { { 1, accent, 1 } },
            border_subtle = { { 1, text_dim, 0.6 } },
            accent        = { { 1, accent, 1 } },
            positive      = { { 1, positive, 1 } },
            neutral       = { { 1, neutral, 1 } },
            negative      = { { 1, negative, 1 } },
        },
        defaults = {
            background = {
                bg           = { { 1, bg_panel, 0.9 } },
                border       = { { 1, border, 1 } },
                border_width = 2,
            },
            bar = {
                fg = { { 1, accent, 1 } },
                bg = { { 1, bg_alt, 1 } },
            },
            line = {
                fg = { { 1, text_dim, 1 } },
            },
            graph = {
                fg         = { { 1, accent, 1 } },
                bg         = { { 1, bg_alt, 1 } },
                border     = { { 1, border, 1 } },
                grid_color = { { 1, bg_widget, 1 } },
            },
            ring = {
                fg = { { 1, accent, 1 } },
                bg = { { 1, bg_alt, 1 } },
            },
            text = {
                color = { { 1, text_main, 1 } },
            },
            clock = {
                bg           = { { 1, bg_widget, 1 } },
                border       = { { 1, border, 1 } },
                tick_color   = { { 1, text_dim, 1 } },
                number_color = { { 1, text_main, 1 } },
                hour_color   = { { 1, text_main, 1 } },
                minute_color = { { 1, accent, 1 } },
                second_color = { { 1, neutral, 1 } },
                left_color   = { { 1, accent, 1 } },
            },
            calendar = {
                color_month    = { { 1, text_main, 1 } },
                color_weekdays = { { 1, text_dim, 1 } },
                color_days     = { { 1, text_main, 1 } },
                color_today    = { { 1, accent, 1 } },
                color_outside  = { { 1, text_dim, 0.5 } },
                color_weeknums = { { 1, accent, 1 } },
                color_popup    = { { 1, text_dim, 1 } },
            },
        },
    }
end

local function apply_fallbacks()
    if not PLASMA.bg_panel  then set_color("bg_panel",  { 0.15, 0.17, 0.19, 1.0 }, "#262b30") end
    if not PLASMA.bg_widget then set_color("bg_widget", { 0.12, 0.14, 0.16, 1.0 }, "#1f2429") end
    if not PLASMA.bg_alt    then set_color("bg_alt",    { 0.19, 0.21, 0.24, 1.0 }, "#31363c") end
    if not PLASMA.text_main then set_color("text_main", { 1.0,  1.0,  1.0,  1.0 }, "#ffffff") end
    if not PLASMA.text_dim  then set_color("text_dim",  { 0.7,  0.7,  0.7,  1.0 }, "#b3b3b3") end
    if not PLASMA.accent    then set_color("accent",    { 0.24, 0.6,  0.95, 1.0 }, "#3d99f2") end
    if not PLASMA.neutral   then set_color("neutral",   { 0.96, 0.45, 0.0,  1.0 }, "#f67400") end
    if not PLASMA.link      then set_color("link",      { 0.16, 0.50, 0.73, 1.0 }, "#2980b9") end
    if not PLASMA.positive  then set_color("positive",  { 0.15, 0.68, 0.38, 1.0 }, "#27ae60") end
    if not PLASMA.negative  then set_color("negative",  { 0.85, 0.27, 0.33, 1.0 }, "#da4453") end
    if not PLASMA.border    then set_color("border",    PLASMA.bg_alt, PLASMA_HEX.bg_alt) end
end

local function load_kdeglobals()
    local home = os.getenv("HOME")
    if not home then
        apply_fallbacks()
        rebuild_plasma_theme()
        return
    end

    local path = home .. "/.config/kdeglobals"
    local f = io.open(path, "r")
    if not f then
        apply_fallbacks()
        rebuild_plasma_theme()
        return
    end

    local section = nil
    for line in f:lines() do
        local s = line:match("^%[(.+)%]$")
        if s then
            section = s
        else
            local key, val = line:match("^([^=]+)=([%d,]+)")
            if key and val then
                if section == "Colors:Window" then
                    if key == "BackgroundNormal" then
                        set_color("bg_panel", parse_rgb(val, 1.0))
                    elseif key == "BackgroundAlternate" then
                        set_color("border", parse_rgb(val, 1.0))
                    elseif key == "ForegroundNormal" then
                        set_color("text_main", parse_rgb(val, 1.0))
                    elseif key == "ForegroundInactive" then
                        set_color("text_dim", parse_rgb(val, 0.7))
                    end
                elseif section == "Colors:View" then
                    if key == "BackgroundNormal" then
                        set_color("bg_widget", parse_rgb(val, 1.0))
                    elseif key == "BackgroundAlternate" then
                        set_color("bg_alt", parse_rgb(val, 1.0))
                    elseif key == "ForegroundNeutral" then
                        set_color("neutral", parse_rgb(val, 1.0))
                    elseif key == "ForegroundLink" then
                        set_color("link", parse_rgb(val, 1.0))
                    end
                elseif section == "Colors:Selection" then
                    if key == "BackgroundNormal" then
                        set_color("accent", parse_rgb(val, 1.0))
                    end
                elseif section == "Colors:Button" then
                    if key == "ForegroundPositive" then
                        set_color("positive", parse_rgb(val, 1.0))
                    elseif key == "ForegroundNegative" then
                        set_color("negative", parse_rgb(val, 1.0))
                    end
                end
            end
        end
    end
    f:close()

    apply_fallbacks()
    rebuild_plasma_theme()
end

function check_plasma_theme_update()
    local home = os.getenv("HOME")
    local path = home and (home .. "/.config/kdeglobals") or nil
    local mtime = (path and lfs) and lfs.attributes(path, "modification") or nil

    if _loaded and mtime == _last_mtime then
        return false
    end

    _last_mtime = mtime
    _loaded = true
    load_kdeglobals()
    return true
end

-- Backwards-compatible alias
check_theme_update = check_plasma_theme_update

-- Initial load on module require
check_plasma_theme_update()
