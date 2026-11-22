#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## fetch_icloud — pyicloud-based Apple iCloud data & Find My mini-map fetcher
#
# Uses python-pyicloud (`pyicloud`) to query Apple iCloud services:
# - Account & iCloud Storage quota + per-media breakdown (Photos, Backups, Docs, Mail)
# - Find My iPhone / Apple devices list (battery, status, GPS coordinates, accuracy)
# - OpenStreetMap Nominatim reverse geocoding (country, postcode, city, district,
#   street, house_number, street_full, short)
# - OpenStreetMap street-level (zoom 16) 3x3 tile download & ImageMagick pixel-exact
#   centered crop into $TMP_DIR/iphone_map.png
# - iCloud Calendar events & iOS Reminders
#
# **Usage:**
# - `./sh/fetch_icloud.sh`            — normal background fetch (smart GPS cache)
# - `./sh/fetch_icloud.sh --force`    — force fresh GPS reverse-geocode & map tiles
# - `./sh/fetch_icloud.sh --auth ID`  — interactive Apple ID + 2FA login & cookie save
# - `./sh/fetch_icloud.sh --sound [i]`— play Find My sound on device index i (default 1)
#}}}
_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/common.sh"

ICLOUD_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/conky-nextgen"
ICLOUD_CONF="$ICLOUD_CONF_DIR/icloud.conf"
ICLOUD_COOKIE_STORE="${XDG_DATA_HOME:-$HOME/.local/share}/conky-nextgen/pyicloud"
ICLOUD_TMP_COOKIES="/tmp/pyicloud/${USER:-$(id -un)}"

[ -f "$ICLOUD_CONF" ] && source "$ICLOUD_CONF"
[ -f "$HOME/.conky/icloud.conf" ] && source "$HOME/.conky/icloud.conf"

ICLOUD_USERNAME="${ICLOUD_USERNAME:-}"
ICLOUD_CALENDAR_DAYS="${ICLOUD_CALENDAR_DAYS:-14}"
ICLOUD_MAP_ZOOM="${ICLOUD_MAP_ZOOM:-16}"
ICLOUD_TIMEOUT="${ICLOUD_TIMEOUT:-300}"

mkdir -p "$ICLOUD_COOKIE_STORE" "$ICLOUD_TMP_COOKIES" 2>/dev/null
chmod 700 "$ICLOUD_COOKIE_STORE" "$ICLOUD_TMP_COOKIES" 2>/dev/null || true

