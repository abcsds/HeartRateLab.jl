#!/usr/bin/env python3
"""Build comb_circles.html — a focused, interactive study of the IBI-Comb
wordmark. Fixed stack, top->bottom: LETTERS, then three Julia CIRCLES (each one
letter wide), then the COMB line — with EQUAL margins (letter<->circle ==
circle<->comb). The comb is always at the bottom; the two variants only flip the
comb's TEETH: up (pointing at the dots) or down (pointing away).
All geometry from full_metrics.json (measured JuliaMono Bold, em=1000)."""
import json, pathlib
H = pathlib.Path(__file__).resolve().parent
M = json.loads((H/"full_metrics.json").read_text())

cap = M['cap']; advC = M['advChar']; advW = M['advWidth']
wL, wR = M['wL'], M['wR']
Hc, Rc, Lc = M['H'], M['R'], M['L']
PU, GN, RD, BL, INK = "#9558B2", "#389826", "#CB3C33", "#4063D8", "#1b1b1f"
GOLD = "#b8860b"

# ---- the refined parameters --------------------------------------------------
D    = 600.0            # circle diameter  = one letter width (monospace advance)
Rr   = D/2             # circle radius
m    = 132.0           # EQUAL margin: letter<->circle  ==  circle<->combline (0.18*cap)
tick = 280.0           # comb tooth length
tW   = 84.0            # comb stroke weight (spine + teeth), chunky to match Bold

# fixed vertical stack, measured DOWN from the baseline (letter bottom = y 0):
Ledge = 0.0                    # letter bottom edge (baseline)
cNear = m                      # circle top edge      (margin m below the letters)
cCy   = m + Rr                 # circle centre
cFar  = m + 2*Rr               # circle bottom edge
combY = 2*m + 2*Rr             # comb spine           (margin m below the circles)

# comb teeth: one per letter cell; the H/R/L ones ride the optical centres & tint
TEETH = []
for i in range(12):
    if   i == 0: TEETH.append((Hc, PU))
    elif i == 5: TEETH.append((Rc, RD))
    elif i == 9: TEETH.append((Lc, GN))
    else:        TEETH.append((i*advC + advC/2, INK))
spineX0, spineX1 = wL-40, wR+40

# ---------- tiny SVG helpers (em space) ----------
def ln(x1,y1,x2,y2,c,w,d="",o=1):
    da = f' stroke-dasharray="{d}"' if d else ""
    return f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" stroke="{c}" stroke-width="{w}"{da} opacity="{o}"/>'
def tx(x,y,s,sz,c,a="start",w=400,ha=False):
    halo = ' paint-order="stroke" stroke="#fff" stroke-width="7"' if ha else ''
    return f'<text x="{x:.0f}" y="{y:.0f}" font-family="JMBold,monospace" font-size="{sz:.0f}" font-weight="{w}" fill="{c}" text-anchor="{a}"{halo}>{s}</text>'
def vcal(x,y1,y2,label,c):   # vertical caliper with end ticks + side label
    ymin,ymax=sorted((y1,y2))
    return (ln(x,ymin,x,ymax,c,7)+ln(x-44,ymin,x+44,ymin,c,7)+ln(x-44,ymax,x+44,ymax,c,7)+
            tx(x-58,(y1+y2)/2+24,label,72,c,"end",700,True))
def hcal(y,x1,x2,label,c):   # horizontal caliper
    return (ln(x1,y,x2,y,c,7)+ln(x1,y-38,x1,y+38,c,7)+ln(x2,y-38,x2,y+38,c,7)+
            tx((x1+x2)/2,y-30,label,72,c,"middle",700,True))
def word(colored=True):
    if colored:
        return ('<text x="0" y="0" font-family="JMBold,monospace" font-size="1000" fill="'+INK+'">'
                f'<tspan fill="{PU}">H</tspan>eart<tspan fill="{RD}">R</tspan>ate<tspan fill="{GN}">L</tspan>ab</text>')
    return '<text x="0" y="0" font-family="JMBold,monospace" font-size="1000" fill="'+INK+'">HeartRateLab</text>'

