--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- 36_widget.lua — User widget config. Define draw[], layout[] here.
-- A layout szekciók y_start_<name> globálisokat állítanak be.
-- A draw itemek ezeket használják — ha function, minden ciklusban újraszámolódik.

-- Teszt: override mód, csoport-toggle lenyomja az alatta lévő widgeteket
current_view = "main"
GROUP_STATE = { details = false }

-- View gomb színek
local VIEW_ACTIVE = { { 1, "#FFFFFF", 1 }, { 1, "#4444FF", 1, "bg" } }
local VIEW_INACTIVE = { { 1, "#666666", 1 } }
local VIEW_ACTIVE2 = { { 1, "#FFFFFF", 1 }, { 1, "#FF4444", 1, "bg" } }

layout = {
  { name = "header", height = 150 },
  { name = "details", height = function()
      return GROUP_STATE["details"] and 55 or 0
    end, group = "details" },
}

draw = {
  { type = "background",
    x = 0, y = 0, w = 500, h = function()
      return math.max(500, (y_end_dynamic or 0) + 250)
    end, radius = 10,
    bg = { { 1, "#1a1a1a", 0.7 } },
    border = { { 1, "#4c4e51", 1 } }, border_width = 1,
  },

  -- Main view
  { type = "text",
    x = 250, y = 50, text = "Conky NextGen — override + click teszt",
    size = 16, align = "center", color = { { 1, "#FFFFFF", 1 } },
    view = "main",
  },

  -- View váltó
  { type = "text",
    x = 20, y = 80, w = 100, h = 20,
    text = "main", size = 12, click_view = "main",
    color = function()
      return (current_view == "main") and VIEW_ACTIVE or VIEW_INACTIVE
    end,
  },
  { type = "text",
    x = 130, y = 80, w = 100, h = 20,
    text = "player", size = 12, click_view = "player",
    color = function()
      return (current_view == "player") and VIEW_ACTIVE2 or VIEW_INACTIVE
    end,
  },

  -- OS command click
  { type = "text",
    x = 20, y = 110, w = 200, h = 20,
    text = "Kattints ide: ghostty", size = 14, click = "ghostty",
    color = { { 1, "#FFFF88", 1 } },
  },

  -- Toggle gomb: a header alján
  { type = "text",
    x = 20, y = function() return 140 end, w = 200, h = 20,
    text = function()
      return GROUP_STATE["details"] and "▼ Részletek" or "▶ Részletek"
    end,
    size = 14, click_toggle = "details",
    color = function()
      return GROUP_STATE["details"] and { { 1, "#FFAA00", 1 } } or { { 1, "#00FFAA", 1 } }
    end,
  },

  -- Részletek (csak ha a csoport be van kapcsolva)
  { type = "text",
    x = 30, y = function() return (y_start_details or 150) + 5 end,
    w = 200, h = 20,
    text = "CPU: 45%",  size = 12, group = "details",
  },
  { type = "text",
    x = 30, y = function() return (y_start_details or 150) + 30 end,
    w = 200, h = 20,
    text = "RAM: 60%",  size = 12, group = "details",
  },

  -- Widgetek a részletek ALATT (lenyomódnak ha details kibontva)
  { type = "bar",
    x = 20, y = function() return (y_end_dynamic or 150) + 10 end,
    width = 200, height = 20,
    value = 66, max = 100,
    click = "notify-send 'hello' 'bar clicked'",
    bg = { { 1, "#333333", 1 } }, fg = { { 1, "#00FF00", 1 } },
  },

  { type = "graph",
    x = 20, y = function() return (y_end_dynamic or 150) + 50 end,
    width = 200, height = 40,
    name = "cpu",
    click = "notify-send 'hello' 'graph clicked'",
    bg = { { 1, "#333333", 1 } }, fg = { { 1, "#00FFAA", 1 } },
  },

  { type = "ring",
    x = 150, y = function() return (y_end_dynamic or 150) + 120 end,
    radius = 30,
    value = 75, max = 100,
    click = "notify-send 'hello' 'ring clicked'",
    bg = { { 1, "#333333", 1 } }, fg = { { 1, "#FF8800", 1 } },
  },

  { type = "image",
    x = 300, y = function() return (y_end_dynamic or 150) + 10 end,
    width = 48, height = 48,
    path = "/home/molnar/conky-nextgen/icons/open-meteo.png",
    click = "notify-send 'hello' 'image clicked'",
  },

  -- Player nézet
  { type = "text",
    x = 250, y = 100, w = 300, h = 20,
    text = "Now playing: ...", view = "player",
    size = 14, align = "center", color = { { 1, "#00FFAA", 1 } },
  },
  { type = "text",
    x = 250, y = 130, w = 300, h = 20,
    text = "⏮  ⏸  ⏭", view = "player",
    size = 14, align = "center", color = { { 1, "#FFFFFF", 1 } },
  },
}