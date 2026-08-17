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
    "conky_load_spaceweather",
    "conky_update_alerts",
    "conky_round",
    "conky_read_j",
}

_FUNC_RE = re.compile(r"^\s*function\s+(conky_[A-Za-z0-9_]+)\s*\(([^)]*)\)", re.M)

# weather/units.lua builds conky_unit_*/conky_city_* accessors from Lua map
# tables at load time; the tables are static, so we parse them here too.
_UNITLESS_KEYS = {"is_day", "uv_index", "precipitation_probability", "time", "interval"}
_MAP_TABLES = [
    ("core.lua", "cur_map", "conky_unit_cur_", True),
    ("core.lua", "hour_map", "conky_unit_hour_", True),
    ("units.lua", "air_cur_map", "conky_unit_air_cur_", False),
    ("units.lua", "air_hour_map", "conky_unit_air_hour_", False),
    ("units.lua", "city_num_map", "conky_city_", False),
    ("units.lua", "city_str_map", "conky_city_", False),
]
_MAP_NAME_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\"([^\"]*)\"")


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


def _scan_map_tables(out):
    """Register conky_unit_*/conky_city_* getters built from Lua map tables."""
    for rel, table, prefix, unitless_filter in _MAP_TABLES:
        path = os.path.join(_LUA_DIR, "weather", rel)
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError:
            continue
        m = re.search(r"\b" + re.escape(table) + r"\s*=\s*\{(.*?)\}", text, re.S)
        if not m:
            continue
        for key, field in _MAP_NAME_RE.findall(m.group(1)):
            # units.lua filters on the FIELD name (map value), not the key
            if unitless_filter and field in _UNITLESS_KEYS:
                continue
            name = prefix + key
            if name not in out:
                out[name] = {"args": (), "source": "weather/" + rel}


def list_conky_functions():
    """Return {name: {args: (names), source: relpath}} for all conky_* fns."""
    out = {}
    for root, _dirs, files in os.walk(_LUA_DIR):
        for fn in sorted(files):
            if fn.endswith(".lua"):
                _scan_file(os.path.join(root, fn), out)
    _scan_map_tables(out)
    for name in _EXCLUDED:
        out.pop(name, None)
    return out
