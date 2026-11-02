#!/usr/bin/env bash
# monthly.sh — for each past YYYY-MM report folder not yet archived:
# create reports/archive/YYYY-MM-rollup.md + YYYY-MM.tar.gz (kept forever).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
REPORTS_DIR="${REPORTS_DIR:-$HERE/reports}"
CUR="$(date +%Y-%m)"; mkdir -p "$REPORTS_DIR/archive"
for d in "$REPORTS_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]; do
  [ -d "$d" ] || continue; M="$(basename "$d")"; [ "$M" = "$CUR" ] && continue
  [ -f "$REPORTS_DIR/archive/$M.tar.gz" ] && continue
  N="$(find "$d" -name '*-audit.md' | wc -l | tr -d ' ')"
  FAILDAYS="$(grep -l 'FAIL=[1-9]' "$d"/*-audit.md 2>/dev/null | wc -l | tr -d ' ')"
  { echo "# Mac Assurance Rollup — $M"; echo ""; echo "Reports archived: $N · Days with FAIL: $FAILDAYS"; echo ""
    echo "## Headlines ($M)"; grep "^....-$M" "$REPORTS_DIR/daily.log" 2>/dev/null || echo "(no daily.log entries captured)"
    echo ""; echo "## Change events"; grep -h "CHANGES vs baseline" "$d"/*-audit.md 2>/dev/null | head -n 20 || true
  } > "$REPORTS_DIR/archive/$M-rollup.md"
  tar -czf "$REPORTS_DIR/archive/$M.tar.gz" -C "$REPORTS_DIR" "$M" 2>/dev/null
  echo "Archived $M ($N reports)"
done
