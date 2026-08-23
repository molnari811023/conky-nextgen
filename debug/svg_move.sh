#!/bin/bash
CONF="${1:-$HOME/.conky/svg_test.conf}"
positions=(
    "100:50"
    "800:50"
    "800:400"
    "100:400"
    "400:200"
    "1500:100"
    "1500:500"
    "200:300"
)
i=0
while true; do
    pos="${positions[$((i % ${#positions[@]}))]}"
    gx="${pos%%:*}"
    gy="${pos##*:}"
    sed -i "s/gap_x = [0-9]*/gap_x = $gx/" "$CONF"
    sed -i "s/gap_y = [0-9]*/gap_y = $gy/" "$CONF"
    echo "Pozíció: gap_x=$gx gap_y=$gy"
    sleep 5
    i=$((i + 1))
done
