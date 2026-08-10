#!/usr/bin/env python3
"""Build comb_teeth_up.html — resolve the "Underlined by the Comb" idea using the
solved geometry (letter-wide circles, equal margins, teeth-up comb) and answer:
  (1) the comb gray — how gray, and alternatives
  (2) all colour combinations — letter {ink|colour} x accent-tooth {gray|colour}
  (3) the tooth-height pattern — an irregular tachogram; principled laws
Then present my Top 1 & Top 2. Geometry from metrics_900.json (JuliaMono Black, em=1000)."""
import json, math, pathlib
H = pathlib.Path(__file__).resolve().parent
M = json.loads((H/"metrics_900.json").read_text())

cap = M['cap']; advC = M['advChar']; advW = M['advWidth']
wL, wR = M['wL'], M['wR']
Hc, Rc, Lc = M['H'], M['R'], M['L']
PU, GN, RD, BL, INK = "#9558B2", "#389826", "#CB3C33", "#4063D8", "#1b1b1f"

# ---- solved parameters (from the last run) ----
D   = 600.0; Rr = D/2          # circle = one letter wide
m   = 132.0                    # equal margin: letter<->circle == circle<->comb
tW  = 84.0                     # comb weight
cCy = m + Rr                   # circle centre (below baseline)
cFar = m + 2*Rr                # circle bottom
combNear = 2*m + 2*Rr          # tips of the TALLEST teeth = m below the circles (864)
maxTooth = 280.0               # tallest tooth length
spineY  = combNear + maxTooth  # comb spine, at the bottom (1144)  -> teeth point UP
spineX0, spineX1 = wL-40, wR+40
GRAY = "#8A8F98"               # the series-2 comb gray

CELLX = [i*advC + advC/2 for i in range(12)]
ACC = {0: PU, 5: RD, 9: GN}                       # accent (coloured) tooth indices
ACCX = {0: Hc, 5: Rc, 9: Lc}                      # accents ride the optical centres
def toothx(i): return ACCX.get(i, CELLX[i])

# ---------- tooth-height laws (return 12 lengths; accents forced to max) ----------
def heights(kind):
    L=[]
    for i in range(12):
        if kind=="flat":       h=150
        elif kind=="accent":   h=96
        elif kind=="tacho":    h=170+80*math.sin(i*0.9+0.5)+45*math.sin(i*2.3+1.1)
        elif kind=="rsa":      h=165+92*math.sin(i*0.8+0.3)
        else:                  h=150
        L.append(max(70,min(maxTooth-8,h)))
    for i in ACC: L[i]=maxTooth
    return L

# ---------- gray candidates ----------
def _lin(c): c/=255; return c/12.92 if c<=0.04045 else ((c+0.055)/1.055)**2.4
def lum(hx):
    r,g,b=(int(hx[i:i+2],16) for i in (1,3,5)); return 0.2126*_lin(r)+0.7152*_lin(g)+0.0722*_lin(b)
def contrast(hx,bg="#ffffff"):
    a,b=lum(hx),lum(bg); a,b=max(a,b),min(a,b); return (a+0.05)/(b+0.05)
GRAYS=[("#8A8F98","series-2 · cool"),("#98989E","neutral"),("#9C948C","warm"),("#B4B8BF","light · recessive")]

# ---------- SVG unit: letters, circles, teeth-up comb ----------
def word(letter_colored):
    if letter_colored:
        return ('<text x="0" y="0" font-family="JMBold,monospace" font-size="1000" fill="'+INK+'">'
                f'<tspan fill="{PU}">H</tspan>eart<tspan fill="{RD}">R</tspan>ate<tspan fill="{GN}">L</tspan>ab</text>')
    return '<text x="0" y="0" font-family="JMBold,monospace" font-size="1000" fill="'+INK+'">HeartRateLab</text>'

