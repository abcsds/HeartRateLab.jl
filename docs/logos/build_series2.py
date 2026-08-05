#!/usr/bin/env python3
"""Build docs/series2.html — the focused IBI-first logo run.
Reads logos/series2/manifest2.json; inlines each SVG; stages size to each art's
own viewBox aspect. Highlights the orchestrator's Top-3 at the top."""
import json, re, html, pathlib, os

HERE = pathlib.Path(__file__).resolve().parent          # docs/logos
DOCS = HERE.parent                                       # docs
S2   = HERE / "series2"
MAN  = S2 / "manifest2.json"
OUT  = DOCS / "series2.html"

GROUPS = [
    ("icons",  "IBI-Comb icons",
     "Ten evolutions of the inter-beat-interval comb — beat events as ticks, the "
     "unequal gaps as variability. Icon-only, three Julia dots."),
    ("lockups","Triad + name lockups",
     "Ten logo-next-to-name lockups. The ECG spike is gone; the mark reads as beat "
     "events on a timeline, in IBI vocabulary, beside the HeartRateLab wordmark."),
    ("combos", "Comb × wordmark combinations",
     "Ten fusions where the IBI comb and the wordmark become one integrated mark."),
]

def strip(svg):
    svg = re.sub(r"<\?xml.*?\?>", "", svg, flags=re.S)
    svg = re.sub(r"<!DOCTYPE.*?>", "", svg, flags=re.S)
    return svg.strip()

def aspect(svg):
    m = re.search(r'viewBox="[\d.]+ [\d.]+ ([\d.]+) ([\d.]+)"', svg)
    if not m: return 1.0
    return float(m.group(1)) / float(m.group(2))

def badge(t, cls=""):
    return f'<span class="badge {cls}">{html.escape(t)}</span>'

def card(e, big=False):
    p = S2 / e["file"]
    svg = strip(p.read_text()) if p.exists() else '<svg viewBox="0 0 10 10"></svg>'
    ar = aspect(svg)
    rel = os.path.relpath(p, DOCS)
    wm = e.get("wordmark", "icon-only")
    badges = badge(e.get("motif","—"),"motif")+badge(e.get("register","—"),"register")+\
             badge(wm,"wm"+(" text" if "text" in wm else ""))
    tag = f'<span class="rank">★ Top {e["top3"]}</span>' if e.get("top3") else ""
    reason = f'<p class="pick"><strong>Why I pick it:</strong> {html.escape(e["top3_reason"])}</p>' if e.get("top3_reason") and big else ""
    stage_ar = f"{ar:.3f}"
    return f'''<figure class="card{' big' if big else ''}">
  <div class="stage" style="aspect-ratio:{stage_ar}">{svg}</div>
  <figcaption>
    <div class="cap-head"><h3>{html.escape(e.get("title","Untitled"))}</h3>{tag}</div>
    <code class="id">{html.escape(e["id"])}</code>
    <div class="badges">{badges}</div>
    <p class="concept">{html.escape(e.get("concept",""))}</p>
    <p class="why"><strong>Why:</strong> {html.escape(e.get("why",""))}</p>
    <p class="risk"><strong>Risk:</strong> {html.escape(e.get("risk",""))}</p>
    {reason}
    <a class="dl" href="{html.escape(rel)}" download>↓ SVG</a>
  </figcaption>
</figure>'''

def main():
    E = json.loads(MAN.read_text())
    by = {g[0]: [] for g in GROUPS}
    for e in E: by[e["group"]].append(e)
    for k in by: by[k].sort(key=lambda e:(e.get("rank") or 999))

    top = sorted([e for e in E if e.get("top3")], key=lambda e:e["top3"])
    top_html = "\n".join(card(e, big=True) for e in top)

    secs = []
    for gid, name, desc in GROUPS:
        cards = "\n".join(card(e) for e in by[gid])
        secs.append(f'''<section id="g-{gid}">
  <div class="sec-head"><h2>{html.escape(name)}</h2><p>{html.escape(desc)}</p>
    <span class="count">{len(by[gid])} logos</span></div>
  <div class="grid">{cards}</div></section>''')

    OUT.write_text(TPL.replace("__TOP__", top_html).replace("__BODY__","\n".join(secs))
                       .replace("__N__", str(len(E))))
    print(f"Wrote {OUT} with {len(E)} logos; {len(top)} top picks.")

