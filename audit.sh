#!/usr/bin/env bash
# mac-assurance audit.sh — read-only weekly security audit for a managed Mac.
# NEVER: uses admin privileges, changes settings, or prints private-key material.
# Usage: ./audit.sh [--baseline]   Env: CHECK_UPDATES=1 to include softwareupdate -l
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/config.local.sh" ] && . "$HERE/config.local.sh"
REPORTS_DIR="${REPORTS_DIR:-$HERE/reports}"
BASELINE_FILE="${BASELINE_FILE:-$HERE/baseline.txt}"
WRITE_BASELINE=0
[ "${1:-}" = "--baseline" ] && WRITE_BASELINE=1
if [ "${1:-}" = "--help" ]; then echo "Usage: $0 [--baseline]  (CHECK_UPDATES=1 to check pending updates)"; exit 0; fi

mkdir -p "$REPORTS_DIR/$(date +%Y-%m)"
STAMP="$(date +%F-%H%M)"
REPORT="$REPORTS_DIR/$(date +%Y-%m)/$STAMP-audit.md"
INV="$(mktemp)"; trap 'rm -f "$INV"' EXIT
PASSN=0; WARNN=0; FAILN=0; UNKN=0
exec > >(tee "$REPORT") 2>&1

say()  { echo "$*"; }
pass() { PASSN=$((PASSN+1)); say "✅ PASS  $*"; }
warn() { WARNN=$((WARNN+1)); say "⚠️ WARN  $*"; }
fail() { FAILN=$((FAILN+1)); say "❌ FAIL  $*"; }
unkn() { UNKN=$((UNKN+1)); say "❓ UNKNOWN $*"; }
why()  { say "   ↳ Why it matters: $*"; }
section() { say ""; say "## $*"; }

say "# Mac Assurance Audit — $STAMP"
MA_VERSION="$(cat "$HERE/VERSION" 2>/dev/null || echo dev)"; say "Mac Assurance VERSION $MA_VERSION"
say "Host: $(scutil --get ComputerName 2>/dev/null || hostname) · $(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
say "Mode: read-only · managed endpoint protection is observed, never altered"

section "1. Disk encryption & system integrity"
why "FileVault makes a stolen laptop a brick; SIP/Gatekeeper stop system tampering and unsigned code."
if fdesetup status 2>/dev/null | grep -qi "FileVault is On"; then pass "FileVault is On"; else fail "FileVault is NOT on — escalate to IT"; fi
if csrutil status 2>/dev/null | grep -qi enabled; then pass "SIP enabled"; else fail "SIP disabled"; fi
if spctl --status 2>/dev/null | grep -qi enabled; then pass "Gatekeeper enabled"; else fail "Gatekeeper disabled"; fi

section "2. Corporate protection still active (observe only)"
why "If ESET/Netskope silently died, you'd have no antivirus while believing you do."
EXT="$(systemextensionsctl list 2>/dev/null)"
echo "$EXT" | grep -q "com.eset.endpoint.*activated enabled" && pass "ESET endpoint extension active" || fail "ESET endpoint extension NOT active — escalate to IT"
echo "$EXT" | grep -q "com.eset.network.*activated enabled" && pass "ESET network extension active" || warn "ESET network extension not active — ask IT"
echo "$EXT" | grep -q "netskope.*activated enabled" && pass "Netskope extension active" || warn "Netskope extension not active — ask IT"
echo "$EXT" | grep -qi "lulu.*waiting for user" && warn "LuLu extension installed but waiting for approval — decide with IT: approve or remove"
echo "$EXT" | grep -oE "(com\.[a-z0-9.-]+|io\.[a-z0-9.-]+) \([0-9]" | sed 's/ ($//' | sort -u | while read -r x; do echo "sysext:$x" >> "$INV"; done

