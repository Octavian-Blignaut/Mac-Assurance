# Mac Assurance 🛡️

**A friendly daily health-check for your Mac.**

Every morning at **07:30**, Mac Assurance gives your Mac a quick once-over —
is the disk encrypted, is your protection still running, has anything new
quietly installed itself, is anything listening that shouldn't be — and opens
a simple report in your browser: ✅ all clear, or ⚠️ “have a look at this.”

It never changes anything without asking you first. Ever.

---

## 👋 Start here (5 minutes, no admin password needed)

**You need:** a Mac, and Terminal (press `⌘ + Space`, type `Terminal`, hit Enter).

### 1. Get the code

```bash
cd ~/Desktop
git clone https://github.com/Octavian-Blignaut/Mac-Assurance.git
cd Mac-Assurance
```

No `git`? On the GitHub page: **Code → Download ZIP**, unzip it, then in Terminal:

```bash
cd ~/Downloads/Mac-Assurance-main
```

### 2. Install it

```bash
./install.sh
```

It will show you a short manifest — exactly what it's about to do — and ask
`Proceed? [y/N]`. Type `y`.

**What just happened (in plain English):**
- A copy of the tool was placed in `~/Library/MacAssurance` (where macOS lets
  scheduled jobs run from)
- Two behind-the-scenes helpers were registered: one runs the check at 07:30
  daily, one notices if a program installs a new “launch item” (a common way
  software — good and bad — makes itself start automatically)
- It took a snapshot of *your* Mac called a **baseline**: your admin accounts,
  listening apps, and extensions. Future reports compare against this snapshot.

**What it will never do:** ask for your admin password, change your firewall
or system settings, touch your company security tools, delete files, or send
anything anywhere. It has no “phone home” — there is no server.

### 3. See your first report right now

```bash
~/Library/MacAssurance/daily.sh
```

A report opens in your browser. That's exactly what you'll get every morning.

---

## 📖 Reading your report (30 seconds)

At the top you'll see one of three verdicts:

| Verdict | Meaning | What you do |
|---|---|---|
| ✅ **All clear** | Nothing failed, nothing unexplained changed | Nothing. Close the tab ☕ |
| ⚠️ **New or removed items** | Something differs from your baseline | Find the **BASELINE DIFF** section (below) |
| ❌ **Attention needed** | A real check failed (e.g. protection stopped) | Contact IT — don't try to fix security tooling yourself |

Under the verdict are four counters — how many checks **passed**, **warned**,
**failed**, or couldn't be answered (**unknown** — treat unknown as “worth a
look”, never as “fine”).

### The one section that matters most: BASELINE DIFF

Every item is listed as **NEW:** or **REMOVED:**. Ask yourself one question:

> **“Can I explain this?”**

- *“NEW: Spotify launch item”* — you installed Spotify yesterday. Explained. ✅
- *“NEW admin account I don't recognise”* or a listener you can't name —
  **not explained. That's the finding.** Contact IT (template below).

If everything is explained and you want the tool to learn the new normal,
refresh your baseline and write down *why* in a note to yourself:

```bash
~/Library/MacAssurance/audit.sh --baseline
```

Only ever do this for changes you can explain.

---

## 🔧 “Fixes” — the tool asks, you decide

Sometimes the report queues a small cleanup (for example: *“Burp Suite is
still listening — stop it?”*). Nothing is ever fixed automatically. To review:

```bash
~/Library/MacAssurance/fix.sh
```

It walks you through each item in plain language:

- `y` — yes, do it (it confirms the result and writes it to a log)
- `n` — not now (it will ask again tomorrow if the thing is still there)
- `q` — quit, decide later

Changed your mind after a fix? Reopen the app:

```bash
~/Library/MacAssurance/fix.sh --reopen burp
```

Only two fixes exist today — stopping the Burp Suite or Grammarly helpers
when they've been left running. Everything company-managed is permanently
off-limits to the tool: it will alert you instead of touching it.

---

## 🗓️ Your routine (that's it — this is the whole ask)

| When | What |
|---|---|
| Every morning | Glance at the report that opens. ✅ → done |
| When it shows ⚠️/❌ | Read the diff. Explained → re-baseline. Unexplained → IT |
| Monthly | When you plug in a backup drive, notice whether it nags about backups |

## 🆘 Something's wrong?

**The report didn't open this morning**
Run it by hand: `~/Library/MacAssurance/daily.sh`. Still nothing? Check the
log: `tail ~/Library/MacAssurance/reports/daily.log`

**I don't get notifications**
System Settings → Notifications → find *Script Editor* (notifications arrive
under that name — a macOS quirk) → allow notifications. The report file still
exists regardless: `open ~/Library/MacAssurance/reports/` and pick the newest.

**My security software mentioned “Mac Assurance”**
Expected, and honestly good — it noticed our two helpers. They're named
`digital.blouberg.mac-assurance.daily` and `.watch`. You can show IT this
repo; every line is readable and nothing runs hidden.

**It flagged a change right after I installed/updated something**
That's the design working. If you can explain it, re-baseline (above).

**I need to contact IT — what do I say?**
> Hi IT — my Mac Assurance check on [date] flagged: [finding]. Mac is on
> macOS [version]. I haven't changed any managed settings. Expected, or
> something to look at?

Don't paste a full report into chat/tickets — it lists your machine's
accounts and apps. The one relevant section (e.g. BASELINE DIFF) is enough.

---

## 🧹 Uninstall (clean, complete)

```bash
~/Library/MacAssurance/uninstall.sh
```

That stops and removes both helpers. Your past reports stay in
`~/Library/MacAssurance/reports/` if you want them; delete the
`~/Library/MacAssurance` folder to remove everything.

## 🔄 Updating

```bash
cd <where you cloned it>/Mac-Assurance
git pull && ./install.sh
```

## 🧪 For the curious / technical

- Full test suite (run it any time): `./tests/run-tests.sh`
- All checks explained: each report section has a *“Why it matters”* line —
  the reports are written to teach, not just to score.
- Design & safety model: `SECURITY.md` · Changes: `CHANGELOG.md`
- Per-machine settings (expected admin accounts etc.): copy
  `config.example.sh` to `config.local.sh` and edit — it's ignored by git,
  as are your `baseline.txt` and reports. Never share those files.

## Pilot feedback 🙏

You're in a small pilot — please tell us how it went using the
**Pilot feedback** issue template on GitHub: how the install felt, whether
you actually read the morning report, and one thing that confused you.
That feedback decides whether this grows up into something IT rolls out
to everyone.
