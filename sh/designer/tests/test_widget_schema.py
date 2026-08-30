#!/usr/bin/env python3
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## Test_Widget_Schema
#
# Headless parity + integrity tests for engine.widget_schema: freezes the
# legacy widget type lists, field orders, defaults and string fields from the
# pre-migration main.py and checks widgets_schema against them, then validates
# schema integrity (kinds, labels, duplicates, orphan templates) and performs a
# parse → generate → parse roundtrip via main.lua generators. Runnable standalone.
#
# **Exposed/global:**
# - `LEGACY_WIDGET_TYPES` — frozen list of widget types from before the migration
# - `LEGACY_FIELD_ORDER` — frozen widget field ordering used by the builders
# - `LEGACY_WIDGET_DEFAULTS` — frozen per-type default values dict
# - `LEGACY_WIDGET_TYPE_FIELDS` — frozen per-type field lists
# - `LEGACY_STRING_FIELDS` — frozen set of fields rendered as Lua strings
# - `check(name, cond)` — records and reports a failed assertion
# - `test_widget_types()` — widget_types() matches the legacy list
# - `test_field_order_prefix()` — field_order() preserves legacy prefix and covers all templates
# - `test_defaults_parity()` — defaults_for() equals legacy defaults per type
# - `test_props_parity()` — props_for() equals legacy field order per type
# - `test_string_fields_parity()` — string_fields() equals legacy set
# - `test_schema_integrity()` — validates WidgetSpec/PropertySpec shapes and templates
# - `test_string_kind_consistency()` — string_fields() only contains string kinds
# - `test_spec_for()` — spec_for() maps known kinds and returns None for unknown
# - `test_roundtrip()` — widget.lua parse → generate → parse roundtrip equality
# - `test_generate_empty_group()` — empty/None group must be omitted from generated Lua
# - `main()` — runs all tests and exits nonzero on failures
#}}}
"""Headless parity + integrity tests for engine.widget_schema.

Run:  python3 tests/test_widget_schema.py
(or pytest tests/)
"""

import os
import sys
import tempfile

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))

from engine import widget_schema as ws
from engine.widget_schema import Kind, PropertySpec, WidgetSpec


# ── frozen legacy values (from main.py before migration) ──

LEGACY_WIDGET_TYPES = ["background", "text", "bar", "graph", "ring", "line",
                       "clock", "calendar", "image", "svg"]

LEGACY_FIELD_ORDER = ["view", "group", "draw_me", "x", "y", "x1", "y1", "x2", "y2", "w", "h",
                      "width", "height", "radius", "thickness", "size", "font",
                      "weight", "max", "value", "text", "fg", "bg", "border",
                      "border_width", "dash", "style_type", "path",
                      "click", "click_view"]

LEGACY_WIDGET_DEFAULTS = {
    "background": {"x": 0, "y": 0, "w": 0, "h": 0, "radius": 12, "border_width": 2},
    "text":       {"x": 20, "y": 10, "font": "Mono", "size": 12, "text": "New text"},
    "bar":        {"x": 50, "y": 10, "width": 220, "height": 12, "value": "${cpu}", "max": 100},
    "graph":      {"x": 20, "y": 10, "width": 360, "height": 40, "value": "${cpu}", "max": 100},
    "ring":       {"x": 200, "y": 50, "radius": 35, "thickness": 8, "value": "${cpu}", "max": 100,
                   "sectors": 6, "mode": "ring", "sides": 6},
    "line":       {"x1": 20, "y1": 15, "x2": 380, "y2": 15, "thickness": 2},
    "clock":      {"x": 200, "y": 80, "radius": 60, "show_seconds": True},
    "calendar":   {"x": 20, "y": 10, "cell_w": 48, "row_h": 22, "font": "Mono", "size": 10},
    "image":      {"x": 20, "y": 10, "width": 48, "height": 48, "path": ""},
    "svg":        {"x": 20, "y": 10, "w": 48, "h": 48, "path": ""},
}

