#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## gog_open_mail — open a Gmail thread in the default browser
#
# Defines open_gmail_thread(), which takes a Gmail message/thread ID, asks
# `gog` to build the corresponding Gmail URL and opens it in the default browser using
# a background process. Uses the gog file keyring backend with a default
# keyring password (overridable via GOG_KEYRING_PASSWORD).
#
# **What it does:**
# - Exports GOG_KEYRING_BACKEND=file and GOG_KEYRING_PASSWORD
# - Validates the message ID and that gog + firefox are installed
# - Resolves the Gmail URL via `gog gmail url <id> --plain`
# - Launches `xdg-open <url>` in the background
#
# **Environment/requirements:** needs `gog` and `firefox`; optional
# GOG_KEYRING_PASSWORD override
#}}}
export GOG_KEYRING_BACKEND=file
export GOG_KEYRING_PASSWORD="${GOG_KEYRING_PASSWORD:-conky-google-dashboard}"
GOG_BIN="${GOG_BIN:-/usr/bin/gog}"
BROWSER_BIN="${BROWSER_BIN:-/usr/bin/xdg-open}"
LOG_FILE="${GOG_OPEN_MAIL_LOG:-/tmp/conky_gog_open_mail.log}"

open_gmail_thread() {
	local id="${1:-}"
	if [ -z "$id" ]; then
		echo "[error] No message ID given" >&2
		return 1
	fi

	if [ ! -x "$GOG_BIN" ]; then
		echo "[error] gog not found: $GOG_BIN" | tee -a "$LOG_FILE" >&2
		return 1
	fi
	if [ ! -x "$BROWSER_BIN" ]; then
		echo "[error] browser not found: $BROWSER_BIN" | tee -a "$LOG_FILE" >&2
		return 1
	fi

	local output url
	output=$("$GOG_BIN" gmail url "$id" --plain 2>>"$LOG_FILE" || true)
	url=$(printf '%s\n' "$output" | tr -d '\r' | head -n 1 | awk 'NF {print $1; exit}')
	if [ -z "$url" ] || ! printf '%s' "$url" | grep -Eq '^https?://'; then
		url=$(printf '%s\n' "$output" | tr -d '\r' | awk 'NF {print $2; exit}')
	fi
	if [ -z "$url" ] || ! printf '%s' "$url" | grep -Eq '^https?://'; then
		# The thread id is enough to open the message and avoids requiring the
		# interactive shell's gog keyring password during desktop startup.
		url="https://mail.google.com/mail/u/0/#all/$id"
		echo "[info] gog URL unavailable; using direct Gmail URL" >>"$LOG_FILE"
	fi

	echo "[open] $url" | tee -a "$LOG_FILE"
	"$BROWSER_BIN" "$url" >>"$LOG_FILE" 2>&1 &
	return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	open_gmail_thread "$1"
fi