section "3. Firewall (report only — may be IT policy)"
why "A firewall blocks unsolicited inbound connections on coffee-shop Wi-Fi. On managed Macs ESET may replace it, so we never toggle it ourselves."
FW="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null)"
echo "$FW" | grep -qi enabled && pass "macOS firewall enabled" || warn "macOS firewall disabled ($FW) — confirm with IT that ESET covers this; do not enable unilaterally"

section "4. Accounts & admins"
why "An unknown account or admin is classic attacker persistence. Admins hold the keys to the kingdom."
dscl . -read /Groups/admin GroupMembership 2>/dev/null | tr ' ' '\n' | tail -n +2 | sort -u | while read -r u; do [ -n "$u" ] && echo "admin:$u" >> "$INV"; done
say "Admins: $(grep '^admin:' "$INV" 2>/dev/null | cut -d: -f2 | paste -sd' ' -)"
[ -n "${EXPECTED_ADMINS:-}" ] && say "   ↳ Expected admins per config.local.sh: $EXPECTED_ADMINS — any admin NOT in the list above and not expected should be treated as a finding and raised with ${IT_NAME:-your IT team}."
if defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser >/dev/null 2>&1; then warn "Auto-login is configured — should be off"; else pass "No auto-login user"; fi

section "5. Remote access surface"
why "Every listening remote service is a door. Doors you didn't open are how breaches start."
if launchctl print system/com.openssh.sshd >/dev/null 2>&1; then warn "SSH server (sshd) is loaded — expected? If not, ask IT"; else pass "SSH server not running"; fi
if launchctl print-disabled system 2>/dev/null | grep -q '"com.apple.screensharing" => enabled'; then warn "Screen Sharing enabled"; else pass "Screen Sharing disabled"; fi
if [ -s "$HOME/.ssh/authorized_keys" ]; then warn "~/.ssh/authorized_keys exists ($(wc -l < "$HOME/.ssh/authorized_keys" | tr -d ' ') keys) — review each one"; else pass "No ~/.ssh/authorized_keys (nobody can SSH in with a key)"; fi

section "6. Persistence inventory (LaunchAgents / LaunchDaemons)"
why "Malware survives reboot by registering here. The defence is not 'empty' — it's 'every item attributable to a known vendor'."
for d in "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons; do
  ls "$d" 2>/dev/null | while read -r f; do echo "launchd:$f" >> "$INV"; done
done
say "Launch items: $(grep -c '^launchd:' "$INV" 2>/dev/null || echo 0) (full list in baseline diff below)"
if crontab -l >/dev/null 2>&1; then warn "User crontab exists — review it: crontab -l"; else pass "No user crontab"; fi
shasum -a 256 "$HOME/.zshrc" 2>/dev/null | awk '{print "zshrc-sha256:" $1}' >> "$INV"

section "7. Network listeners"
why "127.0.0.1 listeners are reachable only by your own machine. A * listener is reachable by anyone on your network — it must have a name and a reason."
netstat -an -p tcp 2>/dev/null | grep LISTEN | awk '{print $4}' | sort -u | while read -r p; do echo "listener:$p" >> "$INV"; done
if netstat -an -p tcp 2>/dev/null | grep LISTEN | grep -qE '\*\.[0-9]+ '; then warn "Wildcard (*) listener present — identify it (see README: owner-run lsof command)"; else pass "No wildcard listeners"; fi
say "User processes listening:"; lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null | tail -n +2 | awk '{print "   " $1, $9}' | sort -u

section "8. SSH private keys (existence & passphrase only — contents never read)"
why "An unencrypted private key is a password in a file. Anyone who copies it owns every server it opens."
for k in "$HOME"/.ssh/*; do
  [ -f "$k" ] || continue; case "$k" in *.pub|*known_hosts*|*/config|*.old) continue;; esac
  head -n 1 "$k" 2>/dev/null | grep -q "PRIVATE KEY" || continue
  if ssh-keygen -y -P "" -f "$k" >/dev/null 2>&1; then warn "Key has NO passphrase: $k"; else pass "Key is passphrase-protected (or unreadable): $k"; fi
