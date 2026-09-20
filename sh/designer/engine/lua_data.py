#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## lua_data.py
#
# Scans the project's lua/ source for the `conky_*` data functions and
# builds a {name: {args, source}} catalog for the designer's function
# picker. Nothing is evaluated here — the live preview is the real conky,
# not a Python renderer, so the old probe machinery is gone.
#
# **Exposed/global:**
# - `list_conky_functions()` — {name: {args: (names), source: relpath}}
#
# **Used by / input data:** walks lua/hardware/*.lua, lua/weather/*.lua
# and lua/nowplaying.lua plus the weather map tables; feeds the designer's
# function picker (control/draw helpers excluded).
#}}}
"""List the project's conky_* Lua functions for the designer's function picker.

The project's data layer (lua/hardware/*.lua, lua/weather/*.lua,
lua/nowplaying.lua) defines conky_* data functions. We scan the source so the
designer can offer them in a picker. No evaluation happens here — the live
preview is the real conky, not a Python renderer, so the probe machinery is
gone.
"""

import os
import re

_LUA_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))))), "lua")

# control/draw helpers, not data for text/widget values
_EXCLUDED = {
    "conky_core_main",
    "conky_cleanup",
    "conky_on_mouse",
    "conky_load_weather_data",
    "conky_update_alerts",
    "conky_round",
    "conky_read_j",
}

_FUNC_RE = re.compile(r"^\s*function\s+(conky_[A-Za-z0-9_]+)\s*\(([^)]*)\)", re.M)

def _scan_file(path, out):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            text = f.read()
    except OSError:
        return
    rel = os.path.relpath(path, _LUA_DIR)
    for m in _FUNC_RE.finditer(text):
        name = m.group(1)
        args = tuple(a.strip() for a in m.group(2).split(",") if a.strip())
        if name not in out:
            out[name] = {"args": args, "source": rel}


def list_conky_functions():
    """Return {name: {args: (names), source: relpath}} for all conky_* fns."""
    out = {}
    for root, _dirs, files in os.walk(_LUA_DIR):
        for fn in sorted(files):
            if fn.endswith(".lua"):
                _scan_file(os.path.join(root, fn), out)
    for name in _EXCLUDED:
        out.pop(name, None)
    return out
