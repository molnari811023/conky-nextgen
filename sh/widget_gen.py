#!/usr/bin/env python3
"""Widget Generator for Conky NextGen — interactive CLI tool

Usage:
  python3 sh/widget_gen.py          interactive mode
  python3 sh/widget_gen.py --help   help
"""

import argparse
import sys
import textwrap

WIDGETS = {
    "background": {
        "label": "Background (rounded rect)",
        "required": [],
        "optional": [
            ("draw_me", "bool/string/func", "true", "Condition (true/false, '${...}')"),
            ("x", "number", "0", "Left position"),
            ("y", "number", "0", "Top position"),
            ("w", "number", "0", "Width (0 = full window)"),
            ("h", "number", "0", "Height (0 = full window)"),
            ("radius", "number", "20", "Corner radius (px)"),
            ("bg", "stops", "{{1,'#141618',1}}", "Background gradient"),
            ("border", "stops", "{{1,'#4c4e51',1}}", "Border gradient"),
            ("border_width", "number", "2", "Border width (0 = none)"),
        ],
    },
    "text": {
        "label": "Text",
        "required": [("text", "string", "Text or Conky template (${...})")],
        "optional": [
            ("draw_me", "bool/string/func", "true", "Condition"),
            ("x", "number/'center'", "0", "X position or 'center'"),
            ("y", "number/'center'", "0", "Y position or 'center'"),
            ("font", "string", "'Sans'", "Font family"),
            ("size", "number", "14", "Font size (px)"),
            ("slant", "string", "'normal'", "Slant: normal/italic"),
            ("weight", "string", "'normal'", "Weight: normal/bold"),
            ("align", "string", "'left'", "Align: left/center/right"),
            ("color", "stops", "{{0,0xFFFFFF,1},{1,0xCCCCCC,1}}", "Color gradient"),
            ("wrap_width", "number", "nil", "Wrap width (px)"),
            ("wrap_dic", "string", "nil", "Hyphenation dict path"),
        ],
    },
    "bar": {
        "label": "Bar (progress bar)",
        "required": [
            ("name", "string", "Conky variable (e.g. cpu, memperc)"),
        ],
        "optional": [
            ("draw_me", "bool/string/func", "true", "Condition"),
            ("arg", "string", "nil", "Variable argument (e.g. cpu1)"),
            ("x", "number", "0", "Left position"),
            ("width", "number", "100", "Bar width (px)"),
            ("height", "number", "10", "Bar height (px)"),
            ("max", "number", "100", "Maximum value"),
            ("angle", "number", "0", "Rotation (degrees)"),
            ("blocks", "number", "nil", "Block style (nil = smooth)"),
            ("sides", "number", "nil", "Polygon sides (nil=rect, 3=triangle, 6=hexagon)"),
            ("bg", "stops", "{{0,'#333333',1},{1,'#111111',1}}", "Background gradient"),
            ("fg", "stops", "{{0,'#00ff00',1},{1,'#009900',1}}", "Foreground gradient"),
        ],
    },
    "graph": {
        "label": "Graph (time-series)",
        "required": [
            ("name", "string", "Conky variable (e.g. cpu, downspeed)"),
        ],
        "optional": [
            ("draw_me", "bool/string/func", "true", "Condition"),
            ("arg", "string", "nil", "Variable argument"),
            ("x", "number", "0", "Left position"),
            ("y", "number", "0", "Top position"),
            ("width", "number", "100", "Graph width (px)"),
            ("height", "number", "40", "Graph height (px)"),
            ("max", "number", "100", "Maximum (ignored if autoscale)"),
            ("autoscale", "bool", "false", "Auto scale"),
            ("angle", "number", "0", "Rotation (degrees)"),
            ("graph_type", "string", "'line'", "Type: line/fill"),
            ("line_width", "number", "2", "Line width"),
            ("bg", "stops", "{{0,'#333333',1},{1,'#111111',1}}", "Background gradient"),
            ("fg", "stops", "{{0,'#00ffaa',1},{1,'#008866',1}}", "Foreground gradient"),
            ("border", "stops", "{{0,'#FFFFFF',0.8},{1,'#FFFFFF',0.2}}", "Border gradient"),
            ("border_width", "number", "1", "Border width"),
            ("grid", "bool", "false", "Show grid"),
            ("grid_steps", "number", "4", "Grid steps"),
        ],
    },
    "clock": {
        "label": "Analog clock",
        "required": [],
        "optional": [
            ("draw_me", "bool/string/func", "true", "Condition"),
            ("x", "number", "100", "Center X"),
            ("y", "number", "100", "Center Y"),
            ("radius", "number", "50", "Clock radius"),
            ("show_ticks", "bool", "true", "Show tick marks"),
            ("show_numbers", "bool", "true", "Show numbers"),
            ("show_seconds", "bool", "true", "Show second hand"),
            ("number_size", "number", "14", "Number size"),
            ("center_radius", "number", "4", "Center dot radius"),
            ("bg", "stops", "{{0,0x222222,1},{1,0x000000,1}}", "Face background gradient"),
            ("border", "stops", "{{0,0xFFFFFF,1},{1,0x888888,1}}", "Border gradient"),
            ("hour_color", "stops", "{{0,0xFFFFFF,1},{1,0xFFFFFF,1}}", "Hour hand color"),
            ("minute_color", "stops", "{{0,0xFFFFFF,1},{1,0xFFFFFF,1}}", "Minute hand color"),
            ("second_color", "stops", "{{0,0xFF0000,1},{1,0xAA0000,1}}", "Second hand color"),
        ],
    },
    "ring": {
        "label": "Ring (gauge)",
        "required": [
            ("name", "string", "Conky variable (e.g. cpu, memperc)"),
        ],
        "optional": [
            ("draw_me", "bool/string/func", "true", "Condition"),
            ("arg", "string", "nil", "Variable argument"),
            ("x", "number", "100", "Center X"),
            ("y", "number", "100", "Center Y"),
            ("radius", "number", "50", "Ring radius"),
            ("thickness", "number", "6", "Ring thickness (px)"),
            ("start_angle", "number", "0", "Start angle (degrees)"),
            ("end_angle", "number", "360", "End angle (degrees)"),
            ("sectors", "number", "6", "Number of segments"),
            ("sides", "number", "nil", "Polygon sides (nil=arc, 3=gear tooth, 6=hexagon)"),
            ("mode", "string", "'ring'", "Mode: ring/smooth"),
            ("max", "number", "100", "Maximum value"),
            ("bg", "stops", "{{0,'#333333',1},{1,'#111111',1}}", "Background gradient"),
            ("fg", "stops", "{{0,'#00ffaa',1},{1,'#008866',1}}", "Foreground gradient"),
        ],
    },
    "line": {
        "label": "Line",
        "required": [],
        "optional": [
            ("draw_me", "bool/string/func", "true", "Condition"),
            ("x1", "number", "0", "Start X"),
            ("y1", "number", "0", "Start Y"),
            ("x2", "number", "100", "End X"),
            ("y2", "number", "0", "End Y"),
            ("thickness", "number", "2", "Line thickness (px)"),
            ("angle", "number", "0", "Rotation (degrees)"),
            ("style_type", "string", "'solid'", "Style: solid/dashed/dotted"),
            ("fg", "stops", "{{0,0xFFFFFF,1},{1,0xAAAAAA,1}}", "Line color gradient"),
        ],
    },
    "calendar": {
        "label": "Calendar",
        "required": [],
        "optional": [
            ("draw_me", "bool/string/func", "true", "Condition"),
            ("x", "number", "300", "Left position"),
            ("y", "number", "15", "Top position"),
            ("cell_w", "number", "40", "Cell width (px)"),
            ("row_h", "number", "30", "Row height (px)"),
            ("font", "string", "'Sans'", "Font family"),
            ("size", "number", "18", "Font size"),
            ("show_weeknums", "bool", "true", "Show week numbers"),
            ("color_month", "stops", "{{0,'#ffffff',1},{1,'#bbbbbb',1}}", "Month title color"),
            ("color_days", "stops", "{{0,'#ffffff',1},{1,'#cccccc',1}}", "Day number color"),
            ("color_today", "stops", "{{0,'#66ccff',1},{1,'#3399cc',1}}", "Today highlight"),
            ("color_outside", "stops", "{{0,'#550000',0.7},{1,'#550000',0.7}}", "Outside month days"),
        ],
    },
    "image": {
        "label": "Image (PNG)",
        "required": [
            ("path", "string", "PNG file path"),
        ],
        "optional": [
            ("draw_me", "bool/string/func", "true", "Condition"),
            ("x", "number", "0", "Left position"),
            ("y", "number", "0", "Top position"),
            ("width", "number", "nil", "Output width (auto if only height set)"),
            ("height", "number", "nil", "Output height (auto if only width set)"),
            ("alpha", "number", "1", "Opacity (0-1)"),
            ("tint", "string", "nil", "Hex tint (#rrggbb)"),
            ("rotate", "number", "0", "Rotation (degrees)"),
            ("radius", "number", "0", "Corner radius"),
        ],
    },
}

