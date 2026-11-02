#!/usr/bin/env bash
# Tests for audit.sh — run: bash security/mac-assurance/tests/run-tests.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$HERE/audit.sh"
fail=0
check() { if [ "$2" -eq 0 ]; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }

bash -n "$AUDIT" 2>/dev/null; check "audit.sh syntax is valid" $?
"$AUDIT" --help >/dev/null 2>&1; check "--help exits 0" $?

TMP="$(mktemp -d)"
REPORTS_DIR="$TMP" BASELINE_FILE="$TMP/base.txt" "$AUDIT" --baseline >/dev/null 2>&1
find "$TMP" -name '*-audit.md' | grep -q .; check "a run writes a dated report" $?
grep -q "## SUMMARY" $(find "$TMP" -name '*-audit.md' | head -1) 2>/dev/null; check "report contains SUMMARY" $?
find "$TMP" -path '*/20??-??/*-audit.md' | grep -q .; check "reports are filed under YYYY-MM/" $?
grep -q "^admin:" "$TMP/base.txt" 2>/dev/null; check "baseline records admins" $?
grep -q "^launchd:" "$TMP/base.txt" 2>/dev/null; check "baseline records launchd items" $?

OUT="$(REPORTS_DIR="$TMP" BASELINE_FILE="$TMP/base.txt" "$AUDIT" 2>/dev/null)"
echo "$OUT" | grep -q "no changes vs baseline"; check "second run diffs clean vs baseline" $?

grep -q "PRIVATE KEY" "$AUDIT"; check "key check covers extensionless keys (e.g. google_compute_engine)" $?

