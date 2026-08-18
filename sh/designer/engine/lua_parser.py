"""
Lua table parser — parses widget.lua draw[] entries into Python dicts.

Handles:
  draw[#draw + 1] = { type = "bar", x = 30, ... }
  _GROUPS = { { name = "clock", views = { "calendar" } }, ... }

Returns list of dicts for draw[], list of dicts for _GROUPS.
"""

import re
import os


class RawLua(str):
    """Marker: this string is a raw Lua expression, not a plain string.

    When serialized by ``generate_lua_entry()``, ``RawLua`` values are
    emitted **unquoted** so that Lua can evaluate them (e.g. function
    references, string concatenation expressions, function calls).
    """

    def __repr__(self):
        return f"RawLua({super().__repr__()})"


def _is_lua_expression(s):
    """Return True if *s* looks like a raw Lua expression (not a plain string)."""
    if not s:
        return False
    # function() ... end
    if re.match(r'^function\s*\(', s):
        return True
    # conky_*() or other function calls at top level
    if re.match(r'^[a-zA-Z_]\w*\s*\(', s):
        return True
    # string concatenation: contains unquoted ..
    if '..' in s:
        return True
    return False


def parse_lua_value(s):
    """Parse a single Lua value string → Python value."""
    s = s.strip()
    if not s:
        return None
    # nil
    if s == "nil":
        return None
    # boolean
    if s in ("true",):
        return True
    if s in ("false",):
        return False
    # number
    try:
        if "." in s or "e" in s or "E" in s:
            return float(s)
        return int(s)
    except ValueError:
        pass
    # string with double quotes
    m = re.match(r'^"(.*)"$', s, re.DOTALL)
    if m:
        inner = m.group(1).replace('\\"', '"').replace("\\n", "\n")
        if _is_lua_expression(inner):
            return RawLua(inner)
        return inner
    # string with single quotes
    m = re.match(r"^'(.*)'$", s, re.DOTALL)
    if m:
        inner = m.group(1).replace("\\'", "'").replace("\\n", "\n")
        if _is_lua_expression(inner):
            return RawLua(inner)
        return inner
    # table (recursive)
    if s.startswith("{"):
        return parse_lua_table_content(s)
    # expression like 1024 * 1024
    if re.match(r'^[\d\s\*\+\-\/\(\)]+$', s):
        try:
            return int(eval(s))
        except Exception:
            try:
                return float(eval(s))
            except Exception:
                pass
    # Unquoted Lua expression → RawLua
    if _is_lua_expression(s):
        return RawLua(s)
    # fallback: return as string
    return s


def parse_lua_table_content(s):
    """Parse a Lua table string { ... } → Python list or dict."""
    s = s.strip()
    if not s.startswith("{") or not s.endswith("}"):
        return s
    inner = s[1:-1].strip()
    if not inner:
        return []

    items = _split_table_items(inner)

    # Check if it's array-style or dict-style
    is_array = True
    is_dict = False
    for item in items:
        item = item.strip()
        if not item:
            continue
        m = re.match(r'^(\w+)\s*=', item)
        if m:
            is_dict = True
            is_array = False
            break
        m = re.match(r'^\d+\s*=', item)
        if m:
            is_dict = True
            is_array = False
            break

    if is_dict:
        result = {}
        for item in items:
            item = item.strip()
            if not item:
                continue
            m = re.match(r'^(\w+)\s*=\s*', item)
            if m:
                key = m.group(1)
                val_str = item[m.end():]
                result[key] = parse_lua_value(val_str)
        return result
    else:
        result = []
        for item in items:
            item = item.strip()
            if not item:
                continue
            result.append(parse_lua_value(item))
        return result


def _split_table_items(s):
    """Split table items by commas, respecting nested braces and strings."""
    items = []
    depth = 0
    in_string = None
    current = []
    i = 0
    while i < len(s):
        ch = s[i]
        if in_string:
            current.append(ch)
            if ch == in_string and (i == 0 or s[i - 1] != "\\"):
                in_string = None
            i += 1
            continue
        if ch in ('"', "'"):
            in_string = ch
            current.append(ch)
            i += 1
            continue
        if ch == "{":
            depth += 1
            current.append(ch)
        elif ch == "}":
            depth -= 1
            current.append(ch)
        elif ch == "," and depth == 0:
            items.append("".join(current))
            current = []
        else:
            current.append(ch)
        i += 1
    if current:
        items.append("".join(current))
    return items


def parse_lua_array_table(s):
    """Parse a Lua array table like { { name = "a" }, { name = "b" } }."""
    return parse_lua_value(s)