WIDGET_ORDER = [
    "background", "text", "bar", "graph", "clock",
    "ring", "line", "calendar", "image",
]


def c(text):
    sys.stdout.write(text)
    sys.stdout.flush()


def print_header(title):
    print()
    c(f"\033[1;36m{'='*60}\033[0m\n")
    c(f"\033[1;33m  {title}\033[0m\n")
    c(f"\033[1;36m{'='*60}\033[0m\n")
    print()


def input_str(prompt, default=None):
    if default is not None:
        prompt = f"{prompt} [\033[1m{default}\033[0m] "
    else:
        prompt = f"{prompt} "
    val = input(prompt).strip()
    if not val and default is not None:
        return default
    return val


def input_bool(prompt, default="true"):
    val = input_str(f"{prompt} (true/false)", default)
    if val.lower() in ("true", "t", "yes", "y", "1"):
        return "true"
    return "false"


def input_number(prompt, default=None):
    val = input_str(prompt, default)
    if val == "nil":
        return "nil"
    if val in ("true", "false"):
        return val
    try:
        float(val)
        return val
    except ValueError:
        return val if val.startswith("'") else repr(val)


def input_stops(prompt, default=None):
    val = input_str(prompt, default)
    return val


def indent_value(val, indent=4):
    if "\n" not in val:
        return " " * indent + val
    indented = val.replace("\n", "\n" + " " * indent)
    return " " * indent + indented


