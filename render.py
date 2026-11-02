#!/usr/bin/env python3
"""render.py in.md out.html — Mac Assurance report, ocean/kelp palette (stdlib only).
Brand: Atlantic peak #0B3C5D, kelp wave #1F7A5C (brand/README.md)."""
import html, re, sys

src, dst = sys.argv[1], sys.argv[2]
raw = open(src, encoding="utf-8", errors="replace").read()
lines = raw.splitlines()

counts = {"PASS": 0, "WARN": 0, "FAIL": 0, "UNKNOWN": 0}
m = re.findall(r"PASS=(\d+) WARN=(\d+) FAIL=(\d+) UNKNOWN=(\d+)", raw)
if m:
    counts = dict(zip(counts, (int(x) for x in m[-1])))
changed = "CHANGES vs baseline" in raw
if counts["FAIL"]:
    verdict, vcls = "❌ Attention needed — contact IT", "v-fail"
elif changed:
    verdict, vcls = "⚠️ New or removed items — review the Baseline Diff", "v-warn"
else:
    verdict, vcls = "✅ All clear — no unexplained changes", "v-pass"

title = lines[0].lstrip("# ") if lines else "Mac Assurance Audit"
host = next((ln for ln in lines if ln.startswith("Host:")), "")

def render_lines(ls):
    out = []
    for ln in ls:
        e = html.escape(ln)
        cls = ("fail" if "❌" in ln else "warn" if "⚠️" in ln else "pass" if "✅" in ln
               else "unkn" if "❓" in ln else "why" if ln.strip().startswith("↳") else "")
        out.append(f'<p class="{cls}">{e}</p>' if cls else (f"<p>{e}</p>" if ln.strip() else ""))
    return "\n".join(out)

sections, cur, buf = [], None, []
for ln in lines[1:]:
    if ln.startswith("## "):
        if cur is not None: sections.append((cur, buf))
        cur, buf = ln[3:], []
    elif cur is not None:
        buf.append(ln)
if cur is not None: sections.append((cur, buf))

cards = "".join(
    f'<div class="stat-card {k.lower()}"><div class="num">{v}</div><div class="lbl">{k}</div></div>'
    for k, v in counts.items())
body = "\n".join(
    f'<section class="card"><h2>{html.escape(t)}</h2>{render_lines(b)}</section>'
    for t, b in sections)

doc = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title><style>
*{{box-sizing:border-box}}body{{margin:0;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;background:#eef3f6;color:#16232b;line-height:1.5}}
.hero{{background:linear-gradient(120deg,#0B3C5D 55%,#1F7A5C);color:#fff;padding:2.2em 1.2em 1.6em}}
.wrap{{max-width:880px;margin:0 auto;padding:0 1em}}
.hero h1{{margin:0;font-size:1.65em;letter-spacing:.2px}}.hero .host{{opacity:.85;margin-top:.35em;font-size:.95em}}
.hero .brand{{font-size:.8em;text-transform:uppercase;letter-spacing:.18em;opacity:.75}}
.verdict{{max-width:880px;margin:-1.1em auto 0;padding:0 1em}}
.verdict div{{border-radius:12px;padding:.85em 1.1em;font-weight:600;box-shadow:0 4px 18px rgba(11,60,93,.18);background:#fff}}
.v-pass{{border-left:6px solid #1F7A5C}}.v-warn{{border-left:6px solid #d9930d}}.v-fail{{border-left:6px solid #c0392b}}
.stats{{display:grid;grid-template-columns:repeat(4,1fr);gap:.7em;max-width:880px;margin:1em auto 0;padding:0 1em}}
.stat-card{{background:#fff;border-radius:12px;padding:.9em .5em;text-align:center;box-shadow:0 2px 10px rgba(11,60,93,.10)}}
.stat-card .num{{font-size:1.9em;font-weight:700}}.stat-card .lbl{{font-size:.75em;letter-spacing:.14em;color:#5a6b74}}
.stat-card.pass .num{{color:#1F7A5C}}.stat-card.warn .num{{color:#d9930d}}.stat-card.fail .num{{color:#c0392b}}.stat-card.unknown .num{{color:#607d8b}}
main{{max-width:880px;margin:1em auto 2em;padding:0 1em}}
.card{{background:#fff;border-radius:12px;padding:1em 1.2em;margin-bottom:.9em;box-shadow:0 2px 10px rgba(11,60,93,.08)}}
.card h2{{margin:.1em 0 .6em;font-size:1.08em;color:#0B3C5D}}
.card p{{margin:.28em 0}}.warn{{background:#fff7e0;border-radius:6px;padding:.25em .55em}}
.fail{{background:#fdecea;border-radius:6px;padding:.25em .55em}}.unkn{{background:#eceff1;border-radius:6px;padding:.25em .55em}}
.why{{color:#5a6b74;font-size:.92em;margin-left:1em}}
footer{{text-align:center;color:#7a8a92;font-size:.85em;padding:0 1em 2.2em}}
@media(max-width:640px){{.stats{{grid-template-columns:repeat(2,1fr)}}}}
@media print{{body{{background:#fff}}.card,.stat-card,.verdict div{{box-shadow:none}}}}
</style></head><body>
<header class="hero"><div class="wrap"><div class="brand">Mac Assurance</div>
<h1>{html.escape(title)}</h1><div class="host">{html.escape(host)}</div></div></header>
<div class="verdict"><div class="{vcls}">{verdict}</div></div>
<div class="stats">{cards}</div>
<main>{body}</main>
<footer>Read-only audit · ESET / Netskope / Kandji observed, never altered · Baseline diff is the detector: a change you can't explain is the finding.</footer>
</body></html>"""
open(dst, "w", encoding="utf-8").write(doc)