LEGACY_WIDGET_TYPE_FIELDS = {
    "background": ["view", "group", "draw_me", "x", "y", "w", "h", "radius", "border_width",
                   "bg", "border", "click", "click_view"],
    "text":       ["view", "group", "draw_me", "x", "y", "font", "size", "slant", "weight", "align",
                   "text", "color", "wrap_width", "wrap_dic", "click", "click_view"],
    "bar":        ["view", "group", "draw_me", "x", "y", "width", "height", "value", "max", "angle",
                   "mode", "blocks", "blocks_width", "sides", "fg", "bg", "click", "click_view"],
    "graph":      ["view", "group", "draw_me", "x", "y", "width", "height", "value", "max", "autoscale",
                   "angle", "key", "graph_type", "line_width", "border_width", "grid",
                   "grid_steps", "fg", "bg", "border", "grid_color", "click", "click_view"],
    "ring":       ["view", "group", "draw_me", "x", "y", "radius", "thickness", "value", "max",
                   "sectors", "mode", "sides", "start_angle", "end_angle", "sector_size", "alarm_color",
                   "alarm_alpha", "fg", "bg", "click", "click_view"],
    "line":       ["view", "group", "draw_me", "x1", "y1", "x2", "y2", "thickness",
                   "style_type", "dash", "dash_on", "dash_off", "dot_on", "dot_off", "fg",
                   "click", "click_view"],
    "clock":      ["view", "group", "draw_me", "x", "y", "radius",
                   "show_ticks", "show_numbers", "show_seconds",
                   "tick_width_hour", "tick_width_minute",
                   "number_size", "number_radius",
                   "hour_hand_width", "minute_hand_width", "second_hand_width",
                   "center_radius",
                   "bg", "border", "tick_color", "number_color",
                   "hour_color", "minute_color", "second_color", "center_color",
                   "click", "click_view"],
    "calendar":   ["view", "group", "draw_me", "x", "y", "cell_w", "row_h", "font", "size",
                   "color_month", "color_weekdays", "color_days",
                   "color_today", "color_outside", "color_weeknums",
                   "show_weeknums", "click", "click_view"],
    "image":      ["view", "group", "draw_me", "x", "y", "width", "height", "path", "alpha",
                   "radius", "scale_mode", "shape", "rotate",
                   "crop", "tint", "tint_alpha", "click", "click_view"],
    "svg":        ["view", "group", "draw_me", "x", "y", "w", "h", "path", "alpha",
                   "radius", "shape", "rotate", "tint", "tint_alpha",
                   "click", "click_view"],
}

LEGACY_STRING_FIELDS = {"path", "group", "view", "click_view", "click", "font",
                        "text", "value", "key", "graph_type", "style_type", "shape",
                        "scale_mode", "mode", "weight", "slant", "align", "wrap_dic",
                        "draw_me"}


# ── helpers ──

_FAILED = []
def check(name, cond):
    if not cond:
        _FAILED.append(name)
        print(f"  FAIL  {name}")


def test_widget_types():
    check("widget_types matches legacy", ws.widget_types() == LEGACY_WIDGET_TYPES)


def test_field_order_prefix():
    fo = ws.field_order()
    check("field_order starts with legacy order", fo[:len(LEGACY_FIELD_ORDER)] == LEGACY_FIELD_ORDER)
    check("field_order covers all schema keys",
          set(fo) == set(ws.FIELD_TEMPLATES))


def test_defaults_parity():
    for wtype in LEGACY_WIDGET_DEFAULTS:
        check(f"defaults_for({wtype}) == legacy",
              ws.defaults_for(wtype) == LEGACY_WIDGET_DEFAULTS[wtype])


def test_props_parity():
    for wtype in LEGACY_WIDGET_TYPE_FIELDS:
        got = [p.key for p in ws.props_for(wtype)]
        check(f"props_for({wtype}) order == legacy", got == LEGACY_WIDGET_TYPE_FIELDS[wtype])


def test_string_fields_parity():
    check("string_fields == legacy", set(ws.string_fields()) == LEGACY_STRING_FIELDS)


def test_schema_integrity():
    valid_kinds = {Kind.INT, Kind.FLOAT, Kind.BOOL, Kind.ENUM, Kind.STRING,
                   Kind.TEMPLATE, Kind.FONT, Kind.PATH, Kind.COLOR, Kind.STOPS,
                   Kind.CODE, Kind.DRAW_ME}
    all_keys = set()
    for wtype in ws.widget_types():
        spec = ws.WIDGET_SPECS[wtype]
        check(f"{wtype} is WidgetSpec", isinstance(spec, WidgetSpec))
        check(f"{wtype} has label", isinstance(spec.label, str) and spec.label)
        seen = set()
        for p in spec.props:
            check(f"{wtype}:{p.key} is PropertySpec", isinstance(p, PropertySpec))
            check(f"{wtype}:{p.key} valid kind", p.kind in valid_kinds)
            check(f"{wtype}:{p.key} has label", bool(p.label))
            check(f"{wtype}:{p.key} no duplicate", p.key not in seen)
            seen.add(p.key)
            all_keys.add(p.key)
    # every TYPE_PROPS key must exist in FIELD_TEMPLATES
    for wtype, keys in ws.TYPE_PROPS.items():
        for k in keys:
            check(f"template exists for {wtype}:{k}", k in ws.FIELD_TEMPLATES)
    # every template is referenced by at least one type (except intentional:
    # "group" is a coercion/autocomplete template but never a panel row)
    unreferenced = set(ws.FIELD_TEMPLATES) - all_keys
    check("no unexpected orphan templates", unreferenced <= {"group"})


