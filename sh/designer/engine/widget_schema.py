"""PropertySpec metadata for designer widgets.

Headless (no GTK/Qt) — single source of truth for the widget property panel
and Lua generation. Modeled on Conky-Studio's registry.py.

API:
    widgets()          -> ordered list[WidgetSpec]
    widget_types()     -> ordered list[str]
    props_for(wtype)   -> ordered list[PropertySpec] for one widget type
    spec_for(key)      -> shared PropertySpec template for a key (or None)
    defaults_for(wtype)-> {key: default} dict (legacy WIDGET_DEFAULTS)
    field_order()      -> canonical leftover ordering (legacy FIELD_ORDER)
    string_fields()    -> set of keys always coerced to strings
"""

from dataclasses import dataclass


# ── editor kinds ──

class Kind:
    INT = "int"
    FLOAT = "float"
    BOOL = "bool"
    ENUM = "enum"
    STRING = "string"
    TEMPLATE = "template"   # conky template text, e.g. ${cpu}
    FONT = "font"
    PATH = "path"
    COLOR = "color"         # single "#RRGGBB"
    STOPS = "stops"         # gradient stop list [[pos, "#RRGGBB", alpha], ...]
    CODE = "code"
    DRAW_ME = "draw_me"     # conditional draw: true/false / conky template / lua fn


# Kinds whose stored value is always a string (unless string=False).
STRING_KINDS = {Kind.STRING, Kind.TEMPLATE, Kind.FONT, Kind.PATH,
                Kind.COLOR, Kind.ENUM, Kind.CODE}


@dataclass(frozen=True)
class PropertySpec:
    key: str
    label: str
    kind: str
    group: str = ""
    help: str = ""
    default: object = None
    min: float = None
    max: float = None
    step: float = None
    choices: tuple = ()
    choice_labels: tuple = ()
    string: bool = False   # force string coercion (like legacy STRING_FIELDS)


@dataclass(frozen=True)
class WidgetSpec:
    type: str
    label: str
    props: tuple

    def defaults(self):
        return {p.key: p.default for p in self.props if p.default is not None}


# ── section headings ──

G_POSITION = "Position"
G_SIZE = "Size"
G_VALUE = "Value"
G_TEXT = "Text"
G_CONTENT = "Content"
G_APPEARANCE = "Appearance"
G_COLORS = "Colors"
G_BEHAVIOR = "Behavior"


def _f(key, label, kind, group="", help="", **kw):
    return PropertySpec(key=key, label=label, kind=kind, group=group,
                        help=help, **kw)


# ── shared field templates (kind/label/group/help; default set per type) ──

