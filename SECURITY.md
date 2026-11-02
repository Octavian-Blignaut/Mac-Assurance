# Security policy — Mac Assurance

## What this tool promises
- Read-only scanning: no admin rights, no system-settings changes (enforced by tests).
- The only actions ever taken are the two approve-first, user-confirmed process
  stops in the fix engine, each logged and reversible.
- No network access, no telemetry, no data leaves your Mac.

## Handle your data carefully
Reports, `baseline.txt`, and `fixes-pending.txt` inventory your machine
(admins, listeners, extensions). They are git-ignored — keep them that way.
Never attach a full report to a public issue; the monthly rollup with host
details removed is the shareable artifact.

## Reporting a problem with the tool itself
Open a private GitHub issue in this repository describing the behaviour and
your macOS version. If the issue is that the tool *missed* something on your
machine, contact your IT security team first, the tool second.
