-- calendar_popup.lua — Loads the existing clock_cal.lua widget defaulting to the calendar view
local home = os.getenv("HOME") or "/root"
dofile(home .. "/.conky/clock_cal.lua")
current_view = "view_1"
