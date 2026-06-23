# 3 — watcher.lua

## Purpose
Watches Lua files and config for changes. Sends SIGUSR1 to reload Conky when files are modified.

## Functions
| Name | Description |
|------|-------------|
| `watcher.init(name, config_file, base_dir, extra_dirs)` | Start watching |
| `watcher.check()` | Scan mtimes, return true if changes detected |
| `watcher.arm_reload()` | After 3 checks with changes, send SIGUSR1 |
| `watcher.cleanup()` | Remove PID file |

## How it works
- Lists all `.lua` files in the project directory
- Compares mtime + size on every check
- After 3 consecutive checks with changes, sends `kill -SIGUSR1` to Conky
- Writes PID to `/tmp/conky-nextgen-<name>.pid`