FIELD_TEMPLATES = {
    "view": _f("view", "View(s)", Kind.STRING, G_BEHAVIOR,
               "Comma-separated view names this widget belongs to.",
               string=True),
    "group": _f("group", "Group", Kind.STRING, G_BEHAVIOR,
                "Item group name (view switching).", string=True),
    "click": _f("click", "Click action", Kind.STRING, G_BEHAVIOR,
                "Mouse action on click, e.g. MOUSE_CLICK_LEFT.",
                string=True),
    "click_view": _f("click_view", "Click view", Kind.STRING, G_BEHAVIOR,
                     "View to switch to on click.", string=True),
    "draw_me": _f("draw_me", "Draw if", Kind.DRAW_ME, G_BEHAVIOR,
                  "Conditional drawing: true/false, Conky template (${...}), "
                  "or a Lua function/expression ending in () — draws only "
                  "when it evaluates to 1/true.", string=True),

    "x": _f("x", "X", Kind.INT, G_POSITION, "Horizontal position (px).", min=0),
    "y": _f("y", "Y", Kind.INT, G_POSITION, "Vertical position (px).", min=0),
    "x1": _f("x1", "X1", Kind.INT, G_POSITION, "Start point X (px)."),
    "y1": _f("y1", "Y1", Kind.INT, G_POSITION, "Start point Y (px)."),
    "x2": _f("x2", "X2", Kind.INT, G_POSITION, "End point X (px)."),
    "y2": _f("y2", "Y2", Kind.INT, G_POSITION, "End point Y (px)."),

    "w": _f("w", "Width", Kind.INT, G_SIZE, "Width (px).", min=0),
    "h": _f("h", "Height", Kind.INT, G_SIZE, "Height (px).", min=0),
    "width": _f("width", "Width", Kind.INT, G_SIZE, "Width (px).", min=0),
    "height": _f("height", "Height", Kind.INT, G_SIZE, "Height (px).", min=0),
    "radius": _f("radius", "Radius", Kind.INT, G_SIZE, "Corner / ring radius (px).", min=0),
    "thickness": _f("thickness", "Thickness", Kind.INT, G_SIZE, "Line / ring thickness (px).", min=0),
    "border_width": _f("border_width", "Border width", Kind.INT, G_SIZE, "Border width (px).", min=0),
    "line_width": _f("line_width", "Line width", Kind.INT, G_SIZE, "Graph line width (px).", min=0),
    "wrap_width": _f("wrap_width", "Wrap width", Kind.INT, G_SIZE,
                     "Text wrap width in px (nil = no wrap).", min=0),
    "wrap_dic": _f("wrap_dic", "Hyphenation dict", Kind.PATH, G_TEXT,
                   "Hyphenation dictionary (.dic path) for word wrapping.",
                   string=True),
    "cell_w": _f("cell_w", "Cell width", Kind.INT, G_SIZE, "Calendar cell width (px).", min=0),
    "row_h": _f("row_h", "Row height", Kind.INT, G_SIZE, "Calendar row height (px).", min=0),
    "tick_width_hour": _f("tick_width_hour", "Tick width (hour)", Kind.INT, G_APPEARANCE, "Hour tick width (px).", min=0),
    "tick_width_minute": _f("tick_width_minute", "Tick width (min)", Kind.INT, G_APPEARANCE, "Minute tick width (px).", min=0),
    "number_size": _f("number_size", "Number size", Kind.INT, G_TEXT, "Clock number size (px).", min=0),
    "number_radius": _f("number_radius", "Number radius", Kind.FLOAT, G_TEXT,
                        "Clock number ring radius (fraction of clock radius).", min=0, max=1, step=0.05),
    "hour_hand_width": _f("hour_hand_width", "Hour hand width", Kind.INT, G_APPEARANCE, "Hour hand width (px).", min=0),
    "minute_hand_width": _f("minute_hand_width", "Minute hand width", Kind.INT, G_APPEARANCE, "Minute hand width (px).", min=0),
    "second_hand_width": _f("second_hand_width", "Second hand width", Kind.INT, G_APPEARANCE, "Second hand width (px).", min=0),
    "center_radius": _f("center_radius", "Center radius", Kind.INT, G_APPEARANCE, "Clock center dot radius (px).", min=0),

    "font": _f("font", "Font", Kind.FONT, G_TEXT, "Font family name.", string=True),
    "path": _f("path", "Path", Kind.PATH, G_CONTENT,
               "File path to the image / SVG.", string=True),
    "size": _f("size", "Size", Kind.INT, G_TEXT, "Font size (px).", min=0),
    "weight": _f("weight", "Weight", Kind.ENUM, G_TEXT, "Font weight.",
                 choices=("normal", "bold"), choice_labels=("Normal", "Bold"),
                 string=True),
    "slant": _f("slant", "Slant", Kind.ENUM, G_TEXT, "Font slant.",
                choices=("normal", "italic"), choice_labels=("Normal", "Italic"),
                string=True),
    "align": _f("align", "Align", Kind.ENUM, G_TEXT, "Text alignment.",
                choices=("left", "center", "right"),
                choice_labels=("Left", "Center", "Right"), string=True),

    "text": _f("text", "Text", Kind.TEMPLATE, G_CONTENT,
               "Text / conky template, e.g. ${cpu}.", string=True),
    "value": _f("value", "Value", Kind.TEMPLATE, G_VALUE,
                "Conky template, e.g. ${cpu} ${mem}.", string=True),
    "max": _f("max", "Max", Kind.INT, G_VALUE, "Scale maximum.", min=1),
    "autoscale": _f("autoscale", "Autoscale", Kind.BOOL, G_VALUE,
                    "Scale to data max instead of fixed max."),
    "angle": _f("angle", "Angle", Kind.FLOAT, G_VALUE, "Rotation angle (degrees).", step=1),
    "key": _f("key", "Key", Kind.STRING, G_VALUE,
              "Graph data key (stacked graphs).", string=True),

    "mode": _f("mode", "Mode", Kind.ENUM, G_APPEARANCE,
               "Rendering mode.",
               choices=("ring", "smooth", "dot", "polygon"),
               choice_labels=("Ring", "Smooth", "Dot", "Polygon"),
               string=True),
    "blocks": _f("blocks", "Blocks", Kind.INT, G_APPEARANCE,
                 "Number of blocks (block/dot/polygon modes).", min=2),
    "blocks_width": _f("blocks_width", "Block width", Kind.INT, G_APPEARANCE,
                       "Block width in px (default = bar height).", min=1),
    "sides": _f("sides", "Sides", Kind.INT, G_APPEARANCE,
                "Polygon side count (>= 3).", min=3),
    "graph_type": _f("graph_type", "Graph type", Kind.ENUM, G_APPEARANCE,
                     "Graph rendering style.",
                     choices=("line", "fill"), choice_labels=("Line", "Fill"),
                     string=True),
    "grid": _f("grid", "Grid", Kind.BOOL, G_APPEARANCE, "Show graph grid."),
    "grid_steps": _f("grid_steps", "Grid steps", Kind.INT, G_APPEARANCE,
                     "Number of grid divisions.", min=1),
    "sectors": _f("sectors", "Sectors", Kind.INT, G_APPEARANCE,
                  "Number of ring segments.", min=1),
    "start_angle": _f("start_angle", "Start angle", Kind.FLOAT, G_APPEARANCE,
                      "Ring start angle (degrees).", step=1),
    "end_angle": _f("end_angle", "End angle", Kind.FLOAT, G_APPEARANCE,
                    "Ring end angle (degrees).", step=1),
    "sector_size": _f("sector_size", "Sector size", Kind.FLOAT, G_APPEARANCE,
                      "Sector size in degrees (auto when unset).", min=0, step=1),
    "style_type": _f("style_type", "Style", Kind.ENUM, G_APPEARANCE,
                     "Line style.",
                     choices=("solid", "dashed", "dotted"),
                     choice_labels=("Solid", "Dashed", "Dotted"), string=True),
    "dash": _f("dash", "Dash", Kind.FLOAT, G_APPEARANCE, "Dash length (px).", min=0, step=1),
    "dash_on": _f("dash_on", "Dash on", Kind.INT, G_APPEARANCE, "Dash on length (px).", min=0),
    "dash_off": _f("dash_off", "Dash off", Kind.INT, G_APPEARANCE, "Dash off length (px).", min=0),
    "dot_on": _f("dot_on", "Dot on", Kind.INT, G_APPEARANCE, "Dot on length (px).", min=0),
    "dot_off": _f("dot_off", "Dot off", Kind.INT, G_APPEARANCE, "Dot off length (px).", min=0),

    "scale_mode": _f("scale_mode", "Scale mode", Kind.ENUM, G_APPEARANCE,
                     "Image scaling filter.",
                     choices=("bilinear", "nearest", "good"),
                     choice_labels=("Bilinear", "Nearest", "Good"), string=True),
    "shape": _f("shape", "Shape", Kind.STRING, G_APPEARANCE,
                "Clip shape, e.g. \"circle\".", string=True),
    "rotate": _f("rotate", "Rotate", Kind.FLOAT, G_APPEARANCE,
                 "Rotation angle (degrees).", step=1),
    "crop": _f("crop", "Crop", Kind.STRING, G_APPEARANCE,
               "Crop rect as { x, y, w, h }."),
    "alpha": _f("alpha", "Alpha", Kind.FLOAT, G_APPEARANCE,
                "Opacity 0..1.", min=0, max=1, step=0.05),
    "tint": _f("tint", "Tint", Kind.COLOR, G_APPEARANCE, "Tint color #RRGGBB."),
    "tint_alpha": _f("tint_alpha", "Tint alpha", Kind.FLOAT, G_APPEARANCE,
                     "Tint opacity 0..1.", min=0, max=1, step=0.05),

    "show_ticks": _f("show_ticks", "Show ticks", Kind.BOOL, G_APPEARANCE, "Draw clock ticks."),
    "show_numbers": _f("show_numbers", "Show numbers", Kind.BOOL, G_APPEARANCE, "Draw clock numbers."),
    "show_seconds": _f("show_seconds", "Show seconds", Kind.BOOL, G_APPEARANCE, "Draw second hand."),
    "show_weeknums": _f("show_weeknums", "Show week numbers", Kind.BOOL, G_APPEARANCE,
                        "Show calendar week number column."),

    "fg": _f("fg", "Foreground", Kind.STOPS, G_COLORS, "Gradient stops."),
    "bg": _f("bg", "Background", Kind.STOPS, G_COLORS, "Gradient stops."),
    "border": _f("border", "Border", Kind.STOPS, G_COLORS, "Gradient stops."),
    "color": _f("color", "Color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "grid_color": _f("grid_color", "Grid color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "alarm_color": _f("alarm_color", "Alarm color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "alarm_alpha": _f("alarm_alpha", "Alarm alpha", Kind.FLOAT, G_COLORS,
                      "Alarm color opacity 0..1.", min=0, max=1, step=0.05),
    "tick_color": _f("tick_color", "Tick color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "number_color": _f("number_color", "Number color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "hour_color": _f("hour_color", "Hour color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "minute_color": _f("minute_color", "Minute color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "second_color": _f("second_color", "Second color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "center_color": _f("center_color", "Center color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "color_month": _f("color_month", "Month color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "color_weekdays": _f("color_weekdays", "Weekday color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "color_days": _f("color_days", "Day color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "color_today": _f("color_today", "Today color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "color_outside": _f("color_outside", "Outside color", Kind.STOPS, G_COLORS, "Gradient stops."),
    "color_weeknums": _f("color_weeknums", "Week number color", Kind.STOPS, G_COLORS, "Gradient stops."),
}


# ── per-type property lists (ordered; same as legacy WIDGET_TYPE_FIELDS) ──

TYPE_PROPS = {
    "background": ["view", "group", "draw_me", "x", "y", "w", "h", "radius", "border_width",
                   "bg", "border", "click", "click_view"],
    "text":       ["view", "group", "draw_me", "x", "y", "font", "size", "slant", "weight", "align",
                   "text", "color", "wrap_width", "wrap_dic",
                   "click", "click_view"],
    "bar":        ["view", "group", "draw_me", "x", "y", "width", "height", "value", "max", "angle",
                   "mode", "blocks", "blocks_width", "sides", "fg", "bg",
                   "click", "click_view"],
    "graph":      ["view", "group", "draw_me", "x", "y", "width", "height", "value", "max", "autoscale",
                   "angle", "key", "graph_type", "line_width", "border_width", "grid",
                   "grid_steps", "fg", "bg", "border", "grid_color",
                   "click", "click_view"],
    "ring":       ["view", "group", "draw_me", "x", "y", "radius", "thickness", "value", "max",
                   "sectors", "mode", "sides", "start_angle", "end_angle",
                   "sector_size", "alarm_color", "alarm_alpha", "fg", "bg",
                   "click", "click_view"],
    "line":       ["view", "group", "draw_me", "x1", "y1", "x2", "y2", "thickness",
                   "style_type", "dash", "dash_on", "dash_off", "dot_on",
                   "dot_off", "fg", "click", "click_view"],
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

# ── per-type defaults (legacy WIDGET_DEFAULTS) ──

TYPE_DEFAULTS = {
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

# ── widget type display labels ──

TYPE_LABELS = {
    "background": "Background",
    "text": "Text",
    "bar": "Bar",
    "graph": "Graph",
    "ring": "Ring",
    "line": "Line",
    "clock": "Clock",
    "calendar": "Calendar",
    "image": "Image",
    "svg": "SVG",
}

# ── legacy canonical ordering for leftover/extra fields ──

FIELD_ORDER = ["view", "group", "draw_me", "x", "y", "x1", "y1", "x2", "y2", "w", "h", "width",
               "height", "radius", "thickness", "size", "font", "weight",
               "max", "value", "text", "fg", "bg", "border", "border_width",
               "dash", "style_type", "path", "click", "click_view"]

# ── per-type field overrides (shared templates with type-specific choices) ──

TYPE_OVERRIDES = {
    "bar": {
        "mode": _f("mode", "Mode", Kind.ENUM, G_APPEARANCE,
                   "Bar rendering mode.",
                   choices=("smooth", "block", "dot", "polygon"),
                   choice_labels=("Smooth", "Block", "Dot", "Polygon"),
                   string=True),
    },
}


def _build_specs():
    from dataclasses import replace
    result = {}
    for wtype, keys in TYPE_PROPS.items():
        defs = TYPE_DEFAULTS.get(wtype, {})
        overrides = TYPE_OVERRIDES.get(wtype, {})
        props = tuple(
            replace(overrides.get(k, FIELD_TEMPLATES[k]), default=defs.get(k))
            for k in keys)
        result[wtype] = WidgetSpec(type=wtype, label=TYPE_LABELS.get(wtype, wtype),
                                   props=props)
    return result


WIDGET_SPECS = _build_specs()


# ── public API ──

def widgets():
    return [WIDGET_SPECS[t] for t in TYPE_PROPS]

def widget_types():
    return list(TYPE_PROPS)

def props_for(wtype):
    spec = WIDGET_SPECS.get(wtype)
    return list(spec.props) if spec else []

def spec_for(key):
    return FIELD_TEMPLATES.get(key)

def defaults_for(wtype):
    spec = WIDGET_SPECS.get(wtype)
    return dict(spec.defaults()) if spec else {}

def field_order():
    order = list(FIELD_ORDER)
    seen = set(order)
    for wtype in TYPE_PROPS:
        for key in TYPE_PROPS[wtype]:
            if key not in seen:
                seen.add(key)
                order.append(key)
    return order

def string_fields():
    return frozenset(k for k, t in FIELD_TEMPLATES.items() if t.string)
