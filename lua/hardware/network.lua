--[[[
lua/hardware/network.lua — WiFi status, public IP info, ping metrics, and wireless accessors for Conky.
]]--
--{{{
-- ## Network Module
--
-- Detects the active wireless interface, reports public IP geolocation
-- data and ping latency/jitter read from JSON files produced by external
-- scripts, and wraps every Conky `${wireless_*}` / `${downspeed}` /
-- `${upspeed}` template into a Lua function.
--
-- **Exposed/global functions:**
-- - `conky_wifi_interface()` — name of the first wireless interface found in sysfs
-- - `conky_wifi_active()` — returns 1 if the WiFi interface has a carrier, else 0
-- - `conky_public_ip()` — public IP address from JSON cache
-- - `conky_public_city()` — city from JSON cache
-- - `conky_public_country()` — country from JSON cache
-- - `conky_ping_avg()` — average ping round-trip time
-- - `conky_ping_jitter()` — max − min ping difference
-- - `conky_wifi_ap(iface)` — access point name
-- - `conky_wifi_bitrate(iface)` — current bitrate
-- - `conky_wifi_ip(iface)` — interface IP address
-- - `conky_wifi_channel(iface)` — wireless channel
-- - `conky_wifi_essid(iface)` — ESSID (network name)
-- - `conky_wifi_freq(iface)` — frequency
-- - `conky_wifi_downspeed(iface)` / `conky_wifi_downspeedf(iface)` — download speed
-- - `conky_wifi_upspeed(iface)` / `conky_wifi_upspeedf(iface)` — upload speed
-- - `conky_wifi_v6addrs(iface, show_netmask, show_scope)` — IPv6 addresses
-- - `conky_wifi_link_qual(iface)` / `_qual_max(iface)` / `_qual_perc(iface)` — signal quality
-- - `conky_wifi_mode(iface)` — wireless mode
--
-- **Config/globals used:**
-- `JSON_PATH`, `conky_parse()`, `cached()`, `read_file()`, `pread()`, `lfs`
--}}}

local network_ping_time = 0
local network_ip_time = 0
local network_ping_cache = ""
local network_ip_cache = ""

local function read_network_file(filename)
	local path = JSON_PATH .. filename
	local f = io.open(path, "r")
	if not f then return "" end
	local data = f:read("*a")
	f:close()
	return data or ""
end

local function get_ping_data()
	local now = os.time()
	if now - network_ping_time >= 10 then
		network_ping_time = now
		network_ping_cache = read_network_file("network_ping.json")
	end
	return network_ping_cache
end

local function get_ip_data()
	local now = os.time()
	if now - network_ip_time >= 600 then
		network_ip_time = now
		network_ip_cache = read_network_file("network_ip.json")
	end
	return network_ip_cache
end

function conky_wifi_interface()
	return cached("wifi_iface", 3600, function()
		if lfs then
			for iface in lfs.dir("/sys/class/net") do
				if iface ~= "." and iface ~= ".." then
					local f = io.open("/sys/class/net/" .. iface .. "/wireless", "r")
					if f then
						f:close()
						return iface
					end
				end
			end
		else
			local list = pread("ls /sys/class/net 2>/dev/null")
			for iface in list:gmatch("[^\n]+") do
				local f = io.open("/sys/class/net/" .. iface .. "/wireless", "r")
				if f then
					f:close()
					return iface
				end
			end
		end
		return ""
	end)
end

function conky_wifi_active()
	return cached("wifi_conn", 5, function()
		local iface = conky_wifi_interface()
		if iface == "" then
			return 0
		end
		local carrier = read_file("/sys/class/net/" .. iface .. "/carrier")
		return (carrier == "1") and 1 or 0
	end)
end

function conky_public_ip()
	local s = get_ip_data()
	return s:match('"ip"%s*:%s*"([^"]+)"') or "N/A"
end

function conky_public_city()
	local s = get_ip_data()
	return s:match('"city"%s*:%s*"([^"]+)"') or "N/A"
end

function conky_public_country()
	local s = get_ip_data()
	return s:match('"country"%s*:%s*"([^"]+)"') or "N/A"
end

function conky_ping_avg()
	local s = get_ping_data()
	local avg = s:match("rtt min/avg/max/mdev = [%d%.]+/([%d%.]+)/")
	return tonumber(avg)
end

function conky_ping_jitter()
	local s = get_ping_data()
	local min, _, max = s:match("rtt min/avg/max/mdev = ([%d%.]+)/([%d%.]+)/([%d%.]+)/")
	if min and max then
		return math.floor((tonumber(max) - tonumber(min)) * 10) / 10
	end
	return 0
end

--{{{
-- Wireless accessors — all use conky_parse("${wireless_xxx iface}")
--}}}

local function wifi_iface(iface)
	return iface or conky_wifi_interface() or ""
end

function conky_wifi_ap(iface)
	local i = wifi_iface(iface)
	return conky_parse("${wireless_ap " .. i .. "}")
end

function conky_wifi_bitrate(iface)
	local i = wifi_iface(iface)
	return conky_parse("${wireless_bitrate " .. i .. "}")
end

function conky_wifi_ip(iface)
	local i = wifi_iface(iface)
	return conky_parse("${addr " .. i .. "}")
end

function conky_wifi_channel(iface)
	local i = wifi_iface(iface)
	return conky_parse("${wireless_channel " .. i .. "}")
end

function conky_wifi_essid(iface)
	local i = wifi_iface(iface)
	return conky_parse("${wireless_essid " .. i .. "}")
end

function conky_wifi_freq(iface)
	local i = wifi_iface(iface)
	return conky_parse("${wireless_freq " .. i .. "}")
end


function conky_wifi_downspeed(iface)
	local i = wifi_iface(iface)
	return conky_parse("${downspeed " .. i .. "}")
end

function conky_wifi_downspeedf(iface)
	local i = wifi_iface(iface)
	return conky_parse("${downspeedf " .. i .. "}")
end

function conky_wifi_upspeed(iface)
	local i = wifi_iface(iface)
	return conky_parse("${upspeed " .. i .. "}")
end

function conky_wifi_upspeedf(iface)
	local i = wifi_iface(iface)
	return conky_parse("${upspeedf " .. i .. "}")
end

function conky_wifi_v6addrs(iface, show_netmask, show_scope)
	local i = wifi_iface(iface)
	local flags = ""
	if show_netmask then flags = flags .. " -n" end
	if show_scope then flags = flags .. " -s" end
	return conky_parse("${v6addrs" .. flags .. " " .. i .. "}")
end

function conky_wifi_link_qual(iface)
	local i = wifi_iface(iface)
	return tonumber(conky_parse("${wireless_link_qual " .. i .. "}"))
end

function conky_wifi_link_qual_max(iface)
	local i = wifi_iface(iface)
	return tonumber(conky_parse("${wireless_link_qual_max " .. i .. "}"))
end

function conky_wifi_link_qual_perc(iface)
	local i = wifi_iface(iface)
	return tonumber(conky_parse("${wireless_link_qual_perc " .. i .. "}"))
end

function conky_wifi_mode(iface)
	local i = wifi_iface(iface)
	return conky_parse("${wireless_mode " .. i .. "}")
end
