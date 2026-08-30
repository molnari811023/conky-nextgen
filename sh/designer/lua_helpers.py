#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## Lua_Helpers
#
# Lua code-generation helpers: turn Python dicts into Lua table strings for
# draw items, widget groups and views, and emit/parse the MOUSE_* action block.
# Values are escaped for Lua and theme-matching fields can be omitted via
# theme_defaults; global mouse function names are extracted from Lua sources.
#
# **Exposed/global:**
# - `_lua_view_str(val)` — renders a view field ('main, view_1' → 'view = { "main", "view_1" }')
# - `generate_lua_entry(item, theme_defaults=None)` — returns a Lua table string for one draw item
# - `generate_groups_lua(groups)` — returns the _GROUPS Lua table string
# - `generate_views_lua(views)` — returns the _VIEWS Lua table string
# - `MOUSE_ACTIONS` — list of (MOUSE_*_ACTION constant, human label) pairs
# - `MOUSE_ACTIONS_LUA` — path to lua/mouse_actions.lua under CONKY_DIR
# - `FUNCTION_SOURCES` — Lua files scanned for global function names
# - `parse_mouse_functions(filepaths)` — extracts global function names from Lua files
# - `parse_mouse_actions(content)` — parses MOUSE_*_ACTION lines from widget.lua content
# - `generate_mouse_actions_lua(mouse_actions, enabled=True)` — emits the MOUSE_* block Lua string
#}}}
"""Lua code generation helpers for draw items, groups, views, mouse actions."""
import os
import re

from engine.lua_parser import RawLua
from utils import CONKY_DIR, _lua_escape
from constants import _colors_match


def _lua_view_str(val):
    """'main, view_1' → 'view = { "main", "view_1" }' (single name stays a string)."""
    parts = [p.strip() for p in str(val).split(",") if p.strip()]
    if not parts:
        return "nil"
    if len(parts) > 1:
        return "{ " + ", ".join(f'"{_lua_escape(p)}"' for p in parts) + " }"
    return f'"{_lua_escape(parts[0])}"'


def generate_lua_entry(item, theme_defaults=None):
    """Generate a Lua table string from a dict.
    If theme_defaults is provided, skip fields that match the theme."""
    lines = ["{"]
    for key in ("type", "group", "view"):
        if key in item and item[key] is not None:
            if key == "view":
                lines.append(f"    view = {_lua_view_str(item[key])},")
            elif key == "group" and str(item[key]) == "":
                continue
            else:
                lines.append(f'    {key} = "{_lua_escape(str(item[key]))}",')
    for key, val in item.items():
        if key in ("type", "group", "view"):
            continue
        if val is None:
            continue
        if theme_defaults and key in theme_defaults:
            if _colors_match(val, theme_defaults[key]):
                continue
        if isinstance(val, bool):
            lines.append(f"    {key} = {'true' if val else 'false'},")
        elif isinstance(val, (int, float)):
            lines.append(f"    {key} = {val},")
        elif isinstance(val, RawLua):
            lines.append(f"    {key} = {val},")
        elif isinstance(val, str):
            lines.append(f'    {key} = "{_lua_escape(val)}",')
        elif isinstance(val, list):
            parts = []
            for v in val:
                if isinstance(v, (list, tuple)) and len(v) == 3:
                    parts.append(f'{{ {v[0]}, "{_lua_escape(str(v[1]))}", {v[2]} }}')
                elif isinstance(v, RawLua):
                    parts.append(str(v))
                elif isinstance(v, str):
                    parts.append(f'"{_lua_escape(v)}"')
                else:
                    parts.append(repr(v))
            lines.append(f"    {key} = {{ {', '.join(parts)} }},")
        elif isinstance(val, dict):
            parts = [f'{k} = {repr(v)}' for k, v in val.items()]
            lines.append(f"    {key} = {{ {', '.join(parts)} }},")
        else:
            lines.append(f"    {key} = {repr(val)},")
    lines.append("}")
    return "\n".join(lines)


def generate_groups_lua(groups):
    """Generate _GROUPS Lua table string."""
    lines = ["_GROUPS = {"]
    for g in groups:
        name = g.get("name", "unnamed")
        views = g.get("views", [])
        parts = [f'name = "{_lua_escape(str(name))}"']
        if views:
            views_str = ", ".join(f'"{_lua_escape(str(v))}"' for v in views)
            parts.append(f"views = {{ {views_str} }}")
        else:
            parts.append("views = { }")
        dm = g.get("draw_me")
        if dm is not None:
            if isinstance(dm, bool):
                parts.append(f"draw_me = {'true' if dm else 'false'}")
            elif isinstance(dm, RawLua):
                parts.append(f"draw_me = {dm}")
            else:
                parts.append(f'draw_me = "{_lua_escape(str(dm))}"')
        lines.append("    { " + ", ".join(parts) + " },")
    lines.append("}")
    return "\n".join(lines)


