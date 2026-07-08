# 35 — draw_layout.lua

## Purpose
Dynamic layout engine. Computes y-positions for named sections based on their heights. Makes it easy to stack widgets without hardcoding Y coordinates.

## How it works
Define a `layout` table (in `36_widget.lua`). Each entry has a `name` and `height`. The engine computes `y_start_<name>` and `height_<name>` global variables, and `y_end_dynamic` for total height tracking.

## Config Fields
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | — | Section name (used for `y_start_<name>` and `height_<name>`) |
| `height` | number/func | — | Section height in px (can be function for dynamic sizing) |
| `view` | string | nil | View filter — section skipped if doesn't match `current_view` |
| `group` | string | nil | Group toggle — section skipped if `GROUP_STATE[group]` is false |
| `enabled` | bool/func | true | Legacy — use `view`/`group` instead |

## Dynamic Height
`height` can be a function. Called every draw cycle:

```lua
{ name = "details", height = function()
    return GROUP_STATE["details"] and 55 or 0
  end, group = "details" }
```

## View and Group Filtering
When a section is filtered out (view doesn't match or group is hidden), it allocates **zero space** — the next section shifts up. This is how collapsible sections push/pull widgets below them:

```lua
layout = {
  { name = "header", height = 150 },
  { name = "details", height = 55, group = "details" },
}

-- y_end_dynamic = 157 when details hidden
-- y_end_dynamic = 219 when details shown
-- widgets using y_end_dynamic shift automatically
```

## Using in Draw Items
Layout variables are available as regular globals for function-based fields:

```lua
draw = {
  { type = "text", text = "Header", y = y_start_header + 10 },
  { type = "text", text = "Detail",
    y = function() return (y_start_details or 150) + 5 end,
    group = "details" },
  { type = "bar",
    y = function() return (y_end_dynamic or 150) + 10 end },
}
```

When `y_start_details` is nil (section hidden), the fallback `150` is used — but the item isn't drawn because its `group` is "details".

## Example
```lua
layout = {
    { name = "weather", height = 200 },
    { name = "cpu", height = 100, view = "main" },
    { name = "details", height = 55, group = "details" },
}
```

Creates:
- `y_start_weather = 0`, `height_weather = 200`
- `y_start_cpu = 207`, `height_cpu = 100` (only if `current_view == "main"`)
- `y_start_details = 314`, `height_details = 55` (only if `GROUP_STATE["details"] == true`)
- `y_end_dynamic = last_y + padding`

## Padding
Default padding between sections: 7px (set via `PADDING` constant in `35_draw_layout.lua`).
