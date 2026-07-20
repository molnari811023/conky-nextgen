--[[
  Conky NextGen Framework
  widget.lua — Widget definitions (TABLES ONLY)
  Logic in core/draw_core.lua, draw modules in lua/draw/
]]

-- ═══ THEME — colors, sizes ═══

THEME = THEME or {}
THEME.view_active = { { 1, "#FFFFFF", 1 }, { 1, "#4444FF", 1, "bg" } }
THEME.view_inactive = { { 1, "#666666", 1 } }
THEME.header_expanded_color = { { 1, "#FFAA00", 1 } }
THEME.header_collapsed_color = { { 1, "#FF8800", 1 } }
THEME.header_hidden_color = { { 1, "#555555", 1 } }
THEME.header_height = 24

-- ═══ DRAG THEME — drag overlay színek ═══

DRAG_THEME = DRAG_THEME or {}
DRAG_THEME.ghost_fill   = { { 1, "#FFFF80", 0.3 } }
DRAG_THEME.ghost_stroke = { { 1, "#FFFF00", 0.6 } }
DRAG_THEME.drop_fill    = { { 1, "#80FF80", 0.15 } }
DRAG_THEME.drop_stroke  = { { 1, "#80FF80", 0.4 } }
DRAG_THEME.line_width   = 2

-- ═══ LAYOUT ═══

layout = {}

-- ═══ SCROLL ═══

SCROLL = SCROLL or { offset = 0, step = 30, content_height = 0, window_height = 0 }

-- ═══ RAW ELEMENTS ═══

raw_elements = {}