def generate_widget_entry(wtype, fields):
    lines = ["{"]
    lines.append("    type = " + repr(wtype) + ",")
    for key, val in fields.items():
        if key == "draw_me" and val == "true":
            continue
        lines.append(indent_value(f"{key} = {val},"))
    lines.append("},")
    return "\n".join(lines)


def generate_layout_entry(name, height, enabled, comment):
    lines = ["{"]
    lines.append(f'    name = {repr(name)},')
    lines.append(f"    height = {height},")
    if enabled and enabled != "true":
        lines.append(f"    enabled = {enabled},")
    if comment:
        lines.append(f"    -- {comment}")
    lines.append("},")
    return "\n".join(lines)


def interactive_mode():
    print_header("Conky NextGen — Widget Generator")
    print("  This tool helps you create draw[] and layout[] entries for your")
    print("  lua/36_widget.lua configuration file.")
    print()

    entries = []

    while True:
        c("\033[1;34m--- Add widget ---\033[0m\n")
        print("Select widget type:")
        for i, key in enumerate(WIDGET_ORDER, 1):
            w = WIDGETS[key]
            print(f"  {i:2d}. {w['label']}")
        print(f"  {len(WIDGET_ORDER)+1:2d}. Layout section")
        print(f"  {len(WIDGET_ORDER)+2:2d}. Done / exit")
        print()

        choice = input_str("Number", "1")
        if not choice.isdigit():
            continue
        choice = int(choice)

        if choice == len(WIDGET_ORDER) + 2:
            break

        if choice == len(WIDGET_ORDER) + 1:
            entries.append(add_layout_section())
            continue

        if choice < 1 or choice > len(WIDGET_ORDER):
            continue

        wtype = WIDGET_ORDER[choice - 1]
        wdef = WIDGETS[wtype]
        entries.append(add_widget(wtype, wdef))

    if not entries:
        print("Nothing to generate.")
        return

    print_header("Generated code")
    print()
    output_lines = []
    output_lines.append("-- [[ Generated by Widget Generator ]]")
    output_lines.append("")

    has_draw = any(e["type"] == "draw" for e in entries)
    has_layout = any(e["type"] == "layout" for e in entries)

    if has_draw:
        output_lines.append("draw = {")
        for e in entries:
            if e["type"] == "draw":
                output_lines.append(e["code"])
        output_lines.append("}")
        output_lines.append("")

    if has_layout:
        output_lines.append("layout = {")
        for e in entries:
            if e["type"] == "layout":
                output_lines.append(e["code"])
        output_lines.append("}")
        output_lines.append("")

    result = "\n".join(output_lines)
    c("\033[1;35m")
    print(result)
    c("\033[0m")
    print()

    save = input_str("Append to lua/36_widget.lua? (y/n)", "n")
    if save.lower() in ("y", "yes"):
        path = "lua/36_widget.lua"
        with open(path, "a") as f:
            f.write("\n")
            f.write(result)
            f.write("\n")
        print(f"Appended to: {path}")
    else:
        c("\033[1;33mCopy the code block above to your clipboard.\033[0m\n")


