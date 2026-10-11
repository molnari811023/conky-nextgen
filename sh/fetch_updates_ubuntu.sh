#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## fetch_updates_ubuntu — Ubuntu package update counter
#
# Counts the number of available package updates and security updates
# via `apt-check` (or apt simulation fallback). Writes the two counts
# ("<total> <security>") to $TMP_DIR/updates.txt.
#}}}

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONKY_DIR="$(readlink -f "$SCRIPT_DIR/..")"

if [ -n "${NEXTGEN_TMP_DIR:-}" ]; then
	TMP_DIR="$NEXTGEN_TMP_DIR"
elif [[ "$CONKY_DIR" != /usr* ]] && [ -d "$CONKY_DIR/tmp" ] && [ -w "$CONKY_DIR/tmp" ]; then
	TMP_DIR="$CONKY_DIR/tmp"
elif [[ "$CONKY_DIR" != /usr* ]] && [ -w "$CONKY_DIR" ]; then
	TMP_DIR="$CONKY_DIR/tmp"
else
	TMP_DIR="$HOME/.conky/tmp"
fi
OUT="$TMP_DIR/updates.txt"
mkdir -p "$TMP_DIR"

if [ -x /usr/lib/update-notifier/apt-check ]; then
    # apt-check kimenete: "összes;biztonsági"
    /usr/lib/update-notifier/apt-check 2>&1 | tr ';' ' ' > "$OUT"
else
    # Fallback sima apt szimulációval
    TOTAL=$(apt-get -s upgrade 2>/dev/null | grep -P '^\d+ upgraded' | awk '{print $1}')
    echo "${TOTAL:-0} 0" > "$OUT"
fi

USER_OUT="$HOME/.conky/tmp/updates.txt"
if [ "$OUT" != "$USER_OUT" ]; then
    mkdir -p "$HOME/.conky/tmp" 2>/dev/null || true
    cp -f "$OUT" "$USER_OUT" 2>/dev/null || true
fi
