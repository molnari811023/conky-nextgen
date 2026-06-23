# 30 — hyphen.lua

## Purpose
Pure Lua hyphenation engine using LibreOffice `.dic` pattern files. Used by `31_draw_text` for word wrapping with hyphenation.

## Usage
```lua
local hyph = require("30_hyphen")
hyph.load("/usr/share/hyphen/hyph_en_US.dic")
local points = hyph.break_word("hyphenation")  -- byte positions
local wrapped = hyph.insert_hyphens("hyphenation")  -- "hy-phen-ation"
```

## Functions
| Function | Description |
|----------|-------------|
| `hyphen.load(path)` | Load and parse .dic file (cached by path + mtime) |
| `hyphen.break_word(word)` | Return byte positions for hyphenation breaks |
| `hyphen.insert_hyphens(word)` | Return string with hyphens inserted |

## Notes
- Supports UTF-8 (uses `lua-utf8` or builtin `utf8` library)
- Respects `LEFTHYPHENMIN` / `RIGHTHYPHENMIN` from the dictionary file
- Results are cached by file path and mtime
