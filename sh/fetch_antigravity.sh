#!/bin/bash
#{{{
#  Conky NextGen Framework
#  Author: István Molnár
#  GitHub: https://github.com/molnari811023/conky-nextgen
#  Description: Modular Conky UI framework (Lua engine + Bash backend)
#}}}
#{{{
# ## fetch_antigravity — Antigravity (AGY / Gemini CLI) usage & telemetry analyzer
#
# Analyzes local Antigravity transcripts (~/.gemini/antigravity-cli/brain/*/transcript.jsonl)
# and generates structured usage statistics:
# - Active model name & models used
# - Total input, output, cache_read tokens and cache hit ratio
# - Last request token breakdown
# - Conversation steps, user turns, and tool call breakdown (run_command, read_file, edit_file, etc.)
# - Session start time and formatted duration
#
# Writes output to $TMP_DIR/antigravity.json (and copies to ~/.conky/tmp/antigravity.json).
#}}}
_SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$_SCRIPT_DIR/common.sh"

fetch_antigravity() {
	local out_json="$TMP_DIR/antigravity.json"
	local brain_dir="${HOME}/.gemini/antigravity-cli/brain"

	if [ ! -d "$brain_dir" ]; then
		cat <<JSON > "$out_json.tmp"
{
  "status": "not_installed",
  "updated": $(date +%s),
  "updated_str": "$(date '+%Y-%m-%d %H:%M:%S')",
  "models": [],
  "current_model": "N/A",
  "steps": 0,
  "turns": 0,
  "tool_calls_total": 0,
  "tools": {},
  "top_tools": [],
  "tokens": {
    "input": 0,
    "output": 0,
    "cache_read": 0,
    "total": 0,
    "cache_ratio": 0.0
  },
  "last_turn": {
    "input_tokens": 0,
    "output_tokens": 0,
    "cache_read_tokens": 0,
    "time": ""
  },
  "session": {
    "first_time": "",
    "last_time": "",
    "duration_str": "0p",
    "conversations_count": 0
  }
}
JSON
		mv "$out_json.tmp" "$out_json"
		return 0
	fi

	python3 - "$brain_dir" "$out_json.tmp" <<'PYEOF'
import sys, os, glob, json, time
from datetime import datetime
from collections import Counter

brain_dir = sys.argv[1]
out_file = sys.argv[2]

pattern = os.path.join(brain_dir, "*", ".system_generated", "logs", "transcript.jsonl")
files = glob.glob(pattern)

# Sort so the latest modified transcript is processed last (for active state)
files.sort(key=lambda p: os.path.getmtime(p) if os.path.exists(p) else 0)

conv_dirs = [d for d in glob.glob(os.path.join(brain_dir, "*")) if os.path.isdir(d)]
conv_count = len(conv_dirs)

total_in = 0
total_out = 0
total_cache = 0
total_steps = 0
total_turns = 0
tool_counter = Counter()

models_used = set()
last_model = "unknown"
latest_conv_id = os.path.basename(conv_dirs[-1]) if conv_dirs else ""

first_ts = None
last_ts = None

last_turn_data = {
    "input_tokens": 0,
    "output_tokens": 0,
    "cache_read_tokens": 0,
    "time": "",
}

for fpath in files:
    try:
        with open(fpath, "r", encoding="utf-8") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    row = json.loads(line)
                except Exception:
                    continue

                total_steps += 1
                t = row.get("type")
                src = row.get("source")

                if t == "USER_INPUT" or src == "USER_EXPLICIT":
                    total_turns += 1

                for tc in (row.get("tool_calls") or []):
                    fn = tc.get("function", {}).get("name") or tc.get("name") or "unknown"
                    tool_counter[fn] += 1

                m = row.get("model")
                if m:
                    models_used.add(m)
                    last_model = m

                inp = int(row.get("input_tokens") or 0)
                outp = int(row.get("output_tokens") or 0)
                cache = int(row.get("cache_read_tokens") or 0)

                total_in += inp
                total_out += outp
                total_cache += cache

                if inp > 0 or outp > 0 or cache > 0:
                    last_turn_data = {
                        "input_tokens": inp,
                        "output_tokens": outp,
                        "cache_read_tokens": cache,
                        "time": row.get("created_at") or "",
                    }

                ts_str = row.get("created_at")
                if ts_str:
                    if not first_ts:
                        first_ts = ts_str
                    last_ts = ts_str
    except Exception:
        pass

total_processed = total_in + total_out + total_cache
cache_ratio = round((total_cache / (total_in + total_cache) * 100.0), 1) if (total_in + total_cache) > 0 else 0.0

# Format human duration
duration_str = "0p"
if first_ts and last_ts:
    try:
        # ISO format: 2026-11-15T10:36:00Z
        t1 = datetime.fromisoformat(first_ts.replace("Z", "+00:00"))
        t2 = datetime.fromisoformat(last_ts.replace("Z", "+00:00"))
        diff_sec = max(0, int((t2 - t1).total_seconds()))
        hours = diff_sec // 3600
        mins = (diff_sec % 3600) // 60
        if hours > 0:
            duration_str = f"{hours}h {mins:02d}m"
        else:
            duration_str = f"{mins}m"
    except Exception:
        pass

def fmt_tokens(n):
    if n >= 1000000:
        return f"{n / 1000000.0:.2f} M"
    elif n >= 1000:
        return f"{n / 1000.0:.1f} K"
    return str(n)

top_tools = [{"name": name, "count": count} for name, count in tool_counter.most_common(8)]

# Pretty short model name
model_short = last_model
if "gemini-3.8-flash" in last_model:
    model_short = "Flash 3.8"
elif "gemini-4-argon" in last_model:
    model_short = "Gemini 4"
elif "pro" in last_model:
    model_short = "Pro"

payload = {
    "status": "ok",
    "updated": int(time.time()),
    "updated_str": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "models": sorted(list(models_used)),
    "current_model": last_model,
    "current_model_short": model_short,
    "active_conversation": latest_conv_id,
    "steps": total_steps,
    "turns": total_turns,
    "tool_calls_total": sum(tool_counter.values()),
    "tools": dict(tool_counter),
    "top_tools": top_tools,
    "tokens": {
        "input": total_in,
        "input_formatted": fmt_tokens(total_in),
        "output": total_out,
        "output_formatted": fmt_tokens(total_out),
        "cache_read": total_cache,
        "cache_read_formatted": fmt_tokens(total_cache),
        "total": total_processed,
        "total_formatted": fmt_tokens(total_processed),
        "cache_ratio": cache_ratio,
    },
    "last_turn": {
        "input_tokens": last_turn_data["input_tokens"],
        "input_formatted": fmt_tokens(last_turn_data["input_tokens"]),
        "output_tokens": last_turn_data["output_tokens"],
        "output_formatted": fmt_tokens(last_turn_data["output_tokens"]),
        "cache_read_tokens": last_turn_data["cache_read_tokens"],
        "cache_read_formatted": fmt_tokens(last_turn_data["cache_read_tokens"]),
        "time": last_turn_data["time"],
    },
    "session": {
        "first_time": first_ts or "",
        "last_time": last_ts or "",
        "duration_str": duration_str,
        "conversations_count": conv_count,
    }
}

with open(out_file, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
PYEOF

	if [ -f "$out_json.tmp" ]; then
		mv "$out_json.tmp" "$out_json"
		if [ "$TMP_DIR" != "$HOME/.conky/tmp" ]; then
			mkdir -p "$HOME/.conky/tmp" 2>/dev/null || true
			cp -f "$out_json" "$HOME/.conky/tmp/antigravity.json" 2>/dev/null || true
		fi
		log "[antigravity] antigravity.json updated"
	fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	fetch_antigravity "$@"
fi
