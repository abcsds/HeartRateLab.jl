#!/usr/bin/env python3
"""Build index.html — the design-process report. The HEADER is the interactive
comb-under logo (logo 1) with every guideline parameter drawn on the mark and
lit on hover of its card. Below: the three final lockups, the report gallery, and
the parameter table. Geometry from metrics_900.json (JuliaMono Black, em=1000)."""
import json, pathlib, math
H = pathlib.Path(__file__).resolve().parent
def _tlen(i):   # gray tick length — the tachogram (same law as comb_teeth_up); accents stay at max
    h=170+80*math.sin(i*0.9+0.5)+45*math.sin(i*2.3+1.1)
    return max(70.0,min(272.0,h))
M = json.loads((H/"metrics_900.json").read_text())
A=M['advChar']; cap=M['cap']; advW=M['advWidth']; wL=M['wL']; wR=M['wR']
Hc,Rc,Lc = M['H'],M['R'],M['L']
PU,GN,RD,BL,INK,GRAY,GOLD = "#9558B2","#389826","#CB3C33","#4063D8","#1b1b1f","#8A8F98","#b8860b"
# comb-under geometry
m=132.0; Rr=300.0; cCy=m+Rr; cTop=cCy-Rr; cBot=cCy+Rr; combNear=2*m+2*Rr; combFar=combNear+280; tW=84.0
gHR=Rc-Hc; gRL=Lc-Rc
CELL=[i*A+A/2 for i in range(12)]

def ln(x1,y1,x2,y2,c,w,d="",o=1,cap_="round"):
    da=f' stroke-dasharray="{d}"' if d else ""
    return f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{c}" stroke-width="{w:.1f}"{da} stroke-linecap="{cap_}" opacity="{o}"/>'
def tx(x,y,s,sz,c,a="start",w=700,ha=False):
    halo=' paint-order="stroke" stroke="#fff" stroke-width="7"' if ha else ''
    return f'<text x="{x:.0f}" y="{y:.0f}" font-family="JMB,monospace" font-size="{sz:.0f}" font-weight="{w}" fill="{c}" text-anchor="{a}"{halo}>{s}</text>'
def vcal(x,y1,y2,label,c):
    y1,y2=sorted((y1,y2))
    return (ln(x,y1,x,y2,c,7,cap_="butt")+ln(x-44,y1,x+44,y1,c,7,cap_="butt")+ln(x-44,y2,x+44,y2,c,7,cap_="butt")
            +tx(x-58,(y1+y2)/2+24,label,74,c,"end",700,True))
def hcal(y,x1,x2,label,c):
    return (ln(x1,y,x2,y,c,7,cap_="butt")+ln(x1,y-40,x1,y+40,c,7,cap_="butt")+ln(x2,y-40,x2,y+40,c,7,cap_="butt")
            +tx((x1+x2)/2,y-30,label,74,c,"middle",700,True))
def dim(x1,x2,y,label,c):
    return (ln(x1,y,x2,y,c,6)+ln(x1,y-30,x1,y+30,c,6)+ln(x2,y-30,x2,y+30,c,6)+tx((x1+x2)/2,y-22,label,70,c,"middle",700,True))
def wordC():
    return ('<text x="0" y="0" font-family="JMB,monospace" font-size="1000" fill="'+INK+'">'
            f'<tspan fill="{PU}">H</tspan>eart<tspan fill="{RD}">R</tspan>ate<tspan fill="{GN}">L</tspan>ab</text>')

