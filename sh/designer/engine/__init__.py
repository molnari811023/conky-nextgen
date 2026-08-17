"""Engine core — pure-Python logic (no GTK dependency).

Modules:
  lua_parser.py   — parse widget.lua draw[] / themes.lua into Python dicts
  theme_engine.py — theme resolution + apply_theme (mirror of Lua theme_engine.lua)
  theme_writer.py — serialize THEMES dict back to themes.lua format
  gradient_gen.py — standalone gradient/palette/shade generator
  lua_data.py     — scan conky_* functions for the function picker
"""
