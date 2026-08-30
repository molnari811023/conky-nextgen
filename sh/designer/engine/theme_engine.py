#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## theme_engine.py
#
# Theme engine — Python reimplementation of the Lua theme_engine.lua
# (widget.lua THEMES block). Loads themes through lua_parser, resolves a
# theme and its named gradients, and applies per-widget-type defaults to
# a draw item: gradient name references become stop lists, missing color
# fields are filled from the theme, and all color stops are normalized to
# `[pos, hex, alpha]` lists.
#
# **Exposed/global:**
# - `load_themes(filepath)` — parse themes into global THEMES (with defaults)
# - `resolve_theme(name)` — theme dict, falling back to DEFAULT_THEME
# - `resolve_gradient(theme_name, gradient_name)` — stops or None
# - `apply_theme(item)` — fill missing color fields on a widget item in place
# - `_normalize_stops(val)` — coerce gradient stops to [pos, hex, alpha] lists
#
# **Used by / input data:** reads the widget.lua THEMES block via
# lua_parser.parse_themes_lua; mirror of the Lua theme_engine.lua, applied
# to widget items before preview/render in the designer.
#}}}
"""
Theme engine — Python reimplementation of Lua theme_engine.lua
(widget.lua THEMES block).

Provides:
  resolve_theme(name)      → theme dict
  resolve_gradient(t, g)   → stops or None
  apply_theme(item)        → fills missing color fields from theme
"""

from .lua_parser import parse_themes_lua
import os

# ═══ STATE ═══

THEMES = {}
DEFAULT_THEME = "theme"


def load_themes(filepath=None):
    """Load themes from a file (widget.lua or a THEMES block) into THEMES."""
    global THEMES
    if filepath is None:
        base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        filepath = os.path.join(base, "..", "widget.lua")
    THEMES = parse_themes_lua(filepath)
    if not THEMES:
        THEMES = {DEFAULT_THEME: {
            "palette": {},
            "gradients": {},
            "defaults": {
                "background": {
                    "bg": { { 1, "#202326", 0.9 } },
                    "border": { { 1, "#4a4d52", 1 } },
                    "border_width": 2,
                },
                "bar": {
                    "fg": { { 1, "#3daee9", 1 } },
                    "bg": { { 1, "#3a3d41", 1 } },
                },
                "line": {
                    "fg": { { 1, "#a1a9b1", 1 } },
                },
                "graph": {
                    "fg": { { 1, "#3daee9", 1 } },
                    "bg": { { 1, "#3a3d41", 1 } },
                    "border": { { 1, "#4a4d52", 1 } },
                    "grid_color": { { 1, "#31363c", 1 } },
                },
                "ring": {
                    "fg": { { 1, "#3daee9", 1 } },
                    "bg": { { 1, "#3a3d41", 1 } },
                },
                "text": {
                    "color": { { 1, "#a1a9b1", 1 } },
                },
                "clock": {
                    "bg": { { 1, "#31363c", 1 } },
                    "border": { { 1, "#4a4d52", 1 } },
                    "tick_color": { { 1, "#a1a9b1", 1 } },
                    "number_color": { { 1, "#fcfcfc", 1 } },
                    "hour_color": { { 1, "#fcfcfc", 1 } },
                    "minute_color": { { 1, "#3daee9", 1 } },
                    "second_color": { { 1, "#f67400", 1 } },
                    "left_color": { { 1, "#3daee9", 1 } },
                },
                "calendar": {
                    "color_month": { { 1, "#fcfcfc", 1 } },
                    "color_weekdays": { { 1, "#a1a9b1", 1 } },
                    "color_days": { { 1, "#a1a9b1", 1 } },
                    "color_today": { { 1, "#3daee9", 1 } },
                    "color_outside": { { 1, "#4a4d52", 1 } },
                    "color_weeknums": { { 1, "#3daee9", 1 } },
                },
            },
        }}
    return THEMES


def resolve_theme(name=None):
    """Resolve theme name → theme dict. Falls back to DEFAULT_THEME."""
    if name is None:
        name = DEFAULT_THEME
    return THEMES.get(name)


def resolve_gradient(theme_name, gradient_name):
    """Resolve a gradient name from a theme → stops or None."""
    if not gradient_name:
        return None
    if theme_name is None:
        theme_name = DEFAULT_THEME
    theme = THEMES.get(theme_name)
    if theme and gradient_name in theme.get("gradients", {}):
        return theme["gradients"][gradient_name]
    return None


def _normalize_stops(val):
    """Ensure gradient stops are list of [pos, hex, alpha] lists.
    Handles: tuples, strings, single values, nested lists."""
    if not isinstance(val, list):
        return val
    result = []
    for stop in val:
        if isinstance(stop, (list, tuple)) and len(stop) == 3:
            result.append([stop[0], str(stop[1]), stop[2]])
        elif isinstance(stop, str):
            result.append([1, stop, 1])
    return result if result else val


COLOR_FIELDS = ("fg", "bg", "border", "color", "grid_color",
                "tick_color", "number_color", "hour_color",
                "minute_color", "second_color", "center_color",
                "color_month", "color_weekdays", "color_days",
                "color_today", "color_outside", "color_weeknums")


def apply_theme(item):
    """Apply theme defaults to a widget item. Mutates item in place.

    1. Resolves gradient name references in color fields
    2. Fills missing fields from theme defaults for the widget type
    3. Normalizes all color stops to [pos, hex, alpha] lists
    """
    if not item or "type" not in item:
        return

    theme_name = item.get("theme") or DEFAULT_THEME
    theme = THEMES.get(theme_name)
    if not theme:
        return

    # Resolve gradient name references
    for field in COLOR_FIELDS:
        val = item.get(field)
        if isinstance(val, str):
            resolved = resolve_gradient(theme_name, val)
            if resolved:
                item[field] = resolved

    # Apply widget-type defaults for missing fields
    defaults = theme.get("defaults", {}).get(item["type"])
    if defaults:
        for k, v in defaults.items():
            if item.get(k) is None:
                item[k] = v

    # Normalize all color fields to consistent [pos, hex, alpha] format
    for field in COLOR_FIELDS:
        val = item.get(field)
        if isinstance(val, list):
            item[field] = _normalize_stops(val)