def unit(hs, gray=GRAY, letter_colored=False, accent_colored=True, rail=True):
    vbX=-40; vbW=advW+120; vbY=-cap-70; vbH=(spineY+90)-vbY
    S=[f'<svg class="unit" viewBox="{vbX:.0f} {vbY:.0f} {vbW:.0f} {vbH:.0f}">']
    S.append(f'<g>{word(letter_colored)}</g>')
    if rail:
        S.append(f'<line x1="{spineX0:.0f}" y1="{spineY:.0f}" x2="{spineX1:.0f}" y2="{spineY:.0f}" stroke="{gray}" stroke-width="{tW}" stroke-linecap="round"/>')
    for i in range(12):
        x=toothx(i); tip=spineY-hs[i]
        col = (ACC[i] if accent_colored else gray) if i in ACC else gray
        w = tW if i in ACC else tW*0.72
        S.append(f'<line x1="{x:.0f}" y1="{spineY:.0f}" x2="{x:.0f}" y2="{tip:.0f}" stroke="{col}" stroke-width="{w:.0f}" stroke-linecap="round"/>')
    for i,col in ACC.items():                          # the letter-wide Julia circles
        S.append(f'<circle cx="{ACCX[i]:.0f}" cy="{cCy:.0f}" r="{Rr:.0f}" fill="{col}"/>')
    S.append('</svg>')
    return "".join(S)

# ---------- reference: the original series-2 lock-04, inline ----------
LOCK04 = (H.parent/"series2"/"lockups"/"lock-04.svg").read_text()

# ---------- gallery pieces ----------
def gray_row():
    out=[]
    for hx,nm in GRAYS:
        out.append(f'<div class="gcell"><div class="sw" style="background:{hx}"></div>'
                   f'<div class="gk mono">{hx}</div><div class="gn">{nm}</div>'
                   f'<div class="gn">L {lum(hx):.2f} · {contrast(hx):.1f}:1 on white</div>'
                   f'<div class="mini">{unit(heights("tacho"), gray=hx, accent_colored=True)}</div></div>')
    return "\n".join(out)

def combo_matrix():
    cells=[]
    for lc,lname in [(False,"ink letters"),(True,"coloured letters")]:
        for ac,aname in [(False,"gray accent tooth"),(True,"coloured accent tooth")]:
            cells.append(f'<div class="mcell"><div class="cap mono">{lname} · {aname}</div>'
                         f'{unit(heights("tacho"), letter_colored=lc, accent_colored=ac)}</div>')
    return "\n".join(cells)

def pattern_gallery():
    labels=[("flat","Flat","every gray tick equal — a plain rule; the three accents still lead."),
            ("accent","Accent-only","gray ticks short & uniform, accents tall — maximum hierarchy, minimum noise."),
            ("rsa","RSA sine","heights follow a smooth sine — respiratory sinus arrhythmia, HR rising & falling with the breath."),
            ("tacho","Tachogram","heights = successive inter-beat intervals (HF+LF) — irregular; the variation IS the HRV.")]
    out=[]
    for k,t,d in labels:
        out.append(f'<div class="pcell"><div class="cap mono">{t}</div>'
                   f'{unit(heights(k), accent_colored=True)}<p class="pd">{d}</p></div>')
    return "\n".join(out)

# ---------- top picks ----------
TOP1 = unit(heights("tacho"), gray="#8A8F98", letter_colored=False, accent_colored=True)
TOP2 = unit(heights("accent"), gray="#9AA0A6", letter_colored=True, accent_colored=True)

PARAMS=[
 ("Circle Ø","600","one letter wide (advance · 0.82 cap)"),
 ("Margin m","132","letter↔circle = circle↔comb (0.18 cap)"),
 ("Tallest tooth","280","accents; tip = m below its circle"),
 ("Comb weight","84 / 60","spine & accent / gray teeth"),
 ("Tick spacing","600","one per letter (12)"),
 ("Comb gray","#8A8F98","cool blue-gray, 3.3:1 on white"),
]
def params_html():
    return "\n".join(f'<div class="prow"><span class="pk">{k}</span><span class="pv mono">{v}</span><span class="pn">{n}</span></div>' for k,v,n in PARAMS)

