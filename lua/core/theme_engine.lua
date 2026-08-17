--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- core/theme_engine.lua — Theme resolution engine
-- THEMES table + apply_theme() + resolve_theme() + resolve_gradient()
-- Theme definitions live in widget.lua (the inline THEMES = {...} block,
-- defined before the modules are loaded and picked up here).
--
-- Functions:
--   resolve_theme(name)   → theme table (nil name → DEFAULT_THEME)
--     Look up a theme by name in the global THEMES table. Passing nil
--     returns the DEFAULT_THEME ("theme"). The returned table holds
--     palette / gradients / defaults which color-fill draw items.
--   resolve_gradient(theme_name, gradient_name) → stops or nil
--     Return the named gradient stop list from a theme, or nil when the
--     theme or gradient does not exist. Used to expand fg/bg/… color
--     references in widget.lua.
--   apply_theme(item)     → fills in missing color fields from theme
--     Mutates a draw item in place: every color/stop field that is a
--     string (e.g. "text_value") is resolved against the active theme,
--     and missing fields are filled from the theme defaults.
--
-- Globals:
--   THEMES        — { name = { palette, gradients, defaults }, ... }
--   DEFAULT_THEME — "theme" (overridable)
--
-- Usage (widget.lua):
--   draw[#draw+1] = {
--       type = "bar",
--       value = "${cpu}",
--       width = 240, height = 12,
--       -- colors auto-filled from the "theme" theme
--   }
--
--   draw[#draw+1] = {
--       type = "text",
--       text = "Hello",
--       color = "text_value",  -- gradient name resolved from theme
--   }

-- ═══ THEME TABLE ═══
-- Populated from the THEMES block at the top of widget.lua. The or-{}
-- keeps widget.lua's definitions (loaded before this file) intact.
--}}}

THEMES = THEMES or {}

DEFAULT_THEME = DEFAULT_THEME or "theme"

-- ═══ THEME RESOLUTION ═══

local function resolve_theme(name)
    if not name then name = DEFAULT_THEME end
    return THEMES[name]
end

-- Resolve a gradient name from a theme to actual stops.
-- Falls back to the gradient name as-is if not found.

local function resolve_gradient(theme_name, gradient_name)
    if not gradient_name then return nil end
    if not theme_name then theme_name = DEFAULT_THEME end
    local theme = THEMES[theme_name]
    if theme and theme.gradients and theme.gradients[gradient_name] then
        return theme.gradients[gradient_name]
    end
    return nil
end

-- Apply theme defaults to a widget item.
-- Only fills in fields that are NOT already set.
-- Uses DEFAULT_THEME if item.theme is nil.

function apply_theme(item)
    if not item or not item.type then return end
    local theme_name = item.theme or DEFAULT_THEME

    local theme = THEMES[theme_name]
    if not theme then return end

    -- Resolve gradient name fields
    local function resolve_field(field_name, value)
        if value == nil then return nil end
        if type(value) == "string" then
            local resolved = resolve_gradient(theme_name, value)
            if resolved then return resolved end
        end
        return value
    end

    -- Resolve string gradient references in color fields
    for _, field in ipairs({"fg", "bg", "border", "color", "grid_color"}) do
        if item[field] then
            local resolved = resolve_field(field, item[field])
            if resolved then item[field] = resolved end
        end
    end

    -- Apply widget-type defaults for missing fields
    local defaults = theme.defaults[item.type]
    if defaults then
        for k, v in pairs(defaults) do
            if item[k] == nil then
                item[k] = v
            end
        end
    end
end
