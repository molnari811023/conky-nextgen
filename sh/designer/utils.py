"""Path resolution, window state, and small utility functions."""
import sys
import os
import re
import json
import tempfile

from gi.repository import Gdk


def _find_conky_dir():
    """Resolve the conky-nextgen root directory.

    Priority:
      1. --conky-dir <path> CLI flag
      2. CONKY_NEXTGEN_DIR environment variable
      3. conky_dir = <path> in ~/.config/conky-designer.conf
      4. default: in-tree layout (this file is sh/designer/main.py)
    """
    if "--conky-dir" in sys.argv:
        i = sys.argv.index("--conky-dir")
        if i + 1 < len(sys.argv):
            return os.path.abspath(sys.argv[i + 1])

    env = os.environ.get("CONKY_NEXTGEN_DIR")
    if env:
        return os.path.abspath(env)

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

    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


HERE = os.path.dirname(os.path.abspath(__file__))

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
MAIN_LUA = os.path.join(CONKY_DIR, "main.lua")
ICON_PATH = next(
    (p for p in (
        os.path.join(CONKY_DIR, "nd.svg"),
        os.path.join(HERE, "icons", "conky_128.png"),
    ) if os.path.exists(p)),
    None,
)

THEME_NAME = "theme"

WORK_DIR = tempfile.mkdtemp(prefix="conky_designer_")

LIVE_CLEAR_LUA = os.path.join(HERE, "live_clear.lua")

HELP_DIR = os.path.join(tempfile.gettempdir(), "conky-designer-help")
CONKY_MAN_GZ = "/usr/share/man/man1/conky.1.gz"
CONKY_MANUAL_HTML = os.path.join(HELP_DIR, "conky-manual.html")
NEXTGEN_MD = os.path.join(CONKY_DIR, "NextGen.md")
NEXTGEN_HANDBOOK_HTML = os.path.join(HELP_DIR, "nextgen-handbook.html")


def _clamp_size(w, h):
    """Clamp a window size to the workarea of the monitor under the cursor."""
    try:
        disp = Gdk.Display.get_default()
        if disp is None:
            return w, h
        try:
            ptr = disp.get_pointer()
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
    """Short human-readable hint for the items list."""
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
    """Rough height heuristic for stacking newly added widgets."""
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
