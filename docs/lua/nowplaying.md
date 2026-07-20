# nowplaying.lua

## Purpose
Displays currently playing music info from any MPRIS-compatible player (Audacious, VLC, Spotify, etc.) via `playerctl`. Shows title, artist, album, playback status, and album art.

## Dependencies
- `playerctl` (Arch: `extra/playerctl`)
- Any MPRIS-compatible media player (Audacious, VLC, Spotify, Rhythmbox, Strawberry, etc.)

## Accessor Functions

| Function | Returns |
|----------|---------|
| `conky_nowplaying_player()` | Player name (e.g. `audacious`, `vlc`) |
| `conky_nowplaying_title()` | Current track title |
| `conky_nowplaying_artist()` | Artist name |
| `conky_nowplaying_album()` | Album name |
| `conky_nowplaying_status()` | `Playing`, `Paused`, or `Stopped` |
| `conky_nowplaying_art_path()` | Path to cached album art PNG, or empty string |

## Example (`lua/widget.lua`)

```lua
draw = {
    -- Album art
    { type = "image", path = "${conky_nowplaying_art_path}",
      x = 20, y = 20, width = 64, height = 64 },

    -- Track title
    { type = "text", text = "${conky_nowplaying_title}",
      x = 94, y = 22, size = 14, weight = "bold",
      color = { { 1, "#ffffff", 1 } } },

    -- Artist
    { type = "text", text = "${conky_nowplaying_artist}",
      x = 94, y = 42, size = 11,
      color = { { 1, "#aaaaaa", 1 } } },

    -- Status indicator (Playing / Paused / Stopped)
    { type = "text", text = "${conky_nowplaying_status}",
      x = 94, y = 58, size = 10,
      color = { { 1, "#888888", 1 } } },
}
```

## Backend

Data is written by `sh/fetch_nowplaying.sh` to `tmp/nowplaying.json`. The album art is cached as `tmp/album_art.png`.

The fetch script only updates when the track changes (compares current/previous title), avoiding unnecessary file I/O.

## Controls (Conky ≥ 1.23+)

Future Conky 1.23 will support click/hover events, enabling play/pause/next/previous buttons directly in the Conky UI.
