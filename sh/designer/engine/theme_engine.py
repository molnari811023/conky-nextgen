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
USE_PLASMA_THEME = False
_PLASMA_MTIME = None
_PLASMA_LOADED = False


def _rgb_to_hex(val, default="#ffffff"):
    parts = [p.strip() for p in val.split(",")]
    if len(parts) < 3:
        return default
    try:
        r, g, b = int(parts[0]), int(parts[1]), int(parts[2])
        return f"#{r:02x}{g:02x}{b:02x}"
    except ValueError:
        return default


def load_plasma_theme(force=False):
    """Load KDE Plasma colors from ~/.config/kdeglobals using mtime caching."""
    global _PLASMA_MTIME, _PLASMA_LOADED
    path = os.path.expanduser("~/.config/kdeglobals")
    try:
        mtime = os.stat(path).st_mtime
    except OSError:
        mtime = None

    if _PLASMA_LOADED and not force and mtime == _PLASMA_MTIME and "plasma" in THEMES:
        return False

    _PLASMA_MTIME = mtime
    _PLASMA_LOADED = True

    c = {
        "bg_panel": "#262b30",
        "bg_widget": "#1f2429",
        "bg_alt": "#31363c",
        "text_main": "#ffffff",
        "text_dim": "#b3b3b3",
        "accent": "#3d99f2",
        "neutral": "#f67400",
        "link": "#2980b9",
        "positive": "#27ae60",
        "negative": "#da4453",
        "border": "#31363c",
    }

    if mtime is not None:
        section = None
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                for raw in f:
                    line = raw.strip()
                    if line.startswith("[") and line.endswith("]"):
                        section = line[1:-1]
                    elif "=" in line:
                        key, val = line.split("=", 1)
                        if section == "Colors:Window":
                            if key == "BackgroundNormal":
                                c["bg_panel"] = _rgb_to_hex(val, c["bg_panel"])
                            elif key == "BackgroundAlternate":
                                c["border"] = _rgb_to_hex(val, c["border"])
                            elif key == "ForegroundNormal":
                                c["text_main"] = _rgb_to_hex(val, c["text_main"])
                            elif key == "ForegroundInactive":
                                c["text_dim"] = _rgb_to_hex(val, c["text_dim"])
                        elif section == "Colors:View":
                            if key == "BackgroundNormal":
                                c["bg_widget"] = _rgb_to_hex(val, c["bg_widget"])
                            elif key == "BackgroundAlternate":
                                c["bg_alt"] = _rgb_to_hex(val, c["bg_alt"])
                            elif key == "ForegroundNeutral":
                                c["neutral"] = _rgb_to_hex(val, c["neutral"])
                            elif key == "ForegroundLink":
                                c["link"] = _rgb_to_hex(val, c["link"])
                        elif section == "Colors:Selection":
                            if key == "BackgroundNormal":
                                c["accent"] = _rgb_to_hex(val, c["accent"])
                        elif section == "Colors:Button":
                            if key == "ForegroundPositive":
                                c["positive"] = _rgb_to_hex(val, c["positive"])
                            elif key == "ForegroundNegative":
                                c["negative"] = _rgb_to_hex(val, c["negative"])
        except OSError:
            pass

    THEMES["plasma"] = {
        "palette": {
            "bg_dark": c["bg_panel"],
            "bg_mid": c["bg_widget"],
            "bg_light": c["bg_alt"],
            "fg": c["text_main"],
            "fg_dim": c["text_dim"],
            "blue": c["accent"],
            "green": c["positive"],
            "yellow": c["neutral"],
            "red": c["negative"],
            "link": c["link"],
        },
        "gradients": {
            "text_value": [[1, c["positive"], 1]],
            "bar_cpu": [[1, c["accent"], 1]],
            "border_subtle": [[1, c["text_dim"], 0.6]],
            "accent": [[1, c["accent"], 1]],
            "positive": [[1, c["positive"], 1]],
            "neutral": [[1, c["neutral"], 1]],
            "negative": [[1, c["negative"], 1]],
        },
        "defaults": {
            "background": {
                "bg": [[1, c["bg_panel"], 0.9]],
                "border": [[1, c["border"], 1]],
                "border_width": 2,
            },
            "bar": {
                "fg": [[1, c["accent"], 1]],
                "bg": [[1, c["bg_alt"], 1]],
            },
            "line": {
                "fg": [[1, c["text_dim"], 1]],
            },
            "graph": {
                "fg": [[1, c["accent"], 1]],
                "bg": [[1, c["bg_alt"], 1]],
                "border": [[1, c["border"], 1]],
                "grid_color": [[1, c["bg_widget"], 1]],
            },
            "ring": {
                "fg": [[1, c["accent"], 1]],
                "bg": [[1, c["bg_alt"], 1]],
            },
            "text": {
                "color": [[1, c["text_main"], 1]],
            },
            "clock": {
                "bg": [[1, c["bg_widget"], 1]],
                "border": [[1, c["border"], 1]],
                "tick_color": [[1, c["text_dim"], 1]],
                "number_color": [[1, c["text_main"], 1]],
                "hour_color": [[1, c["text_main"], 1]],
                "minute_color": [[1, c["accent"], 1]],
                "second_color": [[1, c["neutral"], 1]],
                "left_color": [[1, c["accent"], 1]],
            },
            "calendar": {
                "color_month": [[1, c["text_main"], 1]],
                "color_weekdays": [[1, c["text_dim"], 1]],
                "color_days": [[1, c["text_main"], 1]],
                "color_today": [[1, c["accent"], 1]],
                "color_outside": [[1, c["text_dim"], 0.5]],
                "color_weeknums": [[1, c["accent"], 1]],
                "color_popup": [[1, c["text_dim"], 1]],
            },
        },
    }
    return True


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
                    "bg": [[1, "#202326", 0.9]],
                    "border": [[1, "#4a4d52", 1]],
                    "border_width": 2,
                },
                "bar": {
                    "fg": [[1, "#3daee9", 1]],
                    "bg": [[1, "#3a3d41", 1]],
                },
                "line": {
                    "fg": [[1, "#a1a9b1", 1]],
                },
                "graph": {
                    "fg": [[1, "#3daee9", 1]],
                    "bg": [[1, "#3a3d41", 1]],
                    "border": [[1, "#4a4d52", 1]],
                    "grid_color": [[1, "#31363c", 1]],
                },
                "ring": {
                    "fg": [[1, "#3daee9", 1]],
                    "bg": [[1, "#3a3d41", 1]],
                },
                "text": {
                    "color": [[1, "#a1a9b1", 1]],
                },
                "clock": {
                    "bg": [[1, "#31363c", 1]],
                    "border": [[1, "#4a4d52", 1]],
                    "tick_color": [[1, "#a1a9b1", 1]],
                    "number_color": [[1, "#fcfcfc", 1]],
                    "hour_color": [[1, "#fcfcfc", 1]],
                    "minute_color": [[1, "#3daee9", 1]],
                    "second_color": [[1, "#f67400", 1]],
                    "left_color": [[1, "#3daee9", 1]],
                },
                "calendar": {
                    "color_month": [[1, "#fcfcfc", 1]],
                    "color_weekdays": [[1, "#a1a9b1", 1]],
                    "color_days": [[1, "#a1a9b1", 1]],
                    "color_today": [[1, "#3daee9", 1]],
                    "color_outside": [[1, "#4a4d52", 1]],
                    "color_weeknums": [[1, "#3daee9", 1]],
                    "color_popup": [[1, "#a9b1d6", 1]],
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

    theme_name = item.get("theme")
    if not theme_name:
        if USE_PLASMA_THEME:
            load_plasma_theme()
            theme_name = "plasma"
        else:
            theme_name = DEFAULT_THEME
    theme = THEMES.get(theme_name) or THEMES.get(DEFAULT_THEME)
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
