# core/draw_mouse.lua

## Purpose

Mouse event handler: `conky_on_mouse()` — the single entry point for all Conky mouse events. Handles click dispatch, scroll, hover, drag-and-drop, context menu interaction, and enter/leave.

## Dependencies

- Requires `core.draw_input` (for `click_registry`, `text_registry`, `group_hit_registry`, `CLICK_ACTIONS`, `execute_scroll_action`)
- Requires `core.draw_context` (for `CONTEX_MENU`, `open_context_menu`, `close_context_menu`, `get_visible_menu_actions`)
- Requires `core.draw_group` (for `GROUP_STATE`, `toggle_group`)
- Loaded last among the core modules

## Conky Mouse Events

All 6 Conky mouse events are handled:

| Event | Field | Description |
|-------|-------|-------------|
| `button_down` | `button` = `"left"`/`"right"` | Click dispatch, drag start |
| `button_up` | — | Drag end (drop) |
| `mouse_scroll` | `direction` = `"up"`/`"down"` | Scroll actions |
| `mouse_move` | `x`, `y` | Hover tracking, drag movement |
| `mouse_enter` | — | Set `MOUSE_INSIDE = true` |
| `mouse_leave` | — | Reset all hover/drag state |

## Event Flow

### `button_down`

1. **Right-click** → find text under cursor → copy to clipboard → find group → open context menu
2. **Context menu open** → check if click is on a menu item → execute action → close menu
3. **Left-click on draggable** → start DRAG state (Neovim-inspired)
4. **Left-click on clickable** → dispatch to `CLICK_ACTIONS` (view/toggle/clipboard/command)

Priority: context menu > drag start > click actions.

### `mouse_scroll`

Iterates `click_registry` in reverse Z-order. If cursor is over an element with `scroll_up_action`/`scroll_down_action`, executes the scroll action.

### `mouse_move`

1. **DRAG active** → update position, find `drop_target` in layout
2. **No drag** → hover tracking: set `HOVER_VIEW` or toggle group on hover

### `button_up`

If DRAG was active and `did_drag` is true and `drop_target` exists → swap layout entries:
```lua
local source = table.remove(layout, DRAG.source_idx)
table.insert(layout, DRAG.drop_target, source)
```

### `mouse_enter` / `mouse_leave`

Enter: sets `MOUSE_INSIDE = true`.
Leave: resets all state — hover, DRAG, scroll offset.

## Hit Testing Order

All registries are iterated in **reverse** order (last drawn = topmost):

1. `group_hit_registry` — for context menu and drag detection
2. `click_registry` — for click/scroll/hover actions
3. `text_registry` — for right-click text copy

## Drag-and-Drop

Neovim-inspired drag system for rearranging groups.

### DRAG State

```lua
DRAG = {
    active = false,        -- drag in progress
    source = nil,          -- {group, name, x, y, w, h}
    source_idx = nil,      -- index in layout[]
    start_x/y = 0,        -- initial click position
    current_x/y = 0,      -- current cursor position
    offset_x/y = 0,       -- click offset from element origin
    prev_x/y = 0,         -- previous position (for velocity)
    did_drag = false,      -- true if moved >2px from start
    drop_target = nil,     -- index in layout[] of drop target
}
```

### Flow

1. **`button_down`** on draggable element → set DRAG state
2. **`mouse_move`** → update `current_x/y`, set `did_drag` if moved >2px, find `drop_target`
3. **`button_up`** → if `did_drag` and `drop_target`, swap layout entries
4. **`mouse_leave`** → reset DRAG state

### Visual Feedback

Rendered in the floating layer stack at `Z_INDEX.DRAG_OVERLAY` (300):
- **Ghost**: yellow semi-transparent rectangle following cursor
- **Drop target**: green semi-transparent highlight on target layout box

## Hover System

Two hover modes:

| Field | Behavior |
|-------|----------|
| `mouse_hover_view` | Sets `HOVER_VIEW` to the specified view while cursor is over the element |
| `mouse_hover_toggle` | Expands group on enter, collapses on leave (remembers previous group) |

Hover state is reset on `mouse_leave` and when cursor moves off the element.

## `on_mouse_enter` / `on_mouse_leave`

Overridable hooks. Default behavior:
- Enter: `MOUSE_INSIDE = true`
- Leave: reset hover, DRAG, scroll offset

```lua
on_mouse_enter = function()
    MOUSE_INSIDE = true
    -- custom behavior
end
```

## Configuration

Requires `conky.conf` settings:

```lua
conky.config = {
    own_window_type = "normal",   -- Wayland; X11-en "override"
    own_window_hints = "undecorated,below,sticky,skip_taskbar,skip_pager",
    lua_mouse_hook = "conky_on_mouse",
}
```

**Important**: `own_window_type` depends on your DE — Wayland usually `"normal"`, X11 `"override"`. See [docs/button_compatibility.md](../button_compatibility.md) for details.
