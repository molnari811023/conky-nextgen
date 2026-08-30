#!/usr/bin/env lua

--[[[
debug/extreme_test.lua — extreme load / stress test: builds a 500-item draw
list (50 columns x 10 element types) from live conky vars, PNG files and
Papirus SVGs, then wraps conky_core_main to log per-update resource stats

Runs inside a live Conky session (it requires the 'require' bootstrap and
defines conky_core_main, the per-update Conky callback). Each update it logs
updates, RSS, VmPeak, CPU% and render time to stdout.
]]--

--{{{
-- ## Extreme draw-list stress test
--
-- Generates an extreme number of heterogeneous draw items from real system
-- data (Conky variables, PNGs found on disk, and Papirus SVG app icons) and
-- wraps Conky's per-update core to report resource usage, so rendering this
-- many items at once can be stress-tested for performance and leaks.
--
-- **What it does:**
-- - Resolves the project root from the debug/ folder, sets the Lua path and
--   the JSON/icon/theme config globals, and defines a THEMES table with a
--   palette, gradients and defaults plus DEFAULT_THEME.
-- - Defines CPU/memory/filesystem variable pools and two asset pools: PNG
--   files from the project and caches, and 50 Papirus SVG filenames.
-- - Builds 50 of each element type -- background, text, bar, graph, ring,
--   clock, calendar, image (PNG), svg and line -- for N = 50 columns
--   (500 draw items total) with unique keys and cycling values.
-- - Bootstraps the widget via require('require') and init_groups().
-- - Wraps conky_core_main() to measure render time and wall-clock CPU%, and
--   reads /proc/self/status for VmRSS/VmPeak, printing
--   '[update N] RSS MB | VmPeak MB | CPU % | render ms | <item count>' per
--   update.
--}}}

local src = debug.getinfo(1, 'S').source or ''
src = src:gsub('^@', '')
local here = src:match('^(.*[/\\])[^/\\]*$') or './'
script_dir = here:gsub('[/\\]debug[/\\]?$', '')
if script_dir == '' then script_dir = here end

package.path      = package.path
    .. ';' .. script_dir .. '/lua/?.lua'
    .. ';' .. script_dir .. '/lua/core/?.lua'
    .. ';' .. script_dir .. '/lua/draw/?.lua'
    .. ';' .. script_dir .. '/lua/weather/?.lua'
    .. ';' .. script_dir .. '/lua/hardware/?.lua'

JSON_PATH         = script_dir .. 'tmp/'
ICON_BASE         = script_dir .. 'icons/'
ICON_THEME        = 'default'
MOON_ICON_BASE    = script_dir .. 'icons/moon/'
WIND_ICON_BASE    = script_dir .. 'icons/wind/'

draw              = {}

THEMES            = {
    theme = {
        palette = {
            bg_dark = "#202326",
            bg_mid = "#292c30",
            bg_light = "#31363c",
            fg = "#fcfcfc",
            fg_dim = "#a1a9b1",
            blue = "#3daee9",
            green = "#27ae60",
            yellow = "#f67400",
            red = "#da4453",
        },
        gradients = {
            text_value    = { { 1, "#27ae60", 1 } },
            bar_cpu       = { { 1, "#3daee9", 1 } },
            border_subtle = { { 1, "#a1a9b1", 0.6 } },
        },
        defaults = {
            background = {
                bg = { { 1, "#202326", 0.9 } },
                border = { { 1, "#4a4d52", 1 } },
                border_width = 2
            },
            bar        = { fg = { { 1, "#3daee9", 1 } }, bg = { { 1, "#3a3d41", 1 } } },
            text       = { color = { { 1, "#fcfcfc", 1 } } },
        },
    },
}
DEFAULT_THEME     = 'theme'
_PADDING          = 0

------------------------------------------------------------
-- Változatos adatforrások és VALÓDI, egyedi fájlok a rendszerből
------------------------------------------------------------
local N, CELL, X0 = 50, 38, 4

local cpu_vars    = { "${cpu}", "${cpu cpu1}", "${cpu cpu2}", "${cpu cpu3}", "${cpu cpu4}" }
local mem_vars    = { "${memperc}", "${swapperc}", "${mem}", "${memfree}" }
local fs_vars     = { "${fs_used_perc /}", "${fs_used_perc /home}", "${fs_free /}", "${fs_size /}" }

-- Különböző PNG-k a te mappáidból / cache-edből
local png_pool    = {
    script_dir .. 'icons/open-meteo.png',
    '/boot/grub/themes/starfield/starfield.png',
    '/boot/grub/themes/starfield/blob_w.png',
    '/boot/grub/themes/starfield/slider_n.png',
    '/home/molnar/.cache/discover/icons/app.lith.Lith.desktop.png',
    '/home/molnar/.cache/discover/icons/com.dropbox.Client.desktop.png',
    '/home/molnar/.cache/discover/icons/com.jagex.RuneScape.desktop.png',
}

-- Papirus SVG ikonok listája az 50 darabos stresszteszthez
local svg_pool    = {
    "0ad.svg", "7zip.svg", "1password.svg", "0cc-famitracker.svg", "140-game.svg",
    "1CD8_rundll32.0.svg", "1cedt.svg", "1cestart.svg", "1cv8c.svg", "1cv8.svg",
    "1E64_notepad.0.svg", "2048-qt.svg", "2064-read-only-memories.svg", "2402_msiexec.0.svg",
    "2905_wscript.0.svg", "2EF4_wordpad.0.svg", "2gis.svg", "3dchess.svg", "3D-Coat.svg",
    "3depict.svg", "4137_winhlp32.0.svg", "4diac-ide.svg", "4digits.svg", "4kslideshowmaker.svg",
    "4kstogram.svg", "4kvideodownloader.svg", "4kvideotomp3.svg", "4kyoutubetomp3.svg",
    "4PaneIcon48.svg", "4Pane.svg", "5742_rundll32.0.svg", "5961_Defunct_x86.0.svg",
    "6180-the-moon.svg", "631F_RobloxStudioLauncherBeta.0.svg", "7596_iexplore.0.svg",
    "7765_winebrowser.0.svg", "7-days-to-die.svg", "7kaa.svg", "7z.svg",
    "81F5_winebrowser.0.svg", "8bitmmo.svg", "8tracks.svg", "97C1_wordpad.0.svg",
    "9gag.svg", "A35F_hh.0.svg", "a7800.svg", "a7xpg.svg", "aaaaxy.svg",
    "aafm.svg", "09BE_EpicGamesLauncher.0.svg"
}

------------------------------------------------------------
-- Extreme draw list: 50 oszlop, teljesen egyedi elemekkel
------------------------------------------------------------

for i = 1, N do
    draw[#draw + 1] = {
        type = 'background',
        x = X0 + (i - 1) * CELL,
        y = 4,
        w = 34,
        h = 96,
        radius = 6,
        border_width = 1
    }
end

for i = 1, N do
    local v = cpu_vars[((i - 1) % #cpu_vars) + 1]
    draw[#draw + 1] = {
        type = 'text',
        x = X0 + (i - 1) * CELL,
        y = 105,
        font = 'Mono',
        size = 8,
        text = 'C' .. i .. ' ' .. v .. '%',
        color = { { 1, "#fcfcfc", 1 } },
        wrap_width = 34
    }
end

for i = 1, N do
    local v = mem_vars[((i - 1) % #mem_vars) + 1]
    draw[#draw + 1] = {
        type = 'bar',
        x = X0 + (i - 1) * CELL,
        y = 130,
        width = 34,
        height = 10,
        value = v,
        max = 100
    }
end

for i = 1, N do
    local v = cpu_vars[((i - 1) % #cpu_vars) + 1]
    draw[#draw + 1] = {
        type = 'graph',
        x = X0 + (i - 1) * CELL,
        y = 155,
        width = 34,
        height = 40,
        value = v,
        max = 100,
        key = 'extreme_graph_' .. i
    }
end

for i = 1, N do
    local v = cpu_vars[((i - 1) % #cpu_vars) + 1]
    draw[#draw + 1] = {
        type = 'ring',
        x = X0 + (i - 1) * CELL + 17,
        y = 220,
        radius = 16,
        thickness = 4,
        value = v,
        max = 100,
        sectors = 6,
        mode = 'ring',
        sides = 6
    }
end

for i = 1, N do
    draw[#draw + 1] = {
        type = 'clock',
        x = X0 + (i - 1) * CELL + 17,
        y = 280,
        radius = 17,
        show_seconds = (i % 2 == 0)
    }
end

for i = 1, N do
    draw[#draw + 1] = {
        type = 'calendar',
        x = X0 + (i - 1) * CELL,
        y = 325,
        cell_w = 34,
        row_h = 12,
        font = 'Mono',
        size = 7
    }
end

for i = 1, N do
    local p = png_pool[((i - 1) % #png_pool) + 1]
    draw[#draw + 1] = {
        type = 'image',
        x = X0 + (i - 1) * CELL,
        y = 430,
        width = 34,
        height = 34,
        path = p
    }
end

-- Pontosan 50 darab SVG generálása a Papirus poolból
for i = 1, N do
    local svg_file = svg_pool[((i - 1) % #svg_pool) + 1]
    draw[#draw + 1] = {
        type = "svg",
        x = X0 + (i - 1) * CELL,
        y = 385,
        w = 32,
        h = 32,
        path = "/usr/share/icons/Papirus/48x48/apps/" .. svg_file,
    }
end

for i = 1, N do
    draw[#draw + 1] = {
        type = 'line',
        x1 = X0 + (i - 1) * CELL,
        y1 = 520,
        x2 = X0 + (i - 1) * CELL + 34,
        y2 = 560,
        thickness = 1 + (i % 3),
        style_type = 'solid'
    }
end

_GROUPS = {}
_VIEWS  = { { name = 'main' } }

------------------------------------------------------------
-- Bootstrap
------------------------------------------------------------
require('require')
init_groups(_GROUPS)

------------------------------------------------------------
-- Per-update stats
------------------------------------------------------------
local _prev_clock = os.clock()
local _prev_time  = os.time()

local function proc_status(field)
    local f = io.open('/proc/self/status', 'r')
    if not f then return 0 end
    local val = 0
    for line in f:lines() do
        local v = line:match('^' .. field .. ':%s+([%d]+)')
        if v then
            val = tonumber(v); break
        end
    end
    f:close()
    return val
end

local _orig_core_main = conky_core_main
function conky_core_main()
    local t0 = os.clock()
    _orig_core_main()
    local render_ms = (os.clock() - t0) * 1000

    local now = os.time()
    local wall = now - _prev_time
    local cpu = 0
    if wall > 0 then
        cpu = (os.clock() - _prev_clock) / wall * 100
    end
    _prev_clock = os.clock()
    _prev_time  = now

    io.write(string.format(
        '[update %s] RSS %6.1f MB | VmPeak %6.1f MB | CPU %5.1f%% | render %6.1f ms | %d draw items\n',
        conky_parse('${updates}'), proc_status('VmRSS') / 1024,
        proc_status('VmPeak') / 1024, cpu, render_ms, #draw))
    io.flush()
end