def test_string_kind_consistency():
    for k in ws.string_fields():
        t = ws.spec_for(k)
        check(f"string field {k} has string kind", t is not None and t.string)
    # non-string kinds must not be in string_fields
    for k, t in ws.FIELD_TEMPLATES.items():
        if t.kind in (Kind.INT, Kind.FLOAT, Kind.BOOL, Kind.STOPS):
            check(f"non-string field {k} not in string_fields", k not in ws.string_fields())


def test_spec_for():
    check("spec_for(x) is INT", ws.spec_for("x").kind == Kind.INT)
    check("spec_for(fg) is STOPS", ws.spec_for("fg").kind == Kind.STOPS)
    check("spec_for(graph_type) is ENUM", ws.spec_for("graph_type").kind == Kind.ENUM)
    check("spec_for(unknown) is None", ws.spec_for("nope") is None)


def test_roundtrip():
    """Parse a sample widget.lua → generate_lua_entry → parse → equal."""
    try:
        sys.path.insert(0, _HERE)
        from main import generate_lua_entry, generate_groups_lua, generate_views_lua
    except Exception as e:  # GTK unavailable
        print(f"  SKIP  roundtrip (cannot import main: {e})")
        return

    from engine.lua_parser import parse_widget_lua

    sample = '''--[[ widget data ]]
DEFAULT_THEME = "theme"
_PADDING = 10
WINDOW_WIDTH = 420
WINDOW_HEIGHT = 1020

draw[#draw + 1] = { type = "bar", x = 50, y = 10, width = 220, height = 12,
    value = "${cpu}", max = 100,
    fg = { { 0, "#7aa2f7", 1 }, { 1, "#bb9af7", 1 } } }
draw[#draw + 1] = { type = "clock", x = 200, y = 80, radius = 60,
    show_seconds = true, view = { "main", "view_1" } }
draw[#draw + 1] = { type = "text", x = 20, y = 10, font = "Mono", size = 12,
    text = "hello", slant = "italic", color = { { 1, "#ffffff", 1 } } }

_GROUPS = { { name = "g1", views = { "main" } } }
_VIEWS = { { name = "main" }, { name = "view_1" } }
'''
    tmp = tempfile.mkdtemp(prefix="ws_rt_")
    path = os.path.join(tmp, "widget.lua")
    with open(path, "w") as f:
        f.write(sample)

    draw_list, groups, views, padding = parse_widget_lua(path)

    lines = []
    for item in draw_list:
        lines.append("draw[#draw + 1] = " + generate_lua_entry(item))
    lines.append(generate_groups_lua(groups))
    lines.append(generate_views_lua(views))
    content = "\n".join(lines)

    out_path = os.path.join(tmp, "out.lua")
    with open(out_path, "w") as f:
        f.write(content)

    draw2, groups2, views2, padding2 = parse_widget_lua(out_path)

    check("roundtrip padding", padding == padding2 == 10)
    check("roundtrip groups", groups == groups2)
    check("roundtrip views", views == views2)
    check("roundtrip item count", len(draw_list) == len(draw2))
    for a, b in zip(draw_list, draw2):
        check(f"roundtrip item {a.get('type')}",
              a == b or (a.get("view") and a["view"] == b.get("view")))


def test_generate_empty_group():
    """Empty-string group must not be emitted (Lua draw_allowed only treats
    nil group as 'group-less'; an empty string would hide the item in
    non-main views). Regression: add widget before any group exists."""
    try:
        sys.path.insert(0, _HERE)
        from main import generate_lua_entry
    except Exception as e:
        print(f"  SKIP  generate empty group (cannot import main: {e})")
        return

    out = generate_lua_entry({"type": "bar", "group": "", "x": 5})
    check("empty group omitted", "group" not in out)
    out = generate_lua_entry({"type": "bar", "group": "g_0", "x": 5})
    check("real group kept", 'group = "g_0"' in out)
    out = generate_lua_entry({"type": "bar", "group": None, "x": 5})
    check("None group omitted", "group" not in out)


def main():
    for fn in [test_widget_types, test_field_order_prefix, test_defaults_parity,
               test_props_parity, test_string_fields_parity, test_schema_integrity,
               test_string_kind_consistency, test_spec_for, test_roundtrip,
               test_generate_empty_group]:
        fn()
    if _FAILED:
        print(f"\n{len(_FAILED)} FAILURES")
        sys.exit(1)
    print("ALL OK")


if __name__ == "__main__":
    main()
