--{{{
--  Conky NextGen Framework
--  Author: István Molnár
--  GitHub: https://github.com/molnari811023/conky-nextgen
--  Description: Modular Conky UI framework (Lua engine + Bash backend)
--}}}

--{{{
-- hardware/network.lua — WiFi status, public IP, ping
-- Network data is fetched by sh/fetch_network.sh (background)
-- Lua reads from cached tmp/ files — no synchronous I/O
-- Callable from Conky:
--   conky_wifi_interface()  → string ("wlp59s0")
--     Name of the active WiFi interface, or "lo"/empty when offline.
--   conky_wifi_active()     → 1|0
--     Whether a WiFi interface is currently up.
--   conky_public_ip()       → string ("1.2.3.4")
--     Public IPv4 address as reported by the network fetcher.
--   conky_public_city()     → string ("Budapest")
--     City of the public IP (geoip), "N/A" when unknown.
--   conky_public_country()  → string ("Hungary")
--     Country of the public IP (geoip).
--   conky_ping_avg()        → number (ms)
--     Average ping latency in milliseconds (from tmp/network_ping.json).
--   conky_ping_jitter()     → number (ms)
--     Ping jitter in milliseconds.
--   conky_wifi_ap()         → string (MAC address)
--   conky_wifi_bitrate()    → string ("11 Mb/s")
--   conky_wifi_channel()    → string
--   conky_wifi_essid()      → string
--   conky_wifi_freq()       → string
--   conky_wifi_link_qual_perc() → number
--   conky_wifi_mode()       → string ("Managed"/"Ad-Hoc"/"Master")
--   conky_wifi_ip(iface)    → string (IPv4 address)
--   conky_wifi_v6addrs(iface, show_netmask, show_scope) → string (IPv6)
--     IPv6 addresses for an interface. Optional: -n (netmask), -s (scope).
--   conky_wifi_downspeed(iface)  → string (e.g. "1.2 KiB/s")
--   conky_wifi_downspeedf(iface) → string (e.g. "1.2 KiB/s")
--   conky_wifi_upspeed(iface)    → string (e.g. "1.2 KiB/s")
--   conky_wifi_upspeedf(iface)   → string (e.g. "1.2 KiB/s")
--   All wireless_* functions accept optional iface argument,
--   default = conky_wifi_interface().
--
-- Data source: tmp/network_ip.json, tmp/network_ping.json
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
