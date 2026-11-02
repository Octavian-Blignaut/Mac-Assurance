#!/usr/bin/env bash
# fix.sh — approve-first fix engine v1 (forgotten tools only).
# Allowlist: stop-burp, stop-grammarly. Everything else is refused, always.
# Usage: fix.sh [--list|--dry-run <id>|--reopen burp|grammarly]  (no args = interactive queue)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PENDING="${FIX_PENDING_FILE:-$HERE/fixes-pending.txt}"
ACTIONS_LOG="${ACTIONS_LOG:-$HERE/reports/actions.log}"
allowed() { case "$1" in stop-burp|stop-grammarly) return 0;; *) return 1;; esac; }
describe() { case "$1" in
  stop-burp) echo "Stop Burp Suite (JavaApplicationStub, proxy :8080). Risk: unsaved Burp session state. Undo: fix.sh --reopen burp";;
  stop-grammarly) echo "Quit Grammarly Desktop (helper listening :49315). Undo: fix.sh --reopen grammarly";;
  *) echo "Unknown fix";; esac; }
log_action() { mkdir -p "$(dirname "$ACTIONS_LOG")"; echo "$(date '+%F %T') $1 $2 $3" >> "$ACTIONS_LOG"; }
stop_one() { # echoes result, returns 0 if queue entry should be removed
  if [ "${FIX_SIMULATE:-0}" = "1" ]; then echo "simulated-stop"; return 0; fi
  case "$1" in
    stop-burp) P="$(pgrep -f 'Burp Suite.app/Contents/MacOS/JavaApplicationStub' || true)"; PORT=8080;;
    stop-grammarly) P="$(pgrep -f 'Grammarly Desktop.app' || true)"; PORT=49315;;
  esac
  [ -z "$P" ] && { echo "stale-not-running"; return 0; }
  kill $P 2>/dev/null; sleep 3
  if lsof -iTCP:$PORT -sTCP:LISTEN -P -n >/dev/null 2>&1; then echo "failed-port-still-open"; return 1; fi
  echo "stopped"; return 0; }

case "${1:-}" in
  --help) echo "Usage: $0 [--list|--dry-run <id>|--reopen burp|grammarly]"; exit 0;;
  --list) [ -s "$PENDING" ] && { echo "Pending fixes:"; while IFS="$(printf '\t')" read -r id ts desc; do echo "  $id — $desc (queued $ts)"; describe "$id" | sed 's/^/    /'; done < "$PENDING"; } || echo "No pending fixes."; exit 0;;
  --dry-run) allowed "${2:-}" || { echo "Refused: ${2:-} is not on the allowlist (stop-burp, stop-grammarly)."; exit 1; }; echo "Would apply ${2}: $(describe "${2}") — no action taken."; exit 0;;
  --reopen) case "${2:-}" in burp) open -a "Burp Suite";; grammarly) open -a "Grammarly Desktop";; *) echo "Refused: reopen target must be burp or grammarly."; exit 1;; esac; echo "Reopened ${2}"; log_action REOPEN "${2}" ok; exit 0;;
esac

[ -s "$PENDING" ] || { echo "No pending fixes. You're in the loop — nothing to approve."; exit 0; }
TMPNEW="$(mktemp)"; SNAP="$(mktemp)"; cp "$PENDING" "$SNAP"
while IFS="$(printf '\t')" read -r id ts desc; do
  [ -n "$id" ] || continue
  if ! allowed "$id"; then echo "⛔ Refused: '$id' is not on the allowlist — left queued for IT/manual review, never auto-applied."; printf '%s\t%s\t%s\n' "$id" "$ts" "$desc" >> "$TMPNEW"; continue; fi
  echo ""; echo "Pending: $id — $desc (queued $ts)"; describe "$id"
  if [ "${FIX_ASSUME_YES:-0}" = "1" ]; then ans=y; else printf "Apply this fix? [y]es / [n]o-detect-again-later / [q]uit: "; read -r ans < /dev/tty 2>/dev/null || read -r ans; fi
  case "$ans" in
    q|Q) printf '%s\t%s\t%s\n' "$id" "$ts" "$desc" >> "$TMPNEW"; echo "Left queued."; break;;
    y|Y) R="$(stop_one "$id")"; S=$?; log_action APPLY "$id" "$R"; echo "Result: $R"
         if [ $S -eq 0 ]; then [ "${FIX_SIMULATE:-0}" != "1" ] && "$HERE/notify.sh" "Mac Assurance — fix applied" "$id: $R" || true; else printf '%s\t%s\t%s\n' "$id" "$ts" "$desc" >> "$TMPNEW"; fi;;
    *) echo "Dismissed (will be re-queued by the next scan if still running)."; log_action DISMISS "$id" by-user;;
  esac
done < "$SNAP"
mv "$TMPNEW" "$PENDING"; rm -f "$SNAP"
echo ""; echo "Done. Actions logged to $ACTIONS_LOG"
