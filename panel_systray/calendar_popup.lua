-- calendar_popup.lua — Loads the existing clock_cal.lua widget defaulting to the calendar view
local this_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local root_dir = this_dir:gsub("/panel_systray/?$", "")
if root_dir == "" or root_dir == this_dir then
    root_dir = (os.getenv("HOME") or "/root") .. "/.conky"
end
dofile(root_dir .. "/clock_cal.lua")
current_view = "view_1"