done

section "9. Browser extensions (Chrome)"
why "Extensions see every page you visit, including banking and email. Unknown extension = unknown watcher."
EXTDIR="$HOME/Library/Application Support/Google/Chrome/Default/Extensions"
if [ -d "$EXTDIR" ]; then ls "$EXTDIR" | while read -r e; do echo "chrome-ext:$e" >> "$INV"; done; say "Chrome extensions: $(grep -c '^chrome-ext:' "$INV" || echo 0) (IDs in baseline; look up any new one at chrome web store by ID)"; else say "No Chrome Default profile extensions dir"; fi

section "10. Screen lock & updates"
why "An unlocked unattended Mac bypasses FileVault entirely. Unpatched software is the #1 entry point."
sysadminctl -screenLock status 2>/dev/null | grep -q "delay is 0" && pass "Screen lock requires password immediately" || warn "Screen lock delay is not immediate — set 'Require password immediately' in System Settings > Lock Screen (safe to do yourself)"
if [ "${CHECK_UPDATES:-0}" = "1" ]; then
  if perl -e 'alarm 50; exec @ARGV' softwareupdate -l 2>&1 | grep -q "No new software available"; then pass "No pending macOS updates"; else warn "Updates pending or check inconclusive — see System Settings > Software Update (Kandji may manage timing)"; fi
else unkn "Pending updates not checked (run with CHECK_UPDATES=1). On Kandji Macs IT often controls this — UNKNOWN is not 'up to date'."; fi

section "11. Hosts file"
why "Attackers redirect banks/updates by editing /etc/hosts. Yours should be near-stock."
grep -vE '^\s*(#|$)|127\.0\.0\.1|255\.255\.255\.255|::1' /etc/hosts | grep -v "kubernetes.docker.internal" | grep -q . && warn "Non-default /etc/hosts entries present — review /etc/hosts" || pass "/etc/hosts is stock (plus Docker's entry)"

section "12. Backup (Time Machine)"
why "Ransomware and disk failure only win if your last backup is stale. Defence you never test is a hope, not a control."
LB="$(tmutil latestbackup 2>/dev/null)"
if [ -n "$LB" ]; then pass "Latest Time Machine backup: $LB"; else unkn "No Time Machine backup found via tmutil — confirm in System Settings > Time Machine (external disk may be disconnected)"; fi

section "BASELINE DIFF"
why "Tools find known-bad. Diffs find new. A change you can't explain is the finding."
sort -u "$INV" -o "$INV"
if [ "$WRITE_BASELINE" = "1" ]; then cp "$INV" "$BASELINE_FILE"; pass "Baseline written to $BASELINE_FILE ($(wc -l < "$BASELINE_FILE" | tr -d ' ') items) — future runs diff against today"; 
elif [ -f "$BASELINE_FILE" ]; then
  DIFF_FILE="$(mktemp)"
  if diff "$BASELINE_FILE" "$INV" > "$DIFF_FILE" 2>&1; then pass "no changes vs baseline"; else warn "CHANGES vs baseline (review each — new app from IT is fine, unexplained is not):"; sed 's/^</  REMOVED:/; s/^>/  NEW:/' "$DIFF_FILE" | grep -E "NEW:|REMOVED:" || cat "$DIFF_FILE"; fi
  rm -f "$DIFF_FILE"
else unkn "No baseline yet — run: $0 --baseline"; fi

section "SUMMARY"
say "PASS=$PASSN WARN=$WARNN FAIL=$FAILN UNKNOWN=$UNKN"
say "Report: $REPORT"
say "Cadence: run weekly · ESET on-demand scan monthly · re-baseline ONLY after a change you can explain."
say "Escalate to IT (do not self-fix): any FAIL, ESET/Netskope inactive, unknown admin/listener, firewall/LuLu decisions."