TPL = r"""<!doctype html>
<html lang="en" data-theme="light">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeartRateLab.jl — IBI-First Logo Run</title>
<style>
:root{--pt:#9558B2;--gn:#389826;--rd:#CB3C33;--bl:#4063D8;
  --bg:#f6f6f8;--fg:#1a1a1e;--muted:#6a6a76;--card:#fff;--line:#e6e6ec;--stage:#ececf1;
  --shadow:0 1px 3px rgba(0,0,0,.08),0 8px 24px rgba(0,0,0,.06);}
html[data-theme=dark]{--bg:#141418;--fg:#ececf1;--muted:#9a9aa8;--card:#1d1d23;
  --line:#2a2a33;--stage:#26262e;--shadow:0 1px 3px rgba(0,0,0,.4),0 8px 24px rgba(0,0,0,.35);}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
  font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
a{color:var(--bl)}
.toggle{position:fixed;top:16px;right:16px;z-index:9;background:var(--card);border:1px solid var(--line);
  border-radius:999px;padding:8px 14px;cursor:pointer;font-size:13px;color:var(--fg);box-shadow:var(--shadow)}
header.hero{padding:60px 24px 26px;max-width:1180px;margin:0 auto}
.brandline{display:flex;gap:6px;margin-bottom:18px}
.brandline i{width:24px;height:24px;border-radius:50%;display:block}
.brandline i:nth-child(1){background:var(--pt)}.brandline i:nth-child(2){background:var(--rd)}
.brandline i:nth-child(3){background:var(--gn)}
h1{font-size:clamp(28px,4.5vw,44px);margin:.1em 0;letter-spacing:-.02em}
.sub{color:var(--muted);font-size:18px;max-width:780px}
.meta{margin-top:18px;display:flex;flex-wrap:wrap;gap:10px}
.chip{background:var(--card);border:1px solid var(--line);border-radius:999px;padding:6px 14px;font-size:13px;color:var(--muted)}
.chip b{color:var(--fg)}
main{max-width:1180px;margin:0 auto;padding:0 24px 80px}
.topwrap{margin:22px 0 10px;padding:22px;border:1px solid var(--line);border-radius:18px;
  background:linear-gradient(180deg,color-mix(in srgb,var(--pt) 7%,var(--card)),var(--card))}
.topwrap h2{margin:0 0 4px;font-size:22px}
.topwrap>p{margin:0 0 16px;color:var(--muted);max-width:760px}
.topgrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:18px}
section{padding-top:40px}
.sec-head{border-left:4px solid var(--pt);padding:2px 0 2px 15px;margin:18px 0 18px;position:relative}
#g-lockups .sec-head{border-color:var(--rd)}#g-combos .sec-head{border-color:var(--gn)}
.sec-head h2{font-size:25px;margin:.1em 0}.sec-head p{color:var(--muted);margin:.2em 0 0;max-width:720px}
.sec-head .count{position:absolute;right:0;top:4px;color:var(--muted);font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:18px}
.card{margin:0;background:var(--card);border:1px solid var(--line);border-radius:15px;overflow:hidden;
  box-shadow:var(--shadow);display:flex;flex-direction:column}
.card.big{border-color:color-mix(in srgb,var(--pt) 45%,var(--line))}
.stage{background:var(--stage);width:100%;display:flex;align-items:center;justify-content:center;padding:24px;min-height:150px}
.stage svg{width:100%;height:100%;max-height:220px;display:block}
figcaption{padding:15px 17px 17px;display:flex;flex-direction:column;gap:7px}
.cap-head{display:flex;align-items:baseline;justify-content:space-between;gap:8px}
.cap-head h3{margin:0;font-size:17px}
.rank{font-size:12px;font-weight:700;color:#fff;background:var(--pt);border-radius:999px;padding:2px 10px;white-space:nowrap}
.id{color:var(--muted);font-size:12px}
.badges{display:flex;flex-wrap:wrap;gap:6px}
.badge{font-size:11px;padding:3px 9px;border-radius:999px;border:1px solid var(--line);color:var(--muted)}
.badge.motif{border-color:var(--bl);color:var(--bl)}.badge.wm.text{border-color:var(--gn);color:var(--gn)}
.concept{margin:2px 0;font-size:14px}.why,.risk{margin:0;font-size:13px;color:var(--muted)}
.why strong{color:var(--gn)}.risk strong{color:var(--rd)}
.pick{margin:4px 0 0;font-size:13.5px;background:color-mix(in srgb,var(--pt) 8%,transparent);
  border:1px solid var(--line);border-radius:10px;padding:8px 10px}
.pick strong{color:var(--pt)}
.dl{margin-top:4px;font-size:13px;text-decoration:none;color:var(--muted);border:1px solid var(--line);
  border-radius:8px;padding:5px 10px;align-self:flex-start}.dl:hover{color:var(--bl);border-color:var(--bl)}
footer{max-width:1180px;margin:0 auto;padding:0 24px 60px;color:var(--muted);font-size:13px}
</style></head>
<body>
<button class="toggle" onclick="var h=document.documentElement;h.dataset.theme=h.dataset.theme==='dark'?'light':'dark'">◐ theme</button>
<header class="hero">
  <div class="brandline"><i></i><i></i><i></i></div>
  <h1>HeartRateLab.jl — IBI-First Logo Run</h1>
  <p class="sub">A focused second pass on the two chosen marks — the <em>IBI Comb</em>
  and the <em>Triad + name lockup</em> — honouring the package's real signal:
  <strong>inter-beat intervals</strong>, not ECG. __N__ new designs.</p>
  <div class="meta">
    <span class="chip"><b>Rule</b> IBI vocabulary only — no ECG/QRS</span>
    <span class="chip"><b>Keep</b> three Julia dots · logo + wordmark lockup</span>
    <span class="chip"><b>Format</b> hand-built SVG</span>
  </div>
</header>
<main>
  <div class="topwrap">
    <h2>★ My top 3</h2>
    <p>Given everything so far — the IBI focus, the lockup you liked, and legibility
    from favicon to README header — these are the three I'd move forward with.</p>
    <div class="topgrid">__TOP__</div>
  </div>
__BODY__
</main>
<footer>Focused run #2 for HeartRateLab.jl. All raw attempts kept under
<code>docs/logos/series2/</code>. Julia palette: purple #9558B2 · green #389826 · red #CB3C33 · blue #4063D8.</footer>
</body></html>"""

if __name__ == "__main__":
    main()
