#!/usr/bin/env python3
"""Build docs/series3.html — the typography-driven, animation-ready logo run."""
import json, re, html, pathlib, os
HERE = pathlib.Path(__file__).resolve().parent   # docs/logos/series3
DOCS = HERE.parent.parent                          # docs
MAN  = HERE / "manifest3.json"
OUT  = DOCS / "series3.html"

GROUPS = [
    ("wordmark","HeartRateLab wordmark systems",
     "The full wordmark in JuliaMono Bold — H·R·L tinted as the three syllable onsets. "
     "The comb is 12 equal time-ticks (one per letter); the three beats land on H·R·L at a real 5:4 interval."),
    ("hrl","HRL monogram & round versions",
     "The compact three-letter mark and the circular 'folded' logo — the round emblem is built to unroll into the linear wordmark."),
    ("combos","Lockups & combinations",
     "Stacked, measured, minimal and emblem lockups — series-2 ideas re-fitted to the measured metrics, plus new ones."),
]
DOTPOS = {"above":"dots above","below":"comb below","ring":"round"}

def strip(s):
    s = re.sub(r"<\?xml.*?\?>","",s,flags=re.S); return re.sub(r"<!DOCTYPE.*?>","",s,flags=re.S).strip()
def aspect(s):
    m = re.search(r'viewBox="(-?[\d.]+) (-?[\d.]+) ([\d.]+) ([\d.]+)"', s)
    return float(m.group(3))/float(m.group(4)) if m else 1.0
def badge(t,cls=""): return f'<span class="badge {cls}">{html.escape(t)}</span>'

def card(e, big=False):
    p = HERE/e["file"]; svg = strip(p.read_text()) if p.exists() else ""
    ar = aspect(svg); rel = os.path.relpath(p, DOCS)
    tag = f'<span class="rank">★ Top {e["top3"]}</span>' if e.get("top3") else ""
    reason = f'<p class="pick"><strong>Why I pick it:</strong> {html.escape(e["top3_reason"])}</p>' if (big and e.get("top3_reason")) else ""
    notes = (f'<dl class="notes">'
             f'<dt>⚑ animation</dt><dd>{html.escape(e["anim"])}</dd>'
             f'<dt>⎙ print</dt><dd>{html.escape(e["prints"])}</dd>'
             f'<dt>◑ colour</dt><dd>{html.escape(e["color"])}</dd></dl>')
    badges = badge(DOTPOS.get(e["dot_pos"],e["dot_pos"]),"pos")+badge(e["group"],"grp")
    return f'''<figure class="card{' big' if big else ''}">
  <div class="stage" style="aspect-ratio:{ar:.3f}">{svg}</div>
  <figcaption>
    <div class="cap-head"><h3>{html.escape(e["title"])}</h3>{tag}</div>
    <code class="id">{html.escape(e["id"])}</code>
    <div class="badges">{badges}</div>
    <p class="concept">{html.escape(e["concept"])}</p>
    <p class="why"><strong>Why:</strong> {html.escape(e["why"])}</p>
    <p class="risk"><strong>Watch:</strong> {html.escape(e["risk"])}</p>
    {reason}{notes}
    <a class="dl" href="{html.escape(rel)}" download>↓ SVG</a>
  </figcaption></figure>'''

def main():
    E = json.loads(MAN.read_text())
    by = {g[0]:[] for g in GROUPS}
    for e in E: by[e["group"]].append(e)
    for k in by: by[k].sort(key=lambda e:e.get("rank",99))
    top = sorted([e for e in E if e.get("top3")], key=lambda e:e["top3"])
    tophtml = "\n".join(card(e,big=True) for e in top)
    secs=[]
    for gid,name,desc in GROUPS:
        cards="\n".join(card(e) for e in by[gid])
        secs.append(f'<section id="g-{gid}"><div class="sec-head"><h2>{html.escape(name)}</h2>'
                    f'<p>{html.escape(desc)}</p><span class="count">{len(by[gid])}</span></div>'
                    f'<div class="grid">{cards}</div></section>')
    OUT.write_text(TPL.replace("__TOP__",tophtml).replace("__BODY__","\n".join(secs)).replace("__N__",str(len(E))))
    print("wrote",OUT,"with",len(E),"designs,",len(top),"top picks")