# --- Always-on layer ---
bash -n "$HERE/daily.sh" 2>/dev/null; check "daily.sh syntax is valid" $?
bash -n "$HERE/notify.sh" 2>/dev/null; check "notify.sh syntax is valid" $?
OUT="$(NOTIFY_DRY_RUN=1 "$HERE/notify.sh" "TestTitle" "TestBody" 2>/dev/null)"
echo "$OUT" | grep -q "TestTitle"; check "notify.sh dry-run echoes title" $?
TMP2="$(mktemp -d)"; mkdir -p "$TMP2/reports"
REPORTS_DIR="$TMP2/reports" BASELINE_FILE="$TMP2/base.txt" "$AUDIT" --baseline >/dev/null 2>&1
NOTIFY_DRY_RUN=1 REPORTS_DIR="$TMP2/reports" BASELINE_FILE="$TMP2/base.txt" "$HERE/daily.sh" >"$TMP2/daily.out" 2>&1
check "daily.sh exits 0 when no changes" $?
grep -q "no new changes" "$TMP2/daily.out"; check "daily headline says no new changes" $?
[ -f "$TMP2/reports/.last-success" ]; check "daily writes .last-success" $?
for t in "$HERE"/launchd/*.plist.template; do
  sed -e "s|@ASSURANCE_DIR@|$HERE|g" -e "s|@HOME@|$HOME|g" "$t" > "$TMP2/test.plist"
  plutil -lint "$TMP2/test.plist" >/dev/null 2>&1; check "plist template lints: $(basename "$t")" $?
done
"$HERE/install.sh" --dry-run >"$TMP2/dry.out" 2>&1; check "install.sh --dry-run exits 0" $?
grep -q "digital.blouberg.mac-assurance.daily" "$TMP2/dry.out"; check "dry-run shows daily agent" $?
grep -q "Library/MacAssurance" "$TMP2/dry.out"; check "agents run from ~/Library/MacAssurance (TCC: launchd cannot read Desktop)" $?
[ ! -f "$HOME/Library/LaunchAgents/digital.blouberg.mac-assurance.daily.plist.dryrun" ]; check "dry-run installs nothing extra" $?
rm -rf "$TMP2"

# --- Delivery & storage ---
TMP2="$(mktemp -d)"; mkdir -p "$TMP2/reports"
REPORTS_DIR="$TMP2/reports" BASELINE_FILE="$TMP2/base.txt" "$AUDIT" --baseline >/dev/null 2>&1
python3 -m py_compile "$HERE/render.py" 2>/dev/null; check "render.py compiles" $?
printf '# T\n## SUMMARY\nPASS line\n' > "$TMP2/sample.md"
python3 "$HERE/render.py" "$TMP2/sample.md" "$TMP2/sample.html" 2>/dev/null
grep -q "<html" "$TMP2/sample.html" 2>/dev/null; check "render.py produces HTML" $?
grep -q "SUMMARY" "$TMP2/sample.html" 2>/dev/null; check "HTML keeps report content" $?
grep -q "0B3C5D" "$TMP2/sample.html" 2>/dev/null; check "HTML uses Blouberg ocean brand colour" $?
grep -q "1F7A5C" "$TMP2/sample.html" 2>/dev/null; check "HTML uses Blouberg kelp brand colour" $?
printf '# Mac Assurance Audit — x\n## SUMMARY\nPASS=3 WARN=1 FAIL=0 UNKNOWN=0\n' > "$TMP2/cards.md"
python3 "$HERE/render.py" "$TMP2/cards.md" "$TMP2/cards.html" 2>/dev/null
grep -q 'stat-card' "$TMP2/cards.html" 2>/dev/null; check "report renders summary stat cards" $?
grep -q '>3<' "$TMP2/cards.html" 2>/dev/null; check "stat card shows PASS count from SUMMARY" $?
NOTIFY_DRY_RUN=1 REPORTS_DIR="$TMP2/reports" BASELINE_FILE="$TMP2/base.txt" "$HERE/daily.sh" >/dev/null 2>&1
find "$TMP2/reports" -name '*-audit.html' | grep -q .; check "daily run renders an HTML report" $?
grep -q "mtime +30" "$HERE/daily.sh"; [ $? -ne 0 ]; check "daily no longer prunes at 30 days" $?
grep -q "mtime +90" "$HERE/daily.sh"; check "full reports kept 90 days" $?
mkdir -p "$TMP2/reports/2000-01"; printf '# old\nPASS=1 WARN=0 FAIL=0 UNKNOWN=0\n' > "$TMP2/reports/2000-01/2000-01-01-0000-audit.md"
REPORTS_DIR="$TMP2/reports" "$HERE/monthly.sh" >/dev/null 2>&1
[ -f "$TMP2/reports/archive/2000-01-rollup.md" ]; check "monthly creates rollup for past month" $?
[ -f "$TMP2/reports/archive/2000-01.tar.gz" ]; check "monthly creates compressed archive" $?
grep -qi "2000-01" "$TMP2/reports/archive/2000-01-rollup.md" 2>/dev/null; check "rollup names its month" $?

# --- Fix Engine v1 ---
bash -n "$HERE/fix.sh" 2>/dev/null; check "fix.sh syntax is valid" $?
bash -n "$HERE/queue-fix.sh" 2>/dev/null; check "queue-fix.sh syntax is valid" $?
TMP3="$(mktemp -d)"; PF="$TMP3/pending.txt"
FIX_PENDING_FILE="$PF" "$HERE/queue-fix.sh" stop-burp "Burp Suite listening on 8080" >/dev/null 2>&1
FIX_PENDING_FILE="$PF" "$HERE/queue-fix.sh" stop-burp "Burp Suite listening on 8080" >/dev/null 2>&1
[ "$(wc -l < "$PF" | tr -d ' ')" = "1" ]; check "queue-fix dedupes by id" $?
FIX_PENDING_FILE="$PF" "$HERE/fix.sh" --list 2>/dev/null | grep -i burp >/dev/null; check "fix.sh --list shows pending Burp fix" $?
FIX_PENDING_FILE="$PF" ACTIONS_LOG="$TMP3/actions.log" "$HERE/fix.sh" --dry-run stop-burp 2>/dev/null | grep -qi "would"; check "fix.sh --dry-run describes without acting" $?
[ "$(wc -l < "$PF" | tr -d ' ')" = "1" ]; check "dry-run leaves queue untouched" $?
printf 'stop-eset\tESET fake entry\n' >> "$PF"
OUT="$(FIX_PENDING_FILE="$PF" ACTIONS_LOG="$TMP3/actions.log" FIX_ASSUME_YES=1 FIX_SIMULATE=1 "$HERE/fix.sh" 2>&1)"; RC=$?
echo "$OUT" | grep -qi "refus"; check "fix engine refuses non-allowlisted target (stop-eset)" $?
grep -q "^stop-eset" "$PF"; check "refused entry stays queued (not silently dropped)" $?
grep -q "stop-burp" "$TMP3/actions.log" 2>/dev/null; check "applied/stale fix is written to actions.log" $?
rm -rf "$TMP3"

# --- Pilot packaging ---
[ -f "$HERE/VERSION" ]; check "VERSION file exists" $?
grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' "$HERE/VERSION" 2>/dev/null; check "VERSION is semver" $?
grep -rnE 'businessit|[Ii]mpact\.com|Octavian' "$HERE/audit.sh" "$HERE/daily.sh" "$HERE/render.py" "$HERE/README.md" >/dev/null 2>&1; [ $? -ne 0 ]; check "shipped code/docs contain no personal or company identifiers" $?
[ -f "$HERE/baseline.example.txt" ]; check "baseline.example.txt ships instead of a real baseline" $?
[ -f "$HERE/config.example.sh" ]; check "config.example.sh exists for EXPECTED_ADMINS etc" $?
"$HERE/install.sh" --dry-run 2>/dev/null | grep -i "manifest" >/dev/null; check "installer dry-run prints a consent manifest" $?
grep -q "Generating a fresh baseline" "$HERE/install.sh"; check "installer generates per-machine baseline when none exists" $?
grep -q "ReadMacAssuranceVersion\|VERSION" "$AUDIT"; check "audit reports its version" $?
DIST_TMP="$(mktemp -d)"; DIST_DIR="$DIST_TMP" "$HERE/make-release.sh" >/dev/null 2>&1
ls "$DIST_TMP"/mac-assurance-*.tar.gz >/dev/null 2>&1; check "make-release builds a tarball" $?
ls "$DIST_TMP"/mac-assurance-*.tar.gz.sha256 >/dev/null 2>&1; check "make-release writes SHA-256" $?
tar -tzf "$DIST_TMP"/mac-assurance-*.tar.gz 2>/dev/null | grep -q "baseline.txt"; [ $? -ne 0 ]; check "release tarball excludes real baseline.txt" $?
tar -tzf "$DIST_TMP"/mac-assurance-*.tar.gz 2>/dev/null | grep -q "reports/"; [ $? -ne 0 ]; check "release tarball excludes reports" $?
rm -rf "$DIST_TMP"

# Safety rails: script must never invoke sudo or change firewall settings
grep -qE '^[[:space:]]*sudo ' "$AUDIT"; [ $? -ne 0 ]; check "audit.sh never calls sudo" $?
grep -q "socketfilterfw --set" "$AUDIT"; [ $? -ne 0 ]; check "audit.sh never changes firewall" $?
grep -q '/tmp/mac-assurance-diff\.\$\$' "$AUDIT"; [ $? -ne 0 ]; check "audit diff does not use a predictable /tmp path" $?
grep -q 'DIFF_FILE="$(mktemp)"' "$AUDIT"; check "audit diff uses a secure temporary file" $?
rm -rf "$TMP"
exit $fail
