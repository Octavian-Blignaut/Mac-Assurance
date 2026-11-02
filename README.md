# Mac Assurance

**A read-only security audit + approve-first fix engine for a managed Mac.**
Built as a learning project on an employer-managed Mac (endpoint protection,
web proxy, and MDM all provided by IT). It *observes* the corporate stack —
it never alters it — and turns "is my machine safe?" into a daily,
evidence-based answer.

```
Detect  →  baseline diff  →  daily HTML digest  →  queue fix  →  YOU approve  →  act + log
```

## Quick start

```bash
./install.sh                    # deploy runtime + LaunchAgents (no admin rights needed)
~/Library/MacAssurance/daily.sh # run today's check now (opens the HTML report)
./audit.sh                      # full scan in this terminal
./tests/run-tests.sh            # 47 checks, all should pass
./uninstall.sh                  # remove the agents cleanly (from the runtime copy)
```

The 07:30 daily job and the persistence watcher install as user LaunchAgents
(`digital.blouberg.mac-assurance.*`). Runtime lives in `~/Library/MacAssurance/`
because `launchd` cannot read scripts on `~/Desktop` (macOS TCC) — this folder
is the source of truth; edit here, then re-run `./install.sh` to deploy.

## What it checks

FileVault · SIP · Gatekeeper · endpoint-protection extensions still active · firewall
state (report-only) · admin accounts · SSH/screen-sharing surface · LaunchAgent/
Daemon persistence inventory · network listeners (localhost vs wildcard) · SSH
key passphrases (existence only — key contents are never read) · Chrome
extensions · screen-lock delay · `/etc/hosts` · Time Machine recency — each with
a one-line *"why it matters"* so every report teaches something.

**The baseline diff is the real detector.** `baseline.txt` is the known-good
inventory; a *new* admin, listener, extension, or launch item you can't explain
is the finding. Tools find known-bad; diffs find new.

## Reports & storage

- Daily digest: notification + an HTML report (ocean/kelp branded,
  verdict banner + PASS/WARN/FAIL/UNKNOWN cards) that **opens itself** at 07:30.
  Watcher-triggered runs notify only — they never auto-open.
- Hot: `~/Library/MacAssurance/reports/YYYY-MM/` — 90 days (~5 KB/day).
- Cold: `monthly.sh` writes `reports/archive/YYYY-MM-rollup.md` + `.tar.gz` —
  kept forever (~2 MB/year total).
- Full reports are sensitive inventory (admins, listeners, extensions):
  **never commit them, never send them off-machine.** Commit `baseline.txt`
  changes instead — `git log` becomes your "when did this change?" timeline.

## Fix Engine v1 (approve-first)

Detection never acts. When Burp Suite (`:8080`) or Grammarly (`:49315`) is
left listening, a fix is *queued*:

```bash
~/Library/MacAssurance/fix.sh            # walk the queue: y / n / q
~/Library/MacAssurance/fix.sh --list
~/Library/MacAssurance/fix.sh --dry-run stop-burp
~/Library/MacAssurance/fix.sh --reopen burp    # undo
```

The allowlist is hard-coded (`stop-burp`, `stop-grammarly`) — any other
target, even a hand-forged queue entry like `stop-eset`, is **refused**.
Everything applied is written to `reports/actions.log`. Endpoint protection,
web proxy, MDM, firewall, system extensions, and admin accounts are a permanent
deny-list: alert + escalate to IT, never self-fix.

## Safety model

| Tier | Examples | Rule |
|---|---|---|
| Observe | All audit checks | Read-only, no `sudo`, ever (tests enforce this) |
| Approve-first | Stop Burp/Grammarly listeners | Queued; only your `y` applies it; logged + reopenable |
| Never | Endpoint/MDM tooling, firewall, `/Library` daemons, admins | Alert + IT escalation template (see below) |

Escalate to IT with: host name, macOS version, finding, timestamp, and
"I have not changed any managed settings." Identifying a root-owned listener:

```bash
sudo lsof -iTCP:8021 -sTCP:LISTEN -P -n   # run it yourself — never share your password
```

## Layout

| File | Job |
|---|---|
| `audit.sh` | The read-only scanner → dated Markdown report |
| `daily.sh` | Scheduler entry: audit → headline → HTML → notify → open (daily only) |
| `render.py` | Markdown → branded HTML (stdlib Python) |
| `queue-fix.sh` / `fix.sh` | Pending-fix queue + approve-first engine |
| `monthly.sh` | Rollup + compressed archive per finished month |
| `notify.sh` | macOS notification (osascript) |
| `launchd/*.plist.template` | Daily 07:30 + WatchPaths persistence watcher |
| `install.sh` / `uninstall.sh` | Deploy/remove runtime + agents, idempotent |
| `baseline.txt` | Known-good inventory (commit your explained changes) |
| `tests/run-tests.sh` | Full test suite — run after every edit |

## Findings that shaped it (Oct 30 – Nov 1, 2026)

- No compromise indicators: FileVault/SIP/Gatekeeper on, no rogue persistence,
  logins, or `authorized_keys`; wildcard listener `*:51348` turned out to be
  Apple's `symptomsd` (verified by owner-run `sudo lsof` + code signature).
- Real hygiene wins: 5 SSH keys without passphrases, 60 s screen-lock delay,
  forgotten Burp/Adobe listeners (disabled/stopped, re-baselined as explained).
- `launchd` + TCC: scripts must live in `~/Library`, not `~/Desktop`.
- A deleted `audit.sh` was restored from the runtime copy — the split paid off.

## Pilot (v0.1.0) — what to expect

You are 1 of a small pilot. Install takes 2 minutes and needs no admin rights:

```bash
git clone <this-private-repo> && cd mac-assurance
./install.sh            # read the manifest, answer y
./tests/run-tests.sh    # optional: prove it on your machine
```

Every morning at 07:30 an HTML report opens with your PASS/WARN/FAIL counts.
If a launch item changes, you may get an extra notification. Fixes are never
applied without you running `fix.sh` and answering `y`.
Uninstall anytime: `~/Library/MacAssurance/uninstall.sh` (see also `./uninstall.sh`).
Please file pilot feedback via the GitHub issue template: install smoothness,
any alert from your existing security tooling mentioning our agents, whether
you actually read the digest, and one thing that confused you.

## Roadmap

- [ ] Identify the last unknown listener (`127.0.0.1:8021`, root-owned)
- [ ] Screen-lock drift + Adobe re-enable rules (approve-first, same engine)
- [ ] Quarantine-unknown-LaunchAgent fix (move, never delete)
- [ ] LuLu/BlockBlock — only with IT approval, they're IT's layer to bless