def generate_views_lua(views):
    """Generate _VIEWS Lua table string."""
    lines = ["_VIEWS = {"]
    for v in views:
        name = v.get("name", "unnamed")
        lines.append(f'    {{ name = "{_lua_escape(str(name))}" }},')
    lines.append("}")
    return "\n".join(lines)


MOUSE_ACTIONS = [
    ("MOUSE_ENTER_ACTION", "Enter"),
    ("MOUSE_LEAVE_ACTION", "Leave"),
    ("MOUSE_HOVER_IN_CONKY_WINDOW_ACTION", "Hover (window)"),
    ("MOUSE_HOVER_IN_GROUP_ACTION", "Hover (group)"),
    ("MOUSE_HOVER_LEAVE_GROUP_ACTION", "Hover leave (group)"),
    ("MOUSE_SCROLL_UP", "Scroll up"),
    ("MOUSE_SCROLL_DOWN", "Scroll down"),
    ("MOUSE_SCROLL_LEFT", "Scroll left"),
    ("MOUSE_SCROLL_RIGHT", "Scroll right"),
    ("MOUSE_CTRL_SCROLL_UP", "Ctrl+scroll up"),
    ("MOUSE_CTRL_SCROLL_DOWN", "Ctrl+scroll down"),
    ("MOUSE_SHIFT_SCROLL_UP", "Shift+scroll up"),
    ("MOUSE_SHIFT_SCROLL_DOWN", "Shift+scroll down"),
    ("MOUSE_ALT_SCROLL_UP", "Alt+scroll up"),
    ("MOUSE_ALT_SCROLL_DOWN", "Alt+scroll down"),
    ("MOUSE_CLICK_LEFT", "Left click"),
    ("MOUSE_CLICK_RIGHT", "Right click"),
    ("MOUSE_CLICK_MIDDLE", "Middle click"),
    ("MOUSE_CLICK_BACK", "Back click"),
    ("MOUSE_CLICK_FORWARD", "Forward click"),
    ("MOUSE_CTRL_CLICK", "Ctrl+click"),
    ("MOUSE_SHIFT_CLICK", "Shift+click"),
    ("MOUSE_ALT_CLICK", "Alt+click"),
]

MOUSE_ACTIONS_LUA = os.path.join(CONKY_DIR, "lua", "mouse_actions.lua")
FUNCTION_SOURCES = [MOUSE_ACTIONS_LUA]


def parse_mouse_functions(filepaths=FUNCTION_SOURCES):
    """Extract global function names from the given Lua files."""
    funcs = []
    for filepath in filepaths:
        if os.path.exists(filepath):
            with open(filepath) as f:
                for line in f:
                    m = re.match(r'\s*function\s+(\w+)\s*\(', line)
                    if m:
                        funcs.append(m.group(1))
    return sorted(set(funcs))


def parse_mouse_actions(content):
    """Parse MOUSE_*_ACTION lines from widget.lua content → { name: value_str }."""
    result = {}
    for line in content.split("\n"):
        m = re.match(r'(MOUSE_[A-Z_]+)\s*=\s*(.+)', line.strip())
        if m:
            result[m.group(1)] = m.group(2).rstrip()
    return result


def generate_mouse_actions_lua(mouse_actions, enabled=True):
    """Generate the MOUSE_* block Lua string (only non-nil actions)."""
    lines = [
        "------------------------------------------------------------",
        "-- Mouse event actions (only the non-nil ones are listed)",
        "-- All callbacks receive: function(event)",
        "-- event has: type, x, y, x_abs, y_abs, time,",
        "--            button (\"left\"/\"right\"/\"middle\"/\"back\"/\"forward\"),",
        "--            direction (\"up\"/\"down\"/\"left\"/\"right\"),",
        "--            mods = { shift=bool, control=bool, alt=bool, super=bool,",
        "--                     caps_lock=bool, num_lock=bool }",
        "------------------------------------------------------------",
        "",
        f"_MOUSE_ENABLED = {'true' if enabled else 'false'}",
    ]
    if enabled:
        for name, _ in MOUSE_ACTIONS:
            val = mouse_actions.get(name, "nil")
            if val != "nil":
                lines.append(f"{name} = {val}")
    lines.append("")
    return "\n".join(lines)
