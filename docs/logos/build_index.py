#!/usr/bin/env python3
"""Build docs/index.html — the HeartRateLab.jl logo showcase.

Reads logos/manifest.json (list of curated entries) and inlines each SVG into a
documented card, grouped by the three design directions. Self-contained output:
theme-aware, no external assets.
"""
import json, os, html, re, pathlib

HERE = pathlib.Path(__file__).resolve().parent            # docs/logos
DOCS = HERE.parent                                        # docs
MAN  = HERE / "manifest.json"
OUT  = DOCS / "index.html"

JULIA = {"purple": "#9558B2", "green": "#389826", "red": "#CB3C33", "blue": "#4063D8"}

DIRECTIONS = [
    ("A", "Julia-Native",
     "Every mark is unmistakably a Julia-family package logo: the three "
     "purple / green / red dots are always present, reinterpreted through HRV."),
    ("B", "HRV-First",
     "Heart-rate identity leads — ECG waveforms, Poincaré ellipses, phase-space "
     "attractors, pulse rings, abstract hearts — in the Julia palette, without "
     "forcing the three-dot arrangement."),
    ("C", "Hybrid / Fusion",
     "The Julia three-dot identity fused with HRV artifacts so both read at once, "
     "plus the wordmark / lockup explorations."),
]

def strip_svg(svg: str) -> str:
    """Strip XML prolog so the <svg> can be inlined; leave the element intact."""
    svg = re.sub(r"<\?xml.*?\?>", "", svg, flags=re.S)
    svg = re.sub(r"<!DOCTYPE.*?>", "", svg, flags=re.S)
    return svg.strip()

def badge(label, cls=""):
    return f'<span class="badge {cls}">{html.escape(label)}</span>'

def card(e):
    svg_path = HERE / e["file"]
    svg = strip_svg(svg_path.read_text()) if svg_path.exists() else \
          '<svg viewBox="0 0 320 320"><text x="160" y="160">missing</text></svg>'
    rel = os.path.relpath(svg_path, DOCS)
    wm = e.get("wordmark", "icon-only")
    wide = "wide" if e.get("wide") else ""
    badges = "".join([
        badge(e.get("motif", "—"), "motif"),
        badge(e.get("register", "—"), "register"),
        badge(wm, "wm" + (" text" if "text" in wm else "")),
    ])
    rank = e.get("rank")
    rankhtml = f'<span class="rank">#{rank}</span>' if rank else ""
    return f'''<figure class="card">
  <div class="stage {wide}">{svg}</div>
  <figcaption>
    <div class="cap-head"><h3>{html.escape(e.get("title","Untitled"))}</h3>{rankhtml}</div>
    <code class="id">{html.escape(e["id"])}</code>
    <div class="badges">{badges}</div>
    <p class="concept">{html.escape(e.get("concept",""))}</p>
    <p class="why"><strong>Why:</strong> {html.escape(e.get("why",""))}</p>
    <p class="risk"><strong>Risk:</strong> {html.escape(e.get("risk",""))}</p>
    <a class="dl" href="{html.escape(rel)}" download>↓ SVG</a>
  </figcaption>
</figure>'''

def main():
    entries = json.loads(MAN.read_text())
    by_dir = {"A": [], "B": [], "C": []}
    for e in entries:
        by_dir[e["direction"]].append(e)
    for k in by_dir:
        by_dir[k].sort(key=lambda e: (e.get("rank") or 999))

    sections = []
    for code, name, desc in DIRECTIONS:
        cards = "\n".join(card(e) for e in by_dir[code])
        sections.append(f'''<section id="dir-{code}">
  <div class="sec-head">
    <span class="sec-tag">Direction {code}</span>
    <h2>{html.escape(name)}</h2>
    <p>{html.escape(desc)}</p>
    <span class="count">{len(by_dir[code])} logos</span>
  </div>
  <div class="grid">{cards}</div>
</section>''')

    total = len(entries)
    body = "\n".join(sections)
    OUT.write_text(TEMPLATE.replace("__BODY__", body).replace("__TOTAL__", str(total)))
    print(f"Wrote {OUT} with {total} logos.")

