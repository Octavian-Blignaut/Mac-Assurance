#!/usr/bin/env bash
# install.sh [--dry-run|--yes] — install two user LaunchAgents (no admin rights needed).
# Runtime lives in ~/Library/MacAssurance: launchd cannot read ~/Desktop (TCC).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; DEST="$HOME/Library/LaunchAgents"; RUNTIME="$HOME/Library/MacAssurance"; UID_N="$(id -u)"
gen() { sed -e "s|@ASSURANCE_DIR@|$RUNTIME|g" -e "s|@HOME@|$HOME|g" "$HERE/launchd/$1.plist.template"; }
manifest() {
  echo "Mac Assurance install manifest — this WILL:"
  echo "  - Copy scripts to $RUNTIME (runtime copy; this folder stays the source)"
  echo "  - Create two user LaunchAgents in $DEST:"
  echo "      digital.blouberg.mac-assurance.daily (07:30 audit + report opens)"
  echo "      digital.blouberg.mac-assurance.watch (audits when launch items change)"
  echo "  - Generate or refresh a per-machine baseline of admins/listeners/extensions"
  echo "This will NEVER: use admin rights (no sudo), change firewall or system settings,"
  echo "alter endpoint/MDM tooling, delete files, or send data anywhere (no network use)."
}
case "${1:-}" in
  --dry-run) manifest; for n in daily watch; do echo "--- digital.blouberg.mac-assurance.$n.plist (runtime: $RUNTIME) ---"; gen "digital.blouberg.mac-assurance.$n"; done; exit 0;;
  --yes) ;;
  "") manifest; printf "Proceed? [y/N] "; read -r ans; case "$ans" in y|Y) ;; *) echo "Aborted — nothing installed."; exit 0;; esac;;
  *) echo "Usage: $0 [--dry-run|--yes]"; exit 2;;
esac
mkdir -p "$DEST" "$RUNTIME/reports"
cp "$HERE/audit.sh" "$HERE/daily.sh" "$HERE/notify.sh" "$HERE/monthly.sh" "$HERE/render.py" "$HERE/fix.sh" "$HERE/queue-fix.sh" "$HERE/uninstall.sh" "$HERE/VERSION" "$RUNTIME/"
[ -f "$HERE/config.local.sh" ] && cp "$HERE/config.local.sh" "$RUNTIME/"
chmod +x "$RUNTIME"/*.sh
for n in daily watch; do
  L="digital.blouberg.mac-assurance.$n"; gen "$L" > "$DEST/$L.plist"
  plutil -lint "$DEST/$L.plist" >/dev/null || { echo "plist lint failed: $L"; exit 1; }
  launchctl bootout "gui/$UID_N/$L" >/dev/null 2>&1
  launchctl bootstrap "gui/$UID_N" "$DEST/$L.plist" && echo "Loaded $L" || { echo "FAILED to load $L"; exit 1; }
done
if [ -f "$RUNTIME/baseline.txt" ]; then
  echo "Refreshing this machine's baseline so the new agents record themselves..."
  "$RUNTIME/audit.sh" --baseline | grep -E "Baseline written|SUMMARY" || true
elif [ -f "$HERE/baseline.txt" ]; then
  cp "$HERE/baseline.txt" "$RUNTIME/baseline.txt"
  "$RUNTIME/audit.sh" --baseline | grep -E "Baseline written|SUMMARY" || true
else
  echo "Generating a fresh baseline for this machine..."
  "$RUNTIME/audit.sh" --baseline | grep -E "Baseline written|SUMMARY" || true
fi
[ -f "$RUNTIME/baseline.txt" ] && cp "$RUNTIME/baseline.txt" "$HERE/baseline.txt" 2>/dev/null || true
echo "Done. Runtime: $RUNTIME · Daily 07:30 + watcher active · Reports: $RUNTIME/reports/ · Edit scripts here, re-run install.sh to deploy."