# ---------- one variant: teeth_dir = -1 (teeth up, at the dots) / +1 (teeth down) ----------
def variant(svgid, teeth_dir):
    # The comb band always sits m below the circles: its NEAR edge is combY (= cFar+m),
    # so the circle->comb gap is exactly m in BOTH variants (the explicit requirement).
    # Teeth-down puts the spine on the near edge and lets teeth fall away; teeth-up puts
    # the spine on the FAR edge (combFar) and lets teeth rise to stop m short of the dots.
    combFar = combY + tick
    if teeth_dir > 0:                       # teeth down: spine near, tips far
        spineY, tEnd = combY, combFar
    else:                                   # teeth up:   spine far, tips near
        spineY, tEnd = combFar, combY
    vbX = -620; vbW = advW + 1240
    vbY = -cap - 200
    bottomLimit = combFar + 250                          # room for the comb + label
    vbH = bottomLimit - vbY
    S=[f'<svg id="{svgid}" class="combfig" viewBox="{vbX:.0f} {vbY:.0f} {vbW:.0f} {vbH:.0f}">']

    # ============ BASE LOGO (always visible) ============
    S.append('<g class="base">')
    S.append(f'<g>{word(True)}</g>')                                  # the wordmark
    S.append(ln(spineX0,spineY,spineX1,spineY,INK,tW))               # comb spine
    for x,c in TEETH:                                                 # teeth
        S.append(ln(x,spineY,x,tEnd,c,tW))
    for x,c in [(Hc,PU),(Rc,RD),(Lc,GN)]:                            # the three circles, on top
        S.append(f'<circle cx="{x:.0f}" cy="{cCy:.0f}" r="{Rr:.0f}" fill="{c}"/>')
    S.append('</g>')

    # ============ ANNOTATION LAYERS (revealed on card hover) ============
    def anno(k, body): S.append(f'<g class="anno" data-k="{k}">{body}</g>')

    # diameter — Ø across the H circle vs the H letter-cell (both 600)
    dia = (f'<rect x="0" y="{-cap:.0f}" width="{advC}" height="{cap:.0f}" fill="{GOLD}" opacity="0.14"/>'
           + "".join(f'<circle cx="{x:.0f}" cy="{cCy:.0f}" r="{Rr:.0f}" fill="none" stroke="{GOLD}" stroke-width="7"/>' for x in (Hc,Rc,Lc))
           + hcal(cCy, Hc-Rr, Hc+Rr, "Ø 600", GOLD)
           + hcal(-cap/2, 0, advC, "letter cell 600", GOLD)
           + tx(Hc, cFar+118, "circle = one letter wide", 70, GOLD, "middle",700,True))
    anno("diameter", dia)

    # margin — the two EQUAL gaps, drawn on the left
    mx = -230
    guides = "".join(ln(mx-10, yy, spineX0, yy, "#c7ccd4", 2, "10 10") for yy in (Ledge,cNear,cFar,combY))
    mar = (guides
           + vcal(mx, Ledge, cNear, "m 132", GOLD)
           + vcal(mx, cFar, combY, "m 132", GOLD)
           + tx(mx-70, cCy, "equal", 66, GOLD, "end",700,True))
    anno("margin", mar)

    # comb — highlight spine + teeth + the 600 tick spacing
    sp = ln(spineX0,spineY,spineX1,spineY, BL, tW+14, o=0.35)
    th = "".join(ln(x,spineY,x,tEnd, BL, tW+10, o=0.30) for x,_ in TEETH)
    spY = (spineY+tEnd)/2
    labelY = combFar + 170
    combA = (sp + th + hcal(spY, 900, 1500, "600", BL)
             + tx((spineX0+spineX1)/2, labelY, "comb line · 12 IBI ticks, one per letter", 70, BL, "middle",700,True))
    anno("comb", combA)

    # centres — the shared vertical axis capital|dot|tick
    ce=[]
    for x,c,nm in [(Hc,PU,"H"),(Rc,RD,"R"),(Lc,GN,"L")]:
        ce.append(ln(x, -cap, x, combFar, c, 4, "3 10"))
        ce.append(f'<circle cx="{x:.0f}" cy="{cCy:.0f}" r="{Rr:.0f}" fill="none" stroke="{c}" stroke-width="7"/>')
        ce.append(tx(x, -cap-46, f"{nm} {x:.0f}", 66, c, "middle",700,True))
    anno("centres", "".join(ce))

    # colours — hexes on the circles
    co=[]
    for x,c,hx in [(Hc,PU,"#9558B2"),(Rc,RD,"#CB3C33"),(Lc,GN,"#389826")]:
        co.append(f'<circle cx="{x:.0f}" cy="{cCy:.0f}" r="{Rr:.0f}" fill="{c}"/>')
        co.append(tx(x, cCy+22, hx, 62, "#fff", "middle",700))
    anno("colours", "".join(co))

    # stack — total letter->comb bracket on the right
    sx = spineX1 + 200
    stackA = (vcal(sx, Ledge, combY, f"2m+Ø {combY:.0f}", "#333")
              + ln(sx-10, Ledge, spineX1, Ledge, "#c7ccd4", 2, "10 10")
              + ln(sx-10, combY, spineX1, combY, "#c7ccd4", 2, "10 10"))
    anno("stack", stackA)

    S.append('</svg>')
    return "".join(S)

