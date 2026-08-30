--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
-- list_functions.lua
-- Recursively lists local and non-local functions of the lua/ modules.
-- Usage: lua list_functions.lua [dir]

local lfs = require("lfs")

-- ANSI colors (disabled when piped or NO_COLOR is set)
local TERM = os.getenv("TERM") or ""
local color = (os.getenv("NO_COLOR") == nil) and TERM ~= "" and TERM ~= "dumb"
local ANSI = {
    bold = "\27[1m",
    cyan = "\27[36m",
    green = "\27[32m",
    yellow = "\27[33m",
    red = "\27[31m",
    dim = "\27[2m",
    reset = "\27[0m",
}
local function c(code, s)
    if not color then return s end
    return ANSI[code] .. s .. ANSI.reset
end

local function list_functions_in_file(path)
    local local_funcs = {}
    local global_funcs = {}

    local f = io.open(path, "r")
    if not f then return local_funcs, global_funcs end
    local text = f:read("*a") or ""
    f:close()

    -- local function foo(  (%s also matches newlines, so multi-line params work)
    for fn in text:gmatch("local%s+function%s+([%w_]+)%s*%(") do
        table.insert(local_funcs, fn)
    end

    -- global: function foo( / function foo.bar( / function foo:bar(
    -- strip "local function" lines first so they are not double-counted
    local no_local = text:gsub("local%s+function", "")
    for fn in no_local:gmatch("function%s+([%w_]+[%.:]?[%w_.]*)%s*%(") do
        table.insert(global_funcs, fn)
    end

    -- dedupe + sort
    local seen = {}
    for _, fn in ipairs(local_funcs) do seen[fn] = true end
    local l2 = {}
    for fn in pairs(seen) do l2[#l2 + 1] = fn end
    table.sort(l2)

    seen = {}
    for _, fn in ipairs(global_funcs) do seen[fn] = true end
    local g2 = {}
    for fn in pairs(seen) do g2[#g2 + 1] = fn end
    table.sort(g2)

    return l2, g2
end

local function scan_dir(dir, out)
    for file in lfs.dir(dir) do
        if file ~= "." and file ~= ".." then
            local full = dir .. "/" .. file
            local attr = lfs.attributes(full)
            if attr and attr.mode == "directory" then
                scan_dir(full, out)
            elseif file:match("%.lua$") then
                local lf, gf = list_functions_in_file(full)
                out[#out + 1] = { path = full, local_funcs = lf, global_funcs = gf }
            end
        end
    end
end

local root = arg[1] or "./lua"
local files = {}
scan_dir(root, files)
table.sort(files, function(a, b) return a.path < b.path end)

local total_l, total_g = 0, 0
for _, e in ipairs(files) do
    print("\n" .. c("bold", c("cyan", "=== " .. e.path .. " ===")))
    print("  " .. c("green", "GLOBAL FUNCTIONS:"))
    if #e.global_funcs == 0 then
        print("    " .. c("dim", "(no global function)"))
    else
        for _, fn in ipairs(e.global_funcs) do
            print("    " .. c("cyan", "- " .. fn))
        end
    end
    print("  " .. c("yellow", "LOCAL FUNCTIONS:"))
    if #e.local_funcs == 0 then
        print("    " .. c("dim", "(no local function)"))
    else
        for _, fn in ipairs(e.local_funcs) do
            print("    " .. c("yellow", "- " .. fn))
        end
    end
    total_l, total_g = total_l + #e.local_funcs, total_g + #e.global_funcs
end

-- Duplicated global functions across files (name defined in more than one)
local dupes = {}
for _, e in ipairs(files) do
    for _, fn in ipairs(e.global_funcs) do
        dupes[fn] = dupes[fn] or {}
        dupes[fn][#dupes[fn] + 1] = e.path
    end
end
local dupe_names = {}
for fn, paths in pairs(dupes) do
    if #paths > 1 then
        dupe_names[#dupe_names + 1] = fn
    end
end
table.sort(dupe_names)

print("\n" .. c("bold", c("red", "DUPLICATED FUNCTIONS:")))
if #dupe_names == 0 then
    print("  " .. c("dim", "(none)"))
else
    for _, fn in ipairs(dupe_names) do
        print("  " .. c("red", "- " .. fn) .. "  " .. c("dim", table.concat(dupes[fn], ", ")))
    end
end

print("\n" .. c("bold", string.format("%d files, %d global, %d local functions", #files, total_g, total_l)))
