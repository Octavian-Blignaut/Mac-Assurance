#!/usr/bin/env bash
# queue-fix.sh <id> <description> — idempotently add a pending fix. Never acts.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PENDING="${FIX_PENDING_FILE:-$HERE/fixes-pending.txt}"
ID="${1:-}"; DESC="${2:-}"; [ -n "$ID" ] || { echo "Usage: $0 <id> <description>"; exit 2; }
mkdir -p "$(dirname "$PENDING")"; touch "$PENDING"
grep -q "^$ID	" "$PENDING" && exit 0
printf '%s\t%s\t%s\n' "$ID" "$(date '+%F %T')" "$DESC" >> "$PENDING"
echo "Queued $ID"