TPL = r"""<!doctype html><html lang="en" data-theme="light"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeartRateLab.jl — Series 3 (typography)</title>
<style>
@font-face{font-family:'JuliaMono';src:local('JuliaMono'),local('JuliaMono Bold'),
  url('logos/typography/fonts/JuliaMono-Bold.ttf') format('truetype');font-weight:700;font-style:normal;font-display:swap}
:root{--pt:#9558B2;--gn:#389826;--rd:#CB3C33;--bl:#4063D8;
  --bg:#f6f6f8;--fg:#1b1b1f;--muted:#6a6a76;--card:#fff;--line:#e6e6ec;--stage:#eceef2;
  --shadow:0 1px 3px rgba(0,0,0,.08),0 8px 24px rgba(0,0,0,.06)}
html[data-theme=dark]{--bg:#141418;--fg:#ececf1;--muted:#9a9aa8;--card:#1d1d23;--line:#2a2a33;
  --stage:#24242b;--shadow:0 1px 3px rgba(0,0,0,.4),0 8px 24px rgba(0,0,0,.35)}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);
  font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
a{color:var(--bl)}
.toggle{position:fixed;top:16px;right:16px;z-index:9;background:var(--card);border:1px solid var(--line);
  border-radius:999px;padding:8px 14px;cursor:pointer;font-size:13px;color:var(--fg);box-shadow:var(--shadow)}
header.hero{padding:60px 24px 24px;max-width:1200px;margin:0 auto}
.wm{font-family:'JuliaMono',monospace;font-weight:700;font-size:clamp(30px,6vw,58px);letter-spacing:-.01em;margin:0 0 6px}
.wm .h{color:var(--pt)}.wm .r{color:var(--rd)}.wm .l{color:var(--gn)}
h1sub{font-size:14px}
.sub{color:var(--muted);font-size:18px;max-width:820px}
.meta{margin-top:18px;display:flex;flex-wrap:wrap;gap:10px}
.chip{background:var(--card);border:1px solid var(--line);border-radius:999px;padding:6px 14px;font-size:13px;color:var(--muted)}
.chip b{color:var(--fg)}
main{max-width:1200px;margin:0 auto;padding:0 24px 80px}
.topwrap{margin:20px 0 8px;padding:22px;border:1px solid var(--line);border-radius:18px;
  background:linear-gradient(180deg,color-mix(in srgb,var(--pt) 7%,var(--card)),var(--card))}
.topwrap h2{margin:0 0 4px;font-size:22px}.topwrap>p{margin:0 0 16px;color:var(--muted);max-width:820px}
.topgrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:18px}
section{padding-top:40px}
.sec-head{border-left:4px solid var(--pt);padding:2px 0 2px 15px;margin:18px 0;position:relative}
#g-hrl .sec-head{border-color:var(--rd)}#g-combos .sec-head{border-color:var(--gn)}
.sec-head h2{font-size:24px;margin:.1em 0}.sec-head p{color:var(--muted);margin:.2em 0 0;max-width:820px}
.sec-head .count{position:absolute;right:0;top:4px;color:var(--muted);font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:18px}
.card{margin:0;background:var(--card);border:1px solid var(--line);border-radius:15px;overflow:hidden;
  box-shadow:var(--shadow);display:flex;flex-direction:column}
.card.big{border-color:color-mix(in srgb,var(--pt) 45%,var(--line))}
.stage{background:var(--stage);width:100%;display:flex;align-items:center;justify-content:center;padding:26px;min-height:150px}
.stage svg{width:100%;height:100%;max-height:210px;display:block}
figcaption{padding:15px 17px 17px;display:flex;flex-direction:column;gap:7px}
.cap-head{display:flex;align-items:baseline;justify-content:space-between;gap:8px}
.cap-head h3{margin:0;font-size:17px}
.rank{font-size:12px;font-weight:700;color:#fff;background:var(--pt);border-radius:999px;padding:2px 10px;white-space:nowrap}
.id{color:var(--muted);font-size:12px;font-family:'JuliaMono',monospace}
.badges{display:flex;flex-wrap:wrap;gap:6px}
.badge{font-size:11px;padding:3px 9px;border-radius:999px;border:1px solid var(--line);color:var(--muted)}
.badge.pos{border-color:var(--bl);color:var(--bl)}
.concept{margin:2px 0;font-size:14px}.why,.risk{margin:0;font-size:13px;color:var(--muted)}
.why strong{color:var(--gn)}.risk strong{color:var(--rd)}
.pick{margin:4px 0 0;font-size:13.5px;background:color-mix(in srgb,var(--pt) 8%,transparent);
  border:1px solid var(--line);border-radius:10px;padding:8px 10px}.pick strong{color:var(--pt)}
.notes{display:grid;grid-template-columns:auto 1fr;gap:2px 10px;margin:6px 0 0;font-size:12px;
  border-top:1px dashed var(--line);padding-top:8px}
.notes dt{color:var(--fg);font-weight:600;white-space:nowrap}.notes dd{margin:0;color:var(--muted)}
.dl{margin-top:6px;font-size:13px;text-decoration:none;color:var(--muted);border:1px solid var(--line);
  border-radius:8px;padding:5px 10px;align-self:flex-start}.dl:hover{color:var(--bl);border-color:var(--bl)}
footer{max-width:1200px;margin:0 auto;padding:0 24px 60px;color:var(--muted);font-size:13px}
footer code{font-family:'JuliaMono',monospace}
</style></head><body>
<button class="toggle" onclick="var h=document.documentElement;h.dataset.theme=h.dataset.theme==='dark'?'light':'dark'">◐ theme</button>
<header class="hero">
  <p class="wm"><span class="h">H</span>eart<span class="r">R</span>ate<span class="l">L</span>ab</p>
  <p class="sub">Series 3 — typography-driven. Every mark is set in <strong>JuliaMono Bold</strong> and
  positioned on the <em>measured</em> glyph metrics, so the geometry maps 1:1 onto the bounce animation.
  The 12 monospace letters are 12 equal time-ticks; the three beats land on <strong>H·R·L</strong> at a
  real <strong>5:4</strong> inter-beat interval — the name itself is an HRV trace. __N__ designs.</p>
  <div class="meta">
    <span class="chip"><b>Type</b> JuliaMono Bold · H·R·L tinted</span>
    <span class="chip"><b>Signal</b> IBI comb (equal ticks = time)</span>
    <span class="chip"><b>Motion</b> bounce-ready · apex ∝ distance²</span>
    <span class="chip"><b>Bars</b> dropped (per your note)</span>
  </div>
</header>
<main>
  <div class="topwrap"><h2>★ My top 3</h2>
    <p>Given the typography findings, the comb-at-bottom concept and the bounce you described — a wordmark
    logo, its compact monogram, and the signature treatment I'd build the animation on.</p>
    <div class="topgrid">__TOP__</div></div>
__BODY__
</main>
<footer>Series 3 for HeartRateLab.jl. Metrics from <code>logos/typography/full_metrics.json</code>;
guidelines in <code>logos/typography/GUIDELINES.md</code>. Text kept as live JuliaMono (not outlined) so
letter fills stay animatable. All raw SVGs under <code>logos/series3/svg/</code>. Bar/tachogram motifs dropped.</footer>
</body></html>"""

if __name__ == "__main__":
    main()
