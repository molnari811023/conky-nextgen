local has_system, system = pcall(require, "system")
if not has_system or not system.kill then system = nil end
local watcher = {}

local function get_script_dir()
    local src = debug.getinfo(1, "S").source
    if src:sub(1,1) == "@" then
        return src:sub(2):match("(.*[/\\])") or "./"
    end
    return "./"
end

local SCRIPT_DIR = get_script_dir()
local last_mtime = {}
local file_list = {}

local function get_pid_from_proc()
    local f = io.open("/proc/self/stat", "r")
    if f then
        local line = f:read("*l")
        f:close()
        if line then return line:match("^(%d+)") end
    end
    return nil
end

local function read_pid_from_file()
    local f = io.open(watcher.pid_file, "r")
    if f then
        local pid = f:read("*l")
        f:close()
        return pid
    end
    return nil
end

local function build_file_list(config_file, extra_dirs)
    local files = {}
    for file in lfs.dir(SCRIPT_DIR) do
        if file:match("%.lua$") then
            files[#files + 1] = SCRIPT_DIR .. file
        end
    end
    if extra_dirs then
        for _, dir in ipairs(extra_dirs) do
            for file in lfs.dir(dir) do
                if file:match("%.lua$") then
                    files[#files + 1] = dir .. file
                end
            end
        end
    end
    if config_file then
        local p = config_file:match("^/") and config_file or (SCRIPT_DIR .. config_file)
        local attr = lfs.attributes(p)
        if attr then files[#files + 1] = p end
    end
    return files
end

local function pid_is_conky(pid)
    if not pid then return false end
    local f = io.open("/proc/" .. pid .. "/comm", "r")
    if not f then return false end
    local comm = f:read("*l")
    f:close()
    return comm and comm:lower():match("conky")
end

local function scan_mtimes()
    local mtimes = {}
    for _, path in ipairs(file_list) do
        local attr = lfs.attributes(path) or (lfs.symlinkattributes and lfs.symlinkattributes(path))
        if attr then mtimes[path] = tostring(attr.modification) .. ":" .. tostring(attr.size or "") end
    end
    return mtimes
end

function watcher.init(cfg_name, config_file, base_dir, extra_dirs)
    if base_dir then SCRIPT_DIR = base_dir end
    watcher.pid_file = "/tmp/conky-nextgen-" .. cfg_name .. ".pid"
    watcher.config_file = config_file
    watcher.reload_counter = 0
    watcher.reload_armed = false
    watcher.last_reload_time = 0

    file_list = build_file_list(config_file, extra_dirs)
    last_mtime = scan_mtimes()
    io.stderr:write("[watcher] Watching " .. #file_list .. " files in " .. SCRIPT_DIR .. "\n")
    for _, p in ipairs(file_list) do
        io.stderr:write("[watcher]   " .. p .. "\n")
    end

    local pid = get_pid_from_proc()
    if pid then
        local f = io.open(watcher.pid_file, "w")
        if f then f:write(pid, "\n"); f:close() end
        io.stderr:write("[watcher] PID " .. pid .. " -> " .. watcher.pid_file .. "\n")
    end
end

function watcher.cleanup()
    io.stderr:write("[watcher] cleanup\n")
    if watcher.pid_file then
        os.remove(watcher.pid_file)
    end
end

function watcher.check()
    if #file_list == 0 then return false end

    local current_mtimes = scan_mtimes()
    local changed = {}

    for path in pairs(last_mtime) do
        if not current_mtimes[path] then
            changed[#changed + 1] = path
            last_mtime[path] = nil
        end
    end

    for path, cur in pairs(current_mtimes) do
        local old = last_mtime[path]
        if cur ~= old then
            changed[#changed + 1] = path
            last_mtime[path] = cur
        end
    end

    if #changed > 0 and not watcher.reload_armed then
        watcher.reload_armed = true
        watcher.reload_counter = 0
        if #changed > 5 then
            io.stderr:write("[watcher] " .. #changed .. " files changed\n")
        else
            for _, p in ipairs(changed) do
                io.stderr:write("[watcher] Change: " .. p .. "\n")
            end
        end
    end
    return #changed > 0
end

function watcher.arm_reload()
    if watcher.reload_armed then
        local now = os.time()
        if now - watcher.last_reload_time < 3 then return end
        watcher.reload_counter = watcher.reload_counter + 1
        if watcher.reload_counter >= 3 then
            local pid = get_pid_from_proc()
            if not pid or not pid_is_conky(pid) then
                pid = read_pid_from_file()
                if not pid or not pid_is_conky(pid) then
                    pid = nil
                end
            end
            if pid then
                io.stderr:write("[watcher] SIGUSR1 -> PID " .. pid .. "\n")
                if system then
                    system.kill(tonumber(pid), system.SIGUSR1)
                else
                    os.execute("kill -SIGUSR1 " .. pid .. " 2>/dev/null")
                end
            else
                io.stderr:write("[watcher] No valid PID, skip\n")
            end
            watcher.reload_armed = false
            watcher.last_reload_time = now
        end
    end
end

return watcher