UP   = variant("combUp",   -1)   # teeth up — point at the dots
DOWN = variant("combDown", +1)   # teeth down — point away

CARDS = [
 ("diameter","Circle Ø","600","Each circle is exactly <b>one letter wide</b> — the 600-unit monospace advance (0.82·cap). The earlier dots were 468; these fill a whole letter cell, which is why they now read bigger."),
 ("margin","Equal margins","m = 132","Top to bottom: letters, circles, comb. The gap <b>letter→circle</b> equals the gap <b>circle→comb line</b> — both 132 (0.18·cap). The circle floats centred in that band."),
 ("comb","The comb","12 × 600","Always at the bottom: a spine spanning the word with one tick per letter — the <b>inter-beat-interval axis</b>. The two variants only flip the teeth: <b>up</b> (at the dots) or <b>down</b> (away)."),
 ("centres","Optical centres","297·3305·5720","Capital, dot and tick share <b>one vertical axis</b> — the capital's ink centre, not its 600-cell centre (R and L would look off-grid otherwise)."),
 ("colours","Julia palette","purple·red·green","H <b>#9558B2</b>, R <b>#CB3C33</b>, L <b>#389826</b> — three of the four Julia brand hues on the three capitals; blue stays a reserved accent."),
 ("stack","Vertical stack","2m + Ø = 864","Letter edge to comb line is margin + circle + margin = <b>1.18·cap</b>. Identical for both variants — only the teeth direction differs."),
]
def cards_html():
    return "\n".join(
        f'<div class="mcard" data-hl="{k}"><div class="mtop"><span class="mtitle">{t}</span>'
        f'<span class="mval">{v}</span></div><p>{d}</p></div>' for k,t,v,d in CARDS)

PROPS = [
 ("Circle Ø", "600", "1.00 · advance · 0.82 · cap"),
 ("Margin m", "132", "0.18 · cap  (letter↔circle = circle↔comb)"),
 ("Tick length", "280", "0.38 · cap"),
 ("Tick spacing", "600", "one letter (12 ticks)"),
 ("Comb weight", "84", "spine = teeth"),
 ("Stack (letter→comb)", "864", "2m + Ø = 1.18 · cap"),
]
def props_html():
    return "\n".join(
        f'<div class="prow"><span class="pk">{k}</span><span class="pv">{v}</span><span class="pn">{n}</span></div>'
        for k,v,n in PROPS)

