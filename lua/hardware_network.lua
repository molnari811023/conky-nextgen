--{{{ WIFI
function conky_wifi_interface()
	return cached("wifi_iface", 3600, function()
		local list = pread("ls /sys/class/net 2>/dev/null")
		for iface in list:gmatch("[^\n]+") do
			local f = io.open("/sys/class/net/" .. iface .. "/wireless", "r")
			if f then
				f:close()
				return iface
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

local function read_ipinfo()
	return cached("ipinfo_raw", 600, function()
		return pread("curl -s https://ipinfo.io")
	end)
end

function conky_public_ip()
	local s = read_ipinfo()
	return s:match('"ip"%s*:%s*"([^"]+)"') or "N/A"
end

function conky_public_city()
	local s = read_ipinfo()
	return s:match('"city"%s*:%s*"([^"]+)"') or "N/A"
end

function conky_public_country()
	local s = read_ipinfo()
	return s:match('"country"%s*:%s*"([^"]+)"') or "N/A"
end

function read_ping()
	return cached("ping_raw", 10, function()
		return pread("ping -c 3 -q 1.1.1.1 2>/dev/null")
	end)
end

function conky_ping_avg()
	local s = read_ping()
	local avg = s:match("rtt min/avg/max/mdev = [%d%.]+/([%d%.]+)/")
	return tonumber(avg) or 0
end

function conky_ping_jitter()
	local s = read_ping()
	local min, _, max = s:match("rtt min/avg/max/mdev = ([%d%.]+)/([%d%.]+)/([%d%.]+)/")
	if min and max then
		return math.floor((tonumber(max) - tonumber(min)) * 10) / 10
	end
	return 0
end
--}}}
