#!/usr/bin/env bash
set -euo pipefail

# svg_type_test.sh — Tesztelő script: ciklikusan váltogatja az own_window_type értékét
# és figyeli a Conky reakcióját / reload viselkedését MATE alatt.

CONF="${1:-$HOME/.conky/debug/svg_test.conf}"

types=(
    "dock"
    "normal"
    "panel"
    "override"
    "desktop"
)

echo "=== Conky own_window_type ciklikus tesztelő indítása ==="
echo "Konfigurációs fájl: $CONF"
echo "Típusok: ${types[*]}"
echo "Kilépéshez: Ctrl+C"
echo "--------------------------------------------------------"

i=0
while true; do
    wt="${types[$((i % ${#types[@]}))]}"
    sed -i "s/own_window_type = '[^']*'/own_window_type = '$wt'/" "$CONF"
    echo "[Lépés $((i + 1))] own_window_type -> '$wt' beállítva. Várakozás 6 másodpercig..."
    sleep 6
    i=$((i + 1))
done
