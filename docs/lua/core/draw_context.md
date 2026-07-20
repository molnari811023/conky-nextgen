# core/draw_context.lua

## Purpose

Right-click context menu for groups: collapse, expand, hide, restore, and text copy. Renders as a floating layer at `Z_INDEX.CONTEXT_MENU` (100).

## Dependencies

- Requires `core.draw_group` (for `GROUP_STATE`, `GROUP_REGISTRY`, `toggle_group`)
- Requires `core.clipboard` (for `copy_to_clipboard`)
- Loaded after `draw_group`, before `draw_mouse`

## State

```lua
CONTEX_MENU = {
    visible = false,  -- is menu open
    x = 0,            -- screen position
    y = 0,
    group = nil,      -- group name under cursor (or nil)
    text = nil,       -- text to copy (right-click on text element)
}
```

## Menu Actions

| Label | Condition | Action |
|-------|-----------|--------|
| `"Copy"` | Right-click on text element | Copy text to clipboard |
| `"Collapse"` | Group is not collapsed AND has header | Set state to `"collapsed"` |
| `"Expand"` | Group is not expanded AND has header | Set state to `"expanded"` |
| `"Hide"` | Group is not nil (visible) | Set state to `nil` |
| `"Restore all"` | Always shown | Reset all groups to `"expanded"` |

**Key detail**: "Collapse"/"Expand" only appear if the group has a header registered in `HEADER_REGISTRY` (i.e., a header element with `click_toggle`). This prevents meaningless collapse/expand for headerless groups like g4.

## Functions

### `open_context_menu(ex, ey, group_name)`

Opens the menu at screen coordinates `(ex, ey)` for the given group.

### `close_context_menu()`

Hides the menu and clears group/text references.

### `get_visible_menu_actions()`

Returns the filtered list of actions based on current state. Handles:
- Text copy (if `CONTEX_MENU.text` is set)
- Group actions (based on `GROUP_STATE` and `HEADER_REGISTRY`)
- "Restore all" (always available)

### `draw_context_menu(cr)`

Renders the menu using Cairo. Dark rounded rectangle background with white text labels. Called from the floating layer stack in `conky_core_main()`.

## Rendering

The menu is rendered in the floating layer stack (not in the main draw loop):

```lua
-- In conky_core_main()
if CONTEX_MENU.visible then
    table.insert(floating, {
        z_index = Z_INDEX.CONTEXT_MENU,  -- 100
        draw = function(cr) draw_context_menu(cr) end,
    })
end
```

This ensures the menu always appears on top of regular elements.

## Hit Testing

Menu item clicks are handled in `conky_on_mouse()` (draw_mouse.lua):

```lua
if CONTEX_MENU.visible then
    for i, entry in ipairs(actions) do
        if ex >= cx and ex <= cx + CONTEX_MENU_W
           and ey >= ey2 and ey <= ey2 + CONTEX_MENU_H then
            entry.action(CONTEX_MENU.group)
            close_context_menu()
        end
    end
end
```

## Visual

- Background: dark semi-transparent (`rgba(0.1, 0.1, 0.14, 0.95)`)
- Border: gray (`rgba(0.35, 0.35, 0.4, 1)`)
- Items: slightly lighter background, white text
- Font: Sans 11px
- Dimensions: 160x28px per item, 8px padding, 6px border radius