def hero():
    vbX=-620; vbY=-cap-260; vbW=advW+900; vbH=(combFar+240)-vbY
    S=[f'<svg id="hero" class="hero-svg anno-svg" viewBox="{vbX:.0f} {vbY:.0f} {vbW:.0f} {vbH:.0f}">']
    # base logo
    S.append('<g class="base">')
    S.append(f'<line x1="{wL-40:.0f}" y1="{combFar}" x2="{wR+40:.0f}" y2="{combFar}" stroke="{GRAY}" stroke-width="{tW}" stroke-linecap="round"/>')
    for i in range(12):
        if i==0: x,col=Hc,PU
        elif i==5: x,col=Rc,RD
        elif i==9: x,col=Lc,GN
        else: x,col=CELL[i],GRAY
        S.append(ln(x,combFar,x,(combNear if i in(0,5,9) else combFar-_tlen(i)),col,(tW if i in(0,5,9) else tW*0.72)))
    for x,col in [(Hc,PU),(Rc,RD),(Lc,GN)]:
        S.append(f'<circle cx="{x:.0f}" cy="{cCy:.0f}" r="{Rr:.0f}" fill="{col}"/>')
    S.append(f'<g>{wordC()}</g></g>')
    def An(k,b): S.append(f'<g class="anno" data-k="{k}">{b}</g>')
    # diameter
    An("dia", f'<rect x="0" y="{-cap:.0f}" width="{A}" height="{cap:.0f}" fill="{GOLD}" opacity="0.13"/>'
        + "".join(f'<circle cx="{c:.0f}" cy="{cCy:.0f}" r="{Rr:.0f}" fill="none" stroke="{GOLD}" stroke-width="7"/>' for c in (Hc,Rc,Lc))
        + hcal(cCy, Hc-Rr, Hc+Rr, "Ø 600", GOLD)
        + tx(Hc, cBot+120, "ball = one letter wide", 70, GOLD,"middle",700,True))
    # equal margins
    mx=-210
    guides="".join(ln(mx-10,yy,wL,yy,"#c7ccd4",2,"10 10") for yy in (0,cTop,cBot,combNear))
    An("margin", guides + vcal(mx, 0, cTop, "m 132", GOLD) + vcal(mx, cBot, combNear, "m 132", GOLD)
        + tx(mx-70, cCy, "equal", 66, GOLD,"end",700,True))
    # optical centres
    ce=[]
    for c,col,nm in [(Hc,PU,"H"),(Rc,RD,"R"),(Lc,GN,"L")]:
        ce.append(ln(c,-cap,c,combFar,col,4,"3 10"))
        ce.append(f'<circle cx="{c:.0f}" cy="{cCy:.0f}" r="{Rr:.0f}" fill="none" stroke="{col}" stroke-width="7"/>')
        ce.append(tx(c,-cap-46,f"{nm} {c:.0f}",66,col,"middle",700,True))
    An("centres","".join(ce))
    # comb
    An("comb", ln(wL-40,combFar,wR+40,combFar,BL,tW+14,o=0.32)
        + "".join(ln((Hc if i==0 else Rc if i==5 else Lc if i==9 else CELL[i]),combFar,(Hc if i==0 else Rc if i==5 else Lc if i==9 else CELL[i]),(combNear if i in(0,5,9) else combFar-_tlen(i)),BL,tW+8,o=0.28) for i in range(12))
        + hcal(1004, CELL[1], CELL[2], "600", BL)
        + tx((wL+wR)/2, combFar+150, "comb line · 12 IBI ticks, one per letter", 70, BL,"middle",700,True))
    # colours
    co=[]
    for c,col,hx in [(Hc,PU,"#9558B2"),(Rc,RD,"#CB3C33"),(Lc,GN,"#389826")]:
        co.append(f'<circle cx="{c:.0f}" cy="{cCy:.0f}" r="{Rr:.0f}" fill="{col}"/>')
        co.append(tx(c,cCy+22,hx,58,"#fff","middle",700))
    An("colours","".join(co))
    # rhythm
    ry=combFar+140
    An("rhythm", dim(Hc,Rc,ry,f"H→R {gHR:.0f}",INK)+dim(Rc,Lc,ry,f"R→L {gRL:.0f}",INK)
        + tx((Hc+Lc)/2, ry+90, "5 : 4  (cells 3000:2400 · optical ~1.26)", 62, INK,"middle",700,True))
    S.append('</svg>')
    return "".join(S)