TEMPLATE = r"""<!doctype html>
<html lang="en" data-theme="light">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeartRateLab.jl — Logo Explorations</title>
<style>
:root{
  --pt:#9558B2; --gn:#389826; --rd:#CB3C33; --bl:#4063D8;
  --bg:#f6f6f8; --fg:#1a1a1e; --muted:#6a6a76; --card:#ffffff; --line:#e6e6ec;
  --stage:#ececf1; --shadow:0 1px 3px rgba(0,0,0,.08),0 8px 24px rgba(0,0,0,.06);
}
html[data-theme=dark]{
  --bg:#141418; --fg:#ececf1; --muted:#9a9aa8; --card:#1d1d23; --line:#2a2a33;
  --stage:#26262e; --shadow:0 1px 3px rgba(0,0,0,.4),0 8px 24px rgba(0,0,0,.35);
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
  font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;}
a{color:var(--bl)}
header.hero{padding:64px 24px 40px;max-width:1200px;margin:0 auto;}
.brandline{display:flex;gap:6px;margin-bottom:20px}
.brandline i{width:26px;height:26px;border-radius:50%;display:block}
.brandline i:nth-child(1){background:var(--pt)}
.brandline i:nth-child(2){background:var(--rd)}
.brandline i:nth-child(3){background:var(--gn)}
h1{font-size:clamp(30px,5vw,48px);margin:.1em 0;letter-spacing:-.02em}
.sub{color:var(--muted);font-size:19px;max-width:760px}
.meta{margin-top:22px;display:flex;flex-wrap:wrap;gap:10px}
.chip{background:var(--card);border:1px solid var(--line);border-radius:999px;
  padding:6px 14px;font-size:13px;color:var(--muted)}
.chip b{color:var(--fg)}
.toggle{position:fixed;top:16px;right:16px;z-index:9;background:var(--card);
  border:1px solid var(--line);border-radius:999px;padding:8px 14px;cursor:pointer;
  font-size:13px;color:var(--fg);box-shadow:var(--shadow)}
nav.jump{position:sticky;top:0;z-index:8;background:color-mix(in srgb,var(--bg) 88%,transparent);
  backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:12px 24px}
nav.jump .in{max-width:1200px;margin:0 auto;display:flex;gap:8px;flex-wrap:wrap;align-items:center}
nav.jump a{padding:6px 14px;border-radius:999px;border:1px solid var(--line);
  text-decoration:none;color:var(--fg);font-size:14px;background:var(--card)}
nav.jump a:hover{border-color:var(--bl)}
main{max-width:1200px;margin:0 auto;padding:8px 24px 80px}
section{padding-top:44px}
.sec-head{border-left:4px solid var(--pt);padding:4px 0 4px 16px;margin:24px 0 20px;position:relative}
#dir-B .sec-head{border-color:var(--rd)} #dir-C .sec-head{border-color:var(--gn)}
.sec-tag{font-size:12px;text-transform:uppercase;letter-spacing:.14em;color:var(--muted);font-weight:700}
.sec-head h2{font-size:28px;margin:.15em 0}
.sec-head p{color:var(--muted);max-width:720px;margin:.2em 0 0}
.sec-head .count{position:absolute;right:0;top:6px;color:var(--muted);font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:20px}
.card{margin:0;background:var(--card);border:1px solid var(--line);border-radius:16px;
  overflow:hidden;box-shadow:var(--shadow);display:flex;flex-direction:column}
.stage{background:var(--stage);aspect-ratio:1/1;display:flex;align-items:center;justify-content:center;padding:26px}
.stage.wide{aspect-ratio:16/7}
.stage svg{width:100%;height:100%;max-height:230px;display:block}
figcaption{padding:16px 18px 18px;display:flex;flex-direction:column;gap:8px}
.cap-head{display:flex;align-items:baseline;justify-content:space-between;gap:8px}
.cap-head h3{margin:0;font-size:18px}
.rank{font-size:12px;font-weight:700;color:#fff;background:var(--pt);border-radius:999px;padding:2px 9px}
.id{color:var(--muted);font-size:12px}
.badges{display:flex;flex-wrap:wrap;gap:6px}
.badge{font-size:11px;padding:3px 9px;border-radius:999px;border:1px solid var(--line);color:var(--muted)}
.badge.motif{border-color:var(--bl);color:var(--bl)}
.badge.wm.text{border-color:var(--gn);color:var(--gn)}
.concept{margin:2px 0;font-size:14px}
.why,.risk{margin:0;font-size:13px;color:var(--muted)}
.why strong{color:var(--gn)} .risk strong{color:var(--rd)}
.dl{margin-top:4px;font-size:13px;text-decoration:none;color:var(--muted);
  border:1px solid var(--line);border-radius:8px;padding:5px 10px;align-self:flex-start}
.dl:hover{color:var(--bl);border-color:var(--bl)}
footer{max-width:1200px;margin:0 auto;padding:0 24px 60px;color:var(--muted);font-size:13px}
</style>
</head>
<body>
<button class="toggle" onclick="var h=document.documentElement;h.dataset.theme=h.dataset.theme==='dark'?'light':'dark'">◐ theme</button>
<header class="hero">
  <div class="brandline"><i></i><i></i><i></i></div>
  <h1>HeartRateLab.jl — Logo Explorations</h1>
  <p class="sub">__TOTAL__ curated logo concepts for the Julia heart-rate-variability
  package, across three design directions. Each mark aims to read as
  <em>heartbeat &amp; rhythm</em> and as a <em>Julia-ecosystem package</em> at a glance.</p>
  <div class="meta">
    <span class="chip"><b>Palette</b> Julia purple / green / red / blue</span>
    <span class="chip"><b>Format</b> hand-built SVG, favicon-safe</span>
    <span class="chip"><b>Method</b> 9 parallel studios → adversarial critique → curation</span>
  </div>
</header>
<nav class="jump"><div class="in">
  <strong style="font-size:14px">Jump:</strong>
  <a href="#dir-A">A · Julia-Native</a>
  <a href="#dir-B">B · HRV-First</a>
  <a href="#dir-C">C · Hybrid</a>
</div></nav>
<main>
__BODY__
</main>
<footer>
  Generated for HeartRateLab.jl. All raw exploration attempts are preserved under
  <code>docs/logos/</code>. Colors follow the official Julia brand palette.
</footer>
</body>
</html>"""

if __name__ == "__main__":
    main()
