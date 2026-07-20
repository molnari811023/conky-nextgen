#!/usr/bin/env python3
"""Widget Generator for Conky NextGen — interactive CLI tool

Usage:
  python3 sh/widget_gen.py          interactive mode
  python3 sh/widget_gen.py --help   help
  python3 sh/widget_gen.py --list   list widget types
"""

import argparse
import sys
import textwrap

WIDGETS = {
    "background": {
        "label": "Background (rounded rect)",
        "required": [],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter (string)"),
            ("group", "string", "nil", "Group toggle name"),
            ("x", "number", "0", "Left position"),
            ("y", "number", "0", "Top position"),
            ("w", "number", "0", "Width (0 = full window)"),
            ("h", "number", "0", "Height (0 = full window)"),
            ("radius", "number", "20", "Corner radius (px)"),
            ("bg", "stops", "{{1,'#141618',1}}", "Background gradient"),
            ("border", "stops", "{{1,'#4c4e51',1}}", "Border gradient"),
            ("border_width", "number", "2", "Border width (0 = none)"),
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
            ("scroll_up_action", "string", "nil", "Scroll up action (e.g. 'scroll:up')"),
            ("scroll_down_action", "string", "nil", "Scroll down action"),
        ],
    },
    "text": {
        "label": "Text",
        "required": [("text", "string", "Text or Conky template (${...})")],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter"),
            ("group", "string", "nil", "Group toggle name"),
            ("click", "string", "nil", "Shell command on click"),
            ("x", "number/'center'", "0", "X position or 'center'"),
            ("y", "number/'center'", "0", "Y position or 'center'"),
            ("w", "number", "0", "Width"),
            ("h", "number", "0", "Height"),
            ("font", "string", "'Sans'", "Font family"),
            ("size", "number", "14", "Font size (px)"),
            ("slant", "string", "'normal'", "Slant: normal/italic"),
            ("weight", "string", "'normal'", "Weight: normal/bold"),
            ("align", "string", "'left'", "Align: left/center/right"),
            ("color", "stops", "{{0,0xFFFFFF,1},{1,0xCCCCCC,1}}", "Color gradient"),
            ("wrap_width", "number", "nil", "Wrap width (px)"),
            ("wrap_dic", "string", "nil", "Hyphenation dict path"),
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
            ("scroll_up_action", "string", "nil", "Scroll up action"),
            ("scroll_down_action", "string", "nil", "Scroll down action"),
        ],
    },
    "bar": {
        "label": "Bar (progress bar)",
        "required": [],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter"),
            ("group", "string", "nil", "Group toggle name"),
            ("click", "string", "nil", "Shell command on click"),
            ("click_view", "string", "nil", "Switch to view name"),
            ("click_toggle", "string", "nil", "Toggle group name"),
            ("clipboard", "string/func", "nil", "Text to copy on click"),
            ("name", "string", "nil", "Conky variable (e.g. cpu, memperc)"),
            ("arg", "string", "nil", "Variable argument (e.g. cpu1)"),
            ("value", "number", "nil", "Static value (alters name+arg)"),
            ("x", "number", "0", "Left position"),
            ("y", "number", "0", "Top position"),
            ("w", "number", "100", "Bar width (px)"),
            ("h", "number", "10", "Bar height (px)"),
            ("max", "number", "100", "Maximum value"),
            ("angle", "number", "0", "Rotation (degrees)"),
            ("blocks", "number", "nil", "Block style (nil = smooth)"),
            ("mode", "string", "'block'", "Block mode: block/dot"),
            ("sides", "number", "nil", "Polygon sides"),
            ("radius", "number", "nil", "Corner radius"),
            ("bg_color", "stops", "{{0,'#333333',1},{1,'#111111',1}}", "Background gradient"),
            ("fg_color", "stops", "{{0,'#00ff00',1},{1,'#009900',1}}", "Foreground gradient"),
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
        ],
    },
    "graph": {
        "label": "Graph (time-series)",
        "required": [],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter"),
            ("group", "string", "nil", "Group toggle name"),
            ("click", "string", "nil", "Shell command on click"),
            ("click_view", "string", "nil", "Switch to view name"),
            ("click_toggle", "string", "nil", "Toggle group name"),
            ("name", "string", "nil", "Conky variable (e.g. cpu, downspeed)"),
            ("arg", "string", "nil", "Variable argument"),
            ("value", "number", "nil", "Static value (alters name+arg)"),
            ("x", "number", "0", "Left position"),
            ("y", "number", "0", "Top position"),
            ("w", "number", "100", "Graph width (px)"),
            ("h", "number", "40", "Graph height (px)"),
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
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
        ],
    },
    "clock": {
        "label": "Analog clock",
        "required": [],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter"),
            ("group", "string", "nil", "Group toggle name"),
            ("click", "string", "nil", "Shell command on click"),
            ("click_view", "string", "nil", "Switch to view name"),
            ("click_toggle", "string", "nil", "Toggle group name"),
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
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
        ],
    },
    "ring": {
        "label": "Ring (gauge)",
        "required": [],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter"),
            ("group", "string", "nil", "Group toggle name"),
            ("click", "string", "nil", "Shell command on click"),
            ("click_view", "string", "nil", "Switch to view name"),
            ("click_toggle", "string", "nil", "Toggle group name"),
            ("name", "string", "nil", "Conky variable (e.g. cpu, memperc)"),
            ("arg", "string", "nil", "Variable argument"),
            ("value", "number", "nil", "Static value (alters name+arg)"),
            ("x", "number", "100", "Center X"),
            ("y", "number", "100", "Center Y"),
            ("radius", "number", "50", "Ring radius"),
            ("thickness", "number", "6", "Ring thickness (px)"),
            ("start_angle", "number", "0", "Start angle (degrees)"),
            ("end_angle", "number", "360", "End angle (degrees)"),
            ("sectors", "number", "6", "Number of segments"),
            ("mode", "string", "'ring'", "Mode: ring/smooth"),
            ("sector_size", "number", "nil", "Auto-calculate gap (degree per sector)"),
            ("max", "number", "100", "Maximum value"),
            ("bg", "stops", "{{0,'#333333',1},{1,'#111111',1}}", "Background gradient"),
            ("fg", "stops", "{{0,'#00ffaa',1},{1,'#008866',1}}", "Foreground gradient"),
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
        ],
    },
    "line": {
        "label": "Line",
        "required": [],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter"),
            ("group", "string", "nil", "Group toggle name"),
            ("click", "string", "nil", "Shell command on click"),
            ("click_view", "string", "nil", "Switch to view name"),
            ("click_toggle", "string", "nil", "Toggle group name"),
            ("x1", "number", "0", "Start X"),
            ("y1", "number", "0", "Start Y"),
            ("x2", "number", "100", "End X"),
            ("y2", "number", "0", "End Y"),
            ("thickness", "number", "2", "Line thickness (px)"),
            ("angle", "number", "0", "Rotation (degrees)"),
            ("style_type", "string", "'solid'", "Style: solid/dashed/dotted"),
            ("dash_on", "number", "nil", "Dash length (dashed)"),
            ("dash_off", "number", "nil", "Gap length (dashed)"),
            ("fg", "stops", "{{0,0xFFFFFF,1},{1,0xAAAAAA,1}}", "Line color gradient"),
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
        ],
    },
    "calendar": {
        "label": "Calendar",
        "required": [],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter"),
            ("group", "string", "nil", "Group toggle name"),
            ("click", "string", "nil", "Shell command on click"),
            ("click_view", "string", "nil", "Switch to view name"),
            ("click_toggle", "string", "nil", "Toggle group name"),
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
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
        ],
    },
    "image": {
        "label": "Image (PNG)",
        "required": [
            ("path", "string", "PNG file path"),
        ],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter"),
            ("group", "string", "nil", "Group toggle name"),
            ("click", "string", "nil", "Shell command on click"),
            ("click_view", "string", "nil", "Switch to view name"),
            ("click_toggle", "string", "nil", "Toggle group name"),
            ("x", "number", "0", "Left position"),
            ("y", "number", "0", "Top position"),
            ("w", "number", "nil", "Output width (auto if only h set)"),
            ("h", "number", "nil", "Output height (auto if only w set)"),
            ("alpha", "number", "1", "Opacity (0-1)"),
            ("tint", "string", "nil", "Hex tint (#rrggbb)"),
            ("rotate", "number", "0", "Rotation (degrees)"),
            ("radius", "number", "0", "Corner radius"),
            ("shape", "string", "nil", "Clip shape: nil/circle"),
            ("scale_mode", "string", "'bilinear'", "Scale filter: bilinear/nearest/good"),
            ("crop", "string", "nil", "Crop table: {x=0,y=0,w=100,h=100}"),
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
        ],
    },
    "svg": {
        "label": "SVG (vector icon via librsvg)",
        "required": [("path", "string", "SVG file path")],
        "optional": [
            ("id", "string", "nil", "Unique identifier"),
            ("view", "string", "nil", "View filter (string)"),
            ("group", "string", "nil", "Group toggle name"),
            ("x", "number", "0", "X position"),
            ("y", "number", "0", "Y position"),
            ("w", "number", "32", "Width (auto aspect if only w)"),
            ("h", "number", "32", "Height (auto aspect if only h)"),
            ("rotate", "number", "0", "Rotation (degrees)"),
            ("shape", "string", "nil", "Clip shape: nil/circle"),
            ("radius", "number", "0", "Corner radius clip"),
            ("alpha", "number", "1", "Opacity (0-1, uses temp surface)"),
            ("tint", "string", "nil", "Hex tint (#rrggbb, uses temp surface)"),
            ("tint_alpha", "number", "1", "Tint opacity (0-1)"),
            ("click", "string", "nil", "Shell command on click"),
            ("click_view", "string", "nil", "Switch to view name"),
            ("click_toggle", "string", "nil", "Toggle group name"),
            ("clipboard", "string/func", "nil", "Text to copy on click"),
            ("mouse_hover_view", "string", "nil", "Switch to view on hover"),
            ("mouse_hover_toggle", "string", "nil", "Expand group on hover"),
            ("target_group", "string", "nil", "Target group for context menu"),
            ("layout_box", "string", "nil", "Layout section name"),
            ("collapse", "bool", "false", "Hidden when group collapsed"),
            ("fixed", "bool", "false", "Not affected by scroll"),
            ("z_index", "number", "nil", "Layer order (higher = on top)"),
        ],
    },
}

