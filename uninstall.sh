#!/usr/bin/env bash
# uninstall.sh — remove the two user LaunchAgents cleanly.
set -uo pipefail
DEST="$HOME/Library/LaunchAgents"; UID_N="$(id -u)"
for n in daily watch; do
  L="digital.blouberg.mac-assurance.$n"
  launchctl bootout "gui/$UID_N/$L" >/dev/null 2>&1 && echo "Unloaded $L" || echo "Not loaded: $L"
  rm -f "$DEST/$L.plist" && echo "Removed $DEST/$L.plist"
done
echo "Reports and baseline kept. Next audit will show the agents as REMOVED — re-baseline with audit.sh --baseline if that is expected."
