local tool_dir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local project_dir = tool_dir .. "../"
local f = assert(io.open(tool_dir .. "lfsdebug.txt", "w"))
local lfs = require("lfs")
f:write("lfs type=", type(lfs), " tostring=", tostring(lfs), "\n")
local dir, dir_obj, err = lfs.dir(project_dir .. "language/")
assert(dir, err)
f:write("dir type=", type(dir), "\n")
for n in dir, dir_obj do
  f:write(" - ", n:sub(1, 20), "\n")
  if n:find("%.mo$") then
    f:write("MO!\n")
    break
  end
end
f:close()
