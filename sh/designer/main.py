#!/usr/bin/env python3
"""
NextGen Designer — GTK3 visual editor for widget.lua.

Features:
  - File > New (empty widget.lua)
  - Item list sorted by group, filtered by current view
  - Groups tab
  - Views tab
  - Property editor (Enter to save)
  - Add/Delete items
  - Auto-reload PNG on save

Target directory (conky-nextgen root with widget.lua + lua/) is resolved by
_find_conky_dir(): --conky-dir flag > CONKY_NEXTGEN_DIR env var >
~/.config/conky-designer.conf (conky_dir = /path) > in-tree layout.
"""

import sys
import os
import re
import json
import html
import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
import shutil
import signal
import subprocess
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Clear __pycache__ at startup
_here = os.path.dirname(os.path.abspath(__file__))
for _root, _dirs, _files in os.walk(_here):
    if "__pycache__" in _dirs:
        shutil.rmtree(os.path.join(_root, "__pycache__"), ignore_errors=True)

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("GtkSource", "3.0")
from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, GObject, Pango, GtkSource

GLib.set_prgname("nextgen-designer")

try:
    from PIL import Image as _PILImage
    _PIL_OK = True
except Exception:
    _PILImage = None
    _PIL_OK = False

from engine.lua_parser import parse_widget_lua, parse_settings, parse_gradient_stops, parse_lua_table_content, RawLua, RawBlock
from engine import activity_log
from engine import gradient_gen as gg
from engine import theme_writer as tw
from engine import lua_data
import engine.theme_engine as te
from engine.widget_schema import (
    Kind, PropertySpec, WidgetSpec, WIDGET_SPECS,
    widget_types, props_for, spec_for, defaults_for, field_order,
    string_fields,
)

def _find_conky_dir():
    """Resolve the conky-nextgen root directory.

    Priority:
      1. --conky-dir <path> CLI flag
      2. CONKY_NEXTGEN_DIR environment variable
      3. conky_dir = <path> in ~/.config/conky-designer.conf
      4. default: in-tree layout (this file is sh/designer/main.py)

    This lets the designer live anywhere and point at a conky-nextgen
    checkout, instead of being tied to the ../.. layout.
    """
    # 1. CLI flag
    if "--conky-dir" in sys.argv:
        i = sys.argv.index("--conky-dir")
        if i + 1 < len(sys.argv):
            return os.path.abspath(sys.argv[i + 1])

    # 2. Environment variable
    env = os.environ.get("CONKY_NEXTGEN_DIR")
    if env:
        return os.path.abspath(env)

    # 3. Config file: ~/.config/conky-designer.conf  (conky_dir = /path)
    cfg = os.path.expanduser("~/.config/conky-designer.conf")
    if os.path.exists(cfg):
        try:
            with open(cfg) as f:
                for line in f:
                    m = re.match(r"\s*conky_dir\s*=\s*[\"']?([^\"'\s]+)", line)
                    if m:
                        return os.path.abspath(m.group(1))
        except OSError:
            pass

    # 4. Default: in-tree layout (sh/designer -> 3 levels up)
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


STATE_FILE = os.path.expanduser("~/.config/conky-designer-state.json")


def _load_window_state():
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def _save_window_state(win):
    win_win = win.get_window()
    maximized = bool(
        win_win is not None
        and (win_win.get_state() & Gdk.WindowState.MAXIMIZED)
    )
    state = {"maximized": maximized}
    if not maximized:
        w, h = win.get_size()
        state["width"] = w
        state["height"] = h
    try:
        with open(STATE_FILE, "w") as f:
            json.dump(state, f)
    except OSError:
        pass


CONKY_DIR = _find_conky_dir()
WIDGET_LUA = os.path.join(CONKY_DIR, "widget.lua")
MAIN_LUA = os.path.join(CONKY_DIR, "main.lua")  # legacy fallback
ICON_PATH = next(
    (p for p in (
        os.path.join(CONKY_DIR, "nd.svg"),
        os.path.join(_here, "icons", "conky_128.png"),
    ) if os.path.exists(p)),
    None,
)

# Single-theme designer: exactly one theme, always named "theme".
THEME_NAME = "theme"

# Unique per-instance work dir (conky.log + scratch)
WORK_DIR = tempfile.mkdtemp(prefix="conky_designer_")

# Preview helper: the designer appends to the PREVIEW conky's lua_load (see
# _preview_conf). Kept out of the framework: the deployed .conf never
# references it, so the desktop widget runs without the ghost-clear.
LIVE_CLEAR_LUA = os.path.join(_here, "live_clear.lua")

# Restart helper: always sends SIGUSR1 for a clean reload (X11 + Wayland).


# Help menu: generated manuals land in /tmp, never inside the conky tree.
HELP_DIR = os.path.join(tempfile.gettempdir(), "conky-designer-help")
CONKY_MAN_GZ = "/usr/share/man/man1/conky.1.gz"
CONKY_MANUAL_HTML = os.path.join(HELP_DIR, "conky-manual.html")
NEXTGEN_MD = os.path.join(CONKY_DIR, "NextGen.md")
NEXTGEN_HANDBOOK_HTML = os.path.join(HELP_DIR, "nextgen-handbook.html")


def _clamp_size(w, h):
    """Clamp a window size to the workarea of the monitor under the cursor
    (falls back to the primary monitor) so it never exceeds the screen."""
    try:
        disp = Gdk.Display.get_default()
        if disp is None:
            return w, h
        try:
            ptr = disp.get_pointer()  # (screen, x, y, mask) or (screen, x, y)
            x, y = ptr[1], ptr[2]
            mon = disp.get_monitor_at_point(x, y)
        except Exception:
            mon = disp.get_primary_monitor()
        if mon is None:
            return w, h
        wa = mon.get_workarea()
        w = min(int(w), max(int(wa.width), 320))
        h = min(int(h), max(int(wa.height), 240))
    except Exception:
        pass
    return w, h


def _item_summary(item, max_len=28):
    """Short human-readable hint for the items list (e.g. the text content
    for a text widget, the value expression for bar/ring/graph)."""
    t = item.get("type", "")
    if t == "text":
        raw = str(item.get("text", ""))
    elif t in ("bar", "ring", "graph"):
        raw = str(item.get("value", ""))
    elif t in ("image", "svg"):
        raw = os.path.basename(str(item.get("path", "")))
    elif t == "background":
        w = item.get("w", 0) or 0
        h = item.get("h", 0) or 0
        raw = f"{w}x{h}" if w and h else "full"
    elif t == "line":
        raw = f"{item.get('x1', 0)},{item.get('y1', 0)} → {item.get('x2', 0)},{item.get('y2', 0)}"
    else:
        raw = ""
    raw = raw.strip().replace("\n", " ")
    return raw if len(raw) <= max_len else raw[: max_len - 1] + "…"


def _lua_escape(s):
    """Escape a string for safe inclusion in a Lua double-quoted literal."""
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def _infer_item_height(item):
    """Rough height heuristic for stacking newly added widgets (local stand-in
    for the old renderer-based estimate in engine/cairo_draw.py)."""
    t = item.get("type", "")
    h = item.get("h")
    if isinstance(h, (int, float)) and h > 0:
        return h
    if t == "text":
        try:
            return int(item.get("size") or 12) * 2 + 4
        except (TypeError, ValueError):
            return 40
    if t == "clock":
        try:
            return int(item.get("radius") or 60) + 10
        except (TypeError, ValueError):
            return 70
    if t == "ring":
        try:
            return int(item.get("radius") or 50) + 10
        except (TypeError, ValueError):
            return 60
    if t == "bar":
        try:
            return int(item.get("height") or 12) + 6
        except (TypeError, ValueError):
            return 18
    if t == "graph":
        try:
            return int(item.get("height") or 40) + 6
        except (TypeError, ValueError):
            return 46
    if t == "calendar":
        try:
            return int(item.get("row_h") or 20) * 9 + 30
        except (TypeError, ValueError):
            return 210
    if t == "line":
        return 10
    if t == "background":
        return 0
    return 40

WIDGET_CONFIG_BLOCK = r'''------------------------------------------------------------
-- Global paths / config (formerly settings.lua)
-- script_dir is widget.lua's own directory (the project root)
------------------------------------------------------------
script_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"

package.path = package.path
    .. ";" .. script_dir .. "lua/?.lua"
    .. ";" .. script_dir .. "lua/core/?.lua"
    .. ";" .. script_dir .. "lua/draw/?.lua"
    .. ";" .. script_dir .. "lua/weather/?.lua"
    .. ";" .. script_dir .. "lua/hardware/?.lua"

-- JSON_PATH is always needed (weather, hardware/network, nowplaying data)
JSON_PATH      = script_dir .. "tmp/"

draw = {}

'''

WEATHER_ICON_SETS = ["default", "metno", "weathermap", "wmo"]


def weather_icon_block(icon_theme):
    """The weather-only icon path globals (emitted only when weather is on)."""
    return (
        "ICON_BASE      = script_dir .. \"icons/\"\n"
        f'ICON_THEME     = "{icon_theme or "default"}"\n'
        "MOON_ICON_BASE = script_dir .. \"icons/moon/\"\n"
        "WIND_ICON_BASE = script_dir .. \"icons/wind/\"\n"
    )


def _installed_icon_themes():
    """Scan the standard XDG icon dirs for installed icon themes."""
    themes = []
    bases = [
        os.path.expanduser("~/.local/share/icons"),
        os.path.expanduser("~/.icons"),
        "/usr/local/share/icons",
        "/usr/share/icons",
    ]
    for base in bases:
        try:
            entries = sorted(os.listdir(base))
        except OSError:
            continue
        for name in entries:
            if name.startswith("."):
                continue
            if os.path.isfile(os.path.join(base, name, "index.theme")):
                if name not in themes:
                    themes.append(name)
    return themes

WIDGET_BOOTSTRAP_TAIL = r'''------------------------------------------------------------
-- Bootstrap (formerly init.lua): initialize the item groups.
------------------------------------------------------------
init_groups(_GROUPS)
'''

WIDGET_WEATHER_FUNC = r'''function conky_weather_update()
    conky_load_weather_data()
    conky_update_alerts()
    return ""
end
'''

_FALLBACK_THEME = {
    "palette": {
        "bg_dark": "#202326", "bg_mid": "#292c30", "bg_light": "#31363c",
        "fg": "#fcfcfc", "fg_dim": "#a1a9b1", "blue": "#3daee9",
        "green": "#27ae60", "yellow": "#f67400", "red": "#da4453",
    },
    "gradients": {
        "text_value": [[1, "#27ae60", 1]],
        "bar_cpu": [[1, "#3daee9", 1]],
        "border_subtle": [[1, "#a1a9b1", 0.6]],
    },
    "defaults": {
        "background": {"bg": [[1, "#202326", 0.9]],
                       "border": [[1, "#4a4d52", 1]], "border_width": 2},
        "bar": {"fg": [[1, "#3daee9", 1]], "bg": [[1, "#3a3d41", 1]]},
        "line": {"fg": [[1, "#a1a9b1", 1]]},
        "graph": {"fg": [[1, "#3daee9", 1]], "bg": [[1, "#3a3d41", 1]],
                  "border": [[1, "#4a4d52", 1]], "grid_color": [[1, "#31363c", 1]]},
        "ring": {"fg": [[1, "#3daee9", 1]], "bg": [[1, "#3a3d41", 1]]},
        "text": {"color": [[1, "#fcfcfc", 1]]},
        "clock": {
            "bg": [[1, "#31363c", 1]],
            "border": [[1, "#4a4d52", 1]],
            "tick_color": [[1, "#a1a9b1", 1]],
            "number_color": [[1, "#fcfcfc", 1]],
            "hour_color": [[1, "#fcfcfc", 1]],
            "minute_color": [[1, "#3daee9", 1]],
            "second_color": [[1, "#f67400", 1]],
            "center_color": [[1, "#3daee9", 1]],
        },
        "calendar": {
            "color_month": [[1, "#fcfcfc", 1]],
            "color_weekdays": [[1, "#a1a9b1", 1]],
            "color_days": [[1, "#a1a9b1", 1]],
            "color_today": [[1, "#3daee9", 1]],
            "color_outside": [[1, "#4a4d52", 1]],
            "color_weeknums": [[1, "#3daee9", 1]],
        },
    },
}


def _empty_widget_lua():
    """Build the empty widget.lua template, embedding the current theme
    (always uses _FALLBACK_THEME for new widgets)."""
    themes = {THEME_NAME: _FALLBACK_THEME}
    if THEME_NAME not in themes:
        themes = {THEME_NAME: themes[next(iter(themes))]}
    themes_block = tw.serialize_themes(themes)
    return (r'''--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

''' + WIDGET_CONFIG_BLOCK + weather_icon_block("default") + r'''--{{{
--  widget.lua — Empty widget data template (loaded directly by Conky)
--}}}

''' + themes_block + '\n' + r'''DEFAULT_THEME = "theme"
_PADDING = 10

_GROUPS = {}

_VIEWS = {
    { name = "main" },
}

_MOUSE_ENABLED = true
''' + WIDGET_BOOTSTRAP_TAIL)


def _colors_match(a, b):
    """Compare two color values (handles str vs list normalization)."""
    if a == b:
        return True
    # Normalize both to comparable form
    na = _color_to_hex_list(a)
    nb = _color_to_hex_list(b)
    return na == nb


def _color_to_hex_list(val):
    """Normalize a color value to [[pos, hex, alpha], ...] for comparison."""
    if isinstance(val, list):
        result = []
        for stop in val:
            if isinstance(stop, (list, tuple)) and len(stop) == 3:
                result.append([stop[0], str(stop[1]).lower(), stop[2]])
        return result
    if isinstance(val, str):
        return [[1, val.lower(), 1]]
    return val


