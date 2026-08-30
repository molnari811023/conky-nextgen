#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}

#{{{
# gog_open_mail.sh — Open a Gmail thread in Firefox from its ID.
#
# Takes a Gmail message/thread ID (as returned by `gog gmail search`),
# builds the web URL via `gog gmail url`, and opens it in Firefox.
#
# Usage:
#   ./gog_open_mail.sh <message-id>
#   ./gog_open_mail.sh 1a051c3b97898a2d
#
# Requires: gog (configured OAuth + file keyring), firefox
#}}}

export GOG_KEYRING_BACKEND=file
export GOG_KEYRING_PASSWORD="${GOG_KEYRING_PASSWORD:-conky-google-dashboard}"

open_gmail_thread() {
	local id="${1:-}"
	if [ -z "$id" ]; then
		echo "[error] No message ID given" >&2
		return 1
	fi

	command -v gog >/dev/null 2>&1 || { echo "[error] gog not found" >&2; return 1; }
	command -v firefox >/dev/null 2>&1 || { echo "[error] firefox not found" >&2; return 1; }

	local url
	url=$(gog gmail url "$id" --plain 2>&1 | awk '{print $2}')
	if [ -z "$url" ]; then
		echo "[error] Could not build Gmail URL for $id" >&2
		return 1
	fi

	echo "[open] $url"
	firefox "$url" >/dev/null 2>&1 &
	return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	open_gmail_thread "$1"
fi
