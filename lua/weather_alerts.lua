-- ============================================================================
-- alerts.lua (merged) — MeteoAlarm weather alert XML parsing
-- ============================================================================

local alerts_cache_storage = nil
local alerts_cache_time = 0

local SEVERITY_WEIGHT = { Minor = 1, Moderate = 2, Severe = 3, Extreme = 4 }

local function alerts_file_mtime(path)
	local attrs = lfs.attributes(path)
	return attrs and attrs.modification or 0
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then return nil end
	local c = f:read("*all")
	f:close()
	return c
end

local lxp_ok, lxp = pcall(require, "lxp")

local function parse_alerts_from_xml(xml, city_name, admin1)
	if not xml or xml == "" then return {} end

	local function sax_parse()
		local entries = {}
		local cur, tag, buf = false, nil, {}
		local data = {}

		local function flush()
			if cur and tag then
				local s = table.concat(buf):match("^%s*(.-)%s*$")
				data[tag] = (data[tag] or "") .. s
			end
			buf = {}
		end

		local cbs = {
			StartElement = function(_, name)
				if name == "entry" or name:match(":entry$") then
					cur = true; data = {}; tag = nil; buf = {}
				elseif cur then
					flush()
					tag = name:match(":(.+)$") or name
				end
			end,
			CharacterData = function(_, s)
				table.insert(buf, s)
			end,
			EndElement = function(_, name)
				if not cur then return end
				if name == "entry" or name:match(":entry$") then
					flush()
					local sev = data.severity or ""
					local title = data.title or ""
					local w = SEVERITY_WEIGHT[sev] or 0
					local color = "yellow"
					local tl = title:lower()
					if tl:match("red") then
						color = "red"
					elseif tl:match("orange") or tl:match("severe") or tl:match("violent") then
						color = "orange"
					end
					table.insert(entries, {
						event = data.event or "", severity = sev,
						certainty = data.certainty or "", area = data.areaDesc or "",
						onset = data.onset or "", expires = data.expires or "",
						title = title, color = color, weight = w,
					})
					cur = false; tag = nil
				else
					local base = name:match(":(.+)$") or name
					if base == tag then
						flush()
						tag = nil
					end
				end
			end,
		}
		local p = lxp.new(cbs)
		p:parse(xml)
		p:close()
		return entries
	end

	local function regex_parse()
		local alerts = {}
		local function get(entry, t)
			local b = t:match(":(.+)$") or t
			local v = entry:match('<[^:>]*:?' .. b .. '[^>]*>([^<]*)')
			if not v then
				v = entry:match('<' .. b .. '[^>]*>([^<]*)')
			end
			if v then
				v = v:match('<!%[CDATA%[(.-)%]%]>') or v
				v = v:match("^%s*(.-)%s*$")
			end
			return v or ""
		end
		for e in xml:gmatch('<entry>(.-)</entry>') do
			local sev = get(e, "cap:severity")
			local title = get(e, "atom:title")
			local w = SEVERITY_WEIGHT[sev] or 0
			local color = "yellow"
			local tl = title:lower()
			if tl:match("red") then
				color = "red"
			elseif tl:match("orange") or tl:match("severe") or tl:match("violent") then
				color = "orange"
			end
			table.insert(alerts, {
				event = get(e, "cap:event"), severity = sev,
				certainty = get(e, "cap:certainty"), area = get(e, "cap:areaDesc"),
				onset = get(e, "cap:onset"), expires = get(e, "cap:expires"),
				title = title, color = color, weight = w,
			})
		end
		return alerts
	end

	local alerts
	if lxp_ok then
		local ok, res = pcall(sax_parse)
		alerts = ok and res or regex_parse()
	else
		alerts = regex_parse()
	end

	table.sort(alerts, function(a, b) return a.weight > b.weight end)

	local cn, a1 = (city_name or ""):lower(), (admin1 or ""):lower()
	local region_alerts = {}
	for _, a in ipairs(alerts) do
		local aa = a.area:lower()
		if (cn ~= "" and aa:find(cn, 1, true)) or (a1 ~= "" and aa:find(a1, 1, true)) then
			table.insert(region_alerts, a)
		end
	end
	if #region_alerts == 0 then region_alerts = alerts end

	local out = {}
	for i = 1, math.min(3, #region_alerts) do
		local a = region_alerts[i]
		table.insert(out, {
			event = a.event, severity = a.severity,
			area = a.area, onset = a.onset, expires = a.expires,
			title = a.title, color = a.color,
		})
	end
	return out
end

function load_alerts()
	local now = os.time()
	if not alerts_cache_storage or (now - alerts_cache_time > 120) then
		local xml_path = JSON_PATH .. "alerts.xml"
		local city_j = conky_read_j(JSON_PATH .. "city.json")
		local city_name = city_j and city_j.results and city_j.results[1] and city_j.results[1].name or ""
		local admin1 = city_j and city_j.results and city_j.results[1] and city_j.results[1].admin1 or ""
		local mtime = alerts_file_mtime(xml_path)

		if not alerts_cache_storage or mtime ~= (alerts_cache_storage._mtime or 0) then
			local xml = read_file(xml_path)
			if xml then
				alerts_cache_storage = { alerts = parse_alerts_from_xml(xml, city_name, admin1), _mtime = mtime }
			else
				alerts_cache_storage = { alerts = {}, _mtime = 0 }
			end
			alerts_cache_time = now
		end
	end
	return alerts_cache_storage and alerts_cache_storage.alerts or {}
end

function conky_update_alerts()
	load_alerts()
end

function alerts_count()
	return #load_alerts()
end

function alert_field(i, field)
	local a = (load_alerts())[i]
	if not a then return "" end
	local val = a[field]
	if not val or val == "" then return "" end
	local tr_map = {
		severity = "alert_severity_",
		color = "alert_color_",
		certainty = "alert_certainty_",
	}
	local prefix = tr_map[field]
	if prefix and get_tr then
		return get_tr(prefix .. val:lower())
	end
	return val
end
