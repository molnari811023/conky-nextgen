#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## update_checker.py
#
# Checks the GitHub repo for new versions at startup by querying the
# GitHub commits API for the latest HEAD commit SHA and comparing it
# with a locally persisted SHA in nextgen_version.txt. Reports one of
# "update_avail", "up_to_date", "dev_build" or "unknown", running in a
# daemon thread so the UI is never blocked; the result callback is
# dispatched via GLib.idle_add so it may touch GTK widgets.
#
# **Exposed/global:**
# - `check_for_update(callback)` — start the async check; calls
#   `callback(status, remote_sha, local_sha)` on the main thread
# - `save_current_version(sha)` — explicitly persist a known SHA
# - `VERSION_FILE` — path of the stored local SHA file
# - `GITHUB_API` — GitHub commits API URL
# - `REPO_URL` — repository home page URL
#
# **Usage / dependencies:**
# - urllib.request/urllib.error (HTTP API query), `json`, `threading`,
#   `os`; optional PyGObject `GLib` (idle dispatch); `CONKY_DIR` from
#   `utils`
#}}}
"""GitHub update checker for the NextGen Designer.

On startup queries the GitHub API for the latest commit SHA of the repo,
compares it with a locally stored version, and reports the status:
  - remote > local  → "Update available"
  - remote == local → "Up to date"
  - remote < local  → "Developer build"

The check runs in a background thread so it never blocks the UI.
"""
import json
import os
import threading
import urllib.request
import urllib.error

from utils import CONKY_DIR

VERSION_FILE = os.path.join(CONKY_DIR, "nextgen_version.txt")
GITHUB_API = "https://api.github.com/repos/molnari811023/conky-nextgen/commits?per_page=1"
REPO_URL = "https://github.com/molnari811023/conky-nextgen"


def _read_local_sha():
    """Read the locally stored commit SHA (short or full)."""
    try:
        with open(VERSION_FILE) as f:
            return f.read().strip()
    except OSError:
        return None


def _write_local_sha(sha):
    """Persist the local commit SHA."""
    try:
        with open(VERSION_FILE, "w") as f:
            f.write(sha)
    except OSError:
        pass


def _fetch_remote_sha():
    """Query the GitHub commits API and return the HEAD commit SHA."""
    try:
        req = urllib.request.Request(
            GITHUB_API,
            headers={"Accept": "application/vnd.github.v3+json",
                     "User-Agent": "NextGen-Designer"},
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode())
            if isinstance(data, list) and len(data) > 0:
                return data[0].get("sha", "")
    except (urllib.error.URLError, json.JSONDecodeError, OSError, IndexError):
        pass
    return None


def check_for_update(callback):
    """Run the update check in a background thread.

    When done, calls ``callback(status, remote_sha, local_sha)`` where
    *status* is one of:
      "up_to_date"   — remote == local
      "update_avail" — remote > local (new commits available)
      "dev_build"    — remote < local (local is ahead)
      "unknown"      — could not determine (network error etc.)

    ``callback`` is always called on the **main thread** (via GLib.idle_add
    wrapper), so it is safe to touch GTK widgets from it.
    """
    try:
        from gi.repository import GLib
    except ImportError:
        GLib = None

    def _worker():
        remote_sha = _fetch_remote_sha()
        local_sha = _read_local_sha()

        if remote_sha is None:
            status = "unknown"
        elif local_sha is None:
            status = "update_avail"
            _write_local_sha(remote_sha)
        elif remote_sha.startswith(local_sha) or local_sha.startswith(remote_sha):
            status = "up_to_date"
        else:
            # Simple prefix-free comparison: treat as strings.
            # remote > local → update available
            # remote < local → developer build
            if remote_sha > local_sha:
                status = "update_avail"
            elif remote_sha < local_sha:
                status = "dev_build"
            else:
                status = "up_to_date"

        def _emit():
            callback(status, remote_sha, local_sha)
            return False

        if GLib is not None:
            GLib.idle_add(_emit)
        else:
            _emit()

    t = threading.Thread(target=_worker, daemon=True)
    t.start()


def save_current_version(sha):
    """Explicitly save a known SHA (e.g. after a successful save)."""
    if sha:
        _write_local_sha(sha)
