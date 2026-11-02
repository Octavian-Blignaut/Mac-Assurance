#!/usr/bin/env bash
# daily.sh [--watch] — run audit, build headline, log, prune, notify.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPORTS_DIR="${REPORTS_DIR:-$HERE/reports}"; export REPORTS_DIR
BASELINE_FILE="${BASELINE_FILE:-$HERE/baseline.txt}"; export BASELINE_FILE
mkdir -p "$REPORTS_DIR"
MODE="Daily"; [ "${1:-}" = "--watch" ] && MODE="Change detected"

OUT="$("$HERE/audit.sh" 2>&1)"; REPORT_PATH="$(echo "$OUT" | grep '^Report:' | tail -1 | awk '{print $2}')"
SUMMARY="$(echo "$OUT" | grep -E '^PASS=[0-9]+ WARN=[0-9]+ FAIL=[0-9]+ UNKNOWN=[0-9]+' | tail -1)"
FAILN="$(echo "$SUMMARY" | sed -nE 's/.*FAIL=([0-9]+).*/\1/p')"; FAILN="${FAILN:-0}"
STALE=""
if [ -f "$REPORTS_DIR/.last-success" ]; then
  LAST="$(cat "$REPORTS_DIR/.last-success" 2>/dev/null || echo 0)"; NOW="$(date +%s)"
  [ $((NOW - LAST)) -gt 129600 ] && STALE=" Last successful run over 36h ago — silence is not safety; check launchd."
fi

if [ "$FAILN" -gt 0 ]; then HEADLINE="❌ Mac Assurance ($MODE): $SUMMARY — contact IT. $STALE"; RC=2
elif echo "$OUT" | grep -q "CHANGES vs baseline"; then HEADLINE="⚠️ Mac Assurance ($MODE): NEW or REMOVED items vs baseline — review report. $SUMMARY$STALE"; RC=2
else HEADLINE="✅ Mac Assurance ($MODE): no new changes. $SUMMARY$STALE"; RC=0; fi

# Forgotten-tools detection -> pending fix queue (never acts here)
PENDING="${FIX_PENDING_FILE:-$HERE/fixes-pending.txt}"; export FIX_PENDING_FILE="$PENDING"
echo "$OUT" | grep -q '127.0.0.1:8080' && "$HERE/queue-fix.sh" stop-burp "Burp Suite listening on :8080 (forgotten proxy?)" >/dev/null 2>&1
echo "$OUT" | grep -q 'app_inkwe' && "$HERE/queue-fix.sh" stop-grammarly "Grammarly helper listening on :49315" >/dev/null 2>&1
NPEND=0; [ -f "$PENDING" ] && NPEND="$(grep -c . "$PENDING" 2>/dev/null || echo 0)"
HTML=""
if [ -n "$REPORT_PATH" ] && [ -f "$REPORT_PATH" ]; then HTML="${REPORT_PATH%.md}.html"; python3 "$HERE/render.py" "$REPORT_PATH" "$HTML" 2>/dev/null || HTML=""; fi
echo "$HEADLINE"; [ "$NPEND" -gt 0 ] && echo "Fixes: $NPEND awaiting your decision — run: $HERE/fix.sh"
[ -n "$REPORT_PATH" ] && echo "Report: $REPORT_PATH"; [ -n "$HTML" ] && echo "HTML: $HTML"
echo "$(date '+%F %T') [$MODE] $HEADLINE" >> "$REPORTS_DIR/daily.log"
date +%s > "$REPORTS_DIR/.last-success"
find "$REPORTS_DIR" -name '*-audit.md' -type f -mtime +90 -delete 2>/dev/null
find "$REPORTS_DIR" -name '*-audit.html' -type f -mtime +90 -delete 2>/dev/null
"$HERE/monthly.sh" >/dev/null 2>&1 || true
"$HERE/notify.sh" "Mac Assurance — $MODE" "$HEADLINE" || true
# Daily digest opens itself; watcher events never auto-open (could be 3am).
if [ "$MODE" = "Daily" ] && [ -n "$HTML" ] && [ "${NOTIFY_DRY_RUN:-0}" != "1" ] && [ "${OPEN_REPORT:-1}" = "1" ]; then open "$HTML" >/dev/null 2>&1 || true; fi
exit $RC
