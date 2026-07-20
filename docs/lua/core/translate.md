# 1 — translate.lua

## Purpose
Loads `.mo` translation files and provides the `get_tr()` function for internationalization.

## Dependencies
- Global `STRINGS_MO_PATH` (set in `main.lua`)

## Globals
| Name | Description |
|------|-------------|
| `get_tr(msgid)` | Returns translated string or the msgid itself as fallback |

## How it works
- Reads a binary `.mo` file (GNU gettext format)
- Parses the message catalog into a Lua table
- If `get_tr` is already defined (by Conky's native support), it is not overridden
