# core/draw_group.lua

## Purpose

Three-state group management: `nil` (hidden), `"collapsed"` (header only), `"expanded"` (full content). Handles toggle logic, group registration from layout, and visibility checks via `draw_me`.

## Dependencies

- Loaded after `draw_core`, before `draw_context` and `draw_mouse`
- Reads/writes `GROUP_STATE`, `GROUP_REGISTRY`, `GROUP_HIDDEN_BY_DRAW_ME` globals (defined in `draw_core`)

## Three-State Model

| State | Meaning | Visible |
|-------|---------|---------|
| `nil` | Hidden (removed from view) | No |
| `"collapsed"` | Header only — content elements skipped | Partial (headers only) |
| `"expanded"` | Full content visible | Yes |

### State Transitions

```
nil ←→ expanded ←→ collapsed
         ↑    ↑
         │    └── toggle_group (arrow click)
         └─────── context menu "Restore all"
```

- **Arrow click** (on header): only `expanded` ↔ `collapsed` (2-state toggle)
- **Context menu "Hide"**: sets to `nil` (hidden)
- **Context menu "Restore all"**: restores all groups to `"expanded"`

## Functions

### `is_element_collapsed(el)`

Returns `true` if the element's group is in `"collapsed"` state. Used by the main draw loop to skip content elements.

```lua
if item.collapse and is_element_collapsed(item) then
    -- skip this element
end
```

### `toggle_group(name)`

Three-state toggle on the group named `name`:
- `"collapsed"` → `"expanded"`
- `"expanded"` → `"collapsed"`
- `nil` → `"expanded"`

Special: `toggle_group("__all_reset__")` resets all registered groups to `"expanded"`.

### `register_group(name)`

Registers a group name in `GROUP_REGISTRY` and initializes its state to `"expanded"` if not yet set.

### `register_groups_from_layout()`

Called once from `conky_core_main()`. Iterates the `layout[]` table and registers all groups. Runs only once (guarded by `groups_registered_from_layout` flag).

### `check_group_visibility()`

Evaluates `draw_me` conditions on layout entries. If a group's `draw_me` returns false:
- Saves current state to `GROUP_HIDDEN_BY_DRAW_ME`
- Sets `GROUP_STATE[group] = nil` (hides the group)

When `draw_me` becomes true again, restores the saved state.

## Header Registration

Headers are registered in `HEADER_REGISTRY` (in `draw_core.lua`) only if they have `click_toggle`:

```lua
if item.id:match("^h_") and item.group and item.click_toggle then
    HEADER_REGISTRY[item.group] = true
end
```

This controls which groups show "Collapse"/"Expand" in the context menu. Groups without a toggleable header (like g4 with static text) only show "Hide"/"Restore all".

## Layout Integration

Groups are defined in the `layout[]` table (in `widget.lua`):

```lua
layout = {
    { name = "g1", group = "Weather", h = 200 },
    { name = "g2", group = "System", h = 200, draggable = true },
}
```

The `DynamicLayout.compute()` function sets `_G["y_start_g1"]`, `_G["x_start_g1"]`, etc. — used by elements with `layout_box = "g1"`.
