"""Lua template constants, theme data, and helper functions."""
import os

import engine.theme_writer as tw
from utils import THEME_NAME, HERE


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
    "gradients": {},
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
    """Build the empty widget.lua template, embedding the current theme."""
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