WIDGET_ORDER = [
    "background", "text", "bar", "graph", "clock",
    "ring", "line", "calendar", "image", "svg",
]

LAYOUT_FIELDS = [
    ("name", "string", "Section identifier"),
    ("height", "number", "Section height (px)"),
    ("group", "string", "Group name (for collapse)"),
    ("header_height", "number", "Header height (px)"),
    ("draggable", "bool", "Can be dragged to rearrange"),
    ("draw_me", "bool/string/func", "Condition"),
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
        lines.append(indent_value(f"{key} = {val},"))
    lines.append("},")
    return "\n".join(lines)


def generate_layout_entry(fields):
    lines = ["{"]
    for key, val in fields.items():
        lines.append(indent_value(f"{key} = {val},"))
    lines.append("},")
    return "\n".join(lines)


def interactive_mode():
    print_header("Conky NextGen — Widget Generator")
    print("  This tool helps you create draw[] and layout[] entries for your")
    print("  lua/widget.lua configuration file.")
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
        output_lines.append("raw_elements = {")
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

    save = input_str("Append to lua/widget.lua? (y/n)", "n")
    if save.lower() in ("y", "yes"):
        path = "lua/widget.lua"
        try:
            with open(path, "a") as f:
                f.write("\n")
                f.write(result)
                f.write("\n")
            print(f"Appended to: {path}")
        except FileNotFoundError:
            c(f"\033[1;31mFile not found: {path}\033[0m\n")
            c("\033[1;33mCopy the code block above to your clipboard.\033[0m\n")
    else:
        c("\033[1;33mCopy the code block above to your clipboard.\033[0m\n")


def add_widget(wtype, wdef):
    c(f"\n\033[1;32m  \u2192 {wdef['label']}\033[0m\n")
    fields = {}

    for key, ftype, label in wdef["required"]:
        val = input_str(f"  {key} ({label})")
        if val:
            if ftype == "string":
                fields[key] = repr(val) if not (val.startswith("'") and val.endswith("'")) else val
            else:
                fields[key] = val

    for key, ftype, default, desc in wdef["optional"]:
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
    c(f"\n\033[1;32m  \u2192 Layout section\033[0m\n")
    fields = {}

    for key, ftype, desc in LAYOUT_FIELDS:
        default = None
        if key == "height":
            default = "100"
        elif key == "draggable":
            default = "false"
        elif key == "draw_me":
            default = "true"

        if ftype == "bool":
            val = input_bool(f"  {key} ({desc})", default or "false")
            if val != (default or "false"):
                fields[key] = val
        elif ftype == "number":
            val = input_number(f"  {key} ({desc})", default)
            if val != default:
                fields[key] = val
        elif ftype == "bool/string/func":
            val = input_str(f"  {key} ({desc})", default)
            if val != default:
                fields[key] = val
        else:
            val = input_str(f"  {key} ({desc})", default)
            if val and val != default:
                fields[key] = repr(val) if not val.startswith("'") else val

    if "name" not in fields:
        fields["name"] = repr("section")

    code = generate_layout_entry(fields)
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
            print(f"  {key:15s} \u2014 {w['label']}")
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
