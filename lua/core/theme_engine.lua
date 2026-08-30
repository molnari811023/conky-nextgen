--[[[
lua/core/theme_engine.lua — theme resolution and per-widget default/color application

Holds the THEMES table and DEFAULT_THEME. apply_theme(item) selects the
item's theme (or DEFAULT_THEME), resolves gradient-name strings in color
fields to actual gradient stop lists, and fills in any missing widget fields
from the theme's per-type defaults.
]]--

--{{{
-- ## Theme Engine
--
-- Resolves an item's theme and applies it before drawing. apply_theme(item)
-- looks up the theme by the item's `.theme` name (falling back to
-- DEFAULT_THEME), maps color-field strings that name a theme-defined
-- gradient to their real stop lists, and back-fills per-widget-type default
-- values for any field the item has not already set.
--
-- **Exposed/global functions:**
-- - `apply_theme(item)` — apply theme defaults and resolve gradient color fields for a widget item
--
-- **Config/globals used:**
-- - `THEMES` — theme table keyed by name, each with optional `gradients` and `defaults`
-- - `DEFAULT_THEME` — theme name used when an item does not name one
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
    if theme.defaults then
        local defaults = theme.defaults[item.type]
        if defaults then
        for k, v in pairs(defaults) do
            if item[k] == nil then
                item[k] = v
            end
        end
    end
end
end
