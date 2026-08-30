#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## theme_writer.py
#
# Serializes the THEMES dict back into the inline `THEMES = { ... }`
# block at the top of widget.lua (palette, gradients and per-widget-type
# defaults) using fixed Lua formatting helpers for numbers, gradient
# stops and nested values. Round-trip partner of
# lua_parser.parse_themes_lua().
#
# **Exposed/global:**
# - `serialize_themes(themes, filepath)` — THEMES dict → Lua block string
# - `_fmt_num(x)` — bool/int/float → Lua number literal
# - `_fmt_stops(stops)` — stop list → Lua table string
# - `_fmt_value(v)` — arbitrary value → Lua literal
#
# **Used by / input data:** receives the THEMES dict (loaded by
# lua_parser.parse_themes_lua / theme_engine) and writes it into the
# THEMES block of widget.lua; round-trip partner of the Lua parser.
#}}}
"""
theme_writer.py — Serialize the THEMES dict into the inline THEMES = {...}
block that lives at the top of widget.lua.

Roundtrip-partner of lua_parser.parse_themes_lua().
"""

import os

THEMES_LUA_HEADER = """--{{{
-- THEMES — Theme definitions (palette, gradients, widget defaults).
-- Lives in widget.lua, before the modules are loaded, so that
-- theme_engine.lua picks it up (THEMES = THEMES or {}).
--
-- THEMES = {
--   theme = {
--     palette   = { key = "#hex", ... },
--     gradients = { name = { stops }, ... },
--     defaults  = {
--       background = { bg, border, border_width },
--       bar        = { fg, bg },
--       graph      = { fg, bg, border, grid_color },
--       ring       = { fg, bg },
--       text       = { color },
--       line       = { fg },
--       clock      = { bg, border, tick/number/hand colors },
--       calendar   = { color_month, color_weekdays, ... },
--     },
--   },
-- }
--}}}
"""


def _fmt_num(x):
    if isinstance(x, bool):
        return "true" if x else "false"
    if isinstance(x, int):
        return str(x)
    if isinstance(x, float):
        return str(int(x)) if x.is_integer() else str(x)
    return str(x)


def _fmt_stops(stops):
    parts = []
    for s in stops or []:
        if isinstance(s, (list, tuple)) and len(s) >= 3:
            parts.append('{{ {}, "{}", {} }}'.format(_fmt_num(s[0]), s[1], _fmt_num(s[2])))
        elif isinstance(s, str):
            parts.append('"{}"'.format(s))
    return "{ " + ", ".join(parts) + " }"


def _fmt_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return str(int(v)) if v.is_integer() else str(v)
    if isinstance(v, str):
        return '"{}"'.format(v.replace('"', '\\"'))
    if isinstance(v, (list, tuple)):
        return _fmt_stops(v)
    if isinstance(v, dict):
        return "{ " + ", ".join("{} = {}".format(k, _fmt_value(val))
                                for k, val in v.items()) + " }"
    return repr(v)


def serialize_themes(themes, filepath=None):
    """Serialize the THEMES dict into the inline `THEMES = { ... }` block."""
    header = THEMES_LUA_HEADER
    out = [header.rstrip("\n"), ""]
    out.append("THEMES = {")

    for name, theme in themes.items():
        out.append("")
        out.append("    -- ═══ {} ═══".format(str(name).upper()))
        out.append("")
        out.append('    {} = {{'.format(name))

        pal = theme.get("palette") or {}
        if pal:
            out.append("")
            out.append("        palette = {")
            for k, v in pal.items():
                out.append('            {} = "{}",'.format(k, v))
            out.append("        },")

        grad = theme.get("gradients") or {}
        if grad:
            out.append("")
            out.append("        gradients = {")
            for gname, stops in grad.items():
                out.append("            {} = {},".format(gname, _fmt_stops(stops)))
            out.append("        },")

        defs = theme.get("defaults") or {}
        if defs:
            out.append("")
            out.append("        defaults = {")
            for wtype, fields in defs.items():
                out.append("            {} = {{".format(wtype))
                for k, v in fields.items():
                    out.append("                {} = {},".format(k, _fmt_value(v)))
                out.append("            },")
            out.append("        },")

        out.append("    },")

    out.append("}")
    out.append("")
    return "\n".join(out)
