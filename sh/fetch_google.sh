#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}

#{{{
# fetch_google.sh — Fetch Google (gog) data: Gmail, Calendar, Tasks,
#                    Contacts, Drive, YouTube subscriptions, Meet.
#
# Uses the `gog` CLI (https://github.com/ungoogled-software/... or the
# user's gogcli) with OAuth credentials stored in the file keyring.
#
# Requires: gog, jq (python3 via 0_common.sh)
# Output files (in $TMP_DIR):
#   gmail_emails.json        — recent Gmail messages (from <senders>, subject…)
#   calendar_events.json     — upcoming Calendar events (from today)
#   tasks_lists.json         — Tasks task-lists
#   tasks.json               — tasks of the first task-list
#   contacts.json            — contacts
#   drive_files.json         — Drive file listing
#   youtube_subs.json        — YouTube subscriptions
#   meet_history.json        — Meet history (requires a meeting code)
#
# Usage: source 0_common.sh && fetch_google
#}}}

_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/0_common.sh"

# gog needs the file keyring backend + password. Values can be overridden
# by environment variables (GOG_KEYRING_PASSWORD, GOG_ACCOUNT).
export GOG_KEYRING_BACKEND="${GOG_KEYRING_BACKEND:-file}"
export GOG_KEYRING_PASSWORD="${GOG_KEYRING_PASSWORD:-conky-google-dashboard}"
GOG_ACCOUNT="${GOG_ACCOUNT:-molnari811023@gmail.com}"

GOG_ARGS=()
if [ -n "$GOG_ACCOUNT" ]; then
	GOG_ARGS=(--account "$GOG_ACCOUNT")
fi

# Number of upcoming calendar days to fetch (default 14).
GOOGLE_CALENDAR_DAYS="${GOOGLE_CALENDAR_DAYS:-14}"
# Max Gmail messages to fetch (default 15).
GOOGLE_GMAIL_MAX="${GOOGLE_GMAIL_MAX:-15}"
# Max Tasks to fetch (default 20).
GOOGLE_TASKS_MAX="${GOOGLE_TASKS_MAX:-20}"

require_gog() {
	command -v gog >/dev/null 2>&1 || { log "[google] gog not found — skipping"; return 1; }
	return 0
}

# gog_emit <outfile> <cmd...>: run gog with JSON output into <outfile>.
gog_emit() {
	local out="$1"; shift
	if gog "${GOG_ARGS[@]}" --json --results-only "$@" >"$TMP_DIR/$out.tmp" 2>"$TMP_DIR/$out.err"; then
		mv "$TMP_DIR/$out.tmp" "$TMP_DIR/$out"
		log "[google] $out OK"
	else
		rm -f "$TMP_DIR/$out.tmp"
		log "[warn] $out failed: $(head -c 120 "$TMP_DIR/$out.err")"
	fi
}

fetch_google_gmail() {
	gog_emit gmail_emails.json gmail search "in:anywhere" --max "$GOOGLE_GMAIL_MAX"
}

fetch_google_calendar() {
	gog_emit calendar_events.json calendar events --from today --days "$GOOGLE_CALENDAR_DAYS"
}

fetch_google_tasks() {
	gog_emit tasks_lists.json tasks lists
	# fetch tasks of the first list, if any
	if [ -s "$TMP_DIR/tasks_lists.json" ]; then
		local lid
		lid=$(jq -r '.[0].id // empty' "$TMP_DIR/tasks_lists.json" 2>/dev/null)
		if [ -n "$lid" ]; then
			gog_emit tasks.json tasks list "$lid" --max "$GOOGLE_TASKS_MAX"
		else
			: > "$TMP_DIR/tasks.json"
		fi
	fi
}

fetch_google_contacts() {
	gog_emit contacts.json contacts list
}

fetch_google_drive() {
	gog_emit drive_files.json drive ls
}

fetch_google_youtube() {
	gog_emit youtube_subs.json youtube subscriptions list
}

# Meet needs an explicit meeting code, normally embedded in a calendar
# event's Hangouts conference link. If GOOGLE_MEET_CODE is set, fetch its
# status/history; otherwise leave meet_history.json empty.
fetch_google_meet() {
	local code="${GOOGLE_MEET_CODE:-}"
	if [ -z "$code" ]; then
		: > "$TMP_DIR/meet_history.json"
		rm -f "$TMP_DIR/meet_history.err"
		return 0
	fi
	gog_emit meet_history.json meet history "$code"
}

fetch_google() {
	require_gog || return 0
	# gmail, contacts, drive, youtube can run in parallel
	fetch_google_gmail &
	fetch_google_contacts &
	fetch_google_drive &
	fetch_google_youtube &
	wait
	# calendar, tasks, meet sequentially
	fetch_google_calendar
	fetch_google_tasks
	fetch_google_meet
	log "[google] Done"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	fetch_google "$@"
fi