class ColorPickButton(Gtk.Button):
    """Gtk.ColorButton-compatible swatch button with an on-screen eyedropper.

    Opens a color chooser dialog with a "Pick color from screen…" button
    to sample a color from the screen (KWin ColorPicker / spectacle overlay).

    API: set_rgba()/get_rgba() + "color-set" signal, same as Gtk.ColorButton.
    """

    __gsignals__ = {
        "color-set": (GObject.SignalFlags.RUN_LAST, None, ()),
    }

    def __init__(self):
        super().__init__()
        self._rgba_val = Gdk.RGBA(red=1.0, green=1.0, blue=1.0, alpha=1.0)
        self.set_size_request(48, 26)
        self.set_relief(Gtk.ReliefStyle.NONE)
        self.set_tooltip_text("Color picker (in the dialog: pick a color from the screen)")
        self.connect("draw", self._draw_swatch)
        self.connect("clicked", self._open_chooser)

    def get_rgba(self):
        return self._rgba_val

    def set_rgba(self, rgba):
        self._rgba_val = rgba
        self.queue_draw()

    def _draw_swatch(self, w, cr):
        aw, ah = w.get_allocated_width(), w.get_allocated_height()
        r = self._rgba_val
        cr.set_source_rgba(r.red, r.green, r.blue, r.alpha)
        cr.rectangle(1, 1, aw - 2, ah - 2)
        cr.fill()
        cr.set_source_rgba(0.4, 0.4, 0.4, 1.0)
        cr.rectangle(0.5, 0.5, aw - 1, ah - 1)
        cr.set_line_width(1)
        cr.stroke()
        return False

    def _open_chooser(self, *a):
        dialog = Gtk.ColorChooserDialog(
            title="Select Color",
            transient_for=self.get_toplevel(),
        )
        dialog.set_use_alpha(False)
        dialog.set_rgba(self._rgba_val)
        self._hide_builtin_picker(dialog)
        if _PIL_OK:
            pick = Gtk.Button(label="Pick color from screen…")
            pick.set_tooltip_text("Click a pixel on the screen")
            pick.connect("clicked", self._on_pick_screen, dialog)
            dialog.get_content_area().pack_start(pick, False, False, 0)
        dialog.show_all()
        resp = dialog.run()
        if resp == Gtk.ResponseType.OK:
            self._rgba_val = dialog.get_rgba()
            self.queue_draw()
            self.emit("color-set")
        dialog.destroy()

    @staticmethod
    def _hide_builtin_picker(widget):
        """Hide the built-in eyedropper button of the GTK color chooser
        (in GtkColorEditor), which doesn't work on Wayland."""
        if isinstance(widget, Gtk.Button):
            child = widget.get_child()
            if isinstance(child, Gtk.Image):
                icon = child.get_icon_name()
                name = icon[0] if isinstance(icon, tuple) else None
                if name and ("color-picker" in name or "color-select" in name):
                    widget.set_no_show_all(True)
                    widget.hide()
        try:
            for c in widget.get_children():
                ColorPickButton._hide_builtin_picker(c)
        except Exception:
            pass

    @staticmethod
    def _grab_screen():
        path = os.path.join(WORK_DIR, "eyedrop.png")
        for cmd in (
            ["spectacle", "-b", "-n", "-o", path, "--current"],
            ["import", "-window", "root", path],
        ):
            try:
                subprocess.run(cmd, timeout=15, check=True,
                               stdout=subprocess.DEVNULL,
                               stderr=subprocess.DEVNULL)
            except Exception:
                continue
            if os.path.exists(path) and os.path.getsize(path) > 0:
                return path
        return None

    def _on_pick_screen(self, btn, chooser):
        res = self._on_pick_screen_raw()
        if isinstance(res, Gdk.RGBA):
            chooser.set_rgba(res)
            chooser.response(Gtk.ResponseType.OK)
        elif res is None:
            self._pick_overlay(
                lambda c: (chooser.set_rgba(c),
                           chooser.response(Gtk.ResponseType.OK)))

    def _on_pick_screen_raw(self):
        """Screen color sampling: returns RGBA, or None (fallback needed),
        or False (the user cancelled)."""
        try:
            res = self._pick_kwin()
        except Exception as e:
            print("PICKER: kwin exception:", repr(e), file=sys.stderr)
            res = "unavailable"
        print("PICKER: kwin res =", res, file=sys.stderr)
        if isinstance(res, Gdk.RGBA):
            return res
        if res == "unavailable":
            return None
        return False

    def _pick_kwin(self):
        """KWin's built-in color picker (Wayland-native, compositor-side).

        Via the `org.kde.kwin.ColorPicker.pick` D-Bus call, KWin draws the
        picker and returns an ARGB uint32 on click. On KDE Wayland this is
        the only reliable path. Otherwise None/"unavailable"/"cancelled".
        """
        try:
            out = subprocess.run(
                ["gdbus", "call", "--session",
                 "--dest", "org.kde.KWin.ScreenShot2",
                 "--object-path", "/ColorPicker",
                 "--method", "org.kde.kwin.ColorPicker.pick"],
                timeout=300, capture_output=True, text=True)
        except subprocess.TimeoutExpired:
            return "cancelled"
        except Exception:
            return "unavailable"
        if out.returncode != 0:
            err = out.stdout + out.stderr
            if "ServiceUnknown" in err:
                return "unavailable"
            return "cancelled"
        m = re.search(r"uint32 (\d+)", out.stdout)
        if not m:
            return "cancelled"
        v = int(m.group(1))
        r = (v >> 16) & 0xFF
        g = (v >> 8) & 0xFF
        b = v & 0xFF
        return Gdk.RGBA(r / 255, g / 255, b / 255, 1.0)

    def _pick_overlay(self, on_result):
        path = self._grab_screen()
        if not path:
            chooser.get_toplevel().set_title("Screen capture failed")
            return
        try:
            img = _PILImage.open(path).convert("RGB")
        except Exception:
            return
        w, h = img.size
        data = img.tobytes()

        mask = (Gdk.EventMask.POINTER_MOTION_MASK |
                Gdk.EventMask.BUTTON_PRESS_MASK |
                Gdk.EventMask.BUTTON_RELEASE_MASK |
                Gdk.EventMask.KEY_PRESS_MASK)

        picker = Gtk.Window(type=Gtk.WindowType.POPUP)
        picker.set_title("Click a color on the screen (Esc: cancel)")
        picker.set_decorated(False)
        picker.set_can_focus(True)
        picker.set_accept_focus(True)
        picker.set_events(mask)
        disp = Gtk.DrawingArea()
        disp.set_events(mask)
        disp.set_hexpand(True)
        disp.set_vexpand(True)
        disp.set_halign(Gtk.Align.FILL)
        disp.set_valign(Gtk.Align.FILL)
        picker.add(disp)

        pb = GdkPixbuf.Pixbuf.new_from_bytes(
            GLib.Bytes(data), GdkPixbuf.Colorspace.RGB, False, 8, w, h, w * 3)

        magnifier = Gtk.Window(type=Gtk.WindowType.POPUP)
        magnifier.set_decorated(False)
        mag_img = Gtk.Image()
        magnifier.add(mag_img)
        mag_sz, zoom = 120, 6
        magnifier.set_default_size(mag_sz, mag_sz)

        state = {"ox": 0, "oy": 0, "pb": None, "scale": 1.0}

        def on_draw(area, cr):
            cr.set_source_rgba(0, 0, 0, 1)
            cr.paint()
            s = state["pb"]
            if s is not None:
                ox = (area.get_allocated_width() - s.get_width()) // 2
                oy = (area.get_allocated_height() - s.get_height()) // 2
                state["ox"], state["oy"] = ox, oy
                Gdk.cairo_set_source_pixbuf(cr, s, ox, oy)
                cr.paint()
            return False

        def mag_at(ix, iy):
            if ix < 0 or iy < 0 or ix >= w or iy >= h:
                magnifier.hide()
                return
            half = mag_sz // zoom // 2
            sx = max(0, min(w - mag_sz // zoom, ix - half))
            sy = max(0, min(h - mag_sz // zoom, iy - half))
            crop = pb.new_subpixbuf(sx, sy, mag_sz // zoom, mag_sz // zoom)
            z = crop.scale_simple(mag_sz, mag_sz,
                                  GdkPixbuf.InterpType.NEAREST)
            pixels = bytearray(z.get_pixels())
            rowstride = z.get_rowstride()
            nch = 4 if z.get_has_alpha() else 3
            for i in range(mag_sz):
                off = rowstride * (mag_sz // 2) + i * nch
                for c in range(nch):
                    pixels[off + c] = min(255, pixels[off + c] + 90)
                off = rowstride * i + (mag_sz // 2) * nch
                for c in range(nch):
                    pixels[off + c] = min(255, pixels[off + c] + 90)
            zc = GdkPixbuf.Pixbuf.new_from_bytes(
                GLib.Bytes(bytes(pixels)), z.get_colorspace(),
                z.get_has_alpha(), z.get_bits_per_sample(),
                z.get_width(), z.get_height(), z.get_rowstride())
            mag_img.set_from_pixbuf(zc)

        def map_xy(ev):
            ix = int((ev.x - state["ox"]) / state["scale"])
            iy = int((ev.y - state["oy"]) / state["scale"])
            return ix, iy

        def on_motion(wdg, ev):
            ix, iy = map_xy(ev)
            mag_at(ix, iy)
            if not magnifier.get_visible():
                magnifier.show_all()
            magnifier.move(int(ev.x_root) + 18, int(ev.y_root) + 18)
            return False

        closed = {"v": False}

        def _close_picker():
            if closed["v"]:
                return
            closed["v"] = True
            try:
                magnifier.destroy()
            except Exception:
                pass
            try:
                picker.destroy()
            except Exception:
                pass

        def on_press(wdg, ev):
            ix, iy = map_xy(ev)
            if 0 <= ix < w and 0 <= iy < h:
                p = img.getpixel((ix, iy))
                on_result(Gdk.RGBA(p[0] / 255, p[1] / 255,
                                   p[2] / 255, 1.0))
                GLib.idle_add(_close_picker)
            return False

        def on_key(wdg, ev):
            if ev.keyval in (Gdk.KEY_Escape, Gdk.KEY_q, Gdk.KEY_Q):
                GLib.idle_add(_close_picker)
                return True
            return False

        disp.connect("draw", on_draw)
        picker.connect("motion-notify-event", on_motion)
        picker.connect("button-press-event", on_press)
        picker.connect("key-press-event", on_key)
        disp.connect("motion-notify-event", on_motion)
        disp.connect("button-press-event", on_press)

        picker.fullscreen()
        picker.show_all()
        pw = picker.get_window().get_width()
        ph = picker.get_window().get_height()
        scale = max(0.01, min(pw / w, ph / h))
        state["scale"] = scale
        state["pb"] = pb.scale_simple(
            max(1, int(w * scale)), max(1, int(h * scale)),
            GdkPixbuf.InterpType.BILINEAR)
        disp.queue_draw()
        picker.get_window().set_cursor(Gdk.Cursor.new_for_display(
            Gdk.Display.get_default(), Gdk.CursorType.CROSSHAIR))
        picker.grab_focus()


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
                # Empty group = group-less (Lua draw_allowed checks `== nil`,
                # an empty string would hide the item in non-main views).
                continue
            else:
                lines.append(f'    {key} = "{_lua_escape(str(item[key]))}",')
    for key, val in item.items():
        if key in ("type", "group", "view"):
            continue
        if val is None:
            continue
        # Skip if value matches theme default
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


class DesignerWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="NextGen Designer")
        self.set_default_size(*_clamp_size(1920, 1000))
        self.set_size_request(640, 400)
        if ICON_PATH:
            self.set_icon_from_file(ICON_PATH)

        self.draw_list = []
        self.groups = []
        self.views = []
        self.selected_index = None
        self.current_view = "main"
        self.current_theme = THEME_NAME
        self.save_path = WIDGET_LUA
        self.dirty = False
        self.padding = 10
        self.window_width = 420
        self.window_height = 1020
        self.mouse_actions = {name: "nil" for name, _ in MOUSE_ACTIONS}
        self.mouse_enabled = True
        self.weather_enabled = True
        self.weather_icon_theme = "default"
        self.xdg_icon_theme = ""
        self.custom_lua_code = ""
        self.conky_settings = self._default_conky_settings()
        self._mouse_tab_views = None  # cache of view names for mouse tab rebuild
        self._weather_loading = False  # guard for weather & icons tab refresh
        self._state_save_timeout = None  # pending debounced window-state save
        # Conky management (live preview instance)
        self._conky_managed = False
        self.conky_proc = None
        self.conky_log_path = None
        self._spawn_conf_path = None  # preview .conf (X11) vs. real .conf
        self._watchdog_id = None
        self._restart_debounce_id = None
        # PNG capture queue (Save → on-demand surface export per view)
        self._capture_queue = []
        self._capture_poll_id = None
        self._log_poll_id = None  # Dev Console → conky log tail
        self.view_item_map = {}  # maps list row index → draw_list index
        self._ready = False  # suppress live writes until construction finishes

        self.connect("configure-event", self._on_window_configure)
        self.connect("window-state-event", self._on_window_state)

        self._setup_ui()
        self._init_empty()
        self._ready = True

    def _setup_ui(self):
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        hbox.set_margin_start(6)
        hbox.set_margin_end(6)
        hbox.set_margin_top(6)
        hbox.set_margin_bottom(6)
        self.add(hbox)

        # ── Left: live view & Conky controls ──
        left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        left.set_size_request(260, -1)
        hbox.pack_start(left, False, False, 0)

        view_bar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        left.pack_start(view_bar, False, False, 0)

        row1 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        view_bar.pack_start(row1, False, False, 0)

        row1.pack_start(Gtk.Label(label="View:"), False, False, 0)
        self.view_combo = Gtk.ComboBoxText()
        self.view_combo.append_text("main")
        self.view_combo.set_active(0)
        self.view_combo.connect("changed", self._on_view_changed)
        row1.pack_start(self.view_combo, True, True, 0)

        row1.pack_start(Gtk.Label(label="Pad:"), False, False, 0)
        self.padding_spin = Gtk.SpinButton.new_with_range(0, 100, 1)
        self.padding_spin.set_value(self.padding)
        self.padding_spin.set_width_chars(4)
        self.padding_spin.connect("value-changed", self._on_padding_changed)
        row1.pack_start(self.padding_spin, False, False, 0)

        # ── Conky live preview controls ──
        conky_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        conky_box.set_border_width(0)
        left.pack_start(conky_box, False, False, 0)
        conky_box.pack_start(
            Gtk.Label(label="Conky", xalign=0), False, False, 0
        )

        self.btn_conky_run = Gtk.Button(label="Run")
        self.btn_conky_run.connect("clicked", lambda _: self._conky_start())
        conky_box.pack_start(self.btn_conky_run, False, False, 0)

        self.btn_conky_stop = Gtk.Button(label="Stop")
        self.btn_conky_stop.connect("clicked", lambda _: self._conky_stop())
        conky_box.pack_start(self.btn_conky_stop, False, False, 0)

        self.btn_conky_restart = Gtk.Button(label="Restart")
        self.btn_conky_restart.connect("clicked", lambda _: self._conky_restart())
        conky_box.pack_start(self.btn_conky_restart, False, False, 0)

        self.btn_reload_all = Gtk.Button(label="Reload All")
        self.btn_reload_all.set_tooltip_text(
            "Panic button: sends SIGUSR1 to all conky instances.\n"
            "Press when a widget crashes while editing another."
        )
        self.btn_reload_all.connect(
            "clicked", lambda _: subprocess.run(
                ["killall", "-USR1", "conky"], capture_output=True
            )
        )
        conky_box.pack_start(self.btn_reload_all, False, False, 0)

        self.conky_state_label = Gtk.Label(label="conky: stopped", xalign=0)
        conky_box.pack_start(self.conky_state_label, False, False, 0)

        self.btn_capture = Gtk.Button(label="Export PNGs")
        self.btn_capture.set_tooltip_text(
            "Capture each view from the running conky to PNG files "
            "(next to the .lua, Conky Manager style)"
        )
        self.btn_capture.connect("clicked", lambda _: self._export_pngs(self.save_path))
        conky_box.pack_start(self.btn_capture, False, False, 0)

        self.conky_hint_label = Gtk.Label(xalign=0, wrap=True)
        self.conky_hint_label.set_markup(
            "<small>Edits are written live to "
            + os.path.basename(self.save_path)
            + ".\nRun starts conky for the sibling .conf.</small>"
        )
        conky_box.pack_start(self.conky_hint_label, False, False, 0)

        # ── Right ──
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        right.set_size_request(360, -1)
        hbox.pack_end(right, False, False, 0)

        # Menu bar
        mb = Gtk.MenuBar()
        right.pack_start(mb, False, False, 0)

        file_menu = Gtk.Menu()
        file_item = Gtk.MenuItem(label="File")
        file_item.set_submenu(file_menu)

        new_item = Gtk.MenuItem(label="New (empty)")
        new_item.connect("activate", lambda _: self._new_widget_lua())
        file_menu.append(new_item)

        save_item = Gtk.MenuItem(label="Save")
        save_item.connect("activate", lambda _: self._save_current())
        file_menu.append(save_item)

        open_item = Gtk.MenuItem(label="Open...")
        open_item.connect("activate", lambda _: self._open_file())
        file_menu.append(open_item)

        save_as_item = Gtk.MenuItem(label="Save As...")
        save_as_item.connect("activate", lambda _: self._save_as())
        file_menu.append(save_as_item)

        file_menu.append(Gtk.SeparatorMenuItem())

        reload_item = Gtk.MenuItem(label="Reload")
        reload_item.connect("activate", lambda _: self._reload())
        file_menu.append(reload_item)

        file_menu.append(Gtk.SeparatorMenuItem())

        show_code_item = Gtk.MenuItem(label="Show the code")
        show_code_item.connect("activate", lambda _: self._show_code())
        file_menu.append(show_code_item)

        file_menu.append(Gtk.SeparatorMenuItem())

        quit_item = Gtk.MenuItem(label="Quit")
        quit_item.set_tooltip_text("Exit the designer (same as closing the window)")
        quit_item.connect("activate", lambda _: self._on_quit())
        file_menu.append(quit_item)

        mb.append(file_item)

        view_menu = Gtk.Menu()
        view_item = Gtk.MenuItem(label="View")
        view_item.set_submenu(view_menu)

        log_item = Gtk.MenuItem(label="Developer Console...")
        log_item.set_tooltip_text("Live error/activity log (conky, Lua probe, render)")
        log_item.connect("activate", lambda _: self._open_log_window())
        view_menu.append(log_item)

        mb.append(view_item)

        help_menu = Gtk.Menu()
        help_item = Gtk.MenuItem(label="Help")
        help_item.set_submenu(help_menu)

        conky_man_item = Gtk.MenuItem(label="Conky Manual")
        conky_man_item.set_tooltip_text(
            "Generate the current conky(1) man page as HTML and open it "
            "(zcat /usr/share/man/man1/conky.1.gz | mandoc -T html)")
        conky_man_item.connect("activate", lambda _: self._open_conky_manual())
        help_menu.append(conky_man_item)

        handbook_item = Gtk.MenuItem(label="NextGen Handbook")
        handbook_item.set_tooltip_text(
            "Convert NextGen.md to HTML (md2html) and open it — always fresh")
        handbook_item.connect("activate", lambda _: self._open_nextgen_handbook())
        help_menu.append(handbook_item)

        help_menu.append(Gtk.SeparatorMenuItem())

        about_item = Gtk.MenuItem(label="About")
        about_item.set_tooltip_text(
            "Open the project page: github.com/molnari811023/conky-nextgen")
        about_item.connect("activate", lambda _: self._open_about())
        help_menu.append(about_item)

        mb.append(help_item)

        # Notebook
        notebook = Gtk.Notebook()
        notebook.set_scrollable(True)
        right.pack_start(notebook, True, True, 0)

        # ── Tab 1: Items ──
        items_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        items_page.set_margin_start(4)
        items_page.set_margin_end(4)
        items_page.set_margin_top(4)
        notebook.append_page(items_page, Gtk.Label(label="Items"))

        items_toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        items_page.pack_start(items_toolbar, False, False, 0)

        btn = Gtk.Button(label="Add Item")
        btn.connect("clicked", lambda _: self._add_item())
        items_toolbar.pack_start(btn, False, False, 0)

        btn = Gtk.Button(label="Delete")
        btn.connect("clicked", lambda _: self._delete_item())
        items_toolbar.pack_start(btn, False, False, 0)

        btn = Gtk.Button(label="Edit Props")
        btn.set_tooltip_text("Open the properties of the selected widget in a separate window")
        btn.connect("clicked", lambda _: self._open_prop_window())
        items_toolbar.pack_start(btn, False, False, 0)

        list_sw = Gtk.ScrolledWindow()
        items_page.pack_start(list_sw, True, True, 0)

        self.liststore = Gtk.ListStore(int, str, str, str)  # draw_list_idx, type, group, summary
        self.treeview = Gtk.TreeView(model=self.liststore)
        self.treeview.set_headers_visible(True)

        col_group = Gtk.TreeViewColumn("Group", Gtk.CellRendererText(), text=2)
        self.treeview.append_column(col_group)

        col_type = Gtk.TreeViewColumn("Type", Gtk.CellRendererText(), text=1)
        self.treeview.append_column(col_type)

        col_value = Gtk.TreeViewColumn("Value", Gtk.CellRendererText(), text=3)
        self.treeview.append_column(col_value)

        sel = self.treeview.get_selection()
        sel.set_mode(Gtk.SelectionMode.SINGLE)
        self.list_selection = sel
        self.list_sel_hid = sel.connect("changed", self._on_list_select)
        self.treeview.connect("row-activated", self._on_list_activate)
        list_sw.add(self.treeview)

        # Property editor lives in a separate window (self._build_prop_window).
        self.prop_win = None

        # Live log window (View > Log...)
        self.log_win = None
        self.log_text = None
        self.prop_entries = {}

        # ── Tab 2: Groups ──
        groups_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        groups_page.set_margin_start(4)
        groups_page.set_margin_end(4)
        groups_page.set_margin_top(4)
        notebook.append_page(groups_page, Gtk.Label(label="Groups"))

        grp_toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        groups_page.pack_start(grp_toolbar, False, False, 0)

        btn = Gtk.Button(label="Add Group")
        btn.connect("clicked", lambda _: self._add_group())
        grp_toolbar.pack_start(btn, False, False, 0)

        btn = Gtk.Button(label="Delete Group")
        btn.connect("clicked", lambda _: self._delete_group())
        grp_toolbar.pack_start(btn, False, False, 0)

        grp_list_sw = Gtk.ScrolledWindow()
        groups_page.pack_start(grp_list_sw, True, True, 0)

        self.grp_liststore = Gtk.ListStore(str, str)
        self.grp_treeview = Gtk.TreeView(model=self.grp_liststore)
        self.grp_treeview.set_headers_visible(True)

        col_name = Gtk.TreeViewColumn("Name", Gtk.CellRendererText(), text=0)
        self.grp_treeview.append_column(col_name)

        col_views = Gtk.TreeViewColumn("Views", Gtk.CellRendererText(), text=1)
        self.grp_treeview.append_column(col_views)

        grp_sel = self.grp_treeview.get_selection()
        grp_sel.set_mode(Gtk.SelectionMode.SINGLE)
        self.grp_selection = grp_sel
        self.grp_sel_hid = grp_sel.connect("changed", self._on_group_select)
        grp_list_sw.add(self.grp_treeview)

        # Group editor
        grp_prop_label = Gtk.Label(label="Group properties (Enter to save)")
        grp_prop_label.set_xalign(0)
        groups_page.pack_start(grp_prop_label, False, False, 0)

        self.grp_prop_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.grp_prop_box.set_margin_start(4)
        self.grp_prop_box.set_margin_end(4)
        groups_page.pack_start(self.grp_prop_box, False, False, 0)
        self.grp_prop_entries = {}
        self.selected_group_index = None

        # ── Tab 3: Views ──
        views_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        views_page.set_margin_start(4)
        views_page.set_margin_end(4)
        views_page.set_margin_top(4)
        notebook.append_page(views_page, Gtk.Label(label="Views"))

        views_toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        views_page.pack_start(views_toolbar, False, False, 0)

        btn = Gtk.Button(label="Add View")
        btn.connect("clicked", lambda _: self._add_view())
        views_toolbar.pack_start(btn, False, False, 0)

        btn = Gtk.Button(label="Delete View")
        btn.connect("clicked", lambda _: self._delete_view())
        views_toolbar.pack_start(btn, False, False, 0)

        views_list_sw = Gtk.ScrolledWindow()
        views_page.pack_start(views_list_sw, True, True, 0)

        self.views_liststore = Gtk.ListStore(str, str)  # name, groups
        self.views_treeview = Gtk.TreeView(model=self.views_liststore)
        self.views_treeview.set_headers_visible(True)

        col_vname = Gtk.TreeViewColumn("Name", Gtk.CellRendererText(), text=0)
        self.views_treeview.append_column(col_vname)

        col_vgroups = Gtk.TreeViewColumn("Groups", Gtk.CellRendererText(), text=1)
        self.views_treeview.append_column(col_vgroups)

        views_sel = self.views_treeview.get_selection()
        views_sel.set_mode(Gtk.SelectionMode.SINGLE)
        self.views_selection = views_sel
        self.views_sel_hid = views_sel.connect("changed", self._on_view_list_select)
        views_list_sw.add(self.views_treeview)

        # View editor
        views_prop_label = Gtk.Label(label="View properties (Enter to save)")
        views_prop_label.set_xalign(0)
        views_page.pack_start(views_prop_label, False, False, 0)

        self.views_prop_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.views_prop_box.set_margin_start(4)
        self.views_prop_box.set_margin_end(4)
        views_page.pack_start(self.views_prop_box, False, False, 0)
        self.views_prop_entries = {}
        self.selected_view_index = None

        # ── Tab 4: Mouse ──
        mouse_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        mouse_page.set_margin_start(4)
        mouse_page.set_margin_end(4)
        mouse_page.set_margin_top(4)
        notebook.append_page(mouse_page, Gtk.Label(label="Mouse"))

        mouse_info = Gtk.Label(label="Select an action or type a function name")
        mouse_info.set_xalign(0)
        mouse_info.set_markup("<small><i>— (none), a mouse_actions.lua function, or switch_view (view)</i></small>")
        mouse_page.pack_start(mouse_info, False, False, 0)

        self.mouse_enabled_check = Gtk.CheckButton(label="Mouse actions")
        self.mouse_enabled_check.set_margin_top(2)
        self.mouse_enabled_check.set_margin_bottom(2)
        self.mouse_enabled_check.connect("toggled", self._on_mouse_enabled_toggled)
        mouse_page.pack_start(self.mouse_enabled_check, False, False, 0)

        mouse_sw = Gtk.ScrolledWindow()
        mouse_page.pack_start(mouse_sw, True, True, 0)

        self.mouse_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.mouse_box.set_margin_start(4)
        self.mouse_box.set_margin_end(4)
        mouse_sw.add(self.mouse_box)
        self.mouse_combos = {}

        # Status
        self.status = Gtk.Label(label="Ready")
        self.status.set_xalign(0)
        right.pack_end(self.status, False, False, 0)

        # ── Tab 5: Gradient (standalone, no Lua writes) ──
        grad_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        grad_page.set_margin_start(4)
        grad_page.set_margin_end(4)
        grad_page.set_margin_top(4)
        notebook.append_page(grad_page, Gtk.Label(label="Gradient"))

        grow1 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        grad_page.pack_start(grow1, False, False, 0)

        add_stop = Gtk.Button(label="+ Stop")
        add_stop.connect("clicked", self._grad_add_stop)
        grow1.pack_start(add_stop, False, False, 0)

        grow1.pack_start(Gtk.Label(label="Mode:"), False, False, 0)
        self.grad_mode = Gtk.ComboBoxText()
        for gid, glabel in gg.MODES:
            self.grad_mode.append(gid, glabel)
        self.grad_mode.set_active_id("linear")
        self.grad_mode.connect("changed", self._grad_changed)
        grow1.pack_start(self.grad_mode, False, False, 0)

        grow1.pack_start(Gtk.Label(label="Steps:"), False, False, 0)
        self.grad_steps = Gtk.SpinButton.new_with_range(2, 64, 1)
        self.grad_steps.set_value(8)
        self.grad_steps.connect("value-changed", self._grad_changed)
        grow1.pack_start(self.grad_steps, False, False, 0)

        grad_sw = Gtk.ScrolledWindow()
        grad_sw.set_min_content_height(120)
        grad_sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        grad_page.pack_start(grad_sw, False, False, 0)
        self.grad_stops_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        grad_sw.add(self.grad_stops_box)

        grad_lbl = Gtk.Label(label="Preview")
        grad_lbl.set_xalign(0)
        grad_page.pack_start(grad_lbl, False, False, 0)
        self.grad_preview = Gtk.DrawingArea()
        self.grad_preview.set_size_request(-1, 40)
        self.grad_preview.connect("draw", self._on_grad_preview_draw)
        grad_page.pack_start(self.grad_preview, False, False, 0)

        self.grad_swatch = Gtk.DrawingArea()
        self.grad_swatch.set_size_request(-1, 30)
        self.grad_swatch.connect("draw", self._on_grad_swatch_draw)
        grad_page.pack_start(self.grad_swatch, False, False, 0)

        # ── shades ──
        shades_sep = Gtk.Separator()
        grad_page.pack_start(shades_sep, False, False, 0)

        shades_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        grad_page.pack_start(shades_row, False, False, 0)
        shades_row.pack_start(Gtk.Label(label="Shades:"), False, False, 0)
        self.shades_color = ColorPickButton()
        self.shades_color.set_rgba(self._rgba("#3daee9"))
        self.shades_color.connect("color-set", self._grad_changed)
        shades_row.pack_start(self.shades_color, False, False, 0)
        shades_row.pack_start(Gtk.Label(label="Db:"), False, False, 0)
        self.shades_steps = Gtk.SpinButton.new_with_range(2, 16, 1)
        self.shades_steps.set_value(7)
        self.shades_steps.connect("value-changed", self._grad_changed)
        shades_row.pack_start(self.shades_steps, False, False, 0)

        self.shades_swatch = Gtk.DrawingArea()
        self.shades_swatch.set_size_request(-1, 26)
        self.shades_swatch.connect("draw", self._on_shades_draw)
        grad_page.pack_start(self.shades_swatch, False, False, 0)

        # ── output / copy ──
        out_lbl = Gtk.Label(label="Output (THEMES block gradient format)")
        out_lbl.set_xalign(0)
        grad_page.pack_start(out_lbl, False, False, 0)
        self.grad_output = Gtk.Entry()
        self.grad_output.set_editable(False)
        self.grad_output.set_hexpand(True)
        grad_page.pack_start(self.grad_output, False, False, 0)

        copy_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        grad_page.pack_start(copy_row, False, False, 0)
        copy_lua = Gtk.Button(label="Copy Lua stops")
        copy_lua.connect("clicked", self._grad_copy_lua)
        copy_row.pack_start(copy_lua, False, False, 0)
        copy_pal = Gtk.Button(label="Copy hex palette")
        copy_pal.connect("clicked", self._grad_copy_palette)
        copy_row.pack_start(copy_pal, False, False, 0)
        copy_sha = Gtk.Button(label="Copy shades")
        copy_sha.connect("clicked", self._grad_copy_shades)
        copy_row.pack_start(copy_sha, False, False, 0)

        # default two-stop gradient
        self._grad_stops = [[0.0, "#3daee9", 1.0], [1.0, "#a065ee", 1.0]]
        self._grad_stop_widgets = []
        self._rebuild_grad_stops()
        self._refresh_gradient()

        # ── Tab 6: Theme editor ──
        theme_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        theme_page.set_margin_start(4)
        theme_page.set_margin_end(4)
        theme_page.set_margin_top(4)
        notebook.append_page(theme_page, Gtk.Label(label="Theme"))

        trow1 = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        theme_page.pack_start(trow1, False, False, 0)
        theme_lbl = Gtk.Label(label="")
        theme_lbl.set_xalign(0)
        theme_lbl.set_line_wrap(True)
        theme_lbl.set_max_width_chars(70)
        theme_lbl.set_markup(
            "<small>Single theme <b>\"{}\"</b> — edits below are written to "
            "widget.lua on <b>Save</b>.</small>".format(THEME_NAME)
        )
        trow1.pack_start(theme_lbl, True, True, 0)

        self.theme_edit_info = Gtk.Label(label="")
        self.theme_edit_info.set_xalign(0)
        self.theme_edit_info.set_line_wrap(True)
        self.theme_edit_info.set_max_width_chars(96)
        self.theme_edit_info.set_markup("<small>Palette: a color set usable in gradient/default fields.</small>")
        theme_page.pack_start(self.theme_edit_info, False, False, 0)

        sec_notebook = Gtk.Notebook()
        theme_page.pack_start(sec_notebook, True, True, 0)

        # ── Theme palette page ──
        pal_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        sec_notebook.append_page(pal_page, Gtk.Label(label="Palette"))
        pal_add = Gtk.Button(label="+ Palette color")
        pal_add.connect("clicked", self._theme_pal_add)
        pal_page.pack_start(pal_add, False, False, 0)
        pal_sw = Gtk.ScrolledWindow()
        pal_page.pack_start(pal_sw, True, True, 0)
        self.theme_pal_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        pal_sw.add(self.theme_pal_box)

        # ── Theme gradients page ──
        thgrad_page = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        sec_notebook.append_page(thgrad_page, Gtk.Label(label="Gradients"))

        thgrad_left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        thgrad_page.pack_start(thgrad_left, False, False, 0)
        thgrad_add = Gtk.Button(label="+ Gradient")
        thgrad_add.connect("clicked", self._theme_grad_add)
        thgrad_left.pack_start(thgrad_add, False, False, 0)
        thgrad_sw = Gtk.ScrolledWindow()
        thgrad_sw.set_size_request(160, -1)
        thgrad_left.pack_start(thgrad_sw, True, True, 0)
        self.theme_grad_liststore = Gtk.ListStore(str)
        self.theme_grad_tree = Gtk.TreeView(model=self.theme_grad_liststore)
        self.theme_grad_tree.append_column(Gtk.TreeViewColumn("Name", Gtk.CellRendererText(), text=0))
        sel = self.theme_grad_tree.get_selection()
        sel.set_mode(Gtk.SelectionMode.SINGLE)
        sel.connect("changed", self._on_theme_grad_select)
        thgrad_sw.add(self.theme_grad_tree)

        self.theme_grad_editor_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        thgrad_page.pack_start(self.theme_grad_editor_box, True, True, 0)

        # ── Theme defaults page ──
        thdef_page = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        sec_notebook.append_page(thdef_page, Gtk.Label(label="Defaults"))

        thdef_left = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        thdef_page.pack_start(thdef_left, False, False, 0)
        thdef_add = Gtk.Button(label="+ Widget type")
        thdef_add.connect("clicked", self._theme_defs_add_type)
        thdef_left.pack_start(thdef_add, False, False, 0)
        thdef_sw = Gtk.ScrolledWindow()
        thdef_sw.set_size_request(160, -1)
        thdef_left.pack_start(thdef_sw, True, True, 0)
        self.theme_defs_liststore = Gtk.ListStore(str)
        self.theme_defs_tree = Gtk.TreeView(model=self.theme_defs_liststore)
        self.theme_defs_tree.append_column(Gtk.TreeViewColumn("Type", Gtk.CellRendererText(), text=0))
        sel = self.theme_defs_tree.get_selection()
        sel.set_mode(Gtk.SelectionMode.SINGLE)
        sel.connect("changed", self._on_theme_defs_select)
        thdef_sw.add(self.theme_defs_tree)

        self.theme_defs_editor_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        thdef_page.pack_start(self.theme_defs_editor_box, True, True, 0)

        # Theme editor state (populated in _init_empty after themes load)
        self._theme_editing = None
        self._theme_sel_gradient = None
        self._theme_sel_type = None

        # ── Tab 7: Conky settings (saved as .conf for Conky Manager) ──
        conky_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        conky_page.set_margin_start(8)
        conky_page.set_margin_end(8)
        conky_page.set_margin_top(8)
        notebook.append_page(conky_page, Gtk.Label(label="Conky"))

        info_lbl = Gtk.Label(label="")
        info_lbl.set_xalign(0)
        info_lbl.set_line_wrap(True)
        info_lbl.set_max_width_chars(96)
        info_lbl.set_markup(
            "<small>Conky window settings. On <b>Save</b> a matching "
            "<b>.conf</b> is written next to the .lua so Conky Manager "
            "can pick the config up. \"auto\" means the value is omitted "
            "and Conky decides.</small>"
        )
        conky_page.pack_start(info_lbl, False, False, 0)

        grid = Gtk.Grid(column_spacing=8, row_spacing=6)
        conky_page.pack_start(grid, False, False, 0)

        def _row(r, label, widget):
            lbl = Gtk.Label(label=label)
            lbl.set_xalign(1)
            grid.attach(lbl, 0, r, 1, 1)
            grid.attach(widget, 1, r, 1, 1)

        self.conky_x_entry = Gtk.Entry()
        self.conky_x_entry.set_placeholder_text("auto")
        self.conky_x_entry.connect("changed", self._on_conky_changed)
        _row(0, "gap_x", self.conky_x_entry)

        self.conky_y_entry = Gtk.Entry()
        self.conky_y_entry.set_placeholder_text("auto")
        self.conky_y_entry.connect("changed", self._on_conky_changed)
        _row(1, "gap_y", self.conky_y_entry)

        self.conky_align_combo = Gtk.ComboBoxText()
        for a in ("top_left", "top_right", "top_middle", "bottom_left",
                  "bottom_right", "bottom_middle", "middle_left",
                  "middle_right", "middle_middle"):
            self.conky_align_combo.append_text(a)
        self.conky_align_combo.set_active(0)
        self.conky_align_combo.connect("changed", self._on_conky_changed)
        _row(2, "alignment", self.conky_align_combo)

        self.conky_hints_entry = Gtk.Entry()
        self.conky_hints_entry.set_text("below,sticky,skip_taskbar,skip_pager")
        self.conky_hints_entry.connect("changed", self._on_conky_changed)
        _row(3, "own_window_hints", self.conky_hints_entry)

        self.conky_type_combo = Gtk.ComboBoxText()
        for t in ("normal", "desktop", "dock", "override", "panel"):
            self.conky_type_combo.append_text(t)
        self.conky_type_combo.set_active(0)
        self.conky_type_combo.connect("changed", self._on_conky_changed)
        _row(4, "own_window_type", self.conky_type_combo)

        self.conky_min_w_spin = Gtk.SpinButton.new_with_range(0, 10000, 1)
        self.conky_min_w_spin.set_value(420)
        self.conky_min_w_spin.connect("value-changed", self._on_conky_size_changed)
        _row(5, "minimum_width", self.conky_min_w_spin)

        self.conky_min_h_spin = Gtk.SpinButton.new_with_range(0, 10000, 1)
        self.conky_min_h_spin.set_value(1020)
        self.conky_min_h_spin.connect("value-changed", self._on_conky_size_changed)
        _row(6, "minimum_height", self.conky_min_h_spin)

        self._conky_loading = False

        # ── Tab 8: Custom Lua ──
        custom_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        custom_page.set_margin_start(8)
        custom_page.set_margin_end(8)
        custom_page.set_margin_top(8)
        notebook.append_page(custom_page, Gtk.Label(label="Custom Lua"))

        custom_info = Gtk.Label()
        custom_info.set_xalign(0)
        custom_info.set_line_wrap(True)
        custom_info.set_max_width_chars(96)
        custom_info.set_markup(
            "<small>Free-form Lua code inserted <b>after</b> <tt>require(\"require\")</tt> "
            "and <b>before</b> draw items. Use this for <b>custom functions</b> and "
            "<b>for-loops</b> that generate draw entries. Do <b>not</b> close the "
            "file — the designer owns the full file structure.</small>"
        )
        custom_page.pack_start(custom_info, False, False, 0)

        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        custom_page.pack_start(sw, True, True, 0)

        self.custom_lua_view = GtkSource.View()
        self.custom_lua_view.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
        self.custom_lua_view.set_left_margin(6)
        self.custom_lua_view.set_right_margin(6)
        self.custom_lua_view.set_top_margin(4)
        self.custom_lua_view.set_bottom_margin(4)
        self.custom_lua_view.set_monospace(True)
        self.custom_lua_view.set_show_line_numbers(True)
        self.custom_lua_view.set_highlight_current_line(True)
        lm = GtkSource.LanguageManager.get_default()
        lang = lm.get_language("lua")
        if lang:
            self.custom_lua_view.get_buffer().set_language(lang)
        scheme = GtkSource.StyleSchemeManager.get_default().get_scheme("oblivion")
        if scheme:
            self.custom_lua_view.get_buffer().set_style_scheme(scheme)
        buf = self.custom_lua_view.get_buffer()
        buf.connect("changed", self._on_custom_lua_changed)
        sw.add(self.custom_lua_view)
        self._custom_lua_loading = False

        # ── Tab 9: Weather & Icons ──
        wi_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        wi_page.set_margin_start(8)
        wi_page.set_margin_end(8)
        wi_page.set_margin_top(8)
        notebook.append_page(wi_page, Gtk.Label(label="Weather & Icons"))

        self.weather_enabled_check = Gtk.CheckButton(label="Use weather")
        self.weather_enabled_check.set_margin_bottom(4)
        self.weather_enabled_check.connect("toggled", self._on_weather_enabled_toggled)
        wi_page.pack_start(self.weather_enabled_check, False, False, 0)

        weather_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        weather_row.pack_start(Gtk.Label(label="Weather icon set:"), False, False, 0)
        self.weather_icon_combo = Gtk.ComboBoxText()
        for s in WEATHER_ICON_SETS:
            self.weather_icon_combo.append_text(s)
        self.weather_icon_combo.set_active(0)
        self.weather_icon_combo.connect("changed", self._on_weather_icon_changed)
        weather_row.pack_start(self.weather_icon_combo, False, False, 0)
        wi_page.pack_start(weather_row, False, False, 0)

        xdg_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        xdg_row.pack_start(Gtk.Label(label="Icon theme (XDG):"), False, False, 0)
        self.xdg_icon_combo = Gtk.ComboBoxText()
        self.xdg_icon_combo.append("", "— (default)")
        for t in _installed_icon_themes():
            self.xdg_icon_combo.append(t, t)
        self.xdg_icon_combo.set_active(0)
        self.xdg_icon_combo.connect("changed", self._on_xdg_icon_changed)
        xdg_row.pack_start(self.xdg_icon_combo, False, False, 0)
        wi_page.pack_start(xdg_row, False, False, 0)

        wi_info = Gtk.Label(label="")
        wi_info.set_xalign(0)
        wi_info.set_line_wrap(True)
        wi_info.set_max_width_chars(96)
        wi_info.set_markup(
            "<small>JSON_PATH is always written (hardware/network and nowplaying "
            "read it too). The weather icon lines are only written when weather "
            "is enabled. An icon theme is only written when one is chosen.</small>"
        )
        wi_page.pack_start(wi_info, False, False, 0)

        # ── DIRTY TRACKING ──

    def _set_dirty(self):
        if not self.dirty:
            self.dirty = True
            self._update_title()

    def _clear_dirty(self):
        if self.dirty:
            self.dirty = False
            self._update_title()

    def _update_title(self):
        name = os.path.basename(self.save_path)
        if self.dirty:
            self.set_title(f"NextGen Designer — {name} *")
        else:
            self.set_title(f"NextGen Designer — {name}")

    def _check_dirty(self, action_text="continue"):
        """No-op in the live-save model: every edit is written to disk
        immediately, so there are never unsaved changes to lose."""
        return True

    def _confirm(self, text, secondary=""):
        """Show a Yes/No warning dialog. Returns True if the user confirms."""
        dialog = Gtk.MessageDialog(
            transient_for=self, modal=True,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text=text,
        )
        if secondary:
            dialog.format_secondary_text(secondary)
        response = dialog.run()
        dialog.destroy()
        return response == Gtk.ResponseType.YES

    # ── FILE: NEW ──

    def _new_widget_lua(self):
        dialog = Gtk.MessageDialog(
            transient_for=self, modal=True,
            message_type=Gtk.MessageType.QUESTION,
            buttons=Gtk.ButtonsType.YES_NO,
            text="Create new empty widget.lua?",
        )
        dialog.format_secondary_text(
            "This will overwrite the live file "
            f"{os.path.basename(self.save_path)} immediately."
        )
        response = dialog.run()
        dialog.destroy()
        if response != Gtk.ResponseType.YES:
            return
        self.save_path = WIDGET_LUA
        self._write_live(_empty_widget_lua())
        self.draw_list, self.groups, self.views, self.padding = parse_widget_lua(self.save_path)
        self._read_settings_from_file()
        self._load_themes()
        for item in self.draw_list:
            te.apply_theme(item)
        self.selected_index = None
        self.selected_group_index = None
        self.selected_view_index = None
        self._refresh_list()
        self._refresh_groups_list()
        self._refresh_views_list()
        self._clear_props()
        self._clear_grp_props()
        self._clear_views_props()
        self._refresh_view_combo()
        self._update_padding_spin()
        self._populate_mouse_tab()
        self._refresh_weather_tab()
        self._refresh_custom_lua_tab()
        self._theme_init()
        self._update_file_ui()
        self.status.set_text(
            f"New empty layout → {os.path.basename(self.save_path)}"
        )

    # ── INIT ──

    def _init_empty(self):
        """Start by loading the live widget.lua if present, else an empty
        in-memory template (nothing is written to disk until the first edit)."""
        src = WIDGET_LUA if os.path.exists(WIDGET_LUA) else MAIN_LUA
        if src and os.path.exists(src):
            self._reload(src)
            return
        scratch = os.path.join(WORK_DIR, "empty_widget.lua")
        with open(scratch, "w") as f:
            f.write(_empty_widget_lua())
        self.draw_list, self.groups, self.views, self.padding = parse_widget_lua(scratch)
        self._read_settings_from_file()
        self._load_themes()
        for item in self.draw_list:
            te.apply_theme(item)
        self.selected_index = None
        self.selected_group_index = None
        self.selected_view_index = None
        self._refresh_list()
        self._refresh_groups_list()
        self._refresh_views_list()
        self._clear_props()
        self._clear_grp_props()
        self._clear_views_props()
        self._refresh_view_combo()
        self._theme_init()
        self._update_padding_spin()
        self.conky_settings = self._default_conky_settings()
        self.conky_settings["minimum_width"] = self.window_width
        self.conky_settings["minimum_height"] = self.window_height
        self._refresh_conky_tab()
        self._populate_mouse_tab()
        self._refresh_weather_tab()
        self._refresh_custom_lua_tab()
        self._update_title()
        self._update_conky_state()
        self.status.set_text("Ready — use File > Open or add items")

    # ── RELOAD ──

    def _reload(self, src=None):
        if src is None:
            src = self.save_path
        if not os.path.exists(src):
            self.status.set_text(f"File not found: {src}")
            return
        self.save_path = src
        self.draw_list, self.groups, self.views, self.padding = parse_widget_lua(src)
        self._read_settings_from_file()

        # Load theme defaults so theme-default colors are visible in editor
        # and can be compared during save (skip identical values)
        self._load_themes()

        for item in self.draw_list:
            te.apply_theme(item)

        # Parse the sibling .conf (Conky Manager style) if it exists
        conf_path = os.path.splitext(src)[0] + ".conf"
        self.conky_settings = self._parse_conf(conf_path)
        self.window_width = int(self.conky_settings.get("minimum_width", 420))
        self.window_height = int(self.conky_settings.get("minimum_height", 1020))
        self._refresh_conky_tab()

        self.selected_index = None
        self.selected_group_index = None
        self.selected_view_index = None
        self._refresh_list()
        self._refresh_groups_list()
        self._refresh_views_list()
        self._clear_props()
        self._clear_grp_props()
        self._clear_views_props()
        self._refresh_view_combo()
        self._update_padding_spin()
        self._populate_mouse_tab()
        self._refresh_weather_tab()
        self._refresh_custom_lua_tab()
        self._theme_init()
        self._update_file_ui()
        self.status.set_text(
            f"Loaded {len(self.draw_list)} items, "
            f"{len(self.groups)} groups, {len(self.views)} views"
        )

    # ── PREVIEW ──

    def _read_settings_from_file(self):
        """Parse settings from the live file into instance attrs."""
        try:
            with open(self.save_path) as f:
                content = f.read()
            s = parse_settings(self.save_path)
            self.padding = s["padding"]
            self.current_theme = s["theme"]
            self.mouse_actions = parse_mouse_actions(content)
            for name, _ in MOUSE_ACTIONS:
                if name not in self.mouse_actions:
                    self.mouse_actions[name] = "nil"
            self.mouse_enabled = s["mouse_enabled"]
            self.weather_enabled = s["weather_enabled"]
            self.weather_icon_theme = s["weather_icon_theme"] or "default"
            self.xdg_icon_theme = s["xdg_icon_theme"] or ""
            m = re.search(r"--\{\{\{ custom_lua\n(.*?)\n--\}\}\} custom_lua",
                          content, re.DOTALL)
            self.custom_lua_code = m.group(1) if m else ""
        except FileNotFoundError:
            pass

    def _populate_mouse_tab(self):
        """Fill the Mouse tab with dropdown rows."""
        for child in self.mouse_box.get_children():
            self.mouse_box.remove(child)
        self.mouse_combos = {}

        funcs = [f for f in parse_mouse_functions()
                 if f not in ("switch_view", "view_toggle")]
        view_names = [v.get("name", "main") for v in self.views] or ["main"]

        for name, label in MOUSE_ACTIONS:
            hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            lab = Gtk.Label(label=label)
            lab.set_width_chars(18)
            lab.set_xalign(0)
            lab.set_markup(f'<small><b>{label}</b></small>')
            hbox.pack_start(lab, False, False, 0)

            combo = Gtk.ComboBoxText()
            ids = ["nil"]
            combo.append("nil", "— (none)")
            for fn in funcs:
                combo.append(fn, fn)
                ids.append(fn)
            for vn in view_names:
                val = f'function() switch_view("{vn}") end'
                combo.append(val, f"switch_view ({vn})")
                ids.append(val)
                val = f'function() view_toggle("{vn}") end'
                combo.append(val, f"view_toggle ({vn})")
                ids.append(val)

            current = self.mouse_actions.get(name, "nil")
            if current not in ids:
                combo.append(current, current)
                ids.append(current)
            combo.set_active(ids.index(current))
            combo.connect("changed", self._on_mouse_action_changed, name)
            hbox.pack_start(combo, True, True, 0)
            self.mouse_combos[name] = combo
            self.mouse_box.pack_start(hbox, False, False, 0)

        self.mouse_box.show_all()
        self._mouse_tab_views = tuple(v.get("name", "main") for v in self.views)
        self.mouse_enabled_check.set_active(self.mouse_enabled)
        self._sync_mouse_rows()

    def _sync_mouse_rows(self):
        for combo in self.mouse_combos.values():
            combo.set_sensitive(self.mouse_enabled)

    def _on_mouse_enabled_toggled(self, check):
        enabled = check.get_active()
        if enabled != self.mouse_enabled:
            self.mouse_enabled = enabled
            self._sync_mouse_rows()
            self._schedule_refresh()

    def _on_mouse_action_changed(self, combo, name):
        val = combo.get_active_id()
        if val is None:
            return
        if val != self.mouse_actions.get(name):
            self.mouse_actions[name] = val
            self._schedule_refresh()

    # ── GRADIENT TAB ──

    def _rgba(self, hexc):
        r, g, b = gg.hex_to_rgb(hexc)
        rgba = Gdk.RGBA()
        rgba.red, rgba.green, rgba.blue, rgba.alpha = r / 255, g / 255, b / 255, 1.0
        return rgba

    def _hex_from_rgba(self, rgba):
        return gg.rgb_to_hex(rgba.red * 255, rgba.green * 255, rgba.blue * 255)

    def _grad_data(self):
        stops = sorted((s[0], s[1], max(0.0, min(1.0, s[2]))) for s in self._grad_stops)
        mode = self.grad_mode.get_active_id() or "linear"
        n = int(self.grad_steps.get_value())
        return stops, mode, n

    def _grad_add_stop(self, *a):
        stops = self._grad_stops
        if len(stops) >= 16:
            self.status.set_text("Max 16 stop")
            return
        if not stops:
            stops.append([0.0, "#3daee9", 1.0])
        else:
            best_i, best_gap = 0, -1
            for i in range(len(stops) - 1):
                gap = stops[i + 1][0] - stops[i][0]
                if gap > best_gap:
                    best_i, best_gap = i, gap
            if best_gap > 0:
                pos = (stops[best_i][0] + stops[best_i + 1][0]) / 2
            else:
                pos = min(1.0, stops[-1][0] + 0.1)
            rgb = gg.sample_stops(stops, pos)
            stops.append([pos, gg.rgb_to_hex(rgb[0], rgb[1], rgb[2]), rgb[3]])
        self._rebuild_grad_stops()
        self._refresh_gradient()

    def _grad_remove_stop(self, btn, i):
        del self._grad_stops[i]
        self._rebuild_grad_stops()
        self._refresh_gradient()

    def _rebuild_grad_stops(self):
        for ch in self.grad_stops_box.get_children():
            self.grad_stops_box.remove(ch)
        self._grad_stop_widgets = []
        for i, (pos, hexc, alpha) in enumerate(self._grad_stops):
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            num = Gtk.Label(label="{}.".format(i + 1))
            num.set_width_chars(3)
            row.pack_start(num, False, False, 0)
            pos_spin = Gtk.SpinButton.new_with_range(0.0, 1.0, 0.01)
            pos_spin.set_value(pos)
            pos_spin.set_width_chars(5)
            color_btn = ColorPickButton()
            color_btn.set_rgba(self._rgba(hexc))
            alpha_spin = Gtk.SpinButton.new_with_range(0.0, 1.0, 0.05)
            alpha_spin.set_value(max(0.0, min(1.0, alpha)))
            rm = Gtk.Button(label="✕")
            pos_spin.connect("value-changed", self._grad_stop_edited, i)
            color_btn.connect("color-set", self._grad_stop_edited, i)
            alpha_spin.connect("value-changed", self._grad_stop_edited, i)
            rm.connect("clicked", self._grad_remove_stop, i)
            row.pack_start(pos_spin, False, False, 0)
            row.pack_start(color_btn, False, False, 0)
            row.pack_start(alpha_spin, False, False, 0)
            row.pack_start(rm, False, False, 0)
            self.grad_stops_box.pack_start(row, False, False, 0)
            self._grad_stop_widgets.append((pos_spin, color_btn, alpha_spin))
        self.grad_stops_box.show_all()

    def _grad_stop_edited(self, widget, i):
        if i >= len(self._grad_stop_widgets):
            return
        pos_spin, color_btn, alpha_spin = self._grad_stop_widgets[i]
        rgba = color_btn.get_rgba()
        self._grad_stops[i] = [pos_spin.get_value(), self._hex_from_rgba(rgba), alpha_spin.get_value()]
        self._refresh_gradient()

    def _grad_changed(self, *a):
        self._refresh_gradient()

    def _refresh_gradient(self):
        self.grad_preview.queue_draw()
        self.grad_swatch.queue_draw()
        self.shades_swatch.queue_draw()
        stops, mode, n = self._grad_data()
        self.grad_output.set_text(gg.format_lua_stops(stops))
        self.status.set_text("Gradient: {} stop, {}, {} steps".format(len(stops), mode, n))

    def _on_grad_preview_draw(self, widget, cr):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        stops, mode, _ = self._grad_data()
        if not stops:
            return
        for x in range(w):
            t = x / (w - 1) if w > 1 else 0
            r, g, b, a = gg.sample_stops(stops, t, mode)
            cr.set_source_rgba(r / 255, g / 255, b / 255, a)
            cr.rectangle(x, 0, 1, h)
            cr.fill()

    def _on_grad_swatch_draw(self, widget, cr):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        stops, mode, n = self._grad_data()
        swatches = gg.discrete_swatches(stops, n, mode)
        if not swatches:
            return
        sw = w / len(swatches)
        for i, (r, g, b, a) in enumerate(swatches):
            cr.set_source_rgba(r / 255, g / 255, b / 255, a)
            cr.rectangle(i * sw, 0, sw + 1, h)
            cr.fill()

    def _shades_data(self):
        rgba = self.shades_color.get_rgba()
        return self._hex_from_rgba(rgba), int(self.shades_steps.get_value())

    def _on_shades_draw(self, widget, cr):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        hexc, steps = self._shades_data()
        cols = gg.shade_colors(hexc, steps)
        sw = w / len(cols)
        for i, (r, g, b, a) in enumerate(cols):
            cr.set_source_rgba(r / 255, g / 255, b / 255, a)
            cr.rectangle(i * sw, 0, sw + 1, h)
            cr.fill()

    def _grad_copy_lua(self, *a):
        stops, mode, n = self._grad_data()
        Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).set_text(gg.format_lua_stops(stops), -1)
        self.status.set_text("Lua stops on clipboard")

    def _grad_copy_palette(self, *a):
        stops, mode, n = self._grad_data()
        swatches = gg.discrete_swatches(stops, n, mode)
        Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).set_text(gg.format_hex_palette(swatches), -1)
        self.status.set_text("Hex palette on clipboard")

    def _grad_copy_shades(self, *a):
        hexc, steps = self._shades_data()
        cols = gg.shade_colors(hexc, steps)
        Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD).set_text(gg.format_hex_palette(cols), -1)
        self.status.set_text("Shades on clipboard")

    # ── THEME EDITOR TAB ──

    def _theme_palette(self):
        theme = te.THEMES.get(self._theme_editing)
        if not theme:
            return {}
        return theme.setdefault("palette", {})

    def _theme_gradients(self):
        theme = te.THEMES.get(self._theme_editing)
        if not theme:
            return {}
        return theme.setdefault("gradients", {})

    def _theme_defaults(self):
        theme = te.THEMES.get(self._theme_editing)
        if not theme:
            return {}
        return theme.setdefault("defaults", {})

    def _theme_init(self):
        self._theme_editing = THEME_NAME
        self._theme_sel_gradient = None
        self._theme_sel_type = None
        self._theme_rebuild_all()

    def _theme_rebuild_all(self):
        self._theme_rebuild_palette()
        self._theme_rebuild_gradients()
        self._theme_rebuild_defaults()
        self._theme_update_meta()

    def _theme_update_meta(self):
        theme = te.THEMES.get(self._theme_editing)
        if not theme:
            return
        pal = theme.get("palette", {})
        grad = theme.get("gradients", {})
        defs = theme.get("defaults", {})
        self.theme_edit_info.set_text(
            "palette: {} colors · gradients: {} · defaults: {} types — saved with Save".format(
                len(pal), len(grad), len(defs)
            )
        )

    def _theme_edit_changed(self):
        pv = getattr(self, "_theme_grad_preview", None)
        if pv is not None:
            pv.queue_draw()
        self._schedule_refresh()
        self._theme_update_meta()

    # ── stop editor helpers ──

    def _theme_stops_rows(self, container, stops, changed_cb):
        """Rebuild `container` with one row per stop in `stops` (mutable list of lists)."""
        for ch in container.get_children():
            container.remove(ch)
        for i, s in enumerate(stops):
            if not isinstance(s, list):
                stops[i] = s = list(s)
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            pos_spin = Gtk.SpinButton.new_with_range(0.0, 1.0, 0.01)
            pos_spin.set_value(float(s[0]))
            pos_spin.set_width_chars(5)
            color_btn = ColorPickButton()
            color_btn.set_rgba(self._rgba(str(s[1])))
            alpha_spin = Gtk.SpinButton.new_with_range(0.0, 1.0, 0.05)
            alpha_spin.set_value(float(s[2]))
            rm = Gtk.Button(label="✕")

            def on_pos(w, spin=pos_spin, idx=i):
                stops[idx][0] = spin.get_value()
                changed_cb()

            def on_color(w, btn=color_btn, idx=i):
                rgba = btn.get_rgba()
                stops[idx][1] = self._hex_from_rgba(rgba)
                changed_cb()

            def on_alpha(w, spin=alpha_spin, idx=i):
                stops[idx][2] = spin.get_value()
                changed_cb()

            def on_rm(w, idx=i, cont=container):
                del stops[idx]
                self._theme_stops_rows(cont, stops, changed_cb)
                changed_cb()

            pos_spin.connect("value-changed", on_pos)
            color_btn.connect("color-set", on_color)
            alpha_spin.connect("value-changed", on_alpha)
            rm.connect("clicked", on_rm)
            row.pack_start(pos_spin, False, False, 0)
            row.pack_start(color_btn, False, False, 0)
            row.pack_start(alpha_spin, False, False, 0)
            row.pack_start(rm, False, False, 0)
            container.pack_start(row, False, False, 0)
        container.show_all()

    def _theme_field_block(self, label_text, stops, changed_cb, on_delete=None):
        """Labeled block: header (+ delete / add buttons) + stop rows."""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        lbl = Gtk.Label(label=label_text)
        lbl.set_xalign(0)
        lbl.set_markup("<small><b>{}</b></small>".format(label_text))
        hdr.pack_start(lbl, True, True, 0)
        if on_delete is not None:
            rm = Gtk.Button(label="✕")
            rm.set_relief(Gtk.ReliefStyle.NONE)
            rm.connect("clicked", on_delete)
            hdr.pack_start(rm, False, False, 0)
        add = Gtk.Button(label="+")
        add.set_relief(Gtk.ReliefStyle.NONE)
        hdr.pack_start(add, False, False, 0)
        box.pack_start(hdr, False, False, 0)
        rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        box.pack_start(rows, False, False, 0)
        self._theme_stops_rows(rows, stops, changed_cb)

        def on_add(w, rbox=rows, st=stops):
            if not st:
                st.append([1.0, "#ffffff", 1.0])
            else:
                best_i, best_gap = 0, -1
                for i in range(len(st) - 1):
                    gap = st[i + 1][0] - st[i][0]
                    if gap > best_gap:
                        best_i, best_gap = i, gap
                if best_gap > 0:
                    pos = (st[best_i][0] + st[best_i + 1][0]) / 2
                else:
                    pos = min(1.0, st[-1][0] + 0.1)
                rgb = gg.sample_stops(st, pos)
                st.append([pos, gg.rgb_to_hex(rgb[0], rgb[1], rgb[2]), rgb[3]])
            self._theme_stops_rows(rbox, st, changed_cb)
            changed_cb()

        add.connect("clicked", on_add)
        return box

    # ── palette ──

    def _theme_pal_add(self, btn):
        pal = self._theme_palette()
        i = 1
        while "color{}".format(i) in pal:
            i += 1
        pal["color{}".format(i)] = "#ffffff"
        self._theme_rebuild_palette()
        self._theme_edit_changed()

    def _theme_rebuild_palette(self):
        for ch in self.theme_pal_box.get_children():
            self.theme_pal_box.remove(ch)
        pal = self._theme_palette()
        for key, hexc in list(pal.items()):
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            key_entry = Gtk.Entry()
            key_entry.set_text(str(key))
            key_entry.set_width_chars(16)
            color_btn = ColorPickButton()
            color_btn.set_rgba(self._rgba(hexc))
            rm = Gtk.Button(label="✕")
            key_entry.connect("activate", self._theme_pal_rename, key)
            color_btn.connect("color-set", self._theme_pal_change, key_entry, key)
            rm.connect("clicked", self._theme_pal_remove, key_entry, key)
            row.pack_start(key_entry, False, False, 0)
            row.pack_start(color_btn, False, False, 0)
            row.pack_start(rm, False, False, 0)
            self.theme_pal_box.pack_start(row, False, False, 0)
        self.theme_pal_box.show_all()

    def _theme_pal_change(self, color_btn, key_entry, orig_key):
        key = key_entry.get_text().strip() or orig_key
        pal = self._theme_palette()
        if key not in pal:
            pal[key] = pal.get(orig_key, "#ffffff")
        rgba = color_btn.get_rgba()
        pal[key] = self._hex_from_rgba(rgba)
        self._theme_edit_changed()

    def _theme_pal_rename(self, entry, orig_key):
        new = entry.get_text().strip()
        pal = self._theme_palette()
        if not new or new == orig_key:
            entry.set_text(str(orig_key))
            return
        if new in pal:
            self.status.set_text("Palette '{}' already exists".format(new))
            entry.set_text(str(orig_key))
            return
        pal[new] = pal.pop(orig_key)
        self._theme_edit_changed()

    def _theme_pal_remove(self, btn, key_entry, orig_key):
        key = key_entry.get_text().strip() or orig_key
        pal = self._theme_palette()
        if key in pal:
            del pal[key]
        self._theme_rebuild_palette()
        self._theme_edit_changed()

    # ── gradients ──

    def _theme_grad_add(self, btn):
        grad = self._theme_gradients()
        i = 1
        while "gradient{}".format(i) in grad:
            i += 1
        name = "gradient{}".format(i)
        grad[name] = [[0.0, "#7aa2f7", 1.0], [1.0, "#bb9af7", 1.0]]
        self._theme_sel_gradient = name
        self._theme_rebuild_gradients()
        self._theme_edit_changed()

    def _on_theme_grad_select(self, selection):
        model, tree_iter = selection.get_selected()
        if tree_iter:
            gname = model[tree_iter][0]
            if gname != self._theme_sel_gradient:
                self._theme_sel_gradient = gname
                self._theme_build_gradient_editor()

    def _theme_rebuild_gradients(self):
        self.theme_grad_liststore.clear()
        grad = self._theme_gradients()
        for gname in grad:
            self.theme_grad_liststore.append([gname])
        if self._theme_sel_gradient not in grad:
            self._theme_sel_gradient = None
        if self._theme_sel_gradient:
            for row in self.theme_grad_liststore:
                if row[0] == self._theme_sel_gradient:
                    self.theme_grad_tree.get_selection().select_iter(row.iter)
                    break
        self._theme_build_gradient_editor()

    def _theme_build_gradient_editor(self):
        box = self.theme_grad_editor_box
        for ch in box.get_children():
            box.remove(ch)
        if self._theme_sel_gradient is None:
            lbl = Gtk.Label(label="Select a gradient from the list")
            lbl.set_line_wrap(True)
            lbl.set_max_width_chars(40)
            box.pack_start(lbl, False, False, 0)
            box.show_all()
            return

        gname = self._theme_sel_gradient
        grad = self._theme_gradients()
        stops = grad.get(gname)
        if not isinstance(stops, list):
            stops = []
            grad[gname] = stops
        for i, s in enumerate(stops):
            if not isinstance(s, list):
                stops[i] = list(s)

        name_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        name_row.pack_start(Gtk.Label(label="Name:"), False, False, 0)
        name_entry = Gtk.Entry()
        name_entry.set_text(gname)
        name_entry.set_hexpand(True)
        name_entry.connect("activate", self._theme_grad_rename, gname)
        name_row.pack_start(name_entry, True, True, 0)
        del_btn = Gtk.Button(label="Delete gradient")
        del_btn.connect("clicked", self._theme_grad_delete)
        name_row.pack_start(del_btn, False, False, 0)
        box.pack_start(name_row, False, False, 0)

        self._theme_grad_preview = Gtk.DrawingArea()
        self._theme_grad_preview.set_size_request(-1, 26)
        self._theme_grad_preview.connect("draw", self._on_theme_grad_preview_draw)
        box.pack_start(self._theme_grad_preview, False, False, 0)

        block = self._theme_field_block("Stops", stops, self._theme_edit_changed)
        box.pack_start(block, False, False, 0)
        box.show_all()

    def _on_theme_grad_preview_draw(self, widget, cr):
        w = widget.get_allocated_width()
        h = widget.get_allocated_height()
        if self._theme_sel_gradient is None:
            return
        stops = self._theme_gradients().get(self._theme_sel_gradient) or []
        if not stops:
            return
        for x in range(w):
            t = x / (w - 1) if w > 1 else 0
            r, g, b, a = gg.sample_stops(stops, t)
            cr.set_source_rgba(r / 255, g / 255, b / 255, a)
            cr.rectangle(x, 0, 1, h)
            cr.fill()

    def _theme_grad_rename(self, entry, old):
        new = entry.get_text().strip()
        grad = self._theme_gradients()
        if not new or new == old:
            entry.set_text(old)
            return
        if new in grad:
            self.status.set_text("Gradient '{}' already exists".format(new))
            entry.set_text(old)
            return
        grad[new] = grad.pop(old)
        self._theme_sel_gradient = new
        self._theme_rebuild_gradients()
        self._theme_edit_changed()

    def _theme_grad_delete(self, btn):
        if self._theme_sel_gradient is None:
            return
        del self._theme_gradients()[self._theme_sel_gradient]
        self._theme_sel_gradient = None
        self._theme_rebuild_gradients()
        self._theme_edit_changed()

    # ── defaults ──

    def _theme_defs_add_type(self, btn):
        defs = self._theme_defaults()
        dialog = Gtk.Dialog(title="Add Widget Type", transient_for=self, modal=True)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Add", Gtk.ResponseType.OK)
        box = dialog.get_content_area()
        box.set_spacing(8)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(12)
        box.add(Gtk.Label(label="Type name:"))
        entry = Gtk.Entry()
        entry.set_text("type{}".format(len(defs)))
        box.add(entry)
        dialog.show_all()
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            name = entry.get_text().strip()
            if name and name not in defs:
                defs[name] = {}
                self._theme_sel_type = name
                self._theme_rebuild_defaults()
                self._theme_edit_changed()
            elif name in defs:
                self.status.set_text("Type '{}' already exists".format(name))
        dialog.destroy()

    def _on_theme_defs_select(self, selection):
        model, tree_iter = selection.get_selected()
        if tree_iter:
            t = model[tree_iter][0]
            if t != self._theme_sel_type:
                self._theme_sel_type = t
                self._theme_build_defaults_editor()

    def _theme_rebuild_defaults(self):
        self.theme_defs_liststore.clear()
        defs = self._theme_defaults()
        for t in defs:
            self.theme_defs_liststore.append([t])
        if self._theme_sel_type not in defs:
            self._theme_sel_type = None
        if self._theme_sel_type:
            for row in self.theme_defs_liststore:
                if row[0] == self._theme_sel_type:
                    self.theme_defs_tree.get_selection().select_iter(row.iter)
                    break
        self._theme_build_defaults_editor()

    def _theme_build_defaults_editor(self):
        box = self.theme_defs_editor_box
        for ch in box.get_children():
            box.remove(ch)
        if self._theme_sel_type is None:
            lbl = Gtk.Label(label="Select a widget type from the list")
            lbl.set_line_wrap(True)
            lbl.set_max_width_chars(40)
            box.pack_start(lbl, False, False, 0)
            box.show_all()
            return

        wtype = self._theme_sel_type
        defs = self._theme_defaults()
        fields = defs.get(wtype)
        if not isinstance(fields, dict):
            fields = {}
            defs[wtype] = fields

        hdr = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        title = Gtk.Label(label=wtype)
        title.set_markup("<small><b>{}</b></small>".format(wtype))
        hdr.pack_start(title, True, True, 0)
        add_field = Gtk.Button(label="+ Field")
        add_field.connect("clicked", self._theme_defs_add_field)
        hdr.pack_start(add_field, False, False, 0)
        del_type = Gtk.Button(label="Delete type")
        del_type.connect("clicked", self._theme_defs_delete_type)
        hdr.pack_start(del_type, False, False, 0)
        box.pack_start(hdr, False, False, 0)

        for k, v in fields.items():
            if isinstance(v, (list, tuple)):
                stops = v if isinstance(v, list) else list(v)
                fields[k] = stops
                block = self._theme_field_block(
                    k, stops, self._theme_edit_changed,
                    on_delete=lambda b, key=k: self._theme_defs_remove_field(key),
                )
                box.pack_start(block, False, False, 0)
            elif isinstance(v, (int, float)):
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
                lbl = Gtk.Label(label=k)
                lbl.set_width_chars(12)
                lbl.set_xalign(0)
                row.pack_start(lbl, False, False, 0)
                spin = Gtk.SpinButton.new_with_range(0, 999, 1)
                spin.set_value(float(v))

                def on_num(w, sp=spin, key=k):
                    fields[key] = sp.get_value()
                    self._theme_edit_changed()

                spin.connect("value-changed", on_num)
                row.pack_start(spin, False, False, 0)
                box.pack_start(row, False, False, 0)
            elif isinstance(v, str):
                row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
                lbl = Gtk.Label(label=k)
                lbl.set_width_chars(12)
                lbl.set_xalign(0)
                row.pack_start(lbl, False, False, 0)
                entry = Gtk.Entry()
                entry.set_text(v)
                entry.set_hexpand(True)
                entry.connect("activate", self._theme_defs_set_str, k)
                row.pack_start(entry, True, True, 0)
                box.pack_start(row, False, False, 0)
        box.show_all()

    def _theme_defs_set_str(self, entry, key):
        fields = self._theme_defaults().get(self._theme_sel_type)
        if fields is not None:
            fields[key] = entry.get_text().strip()
            self._theme_edit_changed()

    def _theme_defs_add_field(self, btn):
        if self._theme_sel_type is None:
            return
        fields = self._theme_defaults().get(self._theme_sel_type)
        if not isinstance(fields, dict):
            fields = {}
            self._theme_defaults()[self._theme_sel_type] = fields
        dialog = Gtk.Dialog(title="Add Field", transient_for=self, modal=True)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Add", Gtk.ResponseType.OK)
        box = dialog.get_content_area()
        box.set_spacing(8)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(12)
        box.add(Gtk.Label(label="Field name:"))
        entry = Gtk.Entry()
        entry.set_text("color{}".format(len(fields)))
        box.add(entry)
        dialog.show_all()
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            key = entry.get_text().strip()
            if key and key not in fields:
                fields[key] = [[1.0, "#ffffff", 1.0]]
                self._theme_build_defaults_editor()
                self._theme_edit_changed()
            elif key in fields:
                self.status.set_text("Field '{}' already exists".format(key))
        dialog.destroy()

    def _theme_defs_remove_field(self, key):
        defs = self._theme_defaults()
        if self._theme_sel_type in defs and key in defs[self._theme_sel_type]:
            del defs[self._theme_sel_type][key]
        self._theme_build_defaults_editor()
        self._theme_edit_changed()

    def _theme_defs_delete_type(self, btn):
        if self._theme_sel_type is None:
            return
        del self._theme_defaults()[self._theme_sel_type]
        self._theme_sel_type = None
        self._theme_rebuild_defaults()
        self._theme_edit_changed()

    # ── theme save / duplicate / delete ──
    # (single theme: no separate themes.lua file — edits are written into
    # widget.lua by Save, so there is nothing to save/duplicate/delete here)

    # ── PNG CAPTURE (from the running conky's own surface) ──

    def _request_capture(self, view, out_path):
        """Ask the running conky to draw one frame of `view` and save the
        whole surface to `out_path` (see lua/core/capture.lua)."""
        req = os.path.join(CONKY_DIR, "tmp", "capture_request")
        try:
            os.makedirs(os.path.dirname(req), exist_ok=True)
            with open(req + ".tmp", "w") as f:
                f.write(f"{view}\n{out_path}\n")
            os.replace(req + ".tmp", req)
            return True
        except OSError as e:
            self.status.set_text(f"Capture request failed: {e}")
            return False

    def _export_pngs(self, lua_path):
        """Capture each view to a PNG next to the saved .lua file.

        Runs on the GLib loop (non-blocking): the request goes to a file
        conky polls every frame, and we watch for the output PNG to appear."""
        if not self.views:
            return
        if not self._ours_running():
            if not self._conky_start():
                return
        base, _ = os.path.splitext(lua_path)
        self._capture_queue = []
        for view in self.views:
            name = view.get("name", "main")
            out = base + ("" if name == "main" else f"_{name}") + ".png"
            try:
                os.remove(out)  # force a fresh capture, not a stale match
            except OSError:
                pass
            self._capture_queue.append({
                "view": name,
                "out": out,
                "requested": False,
                "tries": 0,
            })
        self.status.set_text("Exporting PNGs…")
        if self._capture_poll_id is None:
            self._capture_poll_id = GLib.timeout_add(400, self._capture_step)

    def _capture_step(self):
        if not self._capture_queue:
            self._capture_poll_id = None
            self.status.set_text("PNG export done")
            return GLib.SOURCE_REMOVE
        item = self._capture_queue[0]
        if os.path.exists(item["out"]):
            activity_log.add(
                "Capture", f"view '{item['view']}' → {os.path.basename(item['out'])}"
            )
            self._capture_queue.pop(0)
            return GLib.SOURCE_CONTINUE
        if not item["requested"]:
            if self._request_capture(item["view"], item["out"]):
                item["requested"] = True
            else:
                self._capture_queue.pop(0)
                return GLib.SOURCE_CONTINUE
        item["tries"] += 1
        if item["tries"] > 30:  # ~12s
            activity_log.add(
                "Capture", f"view '{item['view']}' timed out"
            )
            self._capture_queue.pop(0)
        return GLib.SOURCE_CONTINUE

    def _on_view_changed(self, combo):
        self.current_view = combo.get_active_text() or "main"
        self._refresh_list()

    def _load_themes(self):
        """Load the THEMES block from the current live file into te.THEMES."""
        try:
            te.load_themes(self.save_path)
        except Exception:
            te.THEMES = {THEME_NAME: _FALLBACK_THEME}
        te.THEMES.setdefault(THEME_NAME, _FALLBACK_THEME)
        return te.THEMES

    # ── Conky settings (.conf) support ──────────────────────────────────────

    @staticmethod
    def _default_conky_settings():
        return {
            "gap_x": "",
            "gap_y": "",
            "alignment": "top_left",
            "own_window_hints": "below,sticky,skip_taskbar,skip_pager",
            "own_window_type": "normal",
            "minimum_width": 420,
            "minimum_height": 1020,
        }

    def _on_conky_changed(self, *_):
        if not getattr(self, "_conky_loading", False):
            self._read_conky_from_widgets()
            self._set_dirty()
            self._schedule_refresh()

    def _on_conky_size_changed(self, *_):
        if not getattr(self, "_conky_loading", False):
            self._read_conky_from_widgets()
            self.window_width = int(self.conky_min_w_spin.get_value())
            self.window_height = int(self.conky_min_h_spin.get_value())
            self._set_dirty()
            self._schedule_refresh()

    # ── CUSTOM LUA TAB ──

    def _on_custom_lua_changed(self, buf):
        if self._custom_lua_loading:
            return
        start, end = buf.get_bounds()
        self.custom_lua_code = buf.get_text(start, end, True)
        self._set_dirty()
        self._schedule_refresh()

    def _refresh_custom_lua_tab(self):
        self._custom_lua_loading = True
        try:
            buf = self.custom_lua_view.get_buffer()
            buf.set_text(self.custom_lua_code)
        finally:
            self._custom_lua_loading = False

    # ── WEATHER & ICONS TAB ──

    def _refresh_weather_tab(self):
        self._weather_loading = True
        try:
            self.weather_enabled_check.set_active(self.weather_enabled)
            theme = self.weather_icon_theme if self.weather_icon_theme in WEATHER_ICON_SETS else "default"
            idx = max(0, WEATHER_ICON_SETS.index(theme))
            self.weather_icon_combo.set_active(idx)
            self.weather_icon_combo.set_sensitive(self.weather_enabled)
            xdg = self.xdg_icon_theme
            xdg_idx = 0
            for i, t in enumerate(self.xdg_icon_combo.get_model()):
                if t[0] == xdg:
                    xdg_idx = i
                    break
            self.xdg_icon_combo.set_active(xdg_idx)
        finally:
            self._weather_loading = False

    def _on_weather_enabled_toggled(self, check):
        enabled = check.get_active()
        if enabled != self.weather_enabled:
            self.weather_enabled = enabled
            self.weather_icon_combo.set_sensitive(enabled)
            self._set_dirty()

    def _on_weather_icon_changed(self, combo):
        if not self._weather_loading:
            self.weather_icon_theme = combo.get_active_text() or "default"
            self._set_dirty()

    def _on_xdg_icon_changed(self, combo):
        if not self._weather_loading:
            self.xdg_icon_theme = combo.get_active_id() or ""
            self._set_dirty()

    def _read_conky_from_widgets(self):
        s = self.conky_settings
        s["gap_x"] = self.conky_x_entry.get_text().strip()
        s["gap_y"] = self.conky_y_entry.get_text().strip()
        s["alignment"] = self.conky_align_combo.get_active_text() or "top_left"
        s["own_window_hints"] = self.conky_hints_entry.get_text().strip()
        s["own_window_type"] = self.conky_type_combo.get_active_text() or "normal"
        s["minimum_width"] = int(self.conky_min_w_spin.get_value())
        s["minimum_height"] = int(self.conky_min_h_spin.get_value())

    def _refresh_conky_tab(self):
        self._conky_loading = True
        s = self.conky_settings
        try:
            self.conky_x_entry.set_text(str(s.get("gap_x", "")))
            self.conky_y_entry.set_text(str(s.get("gap_y", "")))
            align = s.get("alignment", "top_left")
            idx = 0
            model = self.conky_align_combo.get_model()
            for i, row in enumerate(model):
                if row[0] == align:
                    idx = i
                    break
            self.conky_align_combo.set_active(idx)
            self.conky_hints_entry.set_text(s.get("own_window_hints", ""))
            wtype = s.get("own_window_type", "normal")
            idx = 0
            model = self.conky_type_combo.get_model()
            for i, row in enumerate(model):
                if row[0] == wtype:
                    idx = i
                    break
            self.conky_type_combo.set_active(idx)
            self.conky_min_w_spin.set_value(int(s.get("minimum_width", 420)))
            self.conky_min_h_spin.set_value(int(s.get("minimum_height", 1020)))
        finally:
            self._conky_loading = False

    @staticmethod
    def _parse_conf(path):
        """Parse a Conky Manager .conf into a conky_settings dict."""
        s = DesignerWindow._default_conky_settings()
        try:
            with open(path) as f:
                text = f.read()
        except OSError:
            return s
        for line in text.splitlines():
            m = re.match(r"^\s*(\w+)\s*=\s*(.+?)\s*,?\s*$", line)
            if not m:
                continue
            key, val = m.group(1), m.group(2).strip().strip("'").strip('"')
            if key == "alignment":
                s["alignment"] = val
            elif key == "own_window_hints":
                s["own_window_hints"] = val
            elif key == "own_window_type":
                s["own_window_type"] = val
            elif key in ("gap_x", "gap_y", "x", "y", "minimum_width", "minimum_height"):
                try:
                    # legacy x/y (old designer output) → gap_x/gap_y
                    target = "gap_" + key if key in ("x", "y") else key
                    s[target] = int(float(val))
                except ValueError:
                    pass
        return s

    @staticmethod
    def _generate_conf(basename, s, lua_file, weather_enabled=False):
        """Build the .conf text for Conky Manager (references <lua_file>)."""
        lines = [
            f"-- {basename} — generated by the NextGen Designer",
            f"-- Conky Manager triplet: {basename}.conf + {lua_file} + {basename}.png",
            "",
            "conky.config = {",
            "  background = true,",
            "  out_to_x = true,",
            "  out_to_wayland = true,",
            "  double_buffer = true,",
            "  use_xft = true,",
            "  font = 'Sans:size=10',",
            "  own_window = true,",
            "  own_window_type = '{}',".format(s.get("own_window_type", "normal")),
            "  own_window_hints = '{}',".format(s.get("own_window_hints", "below,sticky,skip_taskbar,skip_pager")),
            "  alignment = '{}',".format(s.get("alignment", "top_left")),
        ]
        for key in ("gap_x", "gap_y"):
            val = s.get(key)
            if val not in (None, ""):
                try:
                    lines.append(f"  {key} = {int(float(val))},")
                except (ValueError, TypeError):
                    lines.append(f"  -- {key} = '{val}' skipped (non-numeric)")
        lines += [
            "  update_interval = 1,",
            "  total_run_times = 0,",
            "  minimum_width = {},".format(int(s.get("minimum_width", 420))),
            "  minimum_height = {},".format(int(s.get("minimum_height", 1020))),
        ]
        lines += [
            "  border_inner_margin = 0,",
            "  border_outer_margin = 0,",
            "  border_width = 0,",
            f"  lua_load = '{lua_file}',",
            "  lua_draw_hook_pre = 'conky_core_main',",
            "  lua_mouse_hook = 'conky_on_mouse',",
            "  lua_shutdown_hook = 'conky_cleanup',",
            "}",
            "",
            "conky.text = [[",
        ]
        if weather_enabled:
            lines.append("  ${lua conky_weather_update}")
        lines += [
            "]]",
            "",
        ]
        return "\n".join(lines)

    def _update_padding_spin(self):
        self.padding_spin.disconnect_by_func(self._on_padding_changed)
        self.padding_spin.set_value(self.padding)
        self.padding_spin.connect("value-changed", self._on_padding_changed)

    def _on_padding_changed(self, spin):
        self.padding = int(spin.get_value())
        self._schedule_refresh()

    def _refresh_view_combo(self):
        prev = self.current_view
        self.view_combo.disconnect_by_func(self._on_view_changed)
        self.view_combo.remove_all()
        # "main" is always present (also stored in self.views), avoid duplicates
        view_names = ["main"]
        self.view_combo.append_text("main")
        for v in self.views:
            name = v.get("name", "")
            if name and name not in view_names:
                view_names.append(name)
                self.view_combo.append_text(name)
        # preserve the current view across refreshes (e.g. property save),
        # fall back to "main" only if it no longer exists
        if prev in view_names:
            self.view_combo.set_active(view_names.index(prev))
            self.current_view = prev
        else:
            self.view_combo.set_active(0)
            self.current_view = "main"
        self.view_combo.connect("changed", self._on_view_changed)

    # ── ITEMS LIST (filtered by view, sorted by group) ──

    def _items_for_view(self):
        """Return draw_list indices visible in current view (matches Lua draw_allowed)."""
        indices = []
        for i, item in enumerate(self.draw_list):
            gname = item.get("group")
            iv = item.get("view") or ""
            ivs = [v.strip() for v in str(iv).split(",") if v.strip()]
            # If the item specifies views, it's only visible in those views
            if ivs and self.current_view not in ivs:
                continue
            if not gname:
                indices.append(i)
                continue
            for g in self.groups:
                if g.get("name") == gname:
                    if self.current_view == "main" or self.current_view in g.get("views", []):
                        indices.append(i)
                    break
        return indices

    def _refresh_list(self):
        self.liststore.clear()
        self.view_item_map = {}
        visible = self._items_for_view()

        # Sort by group then by original index
        def sort_key(idx):
            g = self.draw_list[idx].get("group", "")
            return (g, idx)
        visible.sort(key=sort_key)

        row = 0
        for idx in visible:
            item = self.draw_list[idx]
            t = item.get("type", "?")
            g = item.get("group", "-")
            self.liststore.append([idx, t, g, _item_summary(item)])
            self.view_item_map[row] = idx
            row += 1

    def _on_list_select(self, selection):
        model, tree_iter = selection.get_selected()
        if tree_iter:
            draw_idx = model[tree_iter][0]
            if 0 <= draw_idx < len(self.draw_list):
                self.selected_index = draw_idx
                item = self.draw_list[draw_idx]
                if isinstance(item, RawBlock):
                    self.status.set_text(
                        f"[{draw_idx}] raw Lua block (for-loop — not editable)")
                    self._clear_props()
                    return
                self.status.set_text(
                    f"[{draw_idx}] {item.get('type')} "
                    f"group={item.get('group', '-')}"
                )
                self._populate_props(item)
            else:
                self.selected_index = None

    def _on_list_activate(self, treeview, path, column):
        """Double-click a list row → open the properties window."""
        self._open_prop_window()

    def _select_item_by_index(self, draw_idx):
        """Select an item in the tree view by draw_list index."""
        path = None
        for row_idx, stored_idx in self.view_item_map.items():
            if stored_idx == draw_idx:
                path = Gtk.TreePath.new_from_indices([row_idx])
                break
        if path:
            self.treeview.get_selection().select_path(path)
            self.treeview.scroll_to_cell(path, None, True, 0.5, 0)

    # ── PROPERTIES ──

    def _build_prop_window(self):
        """Create the separate widget-properties window (edits apply live,
        closing it saves)."""
        win = Gtk.Window(title="Widget properties")
        win.set_transient_for(self)
        win.set_default_size(*_clamp_size(430, 700))
        win.set_resizable(True)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        vbox.set_margin_start(8)
        vbox.set_margin_end(8)
        vbox.set_margin_top(8)
        vbox.set_margin_bottom(8)
        win.add(vbox)

        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        vbox.pack_start(top, False, False, 0)
        btn_add_prop = Gtk.Button(label="+ Prop")
        btn_add_prop.set_tooltip_text("Add a custom property")
        btn_add_prop.connect("clicked", lambda _: self._add_property())
        top.pack_end(btn_add_prop, False, False, 0)

        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        vbox.pack_start(sw, True, True, 0)

        self.prop_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.prop_box.set_margin_start(4)
        self.prop_box.set_margin_end(4)
        sw.add(self.prop_box)

        save_btn = Gtk.Button(label="Save & Close")
        save_btn.set_tooltip_text("Save the widget properties and close this window")
        save_btn.connect("clicked", self._on_prop_win_close)
        vbox.pack_end(save_btn, False, False, 0)

        win.connect("delete-event", self._on_prop_win_delete)
        win.connect("destroy", self._on_prop_win_destroyed)
        self.prop_win = win

    def _open_prop_window(self):
        item = self._selected_item()
        if item is None:
            self.status.set_text("Select an item first")
            return
        if self.prop_win is None:
            self._build_prop_window()
        self._populate_props(item)
        self.prop_win.show_all()
        self.prop_win.present()

    def _on_prop_win_delete(self, window, event):
        self._save_and_refresh()
        GLib.idle_add(lambda: window.destroy())
        return True

    def _on_prop_win_close(self, button):
        self._save_and_refresh()
        if self.prop_win is not None:
            win = self.prop_win
            GLib.idle_add(lambda: win.destroy())

    def _on_prop_win_destroyed(self, window):
        self.prop_win = None

    # ── LIVE LOG WINDOW ──

    def _open_log_window(self):
        if self.log_win is not None:
            self.log_win.present()
            return
        win = Gtk.Window(title="Developer Console")
        win.set_transient_for(self)
        win.set_default_size(*_clamp_size(640, 420))
        win.set_resizable(True)
        win.connect("destroy", self._on_log_win_destroyed)

        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        vbox.set_margin_start(8)
        vbox.set_margin_end(8)
        vbox.set_margin_top(8)
        vbox.set_margin_bottom(8)
        win.add(vbox)

        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        vbox.pack_start(top, False, False, 0)
        clear_btn = Gtk.Button(label="Clear")
        clear_btn.set_tooltip_text("Empty the log")
        clear_btn.connect("clicked", lambda _b: self._log_clear())
        top.pack_end(clear_btn, False, False, 0)

        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        vbox.pack_start(sw, True, True, 0)

        self.log_text = Gtk.TextView()
        self.log_text.set_editable(False)
        self.log_text.set_cursor_visible(True)
        self.log_text.set_monospace(True)
        self.log_text.set_wrap_mode(Gtk.WrapMode.NONE)
        self.log_text.set_margin_start(4)
        self.log_text.set_margin_end(4)
        self.log_text.set_margin_top(4)
        self.log_text.set_margin_bottom(4)
        sw.add(self.log_text)

        self.log_win = win
        activity_log.subscribe(self._refresh_log_window)
        # Poll the conky log file (~1s) while the console is open
        self._log_poll_id = GLib.timeout_add(1000, self._refresh_log_window)
        self._refresh_log_window()
        win.show_all()

    def _on_log_win_destroyed(self, _win):
        if self._log_poll_id is not None:
            GLib.source_remove(self._log_poll_id)
            self._log_poll_id = None
        self.log_win = None

    def _refresh_log_window(self):
        if self.log_text is None:
            return False
        lines = []
        if self.conky_log_path and os.path.exists(self.conky_log_path):
            try:
                with open(self.conky_log_path, "rb") as f:
                    f.seek(0, os.SEEK_END)
                    size = f.tell()
                    f.seek(max(0, size - 8192))
                    tail = f.read().decode("utf-8", errors="replace").splitlines()
            except OSError:
                tail = []
            if tail:
                lines.append(f"-- conky ({self.conky_log_path}) --")
                lines.extend(tail)
                lines.append("")
        lines.append("-- activity --")
        lines.extend(
            f"{ts}  {src:<7} {line}"
            for ts, src, line in activity_log.entries()
        )
        buf = self.log_text.get_buffer()
        buf.set_text("\n".join(lines))
        return True

    def _log_clear(self):
        activity_log.clear()
        if self.conky_log_path and os.path.exists(self.conky_log_path):
            try:
                with open(self.conky_log_path, "w") as f:
                    f.write("")
            except OSError:
                pass
        self._refresh_log_window()

    # ── CONKY MANAGEMENT (live preview) ──

    @staticmethod
    def _is_x11():
        return not bool(os.environ.get("WAYLAND_DISPLAY"))

    @staticmethod
    def _conky_pids():
        """All running conky PIDs (pgrep -x conky)."""
        pids = []
        try:
            out = subprocess.run(
                ["pgrep", "-x", "conky"],
                capture_output=True, text=True,
            )
            for line in out.stdout.split():
                line = line.strip()
                if line.isdigit():
                    pids.append(int(line))
        except OSError:
            pass
        return pids

    def _ours_running(self):
        """True when at least one conky process is alive."""
        return bool(self._conky_pids())

    def _ensure_conf(self):
        conf_path = os.path.splitext(self.save_path)[0] + ".conf"
        if not os.path.exists(conf_path):
            self._maybe_write_conf(force=True)
        return conf_path

    def _conky_start(self, preview=True):
        self._conky_managed = True
        if self._ours_running():
            self._update_conky_state()
            self._start_watchdog()
            return True
        conf_path = self._ensure_conf()
        if not os.path.exists(conf_path):
            self.status.set_text(
                f"Missing {os.path.basename(conf_path)} — Save first"
            )
            self._conky_managed = False
            return False
        spawn_conf = conf_path
        if preview and self._is_x11():
            spawn_conf = self._preview_conf(conf_path)
        self._spawn_conf_path = (
            spawn_conf if spawn_conf != conf_path else None
        )
        if self.conky_log_path is None:
            self.conky_log_path = os.path.join(WORK_DIR, "conky.log")
        try:
            logf = open(self.conky_log_path, "ab")
        except OSError:
            logf = None
        try:
            self.conky_proc = subprocess.Popen(
                ["conky", "-c", spawn_conf],
                stdout=logf, stderr=subprocess.STDOUT,
                cwd=os.path.dirname(conf_path) or None,
            )
        except OSError as e:
            if logf is not None:
                logf.close()
            self._conky_managed = False
            self.status.set_text(f"Could not start conky: {e}")
            return False
        activity_log.add(
            "Conky", f"started conky -c {os.path.basename(spawn_conf)}"
        )
        self._update_conky_state()
        self._start_watchdog()
        return True

    def _preview_conf(self, conf_path):
        """Build the X11 preview .conf: the real conf plus live_clear.lua in
        lua_load. The deployed .conf stays clean — the ghost-clear is only
        needed while the designer edits on X11."""
        lua_basename = os.path.basename(self.save_path)
        base = os.path.basename(os.path.splitext(conf_path)[0])
        content = self._generate_conf(
            base, self.conky_settings, lua_basename, self.weather_enabled
        )
        content = content.replace(
            f"  lua_load = '{lua_basename}',",
            f"  lua_load = '{lua_basename} {LIVE_CLEAR_LUA}',",
        )
        preview_path = os.path.join(
            WORK_DIR, base + ".preview.conf"
        )
        if self._atomic_write(preview_path, content):
            return preview_path
        activity_log.add(
            "Conky",
            f"preview conf write failed — using {os.path.basename(conf_path)}",
        )
        return conf_path

    def _conky_stop(self):
        self._stop_watchdog()
        subprocess.run(["killall", "conky"], capture_output=True)
        time.sleep(0.3)
        self._conky_managed = False
        self._update_conky_state()
        activity_log.add("Conky", "stopped conky")

    def _conky_restart(self):
        self._stop_watchdog()
        subprocess.run(["killall", "-USR1", "conky"], capture_output=True)
        self._start_watchdog()
        self._update_conky_state()
        activity_log.add("Conky", "restarted conky")

    def _start_watchdog(self):
        if self._watchdog_id is None:
            self._watchdog_id = GLib.timeout_add(2000, self._watchdog_tick)

    def _stop_watchdog(self):
        if self._watchdog_id is not None:
            GLib.source_remove(self._watchdog_id)
            self._watchdog_id = None

    def _watchdog_tick(self):
        if not self._conky_managed:
            self._watchdog_id = None
            return GLib.SOURCE_REMOVE
        if not self._ours_running():
            activity_log.add("Conky", "watchdog: conky not running — starting")
            self._conky_start()
        self._update_conky_state()
        return GLib.SOURCE_CONTINUE

    def _update_conky_state(self):
        running = self._ours_running()
        self.conky_state_label.set_text(
            f"conky: {'running' if running else 'stopped'}"
        )
        self.btn_conky_run.set_sensitive(not running)
        self.btn_conky_stop.set_sensitive(running)
        self.btn_conky_restart.set_sensitive(True)

    def _conky_restart_debounced(self):
        """Coalesce full restarts triggered by rapid live writes (X11)."""
        if self._restart_debounce_id is not None:
            GLib.source_remove(self._restart_debounce_id)
        self._restart_debounce_id = GLib.timeout_add(
            300, self._flush_restart_debounce
        )

    def _flush_restart_debounce(self):
        self._restart_debounce_id = None
        if self._conky_managed:
            self._conky_restart()
        return False

    def _after_live_write(self):
        """Push a freshly written widget.lua to the running conky.

        Always sends SIGUSR1 to trigger a clean reload, regardless of
        display server (X11 or Wayland)."""
        if not self._conky_managed:
            return
        if self._ours_running():
            self._conky_restart()
        else:
            activity_log.add("Conky", "conky died — watchdog restart")
            self._conky_start()

    @staticmethod
    def _inject_toc(html_bytes):
        """Inject a fixed left sidebar TOC (CSS+HTML+JS) before </body>.
        Builds anchors from the h2/h3 headings (md2html emits them without
        ids), drops the hand-written TOC block, and adds a scrollspy with an
        animated SVG marker plus a live filter box."""
        text = html_bytes.decode("utf-8", errors="replace")
        marker = "</body>"
        if marker not in text:
            return html_bytes

        title = "NextGen — Handbook"

        # The hand-written TOC (h1 + bullet list) is replaced by the sidebar.
        text = re.sub(r"<h1>.*?</h1>\s*<ul>.*?</ul>", "", text, count=1,
                      flags=re.S)
        if "<title></title>" in text:
            text = text.replace("<title></title>",
                                "<title>%s</title>" % title)

        used = {}
        tree = []
        current = None

        def _slug(base):
            if base not in used:
                used[base] = 0
                return base
            used[base] += 1
            return "%s-%d" % (base, used[base])

        def _heading(m):
            nonlocal current
            tag, inner = m.group(1), m.group(2)
            name = html.unescape(re.sub(r"<[^>]+>", "", inner)).strip()
            base = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "sec"
            hid = _slug(base)
            item = {"id": hid, "text": name, "kids": []}
            if tag == "h3":
                if current is not None:
                    current["kids"].append(item)
            else:
                tree.append(item)
                current = item
            return '<%s id="%s">%s</%s>' % (tag, hid, inner, tag)

        text = re.sub(r"<(h2|h3)>(.*?)</\1>", _heading, text, flags=re.S)

        def _render(items):
            out = ["<ul>"]
            for it in items:
                out.append('<li><a href="#%s">%s</a>'
                           % (it["id"], html.escape(it["text"])))
                if it["kids"]:
                    out.append(_render(it["kids"]))
                out.append("</li>")
            out.append("</ul>")
            return "".join(out)

        nav = _render(tree)

        sidebar = (
            '<nav id="ng-toc">\n'
            '<div id="ng-toc-brand">%s<small>Conky NextGen Framework — '
            'Handbook</small></div>\n'
            '<input id="ng-toc-filter" type="search" placeholder="Filter…" '
            'autocomplete="off" spellcheck="false">\n'
            '<div id="ng-toc-scroll">\n'
            '<ul id="ng-toc-list">\n%s\n</ul>\n'
            '<div id="ng-toc-empty">No matches</div>\n'
            '<svg id="ng-marker" viewBox="0 0 280 800" '
            'preserveAspectRatio="none" '
            'xmlns="http://www.w3.org/2000/svg">'
            '<path id="ng-marker-path" d=""></path></svg>\n'
            '</div>\n'
            '</nav>\n' % (title, nav)
        )

        css = (
            "*{box-sizing:border-box}\n"
            "html{scroll-behavior:smooth}\n"
            "body{margin:0;background:#0f1117;color:#d0d4dc;"
            "font:15px/1.65 'Segoe UI',system-ui,Arial,sans-serif}\n"
            "#ng-toc{position:fixed;top:0;left:0;bottom:0;width:280px;"
            "background:#1a1e27;border-right:1px solid #262c38;"
            "display:flex;flex-direction:column;z-index:1000}\n"
            "#ng-toc-brand{padding:14px 16px 8px;font-size:18px;font-weight:700;"
            "color:#fff;border-bottom:1px solid #262c38}\n"
            "#ng-toc-brand small{display:block;font-size:11px;font-weight:400;"
            "color:#8b95a7;margin-top:2px}\n"
            "#ng-toc-filter{margin:10px 12px;padding:6px 9px;"
            "border:1px solid #262c38;border-radius:5px;background:#0f1117;"
            "color:#d0d4dc;outline:none;font-size:12.5px}\n"
            "#ng-toc-filter:focus{border-color:#7aa2f7}\n"
            "#ng-toc-scroll{position:relative;flex:1;overflow-y:auto;"
            "padding-bottom:24px}\n"
            "#ng-toc-scroll ul{list-style:none;margin:0;padding:0}\n"
            "#ng-toc-scroll ul ul{padding-left:1em}\n"
            "#ng-toc-scroll li{position:relative}\n"
            "#ng-toc-scroll li a{display:inline-block;position:relative;"
            "z-index:1;padding:3px 14px 3px 12px;color:#8b95a7;"
            "text-decoration:none;font-size:12.5px;line-height:1.45;"
            "transition:color .25s,transform .25s "
            "cubic-bezier(.23,1,.32,1)}\n"
            "#ng-toc-scroll ul ul li a{font-size:12px}\n"
            "#ng-toc-scroll li.visible>a{color:#fff;transform:translateX(5px)}\n"
            "#ng-toc-scroll li a:hover{color:#7aa2f7}\n"
            "#ng-toc-scroll li.ng-hidden{display:none}\n"
            "#ng-toc-empty{display:none;padding:10px 16px;color:#8b95a7;"
            "font-size:12px}\n"
            "#ng-marker{position:absolute;top:0;left:0;width:100%;height:100%;"
            "z-index:0;pointer-events:none}\n"
            "#ng-marker path{stroke:#7aa2f7;stroke-width:3;fill:transparent;"
            "stroke-linecap:round;stroke-linejoin:round;"
            "transition:opacity .3s ease,stroke-dasharray .3s ease,"
            "stroke-dashoffset .3s ease}\n"
            ".ng-main{margin-left:280px;padding:24px clamp(16px,3vw,48px) "
            "80px;max-width:1100px}\n"
            ".ng-title{margin:0 0 6px;font-size:28px;color:#fff}\n"
            ".ng-sub{color:#8b95a7;font-size:12.5px;margin:0 0 22px}\n"
            ".ng-main h2{margin:40px 0 12px;font-size:21px;color:#fff;"
            "border-bottom:1px solid #262c38;padding-bottom:6px;"
            "scroll-margin-top:20px}\n"
            ".ng-main h3{margin:26px 0 8px;font-size:16px;color:#e6e9ef;"
            "scroll-margin-top:20px}\n"
            ".ng-main p{margin:10px 0}\n"
            ".ng-main a{color:#7aa2f7;text-decoration:none}\n"
            ".ng-main a:hover{text-decoration:underline}\n"
            ".ng-main ul,.ng-main ol{padding-left:1.4em}\n"
            ".ng-main li{margin:3px 0}\n"
            ".ng-main blockquote{margin:12px 0;padding:3px 14px;"
            "border-left:3px solid #7aa2f7;background:rgba(122,162,247,.14);"
            "border-radius:0 6px 6px 0}\n"
            ".ng-main code{background:#1a1e27;border:1px solid #262c38;"
            "border-radius:4px;padding:1px 5px;"
            "font-family:Consolas,'JetBrains Mono',monospace;font-size:12.5px;"
            "color:#c8e1ff}\n"
            ".ng-main pre{background:#1a1e27;border:1px solid #262c38;"
            "border-radius:8px;padding:12px 14px;overflow-x:auto;line-height:1.5}\n"
            ".ng-main pre code{background:transparent;border:0;padding:0;"
            "color:inherit}\n"
            ".ng-wrap{overflow-x:auto;margin:12px 0;border-radius:8px}\n"
            ".ng-main table{border-collapse:collapse;width:100%;font-size:13px}\n"
            ".ng-main th,.ng-main td{border:1px solid #262c38;"
            "padding:5px 10px;text-align:left;vertical-align:top}\n"
            ".ng-main th{background:#1a1e27;color:#7aa2f7;font-weight:600;"
            "white-space:nowrap}\n"
            ".ng-main tr:nth-child(even) td{background:#161a22}\n"
            ".ng-main img{max-width:100%;border-radius:8px}\n"
            ".ng-main strong{color:#fff}\n"
            "@media(max-width:900px){#ng-toc{display:none}"
            ".ng-main{margin-left:0;padding-top:20px}}\n"
        )

        js = (
            "(function(){\n"
            "var scroll=document.getElementById('ng-toc-scroll');\n"
            "var path=document.getElementById('ng-marker-path');\n"
            "var filter=document.getElementById('ng-toc-filter');\n"
            "if(!scroll||!path){return;}\n"
            "var TOP=0.1,BOTTOM=0.2,pathLength=0,lastStart=0,lastEnd=0,"
            "items=[],timer=null;\n"
            "function collect(){\n"
            "  items=[].slice.call(scroll.querySelectorAll('#ng-toc-list>li'))"
            ".map(function(li){\n"
            "    var a=li.firstElementChild;\n"
            "    if(!a||a.tagName!=='A'){return null;}\n"
            "    return {li:li,a:a,target:document.getElementById("
            "a.getAttribute('href').slice(1)),marked:false};\n"
            "  }).filter(function(it){return it&&it.target;});\n"
            "}\n"
            "function draw(){\n"
            "  var seg=[],indent;\n"
            "  items.forEach(function(it,i){\n"
            "    var x=it.a.offsetLeft-5,y=it.a.offsetTop,h=it.a.offsetHeight;\n"
            "    if(i===0){seg.push('M',x,y,'L',x,y+h);it.start=0;}\n"
            "    else{\n"
            "      if(indent!==x){seg.push('L',indent,y);}\n"
            "      seg.push('L',x,y);\n"
            "      path.setAttribute('d',seg.join(' '));\n"
            "      it.start=path.getTotalLength()||0;\n"
            "      seg.push('L',x,y+h);\n"
            "    }\n"
            "    indent=x;path.setAttribute('d',seg.join(' '));\n"
            "    it.end=path.getTotalLength();\n"
            "  });\n"
            "  pathLength=path.getTotalLength();\n"
            "  path.style.opacity='0';sync();\n"
            "}\n"
            "function sync(){\n"
            "  var winH=window.innerHeight,start=pathLength,end=0,count=0;\n"
            "  items.forEach(function(it){\n"
            "    if(it.li.classList.contains('ng-hidden')){return;}\n"
            "    var r=it.target.getBoundingClientRect();\n"
            "    var vis=r.bottom>winH*TOP&&r.top<winH*(1-BOTTOM);\n"
            "    if(vis){start=Math.min(it.start,start);"
            "end=Math.max(it.end,end);count++;\n"
            "      if(!it.marked){it.li.classList.add('visible');"
            "it.marked=true;}}\n"
            "    else if(it.marked){it.li.classList.remove('visible');"
            "it.marked=false;}\n"
            "  });\n"
            "  if(count>0&&start<end){\n"
            "    if(start!==lastStart||end!==lastEnd){\n"
            "      path.setAttribute('stroke-dashoffset','1');\n"
            "      path.setAttribute('stroke-dasharray',"
            "'1, '+start+', '+(end-start)+', '+pathLength);\n"
            "      path.style.opacity='1';\n"
            "    }\n"
            "  }else{path.style.opacity='0';}\n"
            "  lastStart=start;lastEnd=end;\n"
            "}\n"
            "function refresh(){clearTimeout(timer);timer=setTimeout(draw,40);}\n"
            "window.addEventListener('resize',refresh);\n"
            "window.addEventListener('scroll',sync,{passive:true});\n"
            "filter.addEventListener('input',function(){\n"
            "  var q=filter.value.trim().toLowerCase(),any=false;\n"
            "  [].slice.call(scroll.querySelectorAll('#ng-toc-list>li'))"
            ".forEach(function(li){\n"
            "    var kids=[].slice.call(li.querySelectorAll(':scope>ul>li'));\n"
            "    var topOk=li.firstElementChild.textContent.toLowerCase()"
            ".indexOf(q)!==-1;\n"
            "    var shown=0;\n"
            "    kids.forEach(function(k){\n"
            "      var m=k.firstElementChild.textContent.toLowerCase()"
            ".indexOf(q)!==-1;\n"
            "      k.classList.toggle('ng-hidden',!m);if(m){shown++;}\n"
            "    });\n"
            "    var show=topOk||shown>0;\n"
            "    li.classList.toggle('ng-hidden',!show);if(show){any=true;}\n"
            "  });\n"
            "  document.getElementById('ng-toc-empty').style.display="
            "any?'none':'block';\n"
            "  refresh();\n"
            "});\n"
            "collect();draw();\n"
            "})();\n"
        )

        head = (
            "<style>\n%s\n</style>\n" % css
        )
        body = text.replace(
            "<body>",
            "<body>\n" + sidebar + '\n<main class="ng-main">\n'
            '<h1 class="ng-title">%s</h1>\n'
            '<p class="ng-sub">Generated from <code>NextGen.md</code> — '
            'edit the markdown, then open this again.</p>\n' % title, 1)
        body = re.sub(r"<table>", '<div class="ng-wrap"><table>', body)
        body = re.sub(r"</table>", "</table></div>", body)
        tail = "</main>\n" + head + "<script>\n%s\n</script>\n" % js
        return body.replace(marker, tail + marker).encode("utf-8")

    def _ensure_help_dir(self):
        os.makedirs(HELP_DIR, exist_ok=True)

    def _open_html(self, path):
        """Open a local HTML file in a browser (firefox, else xdg-open)."""
        for cmd in (
            ["firefox", path],
            ["xdg-open", path],
        ):
            try:
                subprocess.Popen(cmd, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
                return True
            except Exception as exc:
                activity_log.add("Help", f"browser failed ({cmd[0]}): {exc}")
        return False

    def _open_about(self):
        """Open the project page in a browser (firefox, else xdg-open)."""
        for cmd in (
            ["firefox", "https://github.com/molnari811023/conky-nextgen"],
            ["xdg-open", "https://github.com/molnari811023/conky-nextgen"],
        ):
            try:
                subprocess.Popen(cmd, stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
                activity_log.add("Help", "opened About (project page) in browser")
                return
            except Exception as exc:
                activity_log.add("Help", f"browser failed ({cmd[0]}): {exc}")

    def _open_conky_manual(self):
        """Generate the current conky(1) man page as HTML and open it."""
        if not os.path.exists(CONKY_MAN_GZ):
            activity_log.add("Help", f"missing man source: {CONKY_MAN_GZ}")
            self._show_error("Conky Manual",
                             f"Man page not found:\n{CONKY_MAN_GZ}")
            return
        try:
            self._ensure_help_dir()
            zcat = subprocess.Popen(["zcat", CONKY_MAN_GZ],
                                    stdout=subprocess.PIPE)
            out = subprocess.run(["mandoc", "-T", "html"], stdin=zcat.stdout,
                                 timeout=20, check=True,
                                 capture_output=True)
            zcat.wait(timeout=20)
            with open(CONKY_MANUAL_HTML, "wb") as f:
                f.write(out.stdout)
        except FileNotFoundError as exc:
            activity_log.add("Help", f"tool missing: {exc}")
            self._show_error("Conky Manual",
                             f"Required tool missing:\n{exc.filename or exc}")
            return
        except Exception as exc:
            activity_log.add("Help", f"manual generation failed: {exc}")
            self._show_error("Conky Manual",
                             f"Failed to generate the manual:\n{exc}")
            return
        if self._open_html(CONKY_MANUAL_HTML):
            activity_log.add("Help", "opened Conky Manual in browser")

    def _open_nextgen_handbook(self):
        """Convert NextGen.md to HTML (md2html) and open it."""
        if not os.path.exists(NEXTGEN_MD):
            activity_log.add("Help", f"missing handbook: {NEXTGEN_MD}")
            self._show_error("NextGen Handbook",
                             f"Handbook not found:\n{NEXTGEN_MD}")
            return
        try:
            self._ensure_help_dir()
            out = subprocess.run(
                ["md2html", "--github", "-f", NEXTGEN_MD],
                timeout=30, check=True, capture_output=True)
            html_out = self._inject_toc(out.stdout)
            with open(NEXTGEN_HANDBOOK_HTML, "wb") as f:
                f.write(html_out)
        except FileNotFoundError as exc:
            activity_log.add("Help", f"tool missing: {exc}")
            self._show_error("NextGen Handbook",
                             f"Required tool missing:\n{exc.filename or exc}")
            return
        except Exception as exc:
            activity_log.add("Help", f"handbook generation failed: {exc}")
            self._show_error("NextGen Handbook",
                             f"Failed to generate the handbook:\n{exc}")
            return
        if self._open_html(NEXTGEN_HANDBOOK_HTML):
            activity_log.add("Help", "opened NextGen Handbook in browser")

    def _show_error(self, title, message):
        dialog = Gtk.MessageDialog(transient_for=self, modal=True,
                                   message_type=Gtk.MessageType.ERROR,
                                   buttons=Gtk.ButtonsType.OK,
                                   text=title)
        dialog.format_secondary_text(message)
        dialog.run()
        dialog.destroy()

    def _populate_props(self, item):
        if self.prop_win is None:
            return
        if isinstance(item, RawBlock):
            self.prop_win.set_title("Properties — raw Lua block (not editable)")
            self._clear_props()
            return
        self.prop_win.set_title(
            f"Properties — {item.get('type', 'item')} [{self.selected_index}]"
        )
        self._clear_props()
        self._prop_loading = True
        skip = {"_resolved_text"}
        shown = set()

        # Get theme defaults for this widget type
        theme_defs = {}
        try:
            import engine.theme_engine as te
            theme = te.THEMES.get(self.current_theme, {})
            theme_defs = theme.get("defaults", {}).get(item.get("type", ""), {})
        except Exception:
            pass

        # Show type-specific fields first (always shown, even if empty),
        # with section headings from the PropertySpec schema.
        wtype = item.get("type", "")
        last_group = None
        for spec in props_for(wtype):
            key = spec.key
            if key in skip:
                continue
            if not self._prop_visible(wtype, item, spec):
                continue
            if spec.group and spec.group != last_group:
                self._add_prop_header(spec.group)
                last_group = spec.group
            val = item.get(key, "")
            is_theme = key in theme_defs and _colors_match(val, theme_defs[key])
            self._add_prop_row(spec, val, is_theme_default=is_theme)
            shown.add(key)

        # Show existing fields not yet shown (schema-typed when known)
        for key in field_order():
            if key in item and key not in shown and key not in skip:
                val = item[key]
                is_theme = key in theme_defs and _colors_match(val, theme_defs[key])
                self._add_prop_row(spec_for(key) or self._unknown_spec(key),
                                   val, is_theme_default=is_theme)
                shown.add(key)

        # Show any extra fields from item
        for key in sorted(item.keys()):
            if key not in shown and key not in skip:
                val = item[key]
                is_theme = key in theme_defs and _colors_match(val, theme_defs[key])
                self._add_prop_row(spec_for(key) or self._unknown_spec(key),
                                   val, is_theme_default=is_theme)
        self._prop_loading = False

    def _unknown_spec(self, key):
        return PropertySpec(key=key, label=key, kind=Kind.STRING)

    def _prop_visible(self, wtype, item, spec):
        """Conditional property visibility (bar mode → blocks/sides)."""
        if wtype != "bar":
            return True
        mode = str(item.get("mode", "") or "").strip()
        if spec.key == "blocks":
            return mode in ("block", "dot", "polygon")
        if spec.key == "sides":
            return mode == "polygon"
        return True

    def _add_prop_header(self, text):
        lbl = Gtk.Label()
        lbl.set_xalign(0)
        lbl.set_markup(f"<span foreground='#999'><small><b>—— {text}</b></small></span>")
        lbl.set_margin_top(4)
        self.prop_box.pack_start(lbl, False, False, 0)

    def _add_prop_row(self, spec, value, is_theme_default=False):
        key = spec.key
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        display_key = spec.label
        if is_theme_default:
            display_key = f"{display_key} <span foreground='#888'>(theme)</span>"
        label = Gtk.Label()
        label.set_width_chars(14)
        label.set_xalign(0)
        label.set_markup(f'<small><b>{display_key}</b></small>')
        if spec.help:
            label.set_tooltip_text(spec.help)
        hbox.pack_start(label, False, False, 0)

        editor = self._make_prop_editor(spec, value)
        hbox.pack_start(editor, True, True, 0)
        self.prop_box.pack_start(hbox, False, False, 0)
        self.prop_box.show_all()

    def _fmt_prop_value(self, value):
        if isinstance(value, bool):
            return "true" if value else "false"
        if isinstance(value, dict):
            return "{ " + ", ".join(
                f"{k} = {self._fmt_prop_value(v)}" for k, v in value.items()) + " }"
        if isinstance(value, (list, tuple)):
            return repr(value)[:2000]
        return "" if value is None else str(value)

    def _make_prop_editor(self, spec, value):
        """Build a per-kind GTK editor for a property row."""
        key = spec.key
        kind = spec.kind

        if kind in (Kind.INT, Kind.FLOAT):
            is_int = kind == Kind.INT
            cur = 0
            try:
                cur = float(value) if value not in (None, "") else 0.0
            except (TypeError, ValueError):
                pass
            lo = min(spec.min if spec.min is not None else -100000, cur)
            hi = max(spec.max if spec.max is not None else 1000000, cur)
            step = spec.step if spec.step is not None else (1 if is_int else 0.5)
            spin = Gtk.SpinButton.new_with_range(lo, hi, max(step, 1e-9))
            if not is_int:
                dec = 0
                step_str = repr(step)
                if "." in step_str:
                    dec = len(step_str.split(".")[1].rstrip("0"))
                spin.set_digits(max(1, dec))
            spin.set_value(cur)
            spin.set_width_chars(8)
            spin.connect("value-changed", self._on_spin_commit, key, is_int)
            return spin

        if kind == Kind.BOOL:
            cb = Gtk.CheckButton()
            cb.set_active(bool(value))
            cb.connect("toggled", self._on_bool_commit, key)
            return cb

        if kind == Kind.ENUM:
            combo = Gtk.ComboBoxText()
            choices = list(spec.choices)
            cur = "" if value is None else str(value)
            if cur and cur not in choices:
                choices.insert(0, cur)
            for i, c in enumerate(choices):
                lbl = c
                if i < len(spec.choice_labels) and spec.choice_labels[i]:
                    lbl = spec.choice_labels[i]
                combo.append(c, lbl)
            if cur in choices:
                combo.set_active(choices.index(cur))
            elif choices:
                combo.set_active(0)
            combo.connect("changed", self._on_combo_commit, key)
            return combo

        if kind == Kind.DRAW_ME:
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            combo = Gtk.ComboBoxText()
            combo.append("", "— none —")
            combo.append("true", "true (always draw)")
            combo.append("false", "false (never draw)")
            combo.append("custom", "custom…")
            if isinstance(value, bool):
                cur = "true" if value else "false"
            else:
                cur = "" if value is None else str(value)
            if cur in ("", "true", "false"):
                combo.set_active_id(cur)
            else:
                combo.set_active_id("custom")
            entry = Gtk.Entry()
            entry.set_text(self._fmt_prop_value(value))
            entry.set_hexpand(True)
            entry.set_sensitive(combo.get_active_id() == "custom")
            entry.connect("activate", self._on_prop_commit, key)
            self.prop_entries[key] = entry
            btn = Gtk.Button(label="ƒx")
            btn.set_tooltip_text("Insert a project conky_* function")
            btn.set_sensitive(combo.get_active_id() == "custom")
            btn.connect("clicked", self._on_pick_conky_fn, key, entry)
            box.pack_start(combo, False, False, 0)
            box.pack_start(entry, True, True, 0)
            box.pack_start(btn, False, False, 0)

            def _draw_me_changed(cb):
                mode = cb.get_active_id()
                if mode == "custom":
                    entry.set_sensitive(True)
                    btn.set_sensitive(True)
                    entry.grab_focus()
                    return
                entry.set_sensitive(False)
                btn.set_sensitive(False)
                item = self._selected_item()
                if item is not None:
                    val = None if mode in ("", "custom") else (mode == "true")
                    item[key] = val
                    self._schedule_refresh()
            combo.connect("changed", _draw_me_changed)
            return box

        if kind == Kind.PATH:
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            entry = Gtk.Entry()
            entry.set_text(self._fmt_prop_value(value))
            entry.set_hexpand(True)
            entry.connect("activate", self._on_prop_commit, key)
            self.prop_entries[key] = entry
            btn = Gtk.Button(label="…")
            btn.connect("clicked", self._on_pick_path, key, entry)
            box.pack_start(entry, True, True, 0)
            box.pack_start(btn, False, False, 0)
            return box

        if kind == Kind.CODE:
            tv = Gtk.TextView()
            tv.set_size_request(-1, 60)
            buf = tv.get_buffer()
            if value is not None:
                buf.set_text(str(value))
            tv.connect("focus-out-event", self._on_code_commit, key)
            return tv

        if kind == Kind.STOPS:
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            entry = Gtk.Entry()
            entry.set_text(self._fmt_prop_value(value))
            entry.set_hexpand(True)
            entry.connect("activate", self._on_prop_commit, key)
            self.prop_entries[key] = entry
            btn = Gtk.Button(label="Edit…")
            btn.connect("clicked", self._on_edit_stops, key, value, entry)
            box.pack_start(entry, True, True, 0)
            box.pack_start(btn, False, False, 0)
            return box

        # STRING / TEMPLATE / FONT / COLOR
        entry = Gtk.Entry()
        entry.set_text(self._fmt_prop_value(value))
        entry.set_hexpand(True)
        entry.connect("activate", self._on_prop_commit, key)
        self.prop_entries[key] = entry
        if kind in (Kind.TEMPLATE, Kind.STRING) and key in ("text", "value"):
            box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
            btn = Gtk.Button(label="ƒx")
            btn.set_tooltip_text("Insert a project conky_* function")
            btn.connect("clicked", self._on_pick_conky_fn, key, entry)
            box.pack_start(entry, True, True, 0)
            box.pack_start(btn, False, False, 0)
            return box
        return entry

    def _clear_props(self):
        try:
            children = self.prop_box.get_children()
        except Exception:
            return
        for child in children:
            self.prop_box.remove(child)
        self.prop_entries.clear()

    def _coerce_value(self, key, val_str):
        """Coerce a raw property string to a Python value.
        string_fields() keys are always kept as strings (like the legacy
        STRING_FIELDS).  Lua expressions are wrapped in ``RawLua`` so
        ``generate_lua_entry()`` emits them unquoted.
        Raises on invalid list syntax."""
        if key in string_fields():
            if val_str in ("nil", "None", ""):
                return None
            from engine.lua_parser import _is_lua_expression
            if _is_lua_expression(val_str):
                return RawLua(val_str)
            return val_str
        try:
            return int(val_str)
        except ValueError:
            pass
        try:
            return float(val_str)
        except ValueError:
            pass
        if val_str in ("nil", "None", ""):
            return None
        if val_str == "true":
            return True
        if val_str == "false":
            return False
        if val_str.startswith("["):
            import ast
            return ast.literal_eval(val_str)
        if val_str.startswith("{") and val_str.endswith("}"):
            stops = parse_gradient_stops(val_str)
            if stops:
                return [list(s) for s in stops]
            inner = val_str.strip()[1:-1].strip()
            m = re.fullmatch(r'\s*"(\#[0-9a-fA-F]{6})"\s*,\s*([\d.]+)\s*', inner)
            if m:
                return [[1.0, m.group(1), float(m.group(2))]]
            m = re.fullmatch(r'\s*"(\#[0-9a-fA-F]{6})"\s*', inner)
            if m:
                return [[1.0, m.group(1), 1.0]]
        parsed = parse_lua_table_content(val_str)
        if isinstance(parsed, dict) and parsed:
            return parsed
        if (isinstance(parsed, list) and len(parsed) == 4
                and all(isinstance(n, (int, float)) and not isinstance(n, bool)
                        for n in parsed)):
            return {"x": parsed[0], "y": parsed[1], "w": parsed[2], "h": parsed[3]}
        return val_str

    def _selected_item(self):
        """Return the currently selected item, or None if selection is stale."""
        if self.selected_index is None:
            return None
        if not (0 <= self.selected_index < len(self.draw_list)):
            self.selected_index = None
            return None
        return self.draw_list[self.selected_index]

    def _on_spin_commit(self, spin, key, is_int):
        if getattr(self, "_prop_loading", False):
            return
        item = self._selected_item()
        if item is None:
            return
        item[key] = int(spin.get_value()) if is_int else round(spin.get_value(), 6)
        self._schedule_refresh()

    def _on_bool_commit(self, cb, key):
        if getattr(self, "_prop_loading", False):
            return
        item = self._selected_item()
        if item is None:
            return
        item[key] = cb.get_active()
        self._schedule_refresh()

    def _on_combo_commit(self, combo, key):
        if getattr(self, "_prop_loading", False):
            return
        item = self._selected_item()
        if item is None:
            return
        val = combo.get_active_id()
        if val is not None:
            item[key] = val
            self._schedule_refresh()

    def _on_pick_path(self, btn, key, entry):
        dialog = Gtk.FileChooserDialog(
            title=f"Pick {key}", parent=self, action=Gtk.FileChooserAction.OPEN)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Open", Gtk.ResponseType.OK)
        if dialog.run() == Gtk.ResponseType.OK:
            entry.set_text(dialog.get_filename())
            self._on_prop_commit(entry, key)
        dialog.destroy()

    def _on_pick_conky_fn(self, btn, key, entry):
        """Pick a project conky_* function and insert it into the entry."""
        funcs = lua_data.list_conky_functions()
        if not funcs:
            self.status.set_text("No conky_* functions found in the project")
            return
        dialog = Gtk.Dialog(
            title="Conky / Lua data function", parent=self,
            modal=True, flags=0,
        )
        dialog.add_buttons(
            "Cancel", Gtk.ResponseType.CANCEL,
            "Insert", Gtk.ResponseType.OK,
        )
        dialog.set_default_size(560, 480)
        content = dialog.get_content_area()
        content.set_spacing(6)
        content.set_margin_start(8)
        content.set_margin_end(8)
        content.set_margin_top(8)
        content.set_margin_bottom(8)

        search = Gtk.SearchEntry()
        search.set_placeholder_text("Search (e.g. temp, battery, usb)…")
        content.pack_start(search, False, False, 0)

        store = Gtk.ListStore(str, str, str, str)  # name, call, args, source
        for name in sorted(funcs):
            info = funcs[name]
            quoted = ", ".join("'" + a + "'" for a in info["args"])
            call = name + "(" + quoted + ")"
            store.append([name, call, ", ".join(info["args"]) or "—", info["source"]])

        filtered = store.filter_new()
        view = Gtk.TreeView(model=filtered)
        for col_i, title in enumerate(("Function", "Call", "Arguments", "Source")):
            col = Gtk.TreeViewColumn(title, Gtk.CellRendererText(), text=col_i)
            col.set_expand(col_i == 1)
            view.append_column(col)
        view.set_search_column(0)
        view.set_headers_clickable(True)
        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroller.set_size_request(-1, 360)
        scroller.add(view)
        content.pack_start(scroller, True, True, 0)

        def _insert(sel=None):
            model, tree_iter = view.get_selection().get_selected()
            if not tree_iter:
                return
            call = model[tree_iter][1]
            cur = entry.get_text() or ""
            pos = entry.get_position()
            if pos is None or pos < 0:
                pos = len(cur)
            new_text = cur[:pos] + call + cur[pos:]
            entry.set_text(new_text)
            entry.set_position(pos + len(call))
            GLib.idle_add(lambda: dialog.response(Gtk.ResponseType.OK))

        view.connect("row-activated", lambda v, path, col: _insert())
        ok_btn = dialog.get_widget_for_response(Gtk.ResponseType.OK)
        if ok_btn:
            ok_btn.connect("clicked", lambda *a: _insert())

        def _filter(changed_btn):
            query["q"] = search.get_text().lower()
            filtered.refilter()

        query = {"q": ""}
        filtered.set_visible_func(
            lambda model, tree_iter, data: not query["q"] or query["q"] in (
                (model[tree_iter][0] or "") + " " + (model[tree_iter][1] or "")
            ).lower(),
        )
        search.connect("search-changed", _filter)
        dialog.show_all()
        dialog.run()
        dialog.destroy()

    def _on_code_commit(self, tv, event, key):
        item = self._selected_item()
        if item is None:
            return False
        buf = tv.get_buffer()
        start, end = buf.get_bounds()
        item[key] = buf.get_text(start, end, False)
        self._schedule_refresh()
        return False

    def _on_edit_stops(self, btn, key, value, entry):
        item = self._selected_item()
        if item is None:
            return
        stops = []
        if isinstance(value, (list, tuple)):
            for s in value:
                if isinstance(s, (list, tuple)) and len(s) == 3:
                    stops.append([s[0], str(s[1]), s[2]])
                else:
                    stops.append([1.0, str(s), 1.0])
        elif value is not None:
            stops.append([1.0, str(value), 1.0])
        if not stops:
            stops = [[1.0, "#ffffff", 1.0]]

        dialog = Gtk.Dialog(title=f"Edit {key} — gradient stops",
                            transient_for=self, modal=True)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("OK", Gtk.ResponseType.OK)
        content = dialog.get_content_area()
        content.set_spacing(6)
        content.set_margin_start(12)
        content.set_margin_end(12)
        content.set_margin_top(12)
        rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        changed = lambda: None
        self._theme_stops_rows(rows, stops, changed)
        add_btn = Gtk.Button(label="+ stop")

        def on_add(_b):
            stops.append([1.0, "#ffffff", 1.0])
            self._theme_stops_rows(rows, stops, changed)
        add_btn.connect("clicked", on_add)

        sw = Gtk.ScrolledWindow()
        sw.set_min_content_height(160)
        sw.add(rows)
        content.pack_start(sw, True, True, 0)
        content.pack_start(add_btn, False, False, 0)
        dialog.show_all()

        resp = dialog.run()
        dialog.destroy()
        if resp == Gtk.ResponseType.OK:
            item = self._selected_item()
            if item is None:
                return
            item[key] = stops
            self._save_and_refresh()

    def _add_property(self):
        item = self._selected_item()
        if item is None:
            return
        dialog = Gtk.Dialog(title="Add Property", transient_for=self, modal=True)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Add", Gtk.ResponseType.OK)
        box = dialog.get_content_area()
        box.set_spacing(8)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(12)

        box.add(Gtk.Label(label="Key:"))
        key_entry = Gtk.Entry()
        completion = Gtk.EntryCompletion()
        store = Gtk.ListStore(str)
        for k in dict.fromkeys(p.key for w in WIDGET_SPECS.values() for p in w.props):
            store.append([k])
        completion.set_model(store)
        completion.set_text_column(0)
        key_entry.set_completion(completion)
        box.add(key_entry)

        box.add(Gtk.Label(label="Value:"))
        val_entry = Gtk.Entry()
        val_entry.set_text("10")
        box.add(val_entry)

        dialog.show_all()
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            key = key_entry.get_text().strip()
            val_str = val_entry.get_text().strip()
            if key:
                item = self._selected_item()
                if item is not None:
                    try:
                        item[key] = self._coerce_value(key, val_str)
                    except Exception:
                        self.status.set_text(f"Invalid list syntax for {key}")
                    else:
                        self._save_and_refresh()
                    self._populate_props(item)
        dialog.destroy()

    def _on_prop_commit(self, entry, key):
        item = self._selected_item()
        if item is None:
            return
        val = entry.get_text().strip()
        try:
            item[key] = self._coerce_value(key, val)
        except Exception:
            self.status.set_text(f"Invalid list syntax for {key}")
            return
        self._schedule_refresh()

    # ── ADD / DELETE ITEMS ──

    def _add_item(self):
        dialog = Gtk.Dialog(title="Add Widget", transient_for=self, modal=True)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Add", Gtk.ResponseType.OK)
        box = dialog.get_content_area()
        box.set_spacing(8)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(12)

        box.add(Gtk.Label(label="Type:"))
        type_combo = Gtk.ComboBoxText()
        for t in widget_types():
            type_combo.append_text(t)
        type_combo.set_active(0)
        box.add(type_combo)

        box.add(Gtk.Label(label="Group:"))
        group_combo = Gtk.ComboBoxText()
        for g in self.groups:
            group_combo.append_text(g.get("name", "?"))
        if self.groups:
            group_combo.set_active(0)
        box.add(group_combo)

        box.add(Gtk.Label(label="Count:"))
        count_spin = Gtk.SpinButton.new_with_range(1, 50, 1)
        count_spin.set_value(1)
        count_spin.set_tooltip_text(
            "Number of widgets to add — each new one is stacked below the previous")
        box.add(count_spin)

        dialog.show_all()
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            self._add_widgets(
                type_combo.get_active_text(),
                group_combo.get_active_text() or "",
                int(count_spin.get_value()),
            )
        dialog.destroy()

    def _add_widgets(self, wtype, grp, count):
        """Append `count` widgets of the given type; each extra one is
        stacked vertically below the previous (non-overlapping)."""
        defaults = defaults_for(wtype)
        cursor = None
        for i in range(count):
            new_item = {"type": wtype}
            if grp:
                new_item["group"] = grp
            for k, v in defaults.items():
                new_item[k] = v
            if i > 0 and cursor is not None:
                new_item["y"] = cursor
            self.draw_list.append(new_item)
            base = new_item.get("y") or 0
            cursor = base + _infer_item_height(new_item)
        self._save_and_refresh()

    def _delete_item(self):
        if self.selected_index is None:
            return
        if not (0 <= self.selected_index < len(self.draw_list)):
            self.selected_index = None
            return
        del self.draw_list[self.selected_index]
        self.selected_index = None
        self._clear_props()
        self._save_and_refresh()

    # ── GROUPS ──

    def _refresh_groups_list(self):
        self.grp_liststore.clear()
        for g in self.groups:
            name = g.get("name", "?")
            views = ", ".join(g.get("views", []))
            self.grp_liststore.append([name, views])

    def _on_group_select(self, selection):
        model, tree_iter = selection.get_selected()
        if tree_iter:
            name = model[tree_iter][0]
            for i, g in enumerate(self.groups):
                if g.get("name") == name:
                    self.selected_group_index = i
                    self._populate_grp_props(g)
                    return

    def _populate_grp_props(self, grp):
        self._clear_grp_props()
        self._add_grp_prop_row("name", grp.get("name", ""))
        views = grp.get("views", [])
        self._add_grp_prop_row("views", ", ".join(views) if views else "")
        self._add_grp_draw_me_row(grp)

    def _add_grp_draw_me_row(self, grp):
        """Group-level conditional drawing (draw_me) editor row."""
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        label = Gtk.Label(label="draw_me")
        label.set_width_chars(10)
        label.set_xalign(0)
        label.set_markup("<small><b>draw_me</b></small>")
        hbox.pack_start(label, False, False, 0)

        combo = Gtk.ComboBoxText()
        combo.append("", "— none —")
        combo.append("true", "true (always draw)")
        combo.append("false", "false (never draw)")
        combo.append("custom", "custom…")
        dm = grp.get("draw_me")
        if isinstance(dm, bool):
            cur = "true" if dm else "false"
        else:
            cur = "" if dm is None else str(dm)
        if cur in ("", "true", "false"):
            combo.set_active_id(cur)
        else:
            combo.set_active_id("custom")
        hbox.pack_start(combo, False, False, 0)

        entry = Gtk.Entry()
        entry.set_text(self._fmt_prop_value(dm))
        entry.set_hexpand(True)
        entry.set_sensitive(combo.get_active_id() == "custom")
        entry.connect("activate", self._on_grp_prop_commit, "draw_me")
        self.grp_prop_entries["draw_me"] = entry
        hbox.pack_start(entry, True, True, 0)

        btn = Gtk.Button(label="ƒx")
        btn.set_tooltip_text("Insert a project conky_* function")
        btn.set_sensitive(combo.get_active_id() == "custom")
        btn.connect("clicked", self._on_pick_conky_fn, "draw_me", entry)
        hbox.pack_start(btn, False, False, 0)

        def _grp_draw_me_changed(cb):
            mode = cb.get_active_id()
            if mode == "custom":
                entry.set_sensitive(True)
                btn.set_sensitive(True)
                entry.grab_focus()
                return
            entry.set_sensitive(False)
            btn.set_sensitive(False)
            if self.selected_group_index is None:
                return
            if not (0 <= self.selected_group_index < len(self.groups)):
                self.selected_group_index = None
                return
            g = self.groups[self.selected_group_index]
            g["draw_me"] = None if mode in ("", "custom") else (mode == "true")
            self._schedule_refresh()

        combo.connect("changed", _grp_draw_me_changed)
        self.grp_prop_box.pack_start(hbox, False, False, 0)
        self.grp_prop_box.show_all()

    def _add_grp_prop_row(self, key, value):
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        label = Gtk.Label(label=key)
        label.set_width_chars(10)
        label.set_xalign(0)
        label.set_markup(f'<small><b>{key}</b></small>')
        hbox.pack_start(label, False, False, 0)
        entry = Gtk.Entry()
        entry.set_text(str(value))
        entry.set_hexpand(True)
        entry.connect("activate", self._on_grp_prop_commit, key)
        self.grp_prop_entries[key] = entry
        hbox.pack_start(entry, True, True, 0)
        self.grp_prop_box.pack_start(hbox, False, False, 0)
        self.grp_prop_box.show_all()

    def _clear_grp_props(self):
        for child in self.grp_prop_box.get_children():
            self.grp_prop_box.remove(child)
        self.grp_prop_entries.clear()

    def _on_grp_prop_commit(self, entry, key):
        if self.selected_group_index is None:
            return
        if not (0 <= self.selected_group_index < len(self.groups)):
            self.selected_group_index = None
            return
        grp = self.groups[self.selected_group_index]
        val = entry.get_text().strip()
        if key == "name":
            old_name = grp.get("name", "")
            if val != old_name:
                for i, g in enumerate(self.groups):
                    if i != self.selected_group_index and g.get("name") == val:
                        self.status.set_text(f"Group '{val}' already exists")
                        return
                for item in self.draw_list:
                    if item.get("group") == old_name:
                        item["group"] = val
            grp["name"] = val
        elif key == "views":
            grp["views"] = [v.strip() for v in val.split(",") if v.strip()]
        elif key == "draw_me":
            grp["draw_me"] = None if val in ("nil", "None", "") else val
        self._schedule_refresh()

    def _add_group(self):
        dialog = Gtk.Dialog(title="Add Group", transient_for=self, modal=True)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Add", Gtk.ResponseType.OK)
        box = dialog.get_content_area()
        box.set_spacing(8)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(12)

        box.add(Gtk.Label(label="Group name:"))
        name_entry = Gtk.Entry()
        name_entry.set_text(f"g_{len(self.groups)}")
        box.add(name_entry)

        box.add(Gtk.Label(label="Views (comma separated):"))
        views_entry = Gtk.Entry()
        views_entry.set_text("main")
        box.add(views_entry)

        dialog.show_all()
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            name = name_entry.get_text().strip()
            views = [v.strip() for v in views_entry.get_text().split(",") if v.strip()]
            if not name:
                self.status.set_text("Group name cannot be empty")
            elif any(g.get("name") == name for g in self.groups):
                self.status.set_text(f"Group '{name}' already exists")
            else:
                self.groups.append({"name": name, "views": views})
                self._save_and_refresh()
        dialog.destroy()

    def _delete_group(self):
        if self.selected_group_index is None:
            return
        if not (0 <= self.selected_group_index < len(self.groups)):
            self.selected_group_index = None
            return
        name = self.groups[self.selected_group_index].get("name", "")
        refs = [i for i, item in enumerate(self.draw_list) if item.get("group") == name]
        if refs:
            if not self._confirm(
                f"Delete group '{name}'?",
                f"{len(refs)} item(s) reference this group. Their group field will be cleared."
            ):
                return
            for item in self.draw_list:
                if item.get("group") == name:
                    item["group"] = None
        del self.groups[self.selected_group_index]
        self.selected_group_index = None
        self._clear_grp_props()
        self._save_and_refresh()

    # ── VIEWS ──

    def _refresh_views_list(self):
        self.views_liststore.clear()
        for v in self.views:
            name = v.get("name", "?")
            # Find groups that belong to this view
            grp_names = []
            for g in self.groups:
                if name in g.get("views", []):
                    grp_names.append(g.get("name", "?"))
            self.views_liststore.append([name, ", ".join(grp_names)])

    def _on_view_list_select(self, selection):
        model, tree_iter = selection.get_selected()
        if tree_iter:
            name = model[tree_iter][0]
            for i, v in enumerate(self.views):
                if v.get("name") == name:
                    self.selected_view_index = i
                    self._populate_views_props(v)
                    return

    def _populate_views_props(self, view):
        self._clear_views_props()
        self._add_views_prop_row("name", view.get("name", ""))

    def _add_views_prop_row(self, key, value):
        hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        label = Gtk.Label(label=key)
        label.set_width_chars(10)
        label.set_xalign(0)
        label.set_markup(f'<small><b>{key}</b></small>')
        hbox.pack_start(label, False, False, 0)
        entry = Gtk.Entry()
        entry.set_text(str(value))
        entry.set_hexpand(True)
        entry.connect("activate", self._on_views_prop_commit, key)
        self.views_prop_entries[key] = entry
        hbox.pack_start(entry, True, True, 0)
        self.views_prop_box.pack_start(hbox, False, False, 0)
        self.views_prop_box.show_all()

    def _clear_views_props(self):
        for child in self.views_prop_box.get_children():
            self.views_prop_box.remove(child)
        self.views_prop_entries.clear()

    def _item_view_parts(self, item):
        iv = item.get("view")
        if iv is None:
            return []
        return [p.strip() for p in str(iv).split(",") if p.strip()]

    def _on_views_prop_commit(self, entry, key):
        if self.selected_view_index is None:
            return
        if not (0 <= self.selected_view_index < len(self.views)):
            self.selected_view_index = None
            return
        view = self.views[self.selected_view_index]
        val = entry.get_text().strip()
        if key == "name":
            # Also update all groups and items that reference the old name
            old_name = view.get("name", "")
            if val != old_name:
                for i, v in enumerate(self.views):
                    if i != self.selected_view_index and v.get("name") == val:
                        self.status.set_text(f"View '{val}' already exists")
                        return
                for g in self.groups:
                    vlist = g.get("views", [])
                    if old_name in vlist:
                        vlist.remove(old_name)
                        vlist.append(val)
                for item in self.draw_list:
                    parts = self._item_view_parts(item)
                    if old_name in parts:
                        item["view"] = ", ".join(
                            val if p == old_name else p for p in parts
                        )
            view["name"] = val
        self._schedule_refresh()

    def _add_view(self):
        dialog = Gtk.Dialog(title="Add View", transient_for=self, modal=True)
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Add", Gtk.ResponseType.OK)
        box = dialog.get_content_area()
        box.set_spacing(8)
        box.set_margin_start(12)
        box.set_margin_end(12)
        box.set_margin_top(12)

        box.add(Gtk.Label(label="View name:"))
        name_entry = Gtk.Entry()
        name_entry.set_text(f"view_{len(self.views)}")
        box.add(name_entry)

        dialog.show_all()
        response = dialog.run()
        if response == Gtk.ResponseType.OK:
            name = name_entry.get_text().strip()
            if not name:
                self.status.set_text("View name cannot be empty")
            elif any(v.get("name") == name for v in self.views):
                self.status.set_text(f"View '{name}' already exists")
            else:
                self.views.append({"name": name})
                self._save_and_refresh()
        dialog.destroy()

    def _delete_view(self):
        if self.selected_view_index is None:
            return
        if not (0 <= self.selected_view_index < len(self.views)):
            self.selected_view_index = None
            return
        view_name = self.views[self.selected_view_index].get("name", "")
        item_refs = sum(1 for item in self.draw_list if view_name in self._item_view_parts(item))
        grp_refs = sum(1 for g in self.groups if view_name in g.get("views", []))
        if item_refs or grp_refs:
            if not self._confirm(
                f"Delete view '{view_name}'?",
                f"{item_refs} item(s) and {grp_refs} group(s) reference it. References will be removed."
            ):
                return
            for item in self.draw_list:
                parts = self._item_view_parts(item)
                if view_name in parts:
                    remaining = [p for p in parts if p != view_name]
                    item["view"] = ", ".join(remaining) if remaining else None
            for g in self.groups:
                vlist = g.get("views", [])
                if view_name in vlist:
                    vlist.remove(view_name)
        del self.views[self.selected_view_index]
        self.selected_view_index = None
        self._clear_views_props()
        self._save_and_refresh()

    # ── SAVE / LOAD MAIN.LUA ──

    def _schedule_refresh(self):
        """Coalesced, deferred _save_and_refresh.

        Called from widget signal handlers (entry activate, combo changed,
        spin value-changed...). Deferring to idle lets the emitting widget
        finish its signal before any prop editor is destroyed, avoiding the
        GTK grab_focus/use-after-free SIGSEGV on teardown.
        """
        if not getattr(self, "_ready", False):
            return
        if getattr(self, "_refresh_pending", False):
            return
        self._refresh_pending = True
        GLib.idle_add(self._flush_refresh)

    def _flush_refresh(self):
        self._refresh_pending = False
        self._save_and_refresh()
        return GLib.SOURCE_REMOVE

    def _block_selections(self):
        """Suppress the treeview selection-changed handlers during a
        programmatic list rebuild (they would re-enter _populate_*_props and
        destroy editors in the middle of signal emission)."""
        self._sel_blocks = []
        for attr, hid_attr in (("list_selection", "list_sel_hid"),
                               ("grp_selection", "grp_sel_hid"),
                               ("views_selection", "views_sel_hid")):
            sel = getattr(self, attr, None)
            hid = getattr(self, hid_attr, None)
            if sel is not None and hid is not None:
                try:
                    sel.handler_block(hid)
                    self._sel_blocks.append((sel, hid))
                except Exception:
                    pass

    def _unblock_selections(self):
        for sel, hid in getattr(self, "_sel_blocks", []):
            try:
                sel.handler_unblock(hid)
            except Exception:
                pass
        self._sel_blocks = []

    def _save_and_refresh(self):
        # Remember selection before save
        saved_index = self.selected_index
        # Live-write to the target file (diff-guarded so conky only reloads
        # when something actually changed)
        content = self._generate_content()
        self._write_live(content)
        self.draw_list, self.groups, self.views, self.padding = parse_widget_lua(self.save_path)
        self._load_themes()
        for item in self.draw_list:
            te.apply_theme(item)
        self._theme_init()
        self._block_selections()
        try:
            self._refresh_list()
            self._refresh_groups_list()
            self._refresh_views_list()
        finally:
            self._unblock_selections()
        self._refresh_view_combo()
        # Rebuild the Mouse tab only when the set of views changed
        view_names = tuple(v.get("name", "main") for v in self.views)
        if view_names != self._mouse_tab_views:
            self._mouse_tab_views = view_names
            self._populate_mouse_tab()
        # Restore selection (explicit, since the handlers were blocked above)
        if saved_index is not None and 0 <= saved_index < len(self.draw_list):
            self.selected_index = saved_index
            self._select_item_by_index(saved_index)
            self._populate_props(self.draw_list[saved_index])
        else:
            self.selected_index = None
        if self.selected_group_index is not None and 0 <= self.selected_group_index < len(self.groups):
            self._populate_grp_props(self.groups[self.selected_group_index])
        if self.selected_view_index is not None and 0 <= self.selected_view_index < len(self.views):
            self._populate_views_props(self.views[self.selected_view_index])
        self._update_title()
        self.status.set_text(
            f"{len(self.draw_list)} items, "
            f"{len(self.groups)} groups, {len(self.views)} views"
        )

    def _write_live(self, content):
        """Write generated content to the live file if it differs.

        Returns True when the file was written. Identical writes are skipped
        so conky does not reload/restart on every refresh."""
        try:
            with open(self.save_path) as f:
                if f.read() == content:
                    return False
        except OSError:
            pass
        if not self._atomic_write(self.save_path, content):
            return False
        self._maybe_write_conf()
        self._after_live_write()
        return True

    def _maybe_write_conf(self, force=False):
        """Write the sibling .conf only when its content differs.

        Any .conf write triggers a conky reload (and on X11 destroys the
        window), so byte-identical content must never be rewritten."""
        self._read_conky_from_widgets()
        base, _ = os.path.splitext(self.save_path)
        conf_path = base + ".conf"
        lua_basename = os.path.basename(self.save_path)
        conf = self._generate_conf(
            os.path.basename(base), self.conky_settings, lua_basename, self.weather_enabled
        )
        try:
            with open(conf_path) as f:
                old = f.read()
        except OSError:
            old = None
        if old == conf and not force:
            return
        if not self._atomic_write(conf_path, conf):
            return
        activity_log.add(
            "Conky", f".conf updated: {os.path.basename(conf_path)}"
        )
        # SIGUSR1 is always sent by _after_live_write() after save

    def _generate_content(self):
        """Generate Lua content from current draw_list, groups, views."""
        # Load theme defaults for skipping identical values
        self._load_themes()
        theme = te.THEMES.get(self.current_theme, {})

        lines = [
            "--{{{",
            "--  Conky NextGen Framework",
            "--  Author: István Molnár",
            "--  GitHub: https://github.com/molnari811023/conky-nextgen",
            "--  Description: Modular Conky UI framework (Lua engine + Bash backend)",
            "--}}}",
            "",
            "--{{{",
            "--  widget.lua — Widget data (generated/edited by sh/designer/main.py)",
            "--  Loaded directly by Conky (lua_load = 'widget.lua'). Structure:",
            "--    Global paths / config (formerly settings.lua)",
            "--    DEFAULT_THEME / _PADDING — global settings",
            "--    draw[#draw + 1] = { ... }        — draw items (background, clock, bar, ...)",
            "--    _GROUPS = { { name, views } }    — item groups (view switching)",
            "--    _VIEWS  = { { name } }           — view definitions",
            "--    MOUSE_*_ACTION = ...             — mouse event callbacks",
            "--    Bootstrap (formerly init.lua)    — loads the modules, inits the groups",
            "--}}}",
            "",
            WIDGET_CONFIG_BLOCK,
        ]
        if self.weather_enabled:
            lines.append(weather_icon_block(self.weather_icon_theme))
        if self.xdg_icon_theme:
            lines.append(f'XDG_ICON_THEME = "{self.xdg_icon_theme}"\n')
        lines += [
            tw.serialize_themes(te.THEMES),
            f'DEFAULT_THEME = "{THEME_NAME}"',
            f"_PADDING = {self.padding}",
            "",
            'require("require")',
            "",
        ]
        if self.custom_lua_code.strip():
            lines.append("--{{{ custom_lua")
            lines.append(self.custom_lua_code.rstrip())
            lines.append("--}}} custom_lua")
            lines.append("")
        for item in self.draw_list:
            if isinstance(item, RawBlock):
                # Verbatim Lua block (for-loop, etc.) — emit as-is
                lines.append(item.lua_code)
                lines.append("")
            else:
                wtype = item.get("type", "")
                theme_defs = theme.get("defaults", {}).get(wtype, {})
                lines.append("draw[#draw + 1] = " + generate_lua_entry(item, theme_defs))
                lines.append("")

        lines += [
            "",
            generate_groups_lua(self.groups),
            "",
            generate_views_lua(self.views),
            "",
            generate_mouse_actions_lua(self.mouse_actions, self.mouse_enabled),
            "",
        ]
        if self.weather_enabled:
            lines.append(WIDGET_WEATHER_FUNC)
            lines.append("")
        lines.append(WIDGET_BOOTSTRAP_TAIL)
        return "\n".join(lines)

    def _show_code(self):
        """Write the current in-memory layout to the live file and open it
        in the default editor via xdg-open."""
        content = self._generate_content()
        if not self._atomic_write(self.save_path, content):
            return
        self._maybe_write_conf()
        self._after_live_write()
        try:
            subprocess.Popen(["xdg-open", self.save_path],
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
            self.status.set_text(f"Opened {os.path.basename(self.save_path)}")
        except Exception as e:
            self.status.set_text(f"Could not open editor: {e}")

    def _atomic_write(self, filepath, content):
        tmp = filepath + ".tmp"
        try:
            with open(tmp, "w") as f:
                f.write(content)
                f.flush()
                os.fsync(f.fileno())
            os.replace(tmp, filepath)
            # Ensure the write is visible to inotify before we signal
            time.sleep(0.1)
            return True
        except Exception as e:
            self.status.set_text(f"Save error: {e}")
            return False

    def _on_window_configure(self, widget, event):
        self._save_window_state_debounced()
        return False

    def _on_window_state(self, widget, event):
        self._save_window_state_debounced()
        return False

    def _save_window_state_debounced(self):
        if self._state_save_timeout is not None:
            GLib.source_remove(self._state_save_timeout)
        self._state_save_timeout = GLib.timeout_add(400, self._flush_window_state)

    def _flush_window_state(self):
        self._state_save_timeout = None
        _save_window_state(self)
        return False

    def _on_delete_event(self, widget, event):
        if self._state_save_timeout is not None:
            GLib.source_remove(self._state_save_timeout)
            self._state_save_timeout = None
        _save_window_state(self)
        # Stop all management timers. A running conky is left untouched on
        # purpose: it is the desktop widget and keeps showing after exit.
        self._stop_watchdog()
        for attr in ("_restart_debounce_id", "_capture_poll_id", "_log_poll_id"):
            tid = getattr(self, attr, None)
            if tid is not None:
                GLib.source_remove(tid)
                setattr(self, attr, None)
        # X11: the managed preview ran with the live_clear helper. On exit
        # re-spawn all conky with their plain .conf (no preview ghost-clear).
        if self._conky_managed and self._is_x11() and self._ours_running():
            activity_log.add(
                "Conky", "exit: re-spawning widgets without preview helper"
            )
            subprocess.run(["killall", "-USR1", "conky"], capture_output=True)
            # clean up preview conf
            preview = getattr(self, "_spawn_conf_path", None)
            if preview and os.path.exists(preview):
                try:
                    os.remove(preview)
                except OSError:
                    pass
        return False

    def _on_quit(self, *a):
        if self._on_delete_event(None, None):
            return
        self.destroy()

    def _write_conf_and_pngs(self, lua_path):
        """Write the sibling .conf (diff-guarded, Conky Manager) + PNG captures."""
        self._maybe_write_conf(force=True)
        self._export_pngs(lua_path)

    def _save_current(self):
        content = self._generate_content()
        if self._atomic_write(self.save_path, content):
            self._maybe_write_conf()
            self._after_live_write()
            self._write_conf_and_pngs(self.save_path)
            self._clear_dirty()
            self.status.set_text(
                f"Saved {os.path.basename(self.save_path)} (+ .conf, .png)"
            )
        else:
            self.status.set_text("Save failed!")

    def _update_file_ui(self):
        """Refresh title bar, left-panel hint and conky ownership after the
        target file changes."""
        self._update_title()
        self.conky_hint_label.set_markup(
            "<small>Edits are written live to "
            + os.path.basename(self.save_path)
            + ".\nRun starts conky for the sibling .conf.</small>"
        )
        self._update_conky_state()

    def _open_file(self):
        dialog = Gtk.FileChooserDialog(
            title="Open...", transient_for=self, action=Gtk.FileChooserAction.OPEN,
        )
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Open", Gtk.ResponseType.ACCEPT)
        # Always start in the project folder; pre-select the current file only
        # when it actually lives there.
        dialog.set_current_folder(CONKY_DIR)
        if os.path.dirname(os.path.abspath(self.save_path)) == os.path.abspath(CONKY_DIR):
            dialog.set_filename(self.save_path)

        response = dialog.run()
        path = dialog.get_filename()
        dialog.destroy()

        if response != Gtk.ResponseType.ACCEPT or not path:
            return
        if not os.path.exists(path):
            self.status.set_text(f"File not found: {path}")
            return
        # Validate: try to parse and check for draw entries
        try:
            dl, gr, vw, _ = parse_widget_lua(path)
        except Exception as e:
            self.status.set_text(f"Parse error: {e}")
            return
        if not dl and not gr and not vw:
            dialog2 = Gtk.MessageDialog(
                transient_for=self, modal=True,
                message_type=Gtk.MessageType.WARNING,
                buttons=Gtk.ButtonsType.YES_NO,
                text="No draw items, groups, or views found.",
            )
            dialog2.format_secondary_text(
                "This file does not look like a valid widget.lua. Open anyway?"
            )
            resp2 = dialog2.run()
            dialog2.destroy()
            if resp2 != Gtk.ResponseType.YES:
                return
        self.save_path = path
        self._reload(path)
        self.status.set_text(f"Opened {os.path.basename(path)}")

    def _save_as(self):
        dialog = Gtk.FileChooserDialog(
            title="Save As...", transient_for=self, action=Gtk.FileChooserAction.SAVE,
        )
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Save", Gtk.ResponseType.ACCEPT)
        dialog.set_filename(self.save_path)

        response = dialog.run()
        path = dialog.get_filename()
        dialog.destroy()

        if response != Gtk.ResponseType.ACCEPT or not path:
            return
        content = self._generate_content()
        if self._atomic_write(path, content):
            self.save_path = path
            self._write_conf_and_pngs(path)
            self._clear_dirty()
            self._update_file_ui()
            self.status.set_text(
                f"Saved as {os.path.basename(path)} (+ .conf, .png)"
            )


def main():
    win = DesignerWindow()
    win.connect("delete-event", win._on_delete_event)
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
    shutil.rmtree(WORK_DIR, ignore_errors=True)


if __name__ == "__main__":
    main()
