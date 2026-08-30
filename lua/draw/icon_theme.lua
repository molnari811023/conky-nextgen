--[[[
lua/draw/icon_theme.lua — Resolves freedesktop icon-theme names to file paths

Parses index.theme files, follows the Inherits chain, and caches both parsed
metadata and resolved paths in global tables.
]]--

--{{{
-- ## Icon Theme
--
-- Locates icon files by name within a freedesktop-compliant icon theme. The
-- module searches standard XDG directories, parses index.theme metadata to
-- extract available sizes and the Inherits chain, and picks the closest size
-- match. SVG files are preferred; PNG is used as a fallback. All results are
-- cached in global tables keyed by theme/name/size.
--
-- **Exposed/global functions:**
-- - `icon_resolve(name, target_size, theme_name)` — Returns the filesystem path to the best-matching icon, or nil.
--
-- **Config/globals used:**
-- - `ICON_THEME_CACHE` — global cache for parsed index.theme metadata.
-- - `ICON_PATH_CACHE` — global cache for resolved icon file paths.
-- - `XDG_ICON_THEME` — fallback theme name when none is passed explicitly.
-- - `cache_set()` — external LRU cache helper used for both caches.
--}}}

ICON_THEME_CACHE = ICON_THEME_CACHE or {}
ICON_PATH_CACHE = ICON_PATH_CACHE or {}

local HOME = os.getenv("HOME") or "/root"

local ICON_SEARCH_PATHS = {
    HOME .. "/.local/share/icons/",
    HOME .. "/.icons/",
    "/usr/local/share/icons/",
    "/usr/share/icons/",
}

local CONTEXT_PRIORITY = {
    "apps", "places", "devices", "status", "actions",
    "categories", "emblems", "mimetypes", "panel", "emotes",
}

local function file_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function find_best_size(sizes, target)
    if not sizes or #sizes == 0 then return nil end
    target = tonumber(target) or sizes[1]
    local best, best_diff = sizes[1], math.abs(sizes[1] - target)
    for i = 2, #sizes do
        local diff = math.abs(sizes[i] - target)
        if diff < best_diff then
            best, best_diff = sizes[i], diff
        end
    end
    return best
end

local function parse_index_theme(theme_name)
    if ICON_THEME_CACHE[theme_name] then
        return ICON_THEME_CACHE[theme_name]
    end

    local data = nil
    local theme_path = nil

    for _, base in ipairs(ICON_SEARCH_PATHS) do
        local path = base .. theme_name .. "/index.theme"
        if file_exists(path) then
            data = read_file(path)
            theme_path = base .. theme_name .. "/"
            break
        end
    end

    if not data then
        cache_set(ICON_THEME_CACHE, theme_name, { sizes = {}, inherits = {}, path = nil }, 128)
        return ICON_THEME_CACHE[theme_name]
    end

    local sizes = {}
    local seen = {}
    for size_str in data:gmatch("Size=(%d+)") do
        local s = tonumber(size_str)
        if s and not seen[s] then
            seen[s] = true
            sizes[#sizes + 1] = s
        end
    end
    table.sort(sizes)

    local inherits = {}
    local inh_line = data:match("Inherits=([^\n]+)")
    if inh_line then
        -- CRLF index.theme files would leave a trailing \r on the last name
        inh_line = inh_line:gsub("\r", "")
        for name in inh_line:gmatch("[^,]+") do
            inherits[#inherits + 1] = name:match("^%s*(.-)%s*$")
        end
    end

    local result = { sizes = sizes, inherits = inherits, path = theme_path }
    cache_set(ICON_THEME_CACHE, theme_name, result, 128)
    return result
end

local function icon_resolve(name, target_size, theme_name)
    if not name or name == "" then return nil end
    target_size = target_size or 48
    theme_name = theme_name or XDG_ICON_THEME or "Papirus"

    local cache_key = theme_name .. ":" .. name .. ":" .. tostring(target_size)
    if ICON_PATH_CACHE[cache_key] then
        return ICON_PATH_CACHE[cache_key]
    end

    local theme = parse_index_theme(theme_name)
    if not theme.path then return nil end

    local best_size = find_best_size(theme.sizes, target_size)

    local function try_theme(tname)
        local t = parse_index_theme(tname)
        if not t.path then return nil end

        -- Many themes ship some icons only as .png (hicolor, breeze, ...);
        -- try .svg first, then fall back to .png.
        local exts = { ".svg", ".png" }
        local function find_in(dir)
            for _, ctx in ipairs(CONTEXT_PRIORITY) do
                for _, ext in ipairs(exts) do
                    local path = dir .. "/" .. ctx .. "/" .. name .. ext
                    if file_exists(path) then
                        return path
                    end
                end
            end
            return nil
        end

        local sz = find_best_size(t.sizes, target_size)
        if sz then
            local found = find_in(t.path .. sz .. "x" .. sz)
            if found then return found end
        end

        local found = find_in(t.path .. "scalable")
        if found then return found end

        return nil
    end

    local result = try_theme(theme_name)
    if result then
        cache_set(ICON_PATH_CACHE, cache_key, result, 512)
        return result
    end

    for _, inh in ipairs(theme.inherits) do
        result = try_theme(inh)
        if result then
            cache_set(ICON_PATH_CACHE, cache_key, result, 512)
            return result
        end
    end

    cache_set(ICON_PATH_CACHE, cache_key, false, 512)
    return nil
end
