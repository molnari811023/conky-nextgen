--[[
  Conky NextGen Framework
  Author: István Molnár
  GitHub: https://github.com/molnari811023/conky-nextgen
  Description: Modular Conky UI framework (Lua engine + Bash backend)
--]]
-- hardware/network.lua — WiFi status, public IP, ping
-- Network data is fetched by sh/fetch_network.sh (background)
-- Lua reads from cached tmp/ files — no synchronous I/O

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
	return tonumber(avg) or 0
end

function conky_ping_jitter()
	local s = get_ping_data()
	local min, _, max = s:match("rtt min/avg/max/mdev = ([%d%.]+)/([%d%.]+)/([%d%.]+)/")
	if min and max then
		return math.floor((tonumber(max) - tonumber(min)) * 10) / 10
	end
	return 0
end
