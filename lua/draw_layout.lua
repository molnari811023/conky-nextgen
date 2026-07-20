--[[
  Conky NextGen Framework
  draw_layout.lua — Dynamic y-position layout engine (three-state)
  header_height: collapsed state uses only the header height
  multi-column: when a column is full, moves to the next one
  string key cache: minimizes GC pressure
]]

DynamicLayout = DynamicLayout or {}

local PADDING = 7
local string_name_cache = {}

local function get_cached_keys(name)
  if not string_name_cache[name] then
    string_name_cache[name] = {
      y = "y_start_" .. name,
      x = "x_start_" .. name,
      h = "height_" .. name,
    }
  end
  return string_name_cache[name]
end

local function eval(v)
  if type(v) == "function" then return v() end
  return v
end

function DynamicLayout.compute(list, start_y, opts)
  if not list then return end

  opts = opts or {}
  local max_h = opts.max_height or 800
  local col_w = opts.column_width or 300
  local col_gap = opts.column_gap or 20
  local start_x = opts.start_x or 0

  local cur_x = start_x
  local cur_y = start_y or 0
  local col = 0

  _G.y_end_dynamic = cur_y
  _G.max_column = 0

  for _, box in ipairs(list) do
    local name = box.name
    local enabled = box.enabled
    local view = box.view
    local group = box.group

    if enabled ~= false and draw_allowed(view, group) and name then
      local state = group and GROUP_STATE[group]
      local collapsed = (state == "collapsed")

      local h
      if collapsed then
        h = box.header_height or (THEME and THEME.header_height) or 24
      else
        h = eval(box.height) or 0
      end

      if cur_y + h > max_h and cur_y > (start_y or 0) then
        col = col + 1
        cur_x = start_x + col * (col_w + col_gap)
        cur_y = start_y or 0
      end

      local keys = get_cached_keys(box.name)
      _G[keys.y] = cur_y
      _G[keys.x] = cur_x
      _G[keys.h] = h
      cur_y = cur_y + h + PADDING
      _G.y_end_dynamic = cur_y
      _G.max_column = col
    end
  end
end