TPL = r"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeartRateLab · The Comb, resolved (teeth up)</title>
<style>
@font-face{font-family:JMBold;src:local('JuliaMono Black'),url('fonts/JuliaMono-Black.ttf')}
:root{--pu:#9558B2;--gn:#389826;--rd:#CB3C33;--bl:#4063D8;--ink:#1b1b1f;--mut:#6b7280;
--bg:#fbfbfd;--card:#fff;--line:#e7e8ee;--soft:#f3f4f8}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:1120px;margin:0 auto;padding:0 24px}
.mono{font-family:JMBold,ui-monospace,monospace}
code{font-family:JMBold,monospace}
.kick{font-family:JMBold,monospace;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--pu)}
h1{font-size:clamp(28px,5vw,48px);margin:.15em 0 .1em;letter-spacing:-.02em}
h2{font-size:24px;margin:.1em 0 .3em}
.lead{font-size:18px;color:#3b3f46;max-width:820px}
.hero{padding:52px 0 10px}
.dots{display:flex;gap:9px;margin-bottom:16px}.dots i{width:24px;height:24px;border-radius:50%}
.dots i:nth-child(1){background:var(--pu)}.dots i:nth-child(2){background:var(--rd)}.dots i:nth-child(3){background:var(--gn)}
section{padding:34px 0;border-top:1px solid var(--line)}
.tag{font-family:JMBold,monospace;font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--mut)}
.hint{font-size:14px;color:var(--mut);margin:.2em 0 14px}
svg.unit{width:100%;height:auto;display:block}
.frame{background:#f7f7f9;border:1px solid var(--line);border-radius:16px;padding:18px 20px}
.herobox{background:#fff;border:1px solid var(--line);border-radius:20px;padding:26px 28px;box-shadow:0 12px 40px rgba(20,20,40,.05)}
.answer{background:var(--soft);border-left:4px solid var(--pu);border-radius:0 10px 10px 0;padding:12px 16px;margin:14px 0;font-size:15px}
.answer b{color:var(--pu)}
/* gray row */
.grays{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-top:14px}
.gcell{border:1px solid var(--line);border-radius:12px;padding:12px;background:var(--card)}
.sw{height:44px;border-radius:8px;border:1px solid rgba(0,0,0,.08)}
.gk{margin-top:8px;font-size:14px}.gn{font-size:12px;color:var(--mut)}
.mini{margin-top:8px;background:#fafafb;border-radius:8px;padding:6px}
/* combo matrix */
.matrix{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:14px}
.mcell{border:1px solid var(--line);border-radius:14px;padding:14px 16px;background:var(--card)}
.cap{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--mut);margin-bottom:8px}
/* patterns */
.patterns{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:14px}
.pcell{border:1px solid var(--line);border-radius:14px;padding:14px 16px;background:var(--card)}
.pd{font-size:14px;color:#4b5563;margin:.5em 0 0}
/* tops */
.tops{display:grid;grid-template-columns:1fr;gap:18px;margin-top:8px}
.top{border:1px solid var(--line);border-radius:18px;padding:20px 22px;background:var(--card)}
.top h3{margin:.1em 0 .1em;font-size:20px}
.badge{display:inline-block;font-family:JMBold,monospace;font-size:12px;padding:3px 10px;border-radius:999px;color:#fff;margin-right:8px}
.b1{background:var(--pu)}.b2{background:var(--gn)}
.rat{font-size:15px;color:#3b3f46;margin:.4em 0 0}
/* params + tables */
.props{margin-top:12px;border:1px solid var(--line);border-radius:12px;overflow:hidden;background:var(--card)}
.prow{display:grid;grid-template-columns:150px 110px 1fr;gap:10px;padding:9px 16px;border-bottom:1px solid var(--line);font-size:14px}
.prow:last-child{border-bottom:0}.pk{color:#374151}.pv{color:var(--rd)}.pn{color:var(--mut)}
.htab{width:100%;border-collapse:collapse;margin-top:12px;font-size:13px;font-family:JMBold,monospace}
.htab td{border:1px solid var(--line);padding:5px 7px;text-align:center}.htab .hh{color:var(--mut)}
.ref{max-width:560px;background:#fff;border:1px solid var(--line);border-radius:12px;padding:10px}
footer{padding:26px 0 60px;color:var(--mut);font-size:13px;border-top:1px solid var(--line)}
@media(max-width:820px){.grays{grid-template-columns:1fr 1fr}.matrix,.patterns{grid-template-columns:1fr}.prow{grid-template-columns:1fr 90px;grid-auto-flow:row}.pn{grid-column:1/-1}}
</style></head>
<body>
<div class="wrap">
<header class="hero">
  <div class="dots"><i></i><i></i><i></i></div>
  <div class="kick">HeartRateLab · Comb resolved · teeth up</div>
  <h1>Underlined by the Comb</h1>
  <p class="lead">The two top picks fused — the <b>Triad dots</b> (letter-wide Julia circles) sitting over the
  <b>IBI comb</b> (teeth up) — rebuilt with every parameter we solved: Ø 600 circles, equal <code>m = 132</code>
  margins, optical centres, <b>JuliaMono&nbsp;Black</b>. Below: the comb gray, all colour combinations, and a
  principled tooth-height pattern.</p>
  <div class="herobox">@TOP1@</div>
</header>

<section>
  <div class="tag">01 · The comb gray</div>
  <h2>How gray is it?</h2>
  <p class="lead" style="font-size:17px">The series-2 comb teeth are <code>#8A8F98</code> — a <b>cool blue-gray</b>
  (RGB 138·143·152), luminance 0.27, about <b>3.3 : 1</b> on white. Deliberately recessive: the comb
  <i>underlines</i>, it doesn't compete with the word or the dots. Alternatives, each on the tachogram comb:</p>
  <div class="grays">@GRAYS@</div>
  <p class="hint">Cooler grays read technical/instrument; warmer grays read organic. The accents stay the three Julia hues regardless.</p>
</section>

<section>
  <div class="tag">02 · Colour combinations</div>
  <h2>Where the colour goes — every combination</h2>
  <p class="lead" style="font-size:17px">In the original, only the <b>accent tooth + ball</b> carry colour; the
  letters stay ink. Two independent switches — <b>letter</b> {ink · coloured} and <b>accent tooth</b> {gray ·
  coloured} — give four marks (the letter-wide circle stays the Julia anchor in all):</p>
  <div class="matrix">@MATRIX@</div>
  <p class="hint">Colouring both letters and teeth doubles the colour and can feel loud; ink letters + coloured teeth keeps the word calm and lets the triad lead.</p>
</section>

<section>
  <div class="tag">03 · Tooth-height pattern</div>
  <h2>Why are the teeth uneven? — it's a tachogram</h2>
  <p class="lead" style="font-size:17px">In the original the heights are hand-set and irregular. Measured, the three
  <b>coloured</b> teeth are the tallest (34·32·34) and the grays wander 12–28. Read correctly, the tick heights are
  successive <b>inter-beat intervals</b> — their unevenness <i>is</i> the HRV the package measures. Four principled laws:</p>
  <div class="ref">@LOCK04@<div class="cap mono" style="margin-top:6px">original series-2 lock-04 (Arial, small balls)</div></div>
  <table class="htab"><tr><td class="hh">x</td><td>100</td><td>140</td><td>175</td><td style="color:#9558B2">215</td><td>250</td><td>285</td><td>320</td><td style="color:#CB3C33">355</td><td>390</td><td>425</td><td>460</td><td style="color:#389826">495</td><td>530</td></tr>
  <tr><td class="hh">h</td><td>14</td><td>24</td><td>12</td><td style="color:#9558B2">34</td><td>18</td><td>26</td><td>14</td><td style="color:#CB3C33">32</td><td>20</td><td>15</td><td>28</td><td style="color:#389826">34</td><td>16</td></tr></table>
  <div class="patterns">@PATTERNS@</div>
</section>

<section>
  <div class="tag">04 · My picks</div>
  <h2>Top 1 &amp; Top 2</h2>
  <div class="tops">
    <div class="top"><h3><span class="badge b1">TOP 1</span>The honest tachogram</h3>
      <p class="rat">Ink letters · coloured accent teeth + Julia circles · <b>tachogram</b> gray comb (<code>#8A8F98</code>).
      The word stays calm, the triad leads, and the uneven gray teeth quietly encode HRV — the most on-brand for an
      HRV package, and it degrades to a clean underline at tiny sizes.</p>
      <div class="frame" style="margin-top:12px">@TOP1b@</div></div>
    <div class="top"><h3><span class="badge b2">TOP 2</span>The bold triad</h3>
      <p class="rat">Coloured letters + coloured accents · <b>accent-only</b> heights (short uniform grays) with a lighter
      gray (<code>#9AA0A6</code>). Maximum colour and hierarchy, minimum noise — reads loud and confident at poster
      scale, though busier in body text.</p>
      <div class="frame" style="margin-top:12px">@TOP2@</div></div>
  </div>
  <div class="props">@PARAMS@</div>
</section>

<footer>
  Measured from JuliaMono Black (em 1000) · geometry regenerates from <code>metrics_900.json</code> via
  <code>build_comb2.py</code> · gray #8A8F98 · Julia palette #9558B2 #CB3C33 #389826 · self-contained (font in <code>fonts/</code>).
</footer>
</div>
</body></html>"""

html=(TPL.replace("@TOP1@",TOP1).replace("@TOP1b@",TOP1).replace("@TOP2@",TOP2)
        .replace("@GRAYS@",gray_row()).replace("@MATRIX@",combo_matrix())
        .replace("@PATTERNS@",pattern_gallery()).replace("@LOCK04@",LOCK04)
        .replace("@PARAMS@",params_html()))
(H/"comb_teeth_up.html").write_text(html)
print("wrote comb_teeth_up.html")
