# core/draw_input.lua

## Purpose

Input registration, click/scroll action dispatch, clickable overlay generator, and `build_draw()` — the bridge between user-defined `raw_elements` and the rendering pipeline.

This module was split from the old monolithic `24_draw_core.lua` to separate rendering from input handling.

## Dependencies

- Requires `core.draw_group` (for `toggle_group`)
- Requires `core.clipboard` (for `copy_to_clipboard`)
- Loaded after `draw_core`, before `draw_context` and `draw_mouse`

## Registries

| Registry | Purpose |
|----------|---------|
| `click_registry` | Hit-test targets for click/scroll/hover actions. Each entry has `x, y, w, h` + action fields |
| `text_registry` | Text elements for right-click copy. Each entry has `x, y, w, h, text` |
| `group_hit_registry` | Group-level hit zones for context menu + drag. Each entry has `group`, `target_group`, `layout_index`, `draggable` |
| `HEADER_REGISTRY` | Groups that have a header element with `click_toggle`. Controls context menu collapse/expand visibility |

## Click Actions (`CLICK_ACTIONS`)

Extensible table of click handlers. Keys:

| Key | Field | Description |
|-----|-------|-------------|
| `"view"` | `click_view` | Switch to this view: `current_view = e.click_view` |
| `"toggle"` | `click_toggle` | Toggle group: `toggle_group(e.click_toggle)` |
| `"command"` | `click` | Execute shell command: `os.execute(e.click .. " &")` |
| `"clipboard"` | `clipboard` | Copy text to clipboard: `copy_to_clipboard(text)` |

Priority order in hit testing: `click_view` > `click_toggle` > `clipboard` > `click`.

## Scroll Actions (`SCROLL_ACTIONS`)

Extensible table of scroll handlers. Action format: `"command:arg1:arg2"`.

| Key | Format | Description |
|-----|--------|-------------|
| `"view"` | `"view:viewname"` | Switch view on scroll |
| `"group"` | `"group:name:expand"` | Expand/collapse/toggle group |
| `"command"` | `"command:cmd"` | Execute shell command |
| `"scroll"` | `"scroll:up"` or `"scroll:down"` | Scroll content up/down |

## `clickable(item)`

Returns an `input_overlay` element — an invisible rectangle that carries input fields from a visual element. Used by `build_draw()` to create transparent click targets on top of rendered elements.

```lua
-- Creates an invisible clickable overlay for a text element
table.insert(draw, clickable(my_text_element))
```

## `register_input(item, bounds)`

Registers an element in `click_registry` if it has any input field (`click`, `click_view`, `click_toggle`, `clipboard`, `scroll_up_action`, `scroll_down_action`, `mouse_hover_view`, `mouse_hover_toggle`).

Called from the main draw loop for each non-collapsed element.

## `build_draw(raw_elements)`

Converts `raw_elements` (user-defined table in `widget.lua`) into the `draw` table used by the render loop. For each element with input fields, appends both the visual element and a `clickable()` overlay.

```lua
-- widget.lua
raw_elements = {
    { type = "text", x = 10, y = 10, w = 200, h = 30, text = "Click me", click_view = "settings" },
}
-- build_draw creates:
-- draw[1] = the text element
-- draw[2] = clickable overlay with click_view
```

## `conky_mouse_status()`

Debug function. Returns a status string with current view and hover index. Usage:

```lua
conky.text = [[${lua conky_mouse_status}]]
```

## Input Field Reference

| Field | Type | Trigger | Description |
|-------|------|---------|-------------|
| `click` | string | Left click | Shell command to execute |
| `click_view` | string | Left click | Switch to this view name |
| `click_toggle` | string | Left click | Toggle this group name |
| `clipboard` | string/function | Left click | Text to copy to clipboard |
| `scroll_up_action` | string | Scroll up | Scroll action (format: `"cmd:arg1:arg2"`) |
| `scroll_down_action` | string | Scroll down | Scroll action |
| `mouse_hover_view` | string | Mouse enter | Switch to this view on hover |
| `mouse_hover_toggle` | string | Mouse enter | Expand group on hover, collapse on leave |
