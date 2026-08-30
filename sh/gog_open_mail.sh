#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## gog_open_mail — open a Gmail thread in Firefox
#
# Defines open_gmail_thread(), which takes a Gmail message/thread ID, asks
# `gog` to build the corresponding Gmail URL and opens it in Firefox using
# a background process. Uses the gog file keyring backend with a default
# keyring password (overridable via GOG_KEYRING_PASSWORD).
#
# **What it does:**
# - Exports GOG_KEYRING_BACKEND=file and GOG_KEYRING_PASSWORD
# - Validates the message ID and that gog + firefox are installed
# - Resolves the Gmail URL via `gog gmail url <id> --plain`
# - Launches `firefox <url>` in the background
#
# **Environment/requirements:** needs `gog` and `firefox`; optional
# GOG_KEYRING_PASSWORD override
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
