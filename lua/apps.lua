--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}
--[[[
lua/apps.lua — freedesktop .desktop application enumerator

Recursively scans the XDG applications directories and returns an array of
installed applications as plain Lua tables. The home data dir
($HOME/.local/share/applications) takes precedence over the system data
dirs: if a .desktop file with the same basename exists in a higher-priority
directory, it overrides (shadows) the lower-priority one.

Each returned entry has:
  name        (Name, localized if available)
  command     (Exec, with the %u/%f/%i/%k/%c field codes stripped/resolved)
  icon        (raw icon name from the .desktop file, or nil — NOT resolved;
               pass it to icon_theme.lua's icon_resolve() at draw time)
  icon_path   (resolved filesystem path when the icon is an absolute path)
  categories  (array of XDG category strings, or nil)
  terminal    (boolean, whether it should run in a terminal)
  nodisplay   (true when NoDisplay/Hidden, filtered out unless keep_hidden=true)
  desktop_file(absolute path of the parsed .desktop file)

Hidden entries (NoDisplay=true, Hidden=true) and entries without an Exec are
excluded from the returned list by default. `apps_list()` is idempotent and
cached, so repeated calls during a long-running Conky session only parse the
tree once.

**Exposed/global functions:**
- `apps_list()` — return all visible applications as an array of tables
- `apps_find(name)` — find a single application by Name (case-insensitive)
- `apps_clear_cache()` — forget the parsed application list

**Config/globals used:**
- `os.getenv` — for $HOME and $XDG_DATA_DIRS/HOME
- `APPS_CACHE` — global cache for the parsed application list
--]]
--{{{
-- ## Application enumerator

APPS_CACHE = APPS_CACHE or { _ready = false, list = {} }

local HOME = os.getenv("HOME") or "/root"

-- XDG data directories, most specific / highest priority first.
-- $XDG_DATA_HOME defaults to $HOME/.local/share, $XDG_DATA_DIRS to the
-- usual system locations.
local function xdg_data_dirs()
    local dirs = {}

    local data_home = os.getenv("XDG_DATA_HOME")
    if data_home and data_home ~= "" then
        dirs[#dirs + 1] = data_home
    else
        dirs[#dirs + 1] = HOME .. "/.local/share"
    end

    local data_dirs = os.getenv("XDG_DATA_DIRS")
    if not data_dirs or data_dirs == "" then
        data_dirs = "/usr/local/share:/usr/share:/var/lib/snapd/desktop"
    end
    for d in data_dirs:gmatch("[^:]+") do
        if d ~= "" then dirs[#dirs + 1] = d end
    end

    return dirs
end

local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

local function trim(s)
    if not s then return nil end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\r$", ""))
end

-- Recursively collect every *.desktop basename that exists in dir.
-- Returns { basename = full_path }.
local function collect_desktops(dir, out)
    out = out or {}
    local p = io.popen('find "' .. dir .. '" -type f -name "*.desktop" 2>/dev/null')
    if p then
        for f in p:lines() do
            local base = f:match("([^/]+)%.desktop$")
            if base and not out[base] then
                out[base] = f
            end
        end
        p:close()
    end
    return out
end

-- Parse a single .desktop file into a plain table. Returns nil if the file
-- is not a usable application entry.
local function parse_desktop(path)
    local f = io.open(path, "r")
    if not f then return nil end

    local entry = nil
    local seen_header = false
    for line in f:lines() do
        if line:match("^%[Desktop Entry%]") then
            seen_header = true
            entry = entry or {}
        elseif seen_header and line:match("^%[") then
            break
        elseif seen_header then
            local k, v = line:match("^%s*([^%s=]+)%s*=(.*)$")
            if k and v then
                entry[k] = v
            end
        end
    end
    f:close()

    if not entry then return nil end
    if entry.Type and entry.Type ~= "Application" then return nil end
    if not entry.Name or entry.Name == "" then return nil end

    local app = {
        name        = trim(entry.Name),
        command     = trim(entry.Exec),
        icon        = trim(entry.Icon),
        startupwmclass = trim(entry.StartupWMClass),
        terminal    = trim(entry.Terminal) == "true",
        nodisplay   = trim(entry.NoDisplay) == "true" or trim(entry.Hidden) == "true",
        desktop_file= path,
    }

    -- Categories: semicolon separated XDG list.
    local cats = trim(entry.Categories)
    if cats then
        local t = {}
        for cat in cats:gmatch("[^;]+") do
            local c = trim(cat)
            if c ~= "" then t[#t + 1] = c end
        end
        if #t > 0 then app.categories = t end
    end

-- OnlyShowIn / NotShowIn: keep as plain arrays for the caller to filter.
    local function split_list(s)
        if not s then return nil end
        local t = {}
        for item in s:gmatch("[^;]+") do
            local x = trim(item)
            if x ~= "" then t[#t + 1] = x end
        end
        return #t > 0 and t or nil
    end
    app.only_show_in = split_list(trim(entry.OnlyShowIn))
    app.not_show_in  = split_list(trim(entry.NotShowIn))

    return app
end

-- Strip the desktop-entry spec field codes from an Exec line and return a
-- shell-runnable command. %c → name, %i → --icon <path>, %k → desktop file,
-- %u/%U/%f/%F/%d/%D/%n/%N/%v/%m → removed.
local function clean_exec(exec, name, icon_path, desktop_file)
    if not exec then return nil end
    exec = exec:gsub("%%c", name or "")
    if icon_path then
        exec = exec:gsub("%%i", '--icon "' .. icon_path .. '"')
    else
        exec = exec:gsub("%%i", "")
    end
    exec = exec:gsub("%%k", desktop_file or "")
    exec = exec:gsub("%%[uUfFdDnNvm]", "")
    exec = trim(exec)
    if exec == "" then return nil end
    return exec
end

-- icon name → filesystem path. Only used when the .desktop Icon is already
-- an absolute path (the name alone stays in `icon`; the draw layer resolves
-- it later via icon_theme.lua's icon_resolve()).
local function icon_as_path(icon)
    if not icon or icon == "" then return nil end
    if icon:sub(1, 1) == "/" and file_exists(icon) then
        return icon
    end
    return nil
end

--- Return the list of visible applications, cached. Home .desktop files
-- override system ones with the same basename.
-- @tparam[opt] table opts
-- @tparam[opt] boolean opts.keep_hidden include NoDisplay/Hidden entries
-- @treturn table array of { name, command, icon, categories, terminal, ... }
function apps_list(opts)
    if APPS_CACHE._ready and not opts then
        return APPS_CACHE.list
    end

    local args_passed = opts ~= nil
    opts = opts or {}
    local keep_hidden = opts.keep_hidden
    local seen = {}
    local files = {}
    for _, data_dir in ipairs(xdg_data_dirs()) do
        local apps_dir = data_dir .. "/applications"
        if file_exists(apps_dir) then
            local found = collect_desktops(apps_dir)
            for base, path in pairs(found) do
                if not seen[base] then
                    seen[base] = true
                    files[#files + 1] = path
                end
            end
        end
    end

    local result = {}
    for _, path in ipairs(files) do
        local app = parse_desktop(path)
        if app then
            if not app.nodisplay or keep_hidden then
                -- Skip entries that cannot actually run (no Exec).
                local command = clean_exec(app.command, app.name, app.icon, app.desktop_file)
                if command or keep_hidden then
                    app.command = command
                    -- `icon` keeps the raw name for the theme resolver;
                    -- `icon_path` is filled only for absolute paths.
                    app.icon_path = icon_as_path(app.icon)
                    result[#result + 1] = app
                end
            end
        end
    end

    if not args_passed then
        APPS_CACHE._ready = true
        APPS_CACHE.list = result
    end
    return result
end

--- Find a single application by its Name (case-insensitive).
-- @tparam string name the application name to look for
-- @treturn table|nil the matching application entry, or nil
function apps_find(name)
    if not name then return nil end
    local target = name:lower()
    for _, app in ipairs(apps_list()) do
        if app.name and app.name:lower() == target then
            return app
        end
    end
    return nil
end

--- Find a single application by its StartupWMClass (used by wmctrl output).
-- The lookup is case-insensitive and matches against the StartupWMClass
-- field, the .desktop basename, and each WM_CLASS part ("instance.class").
-- For reverse-DNS classes (e.g. "ghostty.com.mitchellh.ghostty" where the
-- class is "com.mitchellh.ghostty") the class part after the first dot is
-- tried too, so a .desktop's StartupWMClass=com.mitchellh.ghostty matches.
-- @tparam string wmclass the WM_CLASS from wmctrl (e.g. "Navigator.firefox")
-- @treturn table|nil the matching application entry, or nil
function apps_by_wmclass(wmclass)
    if not wmclass or wmclass == "" then return nil end

    local w = tostring(wmclass):lower()
    local wanted = {}
    wanted[w] = true
    for p in w:gmatch("[^%.]+") do
        wanted[tostring(p):lower()] = true
    end
    -- the class part proper: everything after "instance." wmctrl's
    -- "instance.class" → for reverse-DNS ids the useful suffix is the rest
    local class_part = w:match("^[^%.]+%.(.+)$")
    if class_part then
        wanted[class_part] = true
        -- also short reverse-DNS suffixes (com.mitchellh.ghostty → mitchellh.ghostty)
        local s = class_part
        while s:match("^[^%.]+%.(.+)$") do
            s = s:match("^[^%.]+%.(.+)$")
            wanted[s] = true
        end
    end

    for _, app in ipairs(apps_list()) do
        local swc = app.startupwmclass
        if swc and swc ~= "" and wanted[tostring(swc):lower()] then
            return app
        end
    end
    for _, app in ipairs(apps_list()) do
        local base = app.desktop_file and app.desktop_file:match("([^/]+)%.desktop$")
        if base and wanted[tostring(base):lower()] then
            return app
        end
    end
    return nil
end

--- Forget the parsed application list so the next apps_list() re-scans.
function apps_clear_cache()
    APPS_CACHE._ready = false
    APPS_CACHE.list = {}
end
