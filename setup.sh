#!/bin/bash
#{{{
#  Conky NextGen Framework — first-run setup
#  by wim66 (this fork)
#
#  Prompts for:
#    1) weather geocoding language — the language of place/country names
#       shown in the weather widget (e.g. "Nederland" vs "Netherlands" vs
#       "Hollandia"). Written into sh/4_fetch_weather.sh + sh/all_in_one.sh.
#       This is NOT the general UI translation — lua/core/translate.lua
#       already auto-follows the system's $LANG on its own, nothing to
#       set up for that here.
#    2) home city — written into weather.lua's auto-refresh hook, so the
#       background fetch keeps updating for the right city without a
#       manual run.
#
#  Usage: ./setup.sh
#}}}

set -e

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$SCRIPT_DIR"

CODES=(ar cs da de en es fi fr hr hu it ja ko nl pl pt ro ru sv tr uk zh_CN)
NAMES=(
    "Arabisch"
    "Tsjechisch"
    "Deens"
    "Duits"
    "Engels"
    "Spaans"
    "Fins"
    "Frans"
    "Kroatisch"
    "Hongaars"
    "Italiaans"
    "Japans"
    "Koreaans"
    "Nederlands"
    "Pools"
    "Portugees"
    "Roemeens"
    "Russisch"
    "Zweeds"
    "Turks"
    "Oekraïens"
    "Chinees (vereenvoudigd)"
)

echo "=================================================="
echo " Conky NextGen (fork) — eerste-keer-setup"
echo "=================================================="
echo
echo "Deze taalkeuze bepaalt de taal van plaats-/landnamen in de"
echo "weerwidget (bv. 'Nederland' vs 'Netherlands' vs 'Hollandia')."
echo "De algemene widget-teksten volgen automatisch je systeemtaal"
echo "(\$LANG) — daar hoef je hier niets voor in te stellen."
echo
echo "Beschikbare talen:"
for i in "${!CODES[@]}"; do
    printf "  %2d) %-6s %s\n" "$((i + 1))" "${CODES[$i]}" "${NAMES[$i]}"
done
echo

while true; do
    read -rp "Kies een taal (nummer): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#CODES[@]})); then
        WEATHER_LANG="${CODES[$((choice - 1))]}"
        break
    fi
    echo "Ongeldige keuze, probeer opnieuw."
done

echo
read -rp "In welke stad woon je? (bv. Amsterdam): " CITY
while [ -z "$CITY" ]; do
    read -rp "Stad mag niet leeg zijn. Probeer opnieuw: " CITY
done

echo
echo "--------------------------------------------------"
echo " Taal:  $WEATHER_LANG"
echo " Stad:  $CITY"
echo "--------------------------------------------------"
read -rp "Doorgaan en de bestanden aanpassen? [J/n] " confirm
if [[ "$confirm" =~ ^[nN] ]]; then
    echo "Geannuleerd, er is niets aangepast."
    exit 0
fi

# --- Weather geocoding language: sh/4_fetch_weather.sh + sh/all_in_one.sh ---
python3 - "$WEATHER_LANG" << 'PYEOF'
import re, sys

lang = sys.argv[1]
for path in ("sh/4_fetch_weather.sh", "sh/all_in_one.sh"):
    try:
        with open(path) as f:
            content = f.read()
    except FileNotFoundError:
        print(f"[warn] {path} niet gevonden, overgeslagen")
        continue
    new_content, n = re.subn(
        r'local lang="\$\{WEATHER_LANG:-[A-Za-z_]+\}"',
        f'local lang="${{WEATHER_LANG:-{lang}}}"',
        content,
        count=1,
    )
    if n:
        with open(path, "w") as f:
            f.write(new_content)
        print(f"[ok] {path} -> taal: {lang}")
    else:
        print(f"[warn] {path}: patroon niet gevonden, niet aangepast")
PYEOF

# --- City: weather.lua's auto-refresh hook ---
# City is quoted (\"...\") in the generated shell command so multi-word
# cities (e.g. "Den Haag") are passed to fetch_weather() as a single
# argument. Matches either a bare previous city or an already-quoted one,
# so re-running this script to switch cities later works too.
python3 - "$CITY" << 'PYEOF'
import re, sys

city = sys.argv[1]
path = "weather.lua"
try:
    with open(path) as f:
        content = f.read()
except FileNotFoundError:
    print(f"[warn] {path} niet gevonden, overgeslagen")
    sys.exit(0)

pattern = re.compile(r'(sh/0_fetch_all\.sh weather )(\\"[^"]*\\"|[A-Za-z%20]+)')
new_content, n = pattern.subn(lambda m: m.group(1) + '\\"' + city + '\\"', content, count=1)
if n:
    with open(path, "w") as f:
        f.write(new_content)
    print(f"[ok] {path} -> stad: {city}")
else:
    print(f"[warn] {path}: patroon niet gevonden, niet aangepast")
PYEOF

echo
echo "=================================================="
echo " Setup klaar!"
echo "=================================================="
echo
echo "Haal de eerste data nu op:"
echo "  ./sh/0_fetch_all.sh all \"$CITY\""
echo
echo "Start daarna je widgets, bijvoorbeeld via Conky Manager 2,"
echo "of los met: conky -c weather.conf"
