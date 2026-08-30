#!/bin/bash

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