def parse_settings(filepath):
    """Parse global settings from widget.lua → dict."""
    settings = {
        "padding": 10,
        "theme": "theme",
        "width": 420,
        "height": 1020,
        "mouse_enabled": True,
        "weather_enabled": False,
        "weather_icon_theme": "default",
        "xdg_icon_theme": "",
    }
    try:
        with open(filepath) as f:
            content = f.read()
    except FileNotFoundError:
        return settings
    content = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    content = re.sub(r'--[^\n]*', '', content)
    m = re.search(r'_PADDING\s*=\s*(\d+)', content)
    if m: settings["padding"] = int(m.group(1))
    m = re.search(r'DEFAULT_THEME\s*=\s*"(\w+)"', content)
    if m: settings["theme"] = m.group(1)
    m = re.search(r'WINDOW_WIDTH\s*=\s*(\d+)', content)
    if m: settings["width"] = int(m.group(1))
    m = re.search(r'WINDOW_HEIGHT\s*=\s*(\d+)', content)
    if m: settings["height"] = int(m.group(1))
    m = re.search(r'_MOUSE_ENABLED\s*=\s*(true|false)', content)
    if m: settings["mouse_enabled"] = m.group(1) == "true"
    m = re.search(r'ICON_THEME\s*=\s*"(\w+)"', content)
    if m:
        settings["weather_enabled"] = True
        settings["weather_icon_theme"] = m.group(1)
    m = re.search(r'XDG_ICON_THEME\s*=\s*"([^"]+)"', content)
    if m: settings["xdg_icon_theme"] = m.group(1)
    return settings


def parse_widget_lua(filepath):
    """Parse widget.lua → (draw_list, groups_list, views_list, padding).

    draw_list: list of dicts, each with at least 'type' key
    groups_list: list of dicts, each with 'name' and 'views' keys
    views_list: list of dicts, each with 'name' key
    padding: int, value of _PADDING (default 10)
    """
    with open(filepath, "r") as f:
        content = f.read()

    # Strip Lua comments (-- line comments and --[[ block comments ]])
    content = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    content = re.sub(r'--[^\n]*', '', content)

    draw_list = []
    groups_list = []
    views_list = []

    # Parse _PADDING
    padding = 10
    pm = re.search(r'_PADDING\s*=\s*(\d+)', content)
    if pm:
        padding = int(pm.group(1))

    # Parse _GROUPS = { ... }
    gmatch = re.search(r'_GROUPS\s*=\s*(\{.*?\})\s*$', content, re.MULTILINE | re.DOTALL)
    if gmatch:
        groups_raw = gmatch.group(1)
        groups_list = parse_lua_value(groups_raw)
        if isinstance(groups_list, dict):
            groups_list = [groups_list]

    # Parse _VIEWS = { ... }
    vmatch = re.search(r'_VIEWS\s*=\s*(\{.*?\})\s*$', content, re.MULTILINE | re.DOTALL)
    if vmatch:
        views_raw = vmatch.group(1)
        views_list = parse_lua_value(views_raw)
        if isinstance(views_list, dict):
            views_list = [views_list]

    # Parse draw[#draw + 1] = { ... } entries
    pattern = re.compile(
        r'draw\[#draw\s*\+\s*1\]\s*=\s*(\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\})',
        re.DOTALL
    )
    for m in pattern.finditer(content):
        table_str = m.group(1)
        entry = parse_lua_value(table_str)
        if isinstance(entry, dict) and "type" in entry:
            draw_list.append(entry)

    # Normalize multi-view: view = { "main", "view_1" } → "main, view_1"
    for entry in draw_list:
        if isinstance(entry.get("view"), list):
            entry["view"] = ", ".join(str(v) for v in entry["view"])

    # Normalize group views: a missing/None/non-list "views" must become a list,
    # otherwise callers crash on ", ".join(...) / "in ..."
    for g in groups_list:
        if not isinstance(g.get("views"), list):
            g["views"] = []

    return draw_list, groups_list, views_list, padding


def _balanced_block(text, start):
    """text[start] == '{' → return (inner, end_index) of the matching block."""
    depth = 0
    i = start
    while i < len(text):
        ch = text[i]
        if ch in ('"', "'"):
            q = ch
            i += 1
            while i < len(text):
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == q:
                    break
                i += 1
            i += 1
            continue
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1:i], i
        i += 1
    return text[start + 1:], len(text) - 1


def _split_theme_entries(inner):
    """Split the content of `THEMES = { ... }` into (name, block) pairs.

    Each top-level entry looks like:  theme = { ... },
    `block` includes the entry's own outer braces.
    """
    entries = []
    depth = 0
    current = []
    in_string = None
    i = 0
    while i < len(inner):
        ch = inner[i]
        if in_string:
            current.append(ch)
            if ch == in_string and inner[i - 1] != "\\":
                in_string = None
            i += 1
            continue
        if ch in ('"', "'"):
            in_string = ch
            current.append(ch)
            i += 1
            continue
        if ch == "{":
            depth += 1
            current.append(ch)
        elif ch == "}":
            depth -= 1
            current.append(ch)
        elif ch == "," and depth == 0:
            entries.append("".join(current))
            current = []
        else:
            current.append(ch)
        i += 1
    if "".join(current).strip():
        entries.append("".join(current))

    result = []
    for e in entries:
        m = re.match(r'^\s*(\w+)\s*=\s*\{', e)
        if m:
            start = e.find("{")
            block, _ = _balanced_block(e, start)
            result.append((m.group(1), block))
    return result