TPL = r"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeartRateLab · IBI-Comb + Circles · JuliaMono Bold</title>
<style>
@font-face{font-family:JMBold;src:local('JuliaMono Bold'),url('fonts/JuliaMono-Bold.ttf')}
:root{--pu:#9558B2;--gn:#389826;--rd:#CB3C33;--bl:#4063D8;--ink:#1b1b1f;--mut:#6b7280;
--bg:#fbfbfd;--card:#fff;--line:#e7e8ee;--soft:#f3f4f8;--gold:#b8860b}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:1180px;margin:0 auto;padding:0 24px}
code,.mono{font-family:JMBold,ui-monospace,monospace}
.kick{font-family:JMBold,monospace;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--pu)}
h1{font-size:clamp(28px,5vw,48px);margin:.15em 0 .1em;letter-spacing:-.02em}
h2{font-size:24px;margin:.2em 0 .3em}
.lead{font-size:18px;color:#3b3f46;max-width:820px}
.hero{padding:52px 0 22px}
.dots{display:flex;gap:9px;margin-bottom:16px}
.dots i{width:24px;height:24px;border-radius:50%;display:block}
.dots i:nth-child(1){background:var(--pu)}.dots i:nth-child(2){background:var(--rd)}.dots i:nth-child(3){background:var(--gn)}
section{padding:34px 0;border-top:1px solid var(--line)}
.tag{font-family:JMBold,monospace;font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--mut)}
.hint{font-size:14px;color:var(--mut);margin:.2em 0 16px}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin-top:6px}
.vcard{background:#f7f7f9;border:1px solid var(--line);border-radius:16px;padding:14px 14px 8px}
.vcap{font-family:JMBold,monospace;font-size:13px;letter-spacing:.08em;text-transform:uppercase;color:var(--mut);
display:flex;justify-content:space-between;align-items:center;margin:2px 4px 8px}
.vcap b{color:var(--ink)}
svg.combfig{width:100%;height:auto;display:block}
svg.combfig .anno{opacity:0;transition:opacity .16s}
svg.combfig.focus .base{opacity:.42;transition:opacity .16s}
svg.combfig.focus .anno.on{opacity:1}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px;margin-top:16px}
.mcard{border:1px solid var(--line);border-radius:12px;padding:12px 14px;background:var(--card);cursor:default;
transition:border-color .15s,box-shadow .15s,transform .1s}
.mcard:hover,.mcard.active{border-color:var(--gold);box-shadow:0 6px 20px rgba(184,134,11,.16);transform:translateY(-1px)}
.mtop{display:flex;justify-content:space-between;align-items:baseline;gap:10px}
.mtitle{font-weight:700}.mval{font-family:JMBold,monospace;color:var(--gold);font-size:15px;white-space:nowrap}
.mcard p{margin:.35em 0 0;font-size:14px;color:#4b5563}
.mcard b{color:var(--ink)}
.props{margin-top:14px;border:1px solid var(--line);border-radius:12px;overflow:hidden;background:var(--card)}
.prow{display:grid;grid-template-columns:210px 90px 1fr;gap:10px;padding:10px 16px;border-bottom:1px solid var(--line);font-size:14px}
.prow:last-child{border-bottom:0}
.pk{color:#374151}.pv{font-family:JMBold,monospace;color:var(--rd)}.pn{color:var(--mut)}
.note{background:var(--soft);border-left:4px solid var(--gn);border-radius:0 10px 10px 0;padding:12px 16px;margin:16px 0;font-size:15px}
.note b{color:var(--gn)}
footer{padding:26px 0 60px;color:var(--mut);font-size:13px;border-top:1px solid var(--line)}
@media(max-width:820px){.pair{grid-template-columns:1fr}.prow{grid-template-columns:1fr 70px;grid-auto-flow:row}.pn{grid-column:1/-1}}
</style></head>
<body>
<div class="wrap">
<header class="hero">
  <div class="dots"><i></i><i></i><i></i></div>
  <div class="kick">HeartRateLab · Logo refinement</div>
  <h1>IBI-Comb + letter-wide circles</h1>
  <p class="lead">A fixed stack, top to bottom: the <b>HeartRateLab</b> letters, three Julia <b>circles</b> (each
  <b>one letter wide</b>), and a <b>comb</b> of inter-beat-interval ticks — with <b>equal margins</b>
  (letter→circle = circle→comb). The comb is always at the bottom; the two variants only flip its <b>teeth</b>:
  <b>up</b> or <b>down</b>. Set in <b>JuliaMono&nbsp;Bold</b>. Hover any parameter card to light it up on both marks.</p>
</header>

<section>
  <div class="tag">The two variants — teeth up · teeth down</div>
  <div class="pair">
    <div class="vcard"><div class="vcap"><b>Teeth up</b><span>point at the dots</span></div>@UP@</div>
    <div class="vcard"><div class="vcap"><b>Teeth down</b><span>point away</span></div>@DOWN@</div>
  </div>
  <p class="hint">Identical letters, circles and comb line — only the teeth direction differs. Hover a card below → the parameter is remarked on <b>both</b> marks (base dims, guide appears).</p>
  <div class="cards">@CARDS@</div>
</section>

<section>
  <div class="tag">Parameters &amp; proportions</div>
  <h2>Every number, and what it is relative to</h2>
  <div class="props">@PROPS@</div>
  <div class="note"><b>The two headline choices.</b> The circle is now <b>Ø 600 — a full letter cell</b> (up from 468),
  and the two margins are <b>equal</b>: the distance from a capital down to its circle is the same as from the circle
  down to the comb line (<code>m = 132</code>). The comb sits at the bottom in both; only its teeth flip up or down.</div>
</section>

<footer>
  Measured from JuliaMono Bold (em 1000) · geometry regenerates from <code>full_metrics.json</code> via
  <code>build_comb.py</code> · Julia palette #9558B2 #CB3C33 #389826 · self-contained (font in <code>fonts/</code>).
</footer>
</div>
<script>
(function(){
  const svgs=[document.getElementById('combUp'),document.getElementById('combDown')];
  document.querySelectorAll('.mcard').forEach(c=>{ const k=c.dataset.hl;
    c.addEventListener('mouseenter',()=>{ c.classList.add('active');
      svgs.forEach(s=>{ if(!s)return; s.classList.add('focus');
        s.querySelectorAll('.anno').forEach(a=>a.classList.toggle('on',a.dataset.k===k)); }); });
    c.addEventListener('mouseleave',()=>{ c.classList.remove('active');
      svgs.forEach(s=>{ if(!s)return; s.classList.remove('focus');
        s.querySelectorAll('.anno').forEach(a=>a.classList.remove('on')); }); });
  });
  const HM=location.hash.match(/hl=([a-z]+)/);   // QA hook: #hl=margin freezes a hover state
  if(HM){ const k=HM[1]; document.querySelectorAll('.mcard').forEach(c=>c.classList.toggle('active',c.dataset.hl===k));
    svgs.forEach(s=>{ if(!s)return; s.classList.add('focus');
      s.querySelectorAll('.anno').forEach(a=>a.classList.toggle('on',a.dataset.k===k)); }); }
})();
</script>
</body></html>"""

html = (TPL.replace("@UP@",UP).replace("@DOWN@",DOWN)
           .replace("@CARDS@",cards_html()).replace("@PROPS@",props_html()))
(H/"comb_circles.html").write_text(html)
print("wrote comb_circles.html")
