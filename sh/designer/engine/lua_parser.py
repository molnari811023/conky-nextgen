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



def _find_for_blocks(content):
    """Find all ``for ... do ... end`` blocks in *content*.

    Returns a list of ``(start_line, end_line, raw_text)`` tuples
    covering the entire block (including any preceding comment /
    ``local`` lines that logically belong to the block).

    Only blocks that contain at least one ``draw[#draw + 1]`` assignment
    are returned.  Line numbers are 0-based.
    """
    blocks = []
    lines = content.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        # Detect a for-loop header (for i = ... / for k in ...)
        if re.match(r'^for\s+\w+\s*[=,]', line) or re.match(r'^for\s+\w+\s+in\b', line):
            # Walk back to include preceding -- comment / local lines
            j = i - 1
            while j >= 0:
                prev = lines[j].strip()
                if prev.startswith("--") or re.match(r'^local\s+', prev) or prev == "":
                    j -= 1
                else:
                    break
            block_start_line = j + 1

            # Find matching end (handle nested for/if/while)
            depth = 0
            k = i
            while k < len(lines):
                l = lines[k].strip()
                if re.match(r'^for\b', l) or re.match(r'^if\b.*\bthen\s*$', l) or re.match(r'^while\b', l):
                    depth += 1
                elif l == "end":
                    depth -= 1
                    if depth == 0:
                        break
                k += 1
            block_end_line = k  # inclusive

            # Check if block contains draw entries
            block_text = "\n".join(lines[block_start_line:block_end_line + 1])
            if "draw[#draw" in block_text:
                blocks.append((block_start_line, block_end_line, block_text))
            i = block_end_line + 1
        else:
            i += 1
    return blocks


class RawBlock:
    """Marker: verbatim Lua code that must be emitted as-is during save.

    This preserves ``for`` loops, ``if`` blocks, and any other Lua
    constructs that the designer cannot parse into draw entries.
    Behaves like a dict for ``.get()`` / ``in`` checks so that the
    designer GUI code doesn't crash when it encounters one.
    """
    def __init__(self, lua_code):
        self.lua_code = lua_code

    def __repr__(self):
        return f"RawBlock({self.lua_code[:60]!r}...)"

    def get(self, key, default=None):
        if key == "type":
            return "_raw_block"
        return default

    def __contains__(self, key):
        return False

    def __getitem__(self, key):
        if key == "type":
            return "_raw_block"
        raise KeyError(key)

    def __iter__(self):
        return iter([])


def parse_widget_lua(filepath):
    """Parse widget.lua → (draw_list, groups_list, views_list, padding).

    draw_list: list of dicts, each with at least 'type' key.
               ``RawBlock`` instances are inserted for ``for`` loops and
               other un-parseable Lua constructs.
    groups_list: list of dicts, each with 'name' and 'views' keys
    views_list: list of dicts, each with 'name' key
    padding: int, value of _PADDING (default 10)
    """
    with open(filepath, "r") as f:
        content = f.read()

    orig_lines = content.split("\n")

    # --- Find for-blocks (need raw text + line numbers) ---
    for_blocks = _find_for_blocks(content)
    for_block_lines = set()
    for start_line, end_line, _ in for_blocks:
        for ln in range(start_line, end_line + 1):
            for_block_lines.add(ln)

    # Strip Lua comments (-- line comments and --[[ block comments ]])
    # Use a version without comments for text value parsing
    stripped = re.sub(r'--\[\[.*?\]\]', '', content, flags=re.DOTALL)
    stripped = re.sub(r'--[^\n]*', '', stripped)

    draw_list = []
    groups_list = []
    views_list = []

    # Parse _PADDING
    padding = 10
    pm = re.search(r'_PADDING\s*=\s*(\d+)', stripped)
    if pm:
        padding = int(pm.group(1))

    # Parse _GROUPS = { ... }
    gmatch = re.search(r'_GROUPS\s*=\s*(\{.*?\})\s*$', stripped, re.MULTILINE | re.DOTALL)
    if gmatch:
        groups_raw = gmatch.group(1)
        groups_list = parse_lua_value(groups_raw)
        if isinstance(groups_list, dict):
            groups_list = [groups_list]

    # Parse _VIEWS = { ... }
    vmatch = re.search(r'_VIEWS\s*=\s*(\{.*?\})\s*$', stripped, re.MULTILINE | re.DOTALL)
    if vmatch:
        views_raw = vmatch.group(1)
        views_list = parse_lua_value(views_raw)
        if isinstance(views_list, dict):
            views_list = [views_list]

    # Parse draw[#draw + 1] = { ... } entries
    # Run on STRIPPED content (comments removed → no false positives from
    # comment text like "-- draw[#draw + 1] = { ... }")
    pattern = re.compile(
        r'draw\[#draw\s*\+\s*1\]\s*=\s*(\{(?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*\})',
        re.DOTALL
    )

    # Build a mapping: stripped line → original line number.
    # We use a simple line-count approach: strip comments by replacing them
    # in-place (not deleting lines), so both have the same line count.
    content_no_block = re.sub(
        r'--\[\[.*?\]\]',
        lambda m: '\n' * m.group(0).count('\n'),
        content, flags=re.DOTALL,
    )
    content_no_comments = re.sub(r'--[^\n]*', '', content_no_block)

    draw_positions = []  # (original_line, entry_dict)
    for m in pattern.finditer(stripped):
        table_str = m.group(1)
        entry = parse_lua_value(table_str)
        if isinstance(entry, dict) and "type" in entry:
            # Figure out the original line number for this match
            stripped_line = stripped[:m.start()].count("\n")
            # Map to original line by comparing text at that line index
            # Both have the same number of lines because we replaced
            # --[[...]] with same-count newlines
            stripped_lines = stripped.split("\n")
            if stripped_line < len(stripped_lines):
                sl = stripped_lines[stripped_line].strip()
                # Find matching original line
                orig_line = stripped_line  # default: same index
                if 0 <= stripped_line < len(orig_lines):
                    ol = orig_lines[stripped_line].strip()
                    if ol == sl:
                        orig_line = stripped_line
                    else:
                        # Search nearby lines for a match
                        for delta in range(-3, 4):
                            candidate = stripped_line + delta
                            if 0 <= candidate < len(orig_lines):
                                if orig_lines[candidate].strip() == sl:
                                    orig_line = candidate
                                    break
            else:
                orig_line = -1
            draw_positions.append((orig_line, entry))

    # Build ordered draw_list: normal entries + RawBlocks, sorted by position
    all_items = []  # (original_line, item)

    for orig_line, entry in draw_positions:
        if orig_line in for_block_lines:
            continue  # skip — inside a for-block, emitted as RawBlock
        all_items.append((orig_line, entry))

    for start_line, end_line, raw_text in for_blocks:
        all_items.append((start_line, RawBlock(raw_text)))

    all_items.sort(key=lambda x: x[0])
    draw_list = [item for _, item in all_items]

    # Normalize multi-view: view = { "main", "view_1" } → "main, view_1"
    for entry in draw_list:
        if isinstance(entry, dict) and isinstance(entry.get("view"), list):
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