def _parse_theme_block(text):
    """Parse one theme's content (`palette = {...}, gradients = {...},
    defaults = {...}`, WITHOUT the theme's own braces) →
    { palette, gradients, defaults }."""
    theme = {"palette": {}, "gradients": {}, "defaults": {}}
    section = None
    sub_section = None
    brace_depth = 1  # the theme's own braces are implicit

    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("--"):
            continue

        prev_depth = brace_depth
        for ch in stripped:
            if ch == "{":
                brace_depth += 1
            elif ch == "}":
                brace_depth -= 1
                if brace_depth == 0:
                    return theme
                elif brace_depth == 1:
                    section = None
                    sub_section = None

        if section == "palette" and brace_depth >= 2:
            m = re.match(r'(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"', stripped)
            if m:
                theme["palette"][m.group(1)] = m.group(2)
            continue
        if section == "gradients" and brace_depth >= 2:
            m = re.match(r'(\w+)\s*=\s*(\{.+\})', stripped)
            if m:
                gname = m.group(1)
                stops_str = m.group(2).rstrip(",").strip()
                theme["gradients"][gname] = parse_gradient_stops(stops_str)
            continue
        if section == "defaults" and brace_depth >= 2:
            if prev_depth == 2:
                m = re.match(r'(\w+)\s*=\s*\{', stripped)
                if m and m.group(1) not in ("palette", "gradients", "defaults"):
                    sub_section = m.group(1)
                    theme["defaults"][sub_section] = {}
                    continue
            if sub_section and brace_depth >= 3:
                m = re.match(r'(\w+)\s*=\s*(.+)', stripped)
                if m:
                    key = m.group(1)
                    val_str = m.group(2).rstrip(",").strip()
                    theme["defaults"][sub_section][key] = parse_lua_value(val_str)
            continue

        # Section headers (palette / gradients / defaults openers)
        if re.match(r'palette\s*=\s*\{', stripped):
            section = "palette"
            continue
        if re.match(r'gradients\s*=\s*\{', stripped):
            section = "gradients"
            continue
        if re.match(r'defaults\s*=\s*\{', stripped):
            section = "defaults"
            continue

    return theme


def parse_themes_lua(filepath):
    """Parse a file containing theme definitions → { name: { palette,
    gradients, defaults } }.

    Handles both the inline format (`THEMES = { theme = {...} }`, as written
    into widget.lua) and the legacy per-theme format
    (`THEMES["name"] = {...}` from the old themes.lua).
    """
    with open(filepath, "r") as f:
        content = f.read()
    content = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    content = re.sub(r'--[^\n]*', '', content)

    themes = {}

    inline_m = re.search(r'\bTHEMES\s*=\s*\{', content)
    legacy_m = re.search(r'\bTHEMES\["(\w+)"\]\s*=\s*\{', content)

    if inline_m and (not legacy_m or inline_m.start() < legacy_m.start()):
        start = content.index("{", inline_m.start())
        inner, _ = _balanced_block(content, start)
        for name, block in _split_theme_entries(inner):
            themes[name] = _parse_theme_block(block)
        return themes

    # Legacy: extract each THEMES["name"] = { ... } block
    for m in re.finditer(r'\bTHEMES\["(\w+)"\]\s*=\s*\{', content):
        start = content.index("{", m.start())
        inner, _ = _balanced_block(content, start)
        themes[m.group(1)] = _parse_theme_block(inner)

    return themes


def parse_gradient_stops(s):
    """Parse gradient stops string like { { 0.0, "#7aa2f7", 1 }, { 1.0, "#bb9af7", 1 } }.
    Returns list of (pos, hex, alpha) tuples."""
    stops = []
    for m in re.finditer(r'\{\s*([\d.]+)\s*,\s*"(#[0-9a-fA-F]{6})"\s*,\s*([\d.]+)\s*\}', s):
        stops.append((float(m.group(1)), m.group(2), float(m.group(3))))
    return stops


if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <widget.lua>")
        sys.exit(1)
    draw_list, groups, views, padding = parse_widget_lua(sys.argv[1])
    print(f"Found {len(draw_list)} draw entries, {len(groups)} groups, {len(views)} views")
    for i, item in enumerate(draw_list):
        print(f"  [{i}] type={item.get('type')} group={item.get('group', '-')}")
    for g in groups:
        print(f"  Group: {g.get('name')} views={g.get('views', [])}")
    for v in views:
        print(f"  View: {v.get('name')}")
