local src = debug.getinfo(1, "S").source:gsub("^@", "")
local here = src:match("^(.*[/\\])") or "./"
dofile(here .. "extreme_common.lua").run("image")
