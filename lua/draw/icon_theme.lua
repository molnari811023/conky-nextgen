--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- draw/icon_theme.lua — XDG icon theme resolver
-- Finds closest-size SVG from icon themes, with automatic context search.
-- Search order: ~/.local/share/icons → ~/.icons → /usr/local/share/icons → /usr/share/icons

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

function find_best_size(sizes, target)
    if not sizes or #sizes == 0 then return nil end
    local best, best_diff = sizes[1], math.abs(sizes[1] - target)
    for i = 2, #sizes do
        local diff = math.abs(sizes[i] - target)
        if diff < best_diff then
            best, best_diff = sizes[i], diff
        end
    end
    return best
end

function parse_index_theme(theme_name)
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
        ICON_THEME_CACHE[theme_name] = { sizes = {}, inherits = {}, path = nil }
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
        for name in inh_line:gmatch("[^,]+") do
            inherits[#inherits + 1] = name:match("^%s*(.-)%s*$")
        end
    end

    local result = { sizes = sizes, inherits = inherits, path = theme_path }
    ICON_THEME_CACHE[theme_name] = result
    return result
end

function icon_resolve(name, target_size, theme_name)
    if not name or name == "" then return nil end
    target_size = target_size or 48
    theme_name = theme_name or "Papirus"

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

        local sz = find_best_size(t.sizes, target_size)
        if sz then
            local dir = t.path .. sz .. "x" .. sz
            for _, ctx in ipairs(CONTEXT_PRIORITY) do
                local path = dir .. "/" .. ctx .. "/" .. name .. ".svg"
                if file_exists(path) then
                    return path
                end
            end
        end

        local scalable = t.path .. "scalable"
        for _, ctx in ipairs(CONTEXT_PRIORITY) do
            local path = scalable .. "/" .. ctx .. "/" .. name .. ".svg"
            if file_exists(path) then
                return path
            end
        end

        return nil
    end

    local result = try_theme(theme_name)
    if result then
        ICON_PATH_CACHE[cache_key] = result
        return result
    end

    for _, inh in ipairs(theme.inherits) do
        result = try_theme(inh)
        if result then
            ICON_PATH_CACHE[cache_key] = result
            return result
        end
    end

    ICON_PATH_CACHE[cache_key] = false
    return nil
end