CARDS=[
 ("dia","Ball Ø","600","Each ball is <b>one letter wide</b> — the 600 monospace advance (0.82·cap) — floating below its capital."),
 ("margin","Equal margins","m = 132","The gap <b>letter→ball</b> equals <b>ball→comb line</b> — both 132 (0.18·cap). The ball floats centred in the band."),
 ("centres","Optical centres","305·3313·5705","Ball, tick and capital share <b>one vertical axis</b> — each capital's ink centre, not its 600-cell centre."),
 ("comb","The comb","12 × 600","A gray IBI-tick rail under the word — one tick per letter, 600 apart; the three at H·R·L are tinted."),
 ("colours","Julia palette","purple·red·green","H <b>#9558B2</b>, R <b>#CB3C33</b>, L <b>#389826</b> — three of the four brand hues; blue stays reserved."),
 ("rhythm","Rhythm","5 : 4","Cell-centre hops <b>3000 : 2400</b> = exactly 5:4 (optical ≈1.26) — a swung triplet, the cadence the package measures."),
]
def cards():
    return "\n".join(f'<div class="mcard" data-hl="{k}"><div class="mtop"><span class="mtitle">{t}</span>'
        f'<span class="mval mono">{v}</span></div><p>{d}</p></div>' for k,t,v,d in CARDS)