def add_widget(wtype, wdef):
    c(f"\n\033[1;32m  → {wdef['label']}\033[0m\n")
    fields = {}

    c("  draw_me (true / '${var}' / fn_name / function()...end)\n")
    c("  [\033[1mtrue\033[0m]: ")
    first = input().strip()
    if first == "":
        dm = "true"
    elif first.startswith("function"):
        dm = first
        c("    (type function body, empty line = done)\n")
        while True:
            line = input()
            dm += "\n" + line
            if line == "":
                break
        dm = dm.rstrip("\n")
    else:
        dm = first
    if dm != "true":
        fields["draw_me"] = dm

    for key, ftype, label in wdef["required"]:
        val = input_str(f"  {key} ({label})")
        if val:
            if ftype == "string":
                fields[key] = repr(val) if not (val.startswith("'") and val.endswith("'")) else val
            else:
                fields[key] = val

    for key, ftype, default, desc in wdef["optional"]:
        if key == "draw_me":
            continue
        if ftype == "bool":
            val = input_bool(f"  {key} ({desc})", default)
            if val != default:
                fields[key] = val
        elif ftype in ("number", "number/'center'"):
            val = input_number(f"  {key} ({desc})", default)
            if val != default:
                fields[key] = val
        elif ftype == "stops":
            val = input_stops(f"  {key} ({desc})", default)
            if val != default:
                fields[key] = val
        else:
            val = input_str(f"  {key} ({desc})", default)
            if val != default:
                if val.startswith("'") and val.endswith("'"):
                    fields[key] = val
                else:
                    fields[key] = repr(val)

    code = generate_widget_entry(wtype, fields)
    print()
    c("\033[1;30m")
    print(code)
    c("\033[0m")
    print()

    return {"type": "draw", "code": code}


def add_layout_section():
    c(f"\n\033[1;32m  → Layout section\033[0m\n")
    name = input_str("  name (identifier)")
    if not name:
        name = "section"
    height = input_str("  height (px)", "100")
    enabled = input_str("  enabled (condition)", "true")
    comment = input_str("  comment (optional)", "")

    code = generate_layout_entry(name, height, enabled, comment)
    print()
    c("\033[1;30m")
    print(code)
    c("\033[0m")
    print()

    return {"type": "layout", "code": code}


def main():
    parser = argparse.ArgumentParser(
        description="Conky NextGen Widget Generator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent("""\
            Examples:
              python3 sh/widget_gen.py
              python3 sh/widget_gen.py --list
        """),
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List supported widget types",
    )
    args = parser.parse_args()

    if args.list:
        print("Supported widget types:")
        for key in WIDGET_ORDER:
            w = WIDGETS[key]
            print(f"  {key:15s} — {w['label']}")
        print()
        print("Usage: python3 sh/widget_gen.py")
        return

    try:
        interactive_mode()
    except KeyboardInterrupt:
        print()
        c("\033[1;33m\nInterrupted.\033[0m\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
