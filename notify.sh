#!/usr/bin/env bash
# notify.sh "Title" "Message" — macOS notification. NOTIFY_DRY_RUN=1 prints instead.
set -uo pipefail
TITLE="${1:-Mac Assurance}"; MSG="${2:-}"
if [ "${NOTIFY_DRY_RUN:-0}" = "1" ]; then echo "NOTIFY: $TITLE — $MSG"; exit 0; fi
osascript -e 'on run argv' -e 'display notification (item 2 of argv) with title (item 1 of argv) sound name "default"' -e 'end run' -- "$TITLE" "$MSG" >/dev/null 2>&1