# Sync persistent cookies <-> /tmp/pyicloud/$USER using -u (copy only newer/missing files)
sync_cookies_in() {
	mkdir -p "$ICLOUD_COOKIE_STORE" "$ICLOUD_TMP_COOKIES" 2>/dev/null
	chmod 700 "$ICLOUD_COOKIE_STORE" "$ICLOUD_TMP_COOKIES" 2>/dev/null || true
	# 1. First restore /tmp from persistent store after reboot
	cp -puf "$ICLOUD_COOKIE_STORE"/* "$ICLOUD_TMP_COOKIES"/ 2>/dev/null || true
	# 2. If /tmp has newer files, sync them back to persistent store
	cp -puf "$ICLOUD_TMP_COOKIES"/* "$ICLOUD_COOKIE_STORE"/ 2>/dev/null || true
}

sync_cookies_out() {
	mkdir -p "$ICLOUD_COOKIE_STORE" "$ICLOUD_TMP_COOKIES" 2>/dev/null
	chmod 700 "$ICLOUD_COOKIE_STORE" "$ICLOUD_TMP_COOKIES" 2>/dev/null || true
	cp -puf "$ICLOUD_COOKIE_STORE"/* "$ICLOUD_TMP_COOKIES"/ 2>/dev/null || true
	cp -puf "$ICLOUD_TMP_COOKIES"/* "$ICLOUD_COOKIE_STORE"/ 2>/dev/null || true
}

# Immediately sync and restore /tmp during initialization
sync_cookies_in

build_iphone_map() {
	local lat="$1"
	local lon="$2"
	local zoom="${3:-16}"

	local MAGICK="magick"
	command -v magick >/dev/null 2>&1 || MAGICK="convert"
	command -v "$MAGICK" >/dev/null 2>&1 || { log "[icloud] ImageMagick not found — skipping map"; return 1; }

	read -r cx cy px py < <(python3 -c '
import sys, math
lat = float(sys.argv[1]); lon = float(sys.argv[2]); z = int(sys.argv[3])
n = 2.0 ** z
rad = math.radians(lat)
xtile_f = (lon + 180.0) / 360.0 * n
ytile_f = (1.0 - math.asinh(math.tan(rad)) / math.pi) / 2.0 * n
cx = int(xtile_f)
cy = int(ytile_f)
px = int(round((xtile_f - cx) * 256.0))
py = int(round((ytile_f - cy) * 256.0))
print(cx, cy, px, py)
' "$lat" "$lon" "$zoom" 2>/dev/null)

	[ -z "$cx" ] && return 1
	log "[icloud] Building street map LAT=$lat LON=$lon ZOOM=$zoom (tile $cx,$cy offset +$px,+$py)"

	local idx=0
	for dy in -1 0 1; do
		for dx in -1 0 1; do
			local tx=$((cx + dx))
			local ty=$((cy + dy))
			local out="$TMP_DIR/icloud_osm_${idx}.png"
			curl_cmd -A "ConkyNextGen/2.0 (https://github.com/molnari811023/conky-nextgen)" \
				-o "$out" "https://tile.openstreetmap.org/$zoom/$tx/$ty.png"
			if [ ! -s "$out" ]; then
				sleep 0.5
				curl_cmd -A "ConkyNextGen/2.0 (https://github.com/molnari811023/conky-nextgen)" \
					-o "$out" "https://tile.openstreetmap.org/$zoom/$tx/$ty.png"
			fi
			if [ ! -s "$out" ]; then
				"$MAGICK" -size 256x256 xc:"#1e222a" "$out"
			fi
			idx=$((idx + 1))
		done
	done

	# Center point inside the 768x768 3x3 grid is (256 + px, 256 + py).
	# Crop a 512x512 region so the exact GPS coordinate is at the dead center (256, 256).
	local crop_x=$((px))
	local crop_y=$((py))
	[ "$crop_x" -lt 0 ] && crop_x=0
	[ "$crop_y" -lt 0 ] && crop_y=0
	[ "$crop_x" -gt 256 ] && crop_x=256
	[ "$crop_y" -gt 256 ] && crop_y=256

	# Render stitched map with Apple Find My style glowing Blue Dot + accuracy halo at dead center (256, 256)
	"$MAGICK" \
		\( "$TMP_DIR/icloud_osm_0.png" "$TMP_DIR/icloud_osm_1.png" "$TMP_DIR/icloud_osm_2.png" +append \) \
		\( "$TMP_DIR/icloud_osm_3.png" "$TMP_DIR/icloud_osm_4.png" "$TMP_DIR/icloud_osm_5.png" +append \) \
		\( "$TMP_DIR/icloud_osm_6.png" "$TMP_DIR/icloud_osm_7.png" "$TMP_DIR/icloud_osm_8.png" +append \) \
		-append \
		-crop "512x512+${crop_x}+${crop_y}" +repage \
		-fill "rgba(0, 122, 255, 0.20)" -stroke "rgba(0, 122, 255, 0.45)" -strokewidth 1.5 -draw "circle 256,256 256,294" \
		-stroke none -fill "rgba(0, 0, 0, 0.32)" -draw "circle 256,258 256,271" \
		-fill white -draw "circle 256,256 256,269" \
		-fill "#007aff" -draw "circle 256,256 256,265" \
		-fill white -draw "circle 256,256 256,259" \
		"$TMP_DIR/iphone_map.png.tmp" && mv "$TMP_DIR/iphone_map.png.tmp" "$TMP_DIR/iphone_map.png"

	rm -f "$TMP_DIR"/icloud_osm_[0-8].png "$TMP_DIR/iphone_map.png.tmp"

	if [ "$TMP_DIR" != "$HOME/.conky/tmp" ] && [ -f "$TMP_DIR/iphone_map.png" ]; then
		mkdir -p "$HOME/.conky/tmp" 2>/dev/null || true
		cp -f "$TMP_DIR/iphone_map.png" "$HOME/.conky/tmp/iphone_map.png" 2>/dev/null || true
	fi
	log "[icloud] iphone_map.png updated"
}

icloud_auth_interactive() {
	local user="${1:-$ICLOUD_USERNAME}"
	if [ -z "$user" ]; then
		read -r -p "Apple ID (e-mail): " user
	fi
	[ -z "$user" ] && { echo "[error] Apple ID is required!"; return 1; }

	if ! python3 -c "import pyicloud, srp" >/dev/null 2>&1; then
		echo "[error] python-pyicloud package is not installed!"
		echo "        Install via: cd ~/conky-nextgen/pkg/python-pyicloud && makepkg -si"
		return 1
	fi

	mkdir -p "$ICLOUD_CONF_DIR"
	if [ ! -f "$ICLOUD_CONF" ]; then
		cat > "$ICLOUD_CONF" <<EOF
# Conky NextGen — iCloud configuration
ICLOUD_USERNAME="$user"
ICLOUD_MAP_ZOOM="${ICLOUD_MAP_ZOOM:-16}"
ICLOUD_CALENDAR_DAYS="${ICLOUD_CALENDAR_DAYS:-14}"
EOF
	else
		sed -i "s|^ICLOUD_USERNAME=.*|ICLOUD_USERNAME=\"$user\"|" "$ICLOUD_CONF"
	fi
	chmod 600 "$ICLOUD_CONF"
	echo "[icloud] Saved Apple ID ($user) to $ICLOUD_CONF"
	echo "[icloud] Starting interactive authentication (SRP6a + 2FA)..."
	echo "         (Tap 'Allow' on your trusted Apple device when the prompt appears)"
	sync_cookies_in

	icloud auth login --username "$user" --session-dir "$ICLOUD_COOKIE_STORE" --accept-terms
	local rc=$?
	sync_cookies_out
	return $rc
}

icloud_play_sound() {
	local target_idx="${1:-1}"
	python3 -c "import pyicloud" >/dev/null 2>&1 || return 1
	sync_cookies_in
	python3 - "$ICLOUD_USERNAME" "$ICLOUD_COOKIE_STORE" "$target_idx" "${ICLOUD_PASSWORD_B64:-}" <<'PYEOF'
import sys
import os
import base64
from pyicloud import PyiCloudService

username = sys.argv[1]
cookie_dir = sys.argv[2]
target_idx = max(1, int(sys.argv[3]))
pw_b64 = sys.argv[4] if len(sys.argv) > 4 else ""

if not username:
    sys.exit(1)

password = os.environ.get("ICLOUD_PASSWORD")
if not password and pw_b64:
    try:
        password = base64.b64decode(pw_b64.encode("ascii")).decode("utf-8")
    except Exception:
        password = None

try:
    api = PyiCloudService(username, password, cookie_directory=cookie_dir, refresh_interval=None, locate=False)
except TypeError:
    api = PyiCloudService(username, password, cookie_directory=cookie_dir)

if api.requires_2fa or api.requires_2sa:
    sys.exit(2)

devs = list(api.devices)
devs.sort(key=lambda d: (0 if d.data.get("deviceClass") == "iPhone" else 1, d.data.get("name", "")))
if target_idx <= len(devs):
    devs[target_idx - 1].play_sound()
PYEOF
	sync_cookies_out
}

fetch_icloud() {
	local force_map=0
	if [ "${1:-}" = "--force" ] || [ "${ICLOUD_FORCE_MAP:-0}" = "1" ]; then
		force_map=1
	fi

	python3 -c "import pyicloud" >/dev/null 2>&1 || { log "[icloud] python-pyicloud not installed — skipping"; return 0; }

	exec 9>"$TMP_DIR/icloud_fetch.lock"
	flock -n 9 || { log "[icloud] refresh already running — skipping"; return 0; }

	sync_cookies_in

	local prev_json="$TMP_DIR/icloud.json"
	if [ ! -f "$prev_json" ] && [ -f "$HOME/.conky/tmp/icloud.json" ]; then
		prev_json="$HOME/.conky/tmp/icloud.json"
	fi

	if timeout "$ICLOUD_TIMEOUT" python3 - \
		"$ICLOUD_USERNAME" \
		"$ICLOUD_COOKIE_STORE" \
		"$prev_json" \
		"$TMP_DIR/icloud.json.tmp" \
		"$ICLOUD_CALENDAR_DAYS" \
		"$force_map" \
		"$TMP_DIR/iphone_map.png" \
		"${ICLOUD_PASSWORD_B64:-}" <<'PYEOF' 2>"$TMP_DIR/icloud.err"
import sys
import os
import json
import time
import base64
import urllib.request
from datetime import datetime, timedelta

def log_step(msg):
    sys.stderr.write(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}\n")
    sys.stderr.flush()

username = sys.argv[1].strip()
cookie_dir = sys.argv[2]
prev_json_path = sys.argv[3]
out_json_path = sys.argv[4]
cal_days = int(sys.argv[5])
force_map = int(sys.argv[6]) == 1
map_png_path = sys.argv[7]
pw_b64 = sys.argv[8] if len(sys.argv) > 8 else ""

prev_data = {}
if os.path.isfile(prev_json_path):
    try:
        with open(prev_json_path, "r", encoding="utf-8") as f:
            prev_data = json.load(f) or {}
    except Exception:
        prev_data = {}

if not username:
    username = prev_data.get("account", {}).get("apple_id", "")

if not username:
    out = {
        "status": "unconfigured",
        "error": "ICLOUD_USERNAME not configured. Run: ./sh/fetch_icloud.sh --auth <apple_id>",
        "updated": int(time.time()),
        "updated_str": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "storage": {},
        "devices": [],
        "calendar": [],
        "reminders": [],
        "map_needs_update": False,
    }
    with open(out_json_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    sys.exit(0)

from pyicloud import PyiCloudService

password = os.environ.get("ICLOUD_PASSWORD")
if not password and pw_b64:
    try:
        password = base64.b64decode(pw_b64.encode("ascii")).decode("utf-8")
    except Exception:
        password = None

if not password:
    try:
        import keyring
        kr = keyring.get_keyring()
        if "EncryptedKeyring" not in type(kr).__name__ and "Chainer" not in type(kr).__name__:
            from pyicloud.utils import get_password_from_keyring
            password = get_password_from_keyring(username)
    except Exception:
        password = None

try:
    log_step("Init PyiCloudService...")
    api = PyiCloudService(
        username,
        password=password,
        cookie_directory=cookie_dir,
        accept_terms=True,
        refresh_interval=None,
        locate=False,
        authenticate=False,
    )
    if api.session.data.get("session_token"):
        log_step("Token auth...")
        try:
            api._authenticate_with_token()
        except Exception:
            if password:
                api.authenticate()
    elif password:
        log_step("Full auth...")
        api.authenticate()
    log_step("Auth complete")
except Exception as e:
    out = dict(prev_data)
    out["status"] = "auth_error"
    out["error"] = str(e)
    out["updated"] = int(time.time())
    out["updated_str"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    out["map_needs_update"] = False
    with open(out_json_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    sys.exit(0)

if api.requires_2fa or api.requires_2sa:
    out = dict(prev_data)
    out["status"] = "requires_2fa"
    out["error"] = f"2FA required for {username}. Run: ./sh/fetch_icloud.sh --auth {username}"
    out["updated"] = int(time.time())
    out["updated_str"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    out["map_needs_update"] = False
    with open(out_json_path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
    sys.exit(0)

def reverse_geocode(lat, lon):
    url = f"https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat={lat:.6f}&lon={lon:.6f}&zoom=18&addressdetails=1"
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "ConkyNextGen/2.0 (https://github.com/molnari811023/conky-nextgen)",
            "Accept-Language": "hu,de,en",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        r = json.loads(resp.read().decode("utf-8"))
    addr = r.get("address") or {}
    country = addr.get("country") or ""
    country_code = (addr.get("country_code") or "").upper()
    postcode = addr.get("postcode") or ""
    city = (
        addr.get("city")
        or addr.get("town")
        or addr.get("village")
        or addr.get("municipality")
        or addr.get("county")
        or ""
    )
    district = (
        addr.get("suburb")
        or addr.get("city_district")
        or addr.get("quarter")
        or addr.get("neighbourhood")
        or ""
    )
    street = (
        addr.get("road")
        or addr.get("pedestrian")
        or addr.get("footway")
        or addr.get("path")
        or addr.get("residential")
        or addr.get("square")
        or ""
    )
    house_number = addr.get("house_number") or ""
    poi = r.get("name") or addr.get("amenity") or addr.get("building") or ""
    street_full = f"{street} {house_number}".strip() if street else poi
    city_part = f"{postcode} {city}".strip()
    if city_part and street_full:
        short = f"{city_part}, {street_full}"
    else:
        short = city_part or street_full or (r.get("display_name") or "")[:60]
    return {
        "country": country,
        "country_code": country_code,
        "postcode": postcode,
        "city": city,
        "district": district,
        "street": street,
        "house_number": house_number,
        "poi": poi,
        "street_full": street_full,
        "short": short,
        "display_name": r.get("display_name") or "",
    }

# 1. Storage & Account
log_step("Storage query...")
storage_info = {
    "total_bytes": 0,
    "used_bytes": 0,
    "free_bytes": 0,
    "total_gb": 0.0,
    "used_gb": 0.0,
    "free_gb": 0.0,
    "used_perc": 0.0,
    "media": [],
}
try:
    st = api.account.storage
    u = st.usage
    total_b = int(u.total_storage_in_bytes or 0)
    used_b = int(u.used_storage_in_bytes or 0)
    free_b = int(u.available_storage_in_bytes or max(0, total_b - used_b))
    perc = float(u.used_storage_in_percent or 0.0)
    perc = min(100.0, max(0.0, perc))
    media_objs = st.usages_by_media or {}
    if isinstance(media_objs, dict):
        media_iter = media_objs.values()
    else:
        media_iter = media_objs
    media_list = []
    for m in media_iter:
        mb = int(m.usage_in_bytes or 0)
        mp = (mb / total_b * 100.0) if total_b > 0 else 0.0
        mp = min(100.0, max(0.0, round(mp, 1)))
        media_list.append({
            "key": str(m.key or ""),
            "label": str(m.label or m.key or ""),
            "color": "#" + str(m.color or "888888").lstrip("#"),
            "usage_bytes": mb,
            "usage_gb": round(mb / (1024 ** 3), 2),
            "usage_mb": round(mb / (1024 ** 2), 1),
            "usage_perc": mp,
        })
    media_list.sort(key=lambda x: x["usage_bytes"], reverse=True)
    storage_info = {
        "total_bytes": total_b,
        "used_bytes": used_b,
        "free_bytes": free_b,
        "total_gb": round(total_b / (1024 ** 3), 2),
        "used_gb": round(used_b / (1024 ** 3), 2),
        "free_gb": round(free_b / (1024 ** 3), 2),
        "used_perc": round(perc, 1),
        "media": media_list,
    }
except Exception:
    storage_info = prev_data.get("storage") or storage_info

# 2. Find My Devices + Location + Nominatim Address
log_step("Devices query...")
prev_devs_by_id = {}
for pd in (prev_data.get("devices") or []):
    if pd.get("id"):
        prev_devs_by_id[pd["id"]] = pd

devices_list = []
map_needs_update = False
primary_lat = None
primary_lon = None

try:
    raw_devs = list(api.devices)
    # Trigger active Find My refresh if force_map is requested or any iPhone is missing location/battery
    need_locate = force_map
    if not need_locate:
        for d_obj in raw_devs:
            dd = d_obj.data or {}
            if dd.get("deviceClass") == "iPhone" and (not dd.get("location") or dd.get("batteryLevel") is None):
                need_locate = True
                break
    if need_locate:
        try:
            api.devices.refresh(locate=True)
            for wait_step in range(4):
                all_ready = True
                for d_obj in api.devices:
                    dd = d_obj.data or {}
                    if dd.get("deviceClass") == "iPhone":
                        loc_d = dd.get("location")
                        if not loc_d or loc_d.get("latitude") is None or dd.get("batteryLevel") is None:
                            all_ready = False
                            break
                if all_ready:
                    break
                time.sleep(1.5)
                api.devices.refresh(locate=True)
            raw_devs = list(api.devices)
        except Exception:
            pass

    # Sort so iPhone comes first, then iPad/Mac/Watch/AirPods
    order_map = {"iPhone": 0, "iPad": 1, "MacBookPro": 2, "Mac": 2, "Watch": 3, "AirPods": 4}
    raw_devs.sort(key=lambda d: (order_map.get(d.data.get("deviceClass", ""), 9), d.data.get("name", "")))

    for idx, dev in enumerate(raw_devs):
        d = dev.data or {}
        dev_id = str(d.get("id") or "")
        prev_dev = prev_devs_by_id.get(dev_id) or (prev_data.get("devices") or [{}])[0]

        batt_raw = d.get("batteryLevel")
        if batt_raw is not None:
            batt_pct = min(100, max(0, int(round(float(batt_raw) * 100.0))))
        else:
            batt_pct = prev_dev.get("battery", 0)
        if batt_pct == 0 and prev_dev.get("battery", 0) > 0:
            batt_pct = prev_dev.get("battery", 0)

        batt_st = str(d.get("batteryStatus") or "")
        if not batt_st or batt_st == "Unknown":
            batt_st = prev_dev.get("battery_status", "Unknown")

        loc = d.get("location") or {}
        lat = loc.get("latitude")
        lon = loc.get("longitude")
        acc = loc.get("horizontalAccuracy")
        ts_ms = loc.get("timeStamp")
        pos_type = loc.get("positionType") or ""
        is_old = bool(loc.get("isOld", False))
        is_inaccurate = bool(loc.get("isInaccurate", False))

        prev_loc = prev_dev.get("location") or {}
        if lat is None or lon is None:
            lat = prev_loc.get("lat")
            lon = prev_loc.get("lon")
            acc = prev_loc.get("accuracy", 0)
            ts_ms = prev_loc.get("timestamp", 0)
            pos_type = prev_loc.get("position_type", "")

        updated_time = ""
        updated_full = ""
        if ts_ms:
            try:
                dt = datetime.fromtimestamp(float(ts_ms) / 1000.0)
                updated_time = dt.strftime("%H:%M:%S")
                updated_full = dt.strftime("%Y-%m-%d %H:%M:%S")
            except Exception:
                pass

        addr_info = prev_dev.get("address") or {}
        if lat is not None and lon is not None:
            lat_f = float(lat)
            lon_f = float(lon)
            prev_lat = prev_loc.get("lat")
            prev_lon = prev_loc.get("lon")
            moved = (
                prev_lat is None
                or prev_lon is None
                or abs(lat_f - float(prev_lat)) >= 0.0002
                or abs(lon_f - float(prev_lon)) >= 0.0002
            )
            if idx == 0:
                primary_lat = lat_f
                primary_lon = lon_f
                if moved or force_map or not os.path.isfile(map_png_path):
                    map_needs_update = True
            if moved or force_map or not addr_info.get("short"):
                try:
                    addr_info = reverse_geocode(lat_f, lon_f)
                except Exception:
                    pass

        devices_list.append({
            "id": dev_id,
            "name": str(d.get("name") or ""),
            "model": str(d.get("deviceDisplayName") or ""),
            "raw_model": str(d.get("rawDeviceModel") or ""),
            "device_class": str(d.get("deviceClass") or ""),
            "device_status": str(d.get("deviceStatus") or ""),
            "battery": batt_pct,
            "battery_status": batt_st,
            "low_power_mode": bool(d.get("lowPowerMode", False)),
            "location": {
                "lat": round(float(lat), 6) if lat is not None else None,
                "lon": round(float(lon), 6) if lon is not None else None,
                "accuracy": round(float(acc), 1) if acc is not None else 0.0,
                "position_type": str(pos_type),
                "is_old": is_old,
                "is_inaccurate": is_inaccurate,
                "timestamp": int(ts_ms or 0),
                "updated_time": updated_time,
                "updated_full": updated_full,
            },
            "address": addr_info,
        })
except Exception:
    devices_list = prev_data.get("devices") or []

# 3. iCloud Calendar
log_step("Calendar query...")
calendar_list = []
try:
    now_dt = datetime.now()
    end_dt = now_dt + timedelta(days=cal_days)
    if hasattr(api.calendar, "get_events"):
        raw_events = api.calendar.get_events(now_dt, end_dt, as_objs=False) or []
    else:
        raw_events = api.calendar.events(now_dt, end_dt) or []
    for ev in raw_events:
        if not isinstance(ev, dict):
            title = str(getattr(ev, "title", "") or "").strip()
            sd = getattr(ev, "start_date", None)
            ed = getattr(ev, "end_date", None)
            loc_str = str(getattr(ev, "location", "") or "")
            all_day_flag = bool(getattr(ev, "all_day", False))
        else:
            title = str(ev.get("title") or "").strip()
            sd = ev.get("startDate")
            ed = ev.get("endDate")
            loc_str = str(ev.get("location") or "")
            all_day_flag = bool(ev.get("allDay", False))
        if not title:
            continue
        start_str = ""
        end_str = ""
        sort_key = ""
        if isinstance(sd, list) and len(sd) >= 6:
            start_str = f"{int(sd[1]):04d}-{int(sd[2]):02d}-{int(sd[3]):02d} {int(sd[4]):02d}:{int(sd[5]):02d}"
            sort_key = start_str
        elif hasattr(sd, "strftime"):
            start_str = sd.strftime("%Y-%m-%d %H:%M")
            sort_key = start_str
        elif sd:
            start_str = str(sd)
            sort_key = start_str
        if isinstance(ed, list) and len(ed) >= 6:
            end_str = f"{int(ed[1]):04d}-{int(ed[2]):02d}-{int(ed[3]):02d} {int(ed[4]):02d}:{int(ed[5]):02d}"
        elif hasattr(ed, "strftime"):
            end_str = ed.strftime("%Y-%m-%d %H:%M")
        elif ed:
            end_str = str(ed)
        calendar_list.append({
            "title": title,
            "start": start_str,
            "end": end_str,
            "location": loc_str,
            "all_day": all_day_flag,
            "_sort": sort_key,
        })
    calendar_list.sort(key=lambda x: x.get("_sort", ""))
    for item in calendar_list:
        item.pop("_sort", None)
except Exception:
    calendar_list = prev_data.get("calendar") or []

# 4. iCloud Reminders (CloudKit RemindersService 2026+ and legacy dict fallback)
log_step("Reminders query...")
reminders_list = []
try:
    pcs_ok = True
    if hasattr(api, "_check_pcs_consent"):
        pcs_state = api._check_pcs_consent() or {}
        if pcs_state.get("isICDRSDisabled", False) and not pcs_state.get("isDeviceConsentedForPCS", True):
            pcs_ok = False
    if pcs_ok:
        rem_svc = api.reminders
        if callable(getattr(rem_svc, "reminders", None)):
            list_titles = {}
            if callable(getattr(rem_svc, "lists", None)):
                for rl in rem_svc.lists():
                    list_titles[getattr(rl, "id", "")] = getattr(rl, "title", "")
            for r in rem_svc.reminders():
                if getattr(r, "completed", False) or getattr(r, "deleted", False):
                    continue
                title = str(getattr(r, "title", "") or "").strip()
                if not title:
                    continue
                due_dt = getattr(r, "due_date", None)
                due_str = ""
                if hasattr(due_dt, "strftime"):
                    due_str = due_dt.strftime("%Y-%m-%d %H:%M") if (due_dt.hour or due_dt.minute) else due_dt.strftime("%Y-%m-%d")
                elif due_dt:
                    due_str = str(due_dt)
                l_id = getattr(r, "list_id", "")
                reminders_list.append({
                    "list": str(list_titles.get(l_id) or "Reminders"),
                    "title": title,
                    "desc": str(getattr(r, "desc", "") or ""),
                    "due": due_str,
                })
        else:
            rem_lists = getattr(rem_svc, "lists", {}) or {}
            for list_title, items in rem_lists.items():
                for r in (items or []):
                    title = str(r.get("title") or "").strip()
                    if not title:
                        continue
                    due_dt = r.get("due")
                    due_str = ""
                    if hasattr(due_dt, "strftime"):
                        due_str = due_dt.strftime("%Y-%m-%d %H:%M") if (due_dt.hour or due_dt.minute) else due_dt.strftime("%Y-%m-%d")
                    elif due_dt:
                        due_str = str(due_dt)
                    reminders_list.append({
                        "list": str(list_title),
                        "title": title,
                        "desc": str(r.get("desc") or ""),
                        "due": due_str,
                    })
except Exception:
    reminders_list = prev_data.get("reminders") or []

out_payload = {
    "status": "ok",
    "error": "",
    "updated": int(time.time()),
    "updated_str": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "account": {
        "apple_id": username,
    },
    "storage": storage_info,
    "devices": devices_list,
    "calendar": calendar_list,
    "reminders": reminders_list,
    "map_needs_update": map_needs_update,
    "primary_lat": primary_lat,
    "primary_lon": primary_lon,
}

log_step("Writing JSON output...")
with open(out_json_path, "w", encoding="utf-8") as f:
    json.dump(out_payload, f, ensure_ascii=False, indent=2)
log_step("JSON written successfully")
PYEOF
	then
		mv "$TMP_DIR/icloud.json.tmp" "$TMP_DIR/icloud.json"
		if [ "$TMP_DIR" != "$HOME/.conky/tmp" ]; then
			mkdir -p "$HOME/.conky/tmp" 2>/dev/null || true
			cp -f "$TMP_DIR/icloud.json" "$HOME/.conky/tmp/icloud.json" 2>/dev/null || true
		fi
		sync_cookies_out

		local status=$(jq -r '.status // "unknown"' "$TMP_DIR/icloud.json" 2>/dev/null)
		local map_upd=$(jq -r '.map_needs_update // false' "$TMP_DIR/icloud.json" 2>/dev/null)
		local plat=$(jq -r '.primary_lat // empty' "$TMP_DIR/icloud.json" 2>/dev/null)
		local plon=$(jq -r '.primary_lon // empty' "$TMP_DIR/icloud.json" 2>/dev/null)

		log "[icloud] icloud.json status=$status"
		if [ "$map_upd" = "true" ] && [ -n "$plat" ] && [ -n "$plon" ]; then
			build_iphone_map "$plat" "$plon" "$ICLOUD_MAP_ZOOM"
		fi
	else
		rm -f "$TMP_DIR/icloud.json.tmp"
		log "[warn] icloud.json failed: $(head -c 160 "$TMP_DIR/icloud.err" 2>/dev/null)"
	fi
	exec 9>&-
}

icloud_drive_list() {
	sync_cookies_in
	python3 - "$ICLOUD_USERNAME" "$ICLOUD_COOKIE_STORE" "${ICLOUD_PASSWORD_B64:-}" "$@" <<'PYEOF'
import sys
import os
import base64
from pyicloud import PyiCloudService

username = sys.argv[1].strip()
cookie_dir = sys.argv[2]
pw_b64 = sys.argv[3] if len(sys.argv) > 3 else ""

if not username:
    print("[error] ICLOUD_USERNAME is not configured in icloud.conf!")
    sys.exit(1)

password = os.environ.get("ICLOUD_PASSWORD")
if not password and pw_b64:
    try:
        password = base64.b64decode(pw_b64.encode("ascii")).decode("utf-8")
    except Exception:
        password = None

try:
    api = PyiCloudService(
        username,
        password=password,
        cookie_directory=cookie_dir,
        accept_terms=True,
        refresh_interval=None,
        locate=False,
        authenticate=False,
    )
    if api.session.data.get("session_token"):
        try:
            api._authenticate_with_token()
        except Exception:
            if password:
                api.authenticate()
    elif password:
        api.authenticate()
except Exception as e:
    print(f"[error] Authentication error: {e}")
    sys.exit(1)

if api.requires_2fa or api.requires_2sa:
    print(f"[error] 2FA authentication required for account {username}! Run: ./sh/fetch_icloud.sh --auth")
    sys.exit(2)

print(f"=== iCloud Drive root directory ({username}) ===")
try:
    items = api.drive.dir()
    if not items:
        print("  (Root directory is empty or contains no direct files)")
    for item in items:
        try:
            node = api.drive[item]
            type_str = "Folder" if getattr(node, "type", "") == "folder" else "File  "
            size_b = getattr(node, "size", 0) or 0
            size_str = f"({size_b / 1024:.1f} KB)" if size_b > 0 else ""
            print(f"  [{type_str}] {item} {size_str}")
        except Exception:
            print(f"  [-] {item}")
except Exception as e:
    print(f"[error] Failed to list iCloud Drive contents: {e}")
PYEOF
	sync_cookies_out
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	case "${1:-}" in
	--auth)
		shift
		icloud_auth_interactive "$@"
		;;
	--sound)
		shift
		icloud_play_sound "$@"
		;;
	--map)
		shift
		build_iphone_map "$@"
		;;
	--drive|drive)
		shift
		icloud_drive_list "$@"
		;;
	*)
		fetch_icloud "$@"
		;;
	esac
fi
