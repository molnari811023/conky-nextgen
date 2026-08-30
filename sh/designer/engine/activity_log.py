#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## activity_log.py
#
# Thread-safe in-memory error/activity log for the designer GUI. Messages
# from the conky runs, the Lua probe and the render subprocess are stored
# as (timestamp, source, line) tuples and shown LIVE in a log window —
# nothing gets hidden. Consecutive duplicate entries collapse into one
# line to avoid spam, and listeners are notified on every change.
#
# **Exposed/global:**
# - `add(source, message)` — append a timestamped message (deduped)
# - `clear()` — reset the log
# - `entries()` — thread-safe snapshot of all entries
# - `subscribe(cb)` / `unsubscribe(cb)` — listener registration
#
# **Used by / input data:** collects errors/activity surfaced by conky
# runs, the Lua probe and the render subprocess; drives the designer's
# live log window.
#}}}
"""In-memory error/activity log for the designer GUI.

Errors surfaced by the conky runs, the Lua probe and the render
subprocess are collected here so the designer can show them LIVE in a
log window — nothing gets hidden, matching the project's no-swallowing
philosophy.

Consecutive duplicate entries (the same error on repeated preview
renders) collapse into one line to avoid spam.
"""

import threading
import time

_entries = []
_lock = threading.Lock()
_listeners = []


def add(source, message):
    """Append a message from `source` (e.g. "Lua", "Conky", "Render")."""
    with _lock:
        ts = time.strftime("%H:%M:%S")
        for line in (message.rstrip() or " ").splitlines() or [""]:
            if _entries and _entries[-1] == (ts, source, line):
                continue
            _entries.append((ts, source, line))
    _notify()


def clear():
    with _lock:
        del _entries[:]
    _notify()


def entries():
    with _lock:
        return list(_entries)


def subscribe(cb):
    if cb not in _listeners:
        _listeners.append(cb)


def unsubscribe(cb):
    if cb in _listeners:
        _listeners.remove(cb)


def _notify():
    for cb in list(_listeners):
        try:
            cb()
        except Exception:
            pass