TPL=r"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeartRateLab · Logo design process &amp; final marks</title>
<style>
@font-face{font-family:JMB;src:local('JuliaMono Black'),url('fonts/JuliaMono-Black.ttf')}
:root{--pu:#9558B2;--gn:#389826;--rd:#CB3C33;--bl:#4063D8;--ink:#1b1b1f;--mut:#6b7280;--gold:#b8860b;
--bg:#fbfbfd;--card:#fff;--line:#e7e8ee;--soft:#f3f4f8}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:1120px;margin:0 auto;padding:0 24px}
.mono{font-family:JMB,ui-monospace,monospace}code{font-family:JMB,monospace}
.kick{font-family:JMB,monospace;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--pu)}
h1{font-size:clamp(30px,5.5vw,54px);margin:.12em 0 .1em;letter-spacing:-.02em}
h2{font-size:26px;margin:.1em 0 .3em}
h3{margin:.1em 0}
.lead{font-size:19px;color:#3b3f46;max-width:820px}
.hero{padding:52px 0 10px}
.dots{display:flex;gap:9px;margin-bottom:16px}.dots i{width:26px;height:26px;border-radius:50%}
.dots i:nth-child(1){background:var(--pu)}.dots i:nth-child(2){background:var(--rd)}.dots i:nth-child(3){background:var(--gn)}
.herobox{background:var(--card);border:1px solid var(--line);border-radius:20px;padding:22px 24px;box-shadow:0 12px 40px rgba(20,20,40,.05);margin-top:20px}
.hero-svg{width:100%;height:auto;display:block}
.anno-svg .anno{opacity:0;transition:opacity .16s}
.anno-svg.focus .base{opacity:.4;transition:opacity .16s}
.anno-svg.focus .anno.on{opacity:1}
.hint{font-size:14px;color:var(--mut);margin:14px 0 8px}
.hcards{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px;margin-top:8px}
.mcard{border:1px solid var(--line);border-radius:12px;padding:12px 14px;background:var(--card);cursor:default;transition:border-color .15s,box-shadow .15s,transform .1s}
.mcard:hover,.mcard.active{border-color:var(--gold);box-shadow:0 6px 20px rgba(184,134,11,.16);transform:translateY(-1px)}
.mtop{display:flex;justify-content:space-between;align-items:baseline;gap:10px}
.mtitle{font-weight:700}.mval{color:var(--gold);font-size:15px;white-space:nowrap}
.mcard p{margin:.35em 0 0;font-size:14px;color:#4b5563}.mcard b{color:var(--ink)}
.chips{display:flex;gap:10px;flex-wrap:wrap;margin-top:16px}
.chip{background:var(--card);border:1px solid var(--line);border-radius:999px;padding:6px 14px;font-size:13px;color:var(--mut)}
.chip b{color:var(--ink)}
section{padding:36px 0;border-top:1px solid var(--line)}
.tag{font-family:JMB,monospace;font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--mut)}
.finals{display:grid;grid-template-columns:1fr;gap:20px;margin-top:16px}
.final{border:1px solid var(--line);border-radius:18px;background:var(--card);overflow:hidden}
.final .head{display:flex;justify-content:space-between;align-items:baseline;gap:12px;padding:16px 20px 4px}
.final .head .nm{font-weight:700;font-size:18px}.final .head .sub{color:var(--mut);font-size:13px;font-family:JMB,monospace}
.final .imgs{display:grid;grid-template-columns:1fr 1fr;gap:0}
.final .imgs>div{padding:22px;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;min-height:150px;background:#fff}
.final .imgs>div:first-child{border-right:1px solid var(--line)}
.final img{max-width:100%;height:auto}
.cap{font-family:JMB,monospace;font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:var(--mut)}
.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:16px;margin-top:16px}
.rep{border:1px solid var(--line);border-radius:14px;overflow:hidden;background:var(--card);text-decoration:none;color:inherit;transition:box-shadow .15s,transform .1s,border-color .15s;display:block}
.rep:hover{box-shadow:0 10px 30px rgba(20,20,40,.10);transform:translateY(-2px);border-color:var(--pu)}
.rep img{width:100%;display:block;border-bottom:1px solid var(--line)}
.rep .b{padding:12px 14px}
.rep .t{font-weight:700;font-size:15px}.rep .d{font-size:13.5px;color:#4b5563;margin-top:.25em}
.props{margin-top:14px;border:1px solid var(--line);border-radius:12px;overflow:hidden;background:var(--card)}
.prow{display:grid;grid-template-columns:160px 100px 1fr;gap:10px;padding:9px 16px;border-bottom:1px solid var(--line);font-size:14px}
.prow:last-child{border-bottom:0}.pk{color:#374151}.pv{font-family:JMB,monospace;color:var(--rd)}.pn{color:var(--mut)}
.note{background:var(--soft);border-left:4px solid var(--gn);border-radius:0 10px 10px 0;padding:12px 16px;margin:14px 0;font-size:15px}.note b{color:var(--gn)}
.small{font-size:13.5px;color:var(--mut)}.small a{color:var(--pu)}
footer{padding:28px 0 64px;color:var(--mut);font-size:13px;border-top:1px solid var(--line)}
@media(max-width:720px){.final .imgs{grid-template-columns:1fr}.final .imgs>div:first-child{border-right:0;border-bottom:1px solid var(--line)}.prow{grid-template-columns:1fr 90px;grid-auto-flow:row}.pn{grid-column:1/-1}}
</style></head>
<body>
<div class="wrap">

<header class="hero">
  <div class="dots"><i></i><i></i><i></i></div>
  <div class="kick">HeartRateLab.jl · brand · design process</div>
  <h1>Three heartbeats, three dots, one word</h1>
  <p class="lead"><b>HeartRateLab</b> in <b>JuliaMono&nbsp;Black&nbsp;(900)</b>, the three capitals tinted in the Julia
  palette. Below is the primary lockup — <b>comb-under</b> — with every guideline drawn on it: <b>hover a parameter
  card</b> to light it up on the mark.</p>
  <div class="herobox">@HERO@</div>
  <p class="hint">Hover a card → the matching guide is highlighted on the logo (everything else dims). All values in em units (font-size 1000).</p>
  <div class="hcards">@CARDS@</div>
  <div class="chips">
    <span class="chip"><b>Type</b> JuliaMono Black · weight 900</span>
    <span class="chip"><b>Palette</b> #9558B2 · #CB3C33 · #389826</span>
    <span class="chip"><b>Spec</b> <a href="GUIDELINES.md" style="color:inherit">GUIDELINES.md</a></span>
  </div>
</header>

<section>
  <div class="tag">The final marks · static (black-lettered) + animated</div>
  <h2>Three lockups</h2>
  <div class="finals">
    <div class="final">
      <div class="head"><span class="nm">Comb-under</span><span class="sub">balls under the word</span></div>
      <div class="imgs">
        <div><img src="final/logo_under.png" alt="HeartRateLab comb-under logo, black letters"><span class="cap">static · svg + png</span></div>
        <div><img src="final/anim_under.gif" alt="comb-under bounce animation"><span class="cap">anim · gif</span></div>
      </div>
    </div>
    <div class="final">
      <div class="head"><span class="nm">Icon-left</span><span class="sub">balls to the side</span></div>
      <div class="imgs">
        <div><img src="final/logo_side.png" alt="HeartRateLab icon-left logo, black letters"><span class="cap">static · svg + png</span></div>
        <div><img src="final/anim_side.gif" alt="icon-left bounce animation"><span class="cap">anim · gif</span></div>
      </div>
    </div>
    <div class="final">
      <div class="head"><span class="nm">HRL Ring</span><span class="sub">balls all-around · one beat at a time</span></div>
      <div class="imgs">
        <div><img src="final/logo_ring.png" alt="HRL ring logo, black letters" style="max-width:300px"><span class="cap">static · svg + png</span></div>
        <div><img src="final/anim_ring.gif" alt="ring orbit animation" style="max-width:300px"><span class="cap">anim · gif</span></div>
      </div>
    </div>
  </div>
  <p class="small">Static shown black-lettered; colour-cap variants and every animation mode live in the reports below.
  Assets: <code>final/logo_{under,side,ring}.svg&nbsp;/.png</code> · <code>final/anim_{under,side,ring}.gif</code>.</p>
</section>

<section>
  <div class="tag">The design process · reports</div>
  <h2>How we got here — every study</h2>
  <div class="gallery">
    <a class="rep" href="hrl_report.html"><img src="final/thumbs/hrl_report.png" alt="">
      <div class="b"><div class="t">01 · Wordmark anatomy</div><div class="d">Glyph-by-glyph metrics, optical centres, letter widths, balance &amp; pulls, rhythm (5:4), and the live bounce.</div></div></a>
    <a class="rep" href="comb_circles.html"><img src="final/thumbs/comb_circles.png" alt="">
      <div class="b"><div class="t">02 · Comb + circles</div><div class="d">Letter-wide circles with equal margins; teeth-up vs teeth-down, geometry highlighted on hover.</div></div></a>
    <a class="rep" href="comb_teeth_up.html"><img src="final/thumbs/comb_teeth_up.png" alt="">
      <div class="b"><div class="t">03 · Underlined by the Comb <span class="mono" style="color:var(--pu)">Top&nbsp;1</span></div><div class="d">The comb gray, all colour combinations, and the tachogram tooth-height law.</div></div></a>
    <a class="rep" href="comb_icon_left.html"><img src="final/thumbs/comb_icon_left.png" alt="">
      <div class="b"><div class="t">04 · Tick-Comb Mini <span class="mono" style="color:var(--gn)">Top&nbsp;2</span></div><div class="d">The comb shrunk to a cap-height icon at the left; proportions on hover, colour combinations.</div></div></a>
    <a class="rep" href="comb_animated_900.html"><img src="final/thumbs/comb_animated_900.png" alt="">
      <div class="b"><div class="t">05 · The bounce, animated</div><div class="d">16 live variants across all three marks: colour/ink, build-up/blink, bounce-only, remote squash, ring orbit.</div></div></a>
    <div class="rep" style="cursor:default"><div class="b" style="padding:16px">
      <div class="t">06 · Weight comparison</div>
      <div class="d">The same animated report on three weights, to choose the chunkiest:
        <a href="comb_animated.html">Bold&nbsp;700</a> · <a href="comb_animated_800.html">ExtraBold&nbsp;800</a> ·
        <a href="comb_animated_900.html"><b>Black&nbsp;900</b></a> ← chosen.</div></div></div>
  </div>
  <p class="small" style="margin-top:14px">Earlier exploration (kept for the record):
    <a href="../../index.html">the 60-logo set</a> · <a href="../../series2.html">series 2</a> ·
    <a href="../../series3.html">series 3</a>.</p>
</section>

<section>
  <div class="tag">The parameters we solved</div>
  <h2>Key numbers (JuliaMono Black, em 1000)</h2>
  <div class="props">
    <div class="prow"><span class="pk">Typeface</span><span class="pv">Black 900</span><span class="pn">chunkiest JuliaMono; usWeightClass 900</span></div>
    <div class="prow"><span class="pk">Cap-height</span><span class="pv">734</span><span class="pn">x-height 562 · advance 600 (monospace)</span></div>
    <div class="prow"><span class="pk">Optical centres</span><span class="pv">305·3313·5705</span><span class="pn">H · R · L ink centres (not the 600-cell)</span></div>
    <div class="prow"><span class="pk">Ball Ø (word-bounded)</span><span class="pv">516</span><span class="pn">0.70·cap; margin m = 132 (0.18·cap)</span></div>
    <div class="prow"><span class="pk">Rhythm</span><span class="pv">5 : 4</span><span class="pn">cell-centre hops 3000 : 2400 = 1.25 (optical ≈1.26)</span></div>
    <div class="prow"><span class="pk">Balance</span><span class="pv">497 left</span><span class="pn">beats' centroid 3107 vs word centre 3605</span></div>
    <div class="prow"><span class="pk">Motion</span><span class="pv">t ∝ dist</span><span class="pn">constant speed, apex ∝ dist², elastic squash; ring = orbit</span></div>
  </div>
  <div class="note"><b>Full spec.</b> Every parameter, colour, and reproduction step is in
  <a href="GUIDELINES.md">GUIDELINES.md</a>; the source of truth for the geometry is
  <code>metrics_900.json</code>. All figures regenerate from
  <code>build_comb2/3/4.py</code>, <code>build_final.py</code> and <code>build_index.py</code>.</div>
</section>

<footer>
  HeartRateLab.jl brand · JuliaMono Black (900) · palette #9558B2 #CB3C33 #389826 · comb gray #8A8F98 ·
  measured with headless Chromium · self-contained (fonts vendored in <code>fonts/</code>, or system JuliaMono).
</footer>
</div>
<script>
(function(){
  const svg=document.getElementById('hero');
  document.querySelectorAll('.hcards .mcard').forEach(c=>{const k=c.dataset.hl;
    c.addEventListener('mouseenter',()=>{c.classList.add('active');svg.classList.add('focus');
      svg.querySelectorAll('.anno').forEach(a=>a.classList.toggle('on',a.dataset.k===k));});
    c.addEventListener('mouseleave',()=>{c.classList.remove('active');svg.classList.remove('focus');
      svg.querySelectorAll('.anno').forEach(a=>a.classList.remove('on'));});
  });
  const HM=location.hash.match(/hl=([a-z]+)/);
  if(HM){const k=HM[1];svg.classList.add('focus');
    document.querySelectorAll('.hcards .mcard').forEach(c=>c.classList.toggle('active',c.dataset.hl===k));
    svg.querySelectorAll('.anno').forEach(a=>a.classList.toggle('on',a.dataset.k===k));}
})();
</script>
</body></html>"""

html=TPL.replace("@HERO@",hero()).replace("@CARDS@",cards())
(H/"index.html").write_text(html)
print("wrote index.html (unreplaced tokens:", html.count("@HERO@")+html.count("@CARDS@"), ")")
