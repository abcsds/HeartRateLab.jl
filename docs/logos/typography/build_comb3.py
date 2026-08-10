#!/usr/bin/env python3
"""Build comb_icon_left.html — series-2 TOP 2 ("Tick-Comb Mini", lock-02):
take the solved comb, DROP the gray ticks, keep the three colour ticks + circles,
SHRINK horizontally (gap = our margin m), and set it as an icon to the LEFT of the
HeartRateLab wordmark. Then the same variational analysis as top 1: the rail gray,
all colour combinations, the tick-arrangement pattern, and my Top 1 & Top 2.
Geometry & ratios inherited from metrics_900.json + the solved comb (JuliaMono Black, em=1000)."""
import json, pathlib
H = pathlib.Path(__file__).resolve().parent
M = json.loads((H/"metrics_900.json").read_text())
cap = M['cap']; wL = M['wL']; wR = M['wR']
PU, GN, RD, INK = "#9558B2", "#389826", "#CB3C33", "#1b1b1f"
GRAY = "#8A8F98"

# ---- ratios carried over from the solved comb (relative to the circle Ø) ----
R_M   = 132/600      # margin  m / Ø           = 0.22
R_TK  = 280/600      # tallest tooth / Ø       = 0.467
R_W   = 84/600       # comb weight / Ø         = 0.14
# icon total height = Ø + m + tooth = Ø(1 + R_M + R_TK); fit it to the cap-height
Oi = cap / (1 + R_M + R_TK)                 # icon circle diameter (~435)
Rr = Oi/2
mi = R_M*Oi                                 # icon margin (vertical AND horizontal gap)
tki= R_TK*Oi                                # full tick length (dot at cap line)
wi = R_W*Oi                                 # tick / rail weight
spacing = Oi + mi                           # circle centre-to-centre (shrunk: gap = m)
railY = 0.0                                 # rail on the baseline
GAP_WORD = 320.0                            # icon -> word gap
COLS = [PU, RD, GN]

# icon circle x-centres, right edge sits GAP_WORD left of the word ink (wL)
c3x = wL - GAP_WORD - Rr
c2x = c3x - spacing
c1x = c2x - spacing
CX  = [c1x, c2x, c3x]
railX0, railX1 = c1x-Rr, c3x+Rr

def dot_cy(tick_len):                        # dot centre for a given tick length
    return -(tick_len + mi + Rr)             # tip = -tick_len; dot sits m above the tip
def lens(levels): return [max(0.16,l)*tki for l in levels]
TACHO_LEVELS = [0.82, 1.0, 0.58]             # FIXED tachogram — three interval heights (dot 2 on the cap line)
TACHO = lens(TACHO_LEVELS)
CY = [dot_cy(l) for l in TACHO]              # per-dot centres
CY_FLAT = CY[1]                              # tallest dot (cap line) — for top-edge labels

# ---------- SVG helpers ----------
def ln(x1,y1,x2,y2,c,w,d="",o=1,cap_="round"):
    da=f' stroke-dasharray="{d}"' if d else ""
    return f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{c}" stroke-width="{w:.1f}"{da} stroke-linecap="{cap_}" opacity="{o}"/>'
def tx(x,y,s,sz,c,a="start",w=700,ha=False):
    halo=' paint-order="stroke" stroke="#fff" stroke-width="7"' if ha else ''
    return f'<text x="{x:.0f}" y="{y:.0f}" font-family="JMBold,monospace" font-size="{sz:.0f}" font-weight="{w}" fill="{c}" text-anchor="{a}"{halo}>{s}</text>'
def vcal(x,y1,y2,label,c):
    y1,y2=sorted((y1,y2))
    return (ln(x,y1,x,y2,c,7,cap_="butt")+ln(x-44,y1,x+44,y1,c,7,cap_="butt")+ln(x-44,y2,x+44,y2,c,7,cap_="butt")
            +tx(x-58,(y1+y2)/2+24,label,74,c,"end",700,True))
def hcal(y,x1,x2,label,c):
    return (ln(x1,y,x2,y,c,7,cap_="butt")+ln(x1,y-40,x1,y+40,c,7,cap_="butt")+ln(x2,y-40,x2,y+40,c,7,cap_="butt")
            +tx((x1+x2)/2,y-30,label,74,c,"middle",700,True))
def wordtext(colored):
    if colored:
        return ('<text x="0" y="0" font-family="JMBold,monospace" font-size="1000" fill="'+INK+'">'
                f'<tspan fill="{PU}">H</tspan>eart<tspan fill="{RD}">R</tspan>ate<tspan fill="{GN}">L</tspan>ab</text>')
    return '<text x="0" y="0" font-family="JMBold,monospace" font-size="1000" fill="'+INK+'">HeartRateLab</text>'

def icon(tick_lens, rail=GRAY, ticks_colored=True, dots=True):
    """The mini tick-comb icon (3 colour ticks + circles on a short gray rail)."""
    S=[ln(railX0,railY,railX1,railY,rail,wi)]                      # rail
    for i in range(3):
        cy=dot_cy(tick_lens[i]); tip=cy+Rr+mi
        col=COLS[i] if ticks_colored else rail
        S.append(ln(CX[i],railY,CX[i],tip,col,wi))                # tick
        if dots: S.append(f'<circle cx="{CX[i]:.1f}" cy="{cy:.1f}" r="{Rr:.1f}" fill="{COLS[i]}"/>')
    return "".join(S)

def lockup(tick_lens=None, rail=GRAY, letter_colored=False, ticks_colored=True):
    if tick_lens is None: tick_lens=list(TACHO)
    vbX=railX0-120; vbW=(wR+160)-vbX; vbY=-cap-110; vbH=(railY+150)-vbY
    return (f'<svg class="lk" viewBox="{vbX:.0f} {vbY:.0f} {vbW:.0f} {vbH:.0f}">'
            f'{icon(tick_lens,rail,ticks_colored)}<g>{wordtext(letter_colored)}</g></svg>')

# ---------- hero with hover-highlighted proportions ----------
def hero():
    vbX=railX0-620; vbW=(wR+300)-vbX; vbY=-cap-300; vbH=(railY+340)-vbY
    S=[f'<svg id="hero" class="lk anno-svg" viewBox="{vbX:.0f} {vbY:.0f} {vbW:.0f} {vbH:.0f}">']
    S.append(f'<g class="base">{icon(TACHO)}<g>{wordtext(False)}</g></g>')
    def A(k,b): S.append(f'<g class="anno" data-k="{k}">{b}</g>')
    topY=min(CY)-Rr                          # highest dot edge (for top labels)
    # diameter — ring every dot at its own height, caliper the first
    A("dia", "".join(f'<circle cx="{CX[i]:.1f}" cy="{CY[i]:.1f}" r="{Rr:.1f}" fill="none" stroke="#b8860b" stroke-width="7"/>' for i in range(3))
             + hcal(CY[0], c1x-Rr, c1x+Rr, f"Ø {Oi:.0f}", "#b8860b"))
    # margin: vertical (circle->tip) AND horizontal (between circles) both = m
    A("mar", vcal(c1x-Rr-70, CY[0]+Rr, CY[0]+Rr+mi, f"m {mi:.0f}", "#b8860b")
             + hcal(topY-60, c1x+Rr, c2x-Rr, f"m {mi:.0f}", "#b8860b")
             + tx((c1x+c2x)/2, topY-140, "same gap, H & V", 66, "#b8860b","middle",700,True))
    # tick length — highlight all three; caliper the tallest (dot on the cap line)
    A("tick", "".join(ln(CX[i],railY,CX[i],CY[i]+Rr+mi,"#4063D8",wi+10,o=0.35) for i in range(3))
              + vcal(c3x+Rr+80, railY, -tki, f"tick {tki:.0f}", "#4063D8"))
    # spacing
    A("space", hcal(railY+150, c1x, c2x, f"Ø+m {spacing:.0f}", "#333"))
    # rail gray
    A("gray", ln(railX0,railY,railX1,railY,"#4063D8",wi+14,o=0.4)
              + tx((railX0+railX1)/2, railY+150, f"gray rail {GRAY}", 66, "#4063D8","middle",700,True))
    # placement gap to word
    A("place", hcal(-cap*0.5, c3x+Rr, wL, f"gap {GAP_WORD:.0f}", "#333")
               + ln(wL,-cap-40,wL,railY+40,"#c7ccd4",2,"10 10"))
    S.append('</svg>')
    return "".join(S)

CARDS=[
 ("dia","Circle Ø",f"{Oi:.0f}","Icon circle, sized so the whole mark is exactly the word's cap-height. Carries the same Ø:m:tick ratio as the big comb."),
 ("mar","Margin m",f"{mi:.0f}","The one gap that rules everything: circle→tick-tip vertically AND circle→circle horizontally. Shrinking the comb = setting the horizontal gap to m."),
 ("tick","Tick length",f"{tki:.0f}","Ticks follow a fixed <b>tachogram</b> — each dot's height is one interval. The tallest (dot on the cap line) = 0.47·Ø, from the comb's tallest tooth; a dot always sits m above its tip."),
 ("space","Spacing",f"{spacing:.0f}","Centre-to-centre = Ø + m. The three colour ticks — spread across the word in top 1 — compressed to adjacent cells here."),
 ("gray","Rail gray",GRAY,"The gray ticks are gone; only the short rail stays gray (3.3:1). All three ticks now carry a Julia colour."),
 ("place","Gap to word",f"{GAP_WORD:.0f}","Icon right edge to the word's left ink. Icon vertically spans cap-line→baseline, so it locks to the type."),
]
def cards(): return "\n".join(
    f'<div class="mcard" data-hl="{k}"><div class="mtop"><span class="mtitle">{t}</span>'
    f'<span class="mval mono">{v}</span></div><p>{d}</p></div>' for k,t,v,d in CARDS)

def gray_row():
    out=[]
    for hx,nm in [("#8A8F98","series-2 cool"),("#98989E","neutral"),("#9C948C","warm"),("#B4B8BF","light")]:
        out.append(f'<div class="gcell"><div class="sw" style="background:{hx}"></div><div class="gk mono">{hx}</div>'
                   f'<div class="gn">{nm}</div><div class="mini">{lockup(rail=hx)}</div></div>')
    return "\n".join(out)

def combo_matrix():
    cells=[]
    for lc,ln_ in [(False,"ink letters"),(True,"coloured letters")]:
        for tc,tn in [(True,"colour ticks"),(False,"gray ticks (dots only)")]:
            cells.append(f'<div class="mcell"><div class="cap mono">{ln_} · {tn}</div>'
                         f'{lockup(letter_colored=lc, ticks_colored=tc)}</div>')
    return "\n".join(cells)

TOP1 = lockup(rail="#8A8F98", letter_colored=False)              # tachogram (fixed), ink letters
TOP2 = lockup(rail="#9AA0A6", letter_colored=True)               # tachogram (fixed), coloured caps

PARAMS=[("Circle Ø",f"{Oi:.0f}","icon circle = cap-height mark"),
 ("Margin m",f"{mi:.0f}","circle↔tip = circle↔circle (the shrink gap)"),
 ("Tick (full)",f"{tki:.0f}","0.47·Ø — dot on the cap line"),
 ("Spacing",f"{spacing:.0f}","Ø + m centre-to-centre"),
 ("Gap to word",f"{GAP_WORD:.0f}","icon right → word left ink"),
 ("Rail gray","#8A8F98","3.3:1; ticks all coloured")]
def params(): return "\n".join(
    f'<div class="prow"><span class="pk">{k}</span><span class="pv mono">{v}</span><span class="pn">{n}</span></div>' for k,v,n in PARAMS)

TPL=r"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeartRateLab · Tick-Comb Mini (icon-left) · series-2 Top 2</title>
<style>
@font-face{font-family:JMBold;src:local('JuliaMono Black'),url('fonts/JuliaMono-Black.ttf')}
:root{--pu:#9558B2;--gn:#389826;--rd:#CB3C33;--ink:#1b1b1f;--mut:#6b7280;--bg:#fbfbfd;--card:#fff;--line:#e7e8ee;--soft:#f3f4f8;--gold:#b8860b}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:1120px;margin:0 auto;padding:0 24px}
.mono{font-family:JMBold,ui-monospace,monospace}code{font-family:JMBold,monospace}
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
svg.lk{width:100%;height:auto;display:block}
.herobox{background:#fff;border:1px solid var(--line);border-radius:20px;padding:22px 24px;box-shadow:0 12px 40px rgba(20,20,40,.05)}
.anno-svg .anno{opacity:0;transition:opacity .16s}
.anno-svg.focus .base{opacity:.4;transition:opacity .16s}
.anno-svg.focus .anno.on{opacity:1}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px;margin-top:16px}
.mcard{border:1px solid var(--line);border-radius:12px;padding:12px 14px;background:var(--card);cursor:default;transition:border-color .15s,box-shadow .15s,transform .1s}
.mcard:hover,.mcard.active{border-color:var(--gold);box-shadow:0 6px 20px rgba(184,134,11,.16);transform:translateY(-1px)}
.mtop{display:flex;justify-content:space-between;align-items:baseline;gap:10px}
.mtitle{font-weight:700}.mval{color:var(--gold);font-size:15px;white-space:nowrap}
.mcard p{margin:.35em 0 0;font-size:14px;color:#4b5563}.mcard b{color:var(--ink)}
.answer{background:var(--soft);border-left:4px solid var(--pu);border-radius:0 10px 10px 0;padding:12px 16px;margin:14px 0;font-size:15px}.answer b{color:var(--pu)}
.grays{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-top:14px}
.gcell{border:1px solid var(--line);border-radius:12px;padding:12px;background:var(--card)}
.sw{height:40px;border-radius:8px;border:1px solid rgba(0,0,0,.08)}.gk{margin-top:8px;font-size:14px}.gn{font-size:12px;color:var(--mut)}
.mini{margin-top:8px;background:#fafafb;border-radius:8px;padding:6px}
.matrix,.patterns{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:14px}
.mcell,.pcell{border:1px solid var(--line);border-radius:14px;padding:14px 16px;background:var(--card)}
.cap{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--mut);margin-bottom:8px}
.pd{font-size:14px;color:#4b5563;margin:.5em 0 0}
.tops{display:grid;grid-template-columns:1fr;gap:18px;margin-top:8px}
.top{border:1px solid var(--line);border-radius:18px;padding:20px 22px;background:var(--card)}
.top h3{margin:.1em 0;font-size:20px}
.badge{display:inline-block;font-family:JMBold,monospace;font-size:12px;padding:3px 10px;border-radius:999px;color:#fff;margin-right:8px}.b1{background:var(--pu)}.b2{background:var(--gn)}
.rat{font-size:15px;color:#3b3f46;margin:.4em 0 0}
.props{margin-top:12px;border:1px solid var(--line);border-radius:12px;overflow:hidden;background:var(--card)}
.prow{display:grid;grid-template-columns:150px 90px 1fr;gap:10px;padding:9px 16px;border-bottom:1px solid var(--line);font-size:14px}
.prow:last-child{border-bottom:0}.pk{color:#374151}.pv{color:var(--rd)}.pn{color:var(--mut)}
footer{padding:26px 0 60px;color:var(--mut);font-size:13px;border-top:1px solid var(--line)}
@media(max-width:820px){.grays{grid-template-columns:1fr 1fr}.matrix,.patterns{grid-template-columns:1fr}.prow{grid-template-columns:1fr 80px;grid-auto-flow:row}.pn{grid-column:1/-1}}
</style></head>
<body>
<div class="wrap">
<header class="hero">
  <div class="dots"><i></i><i></i><i></i></div>
  <div class="kick">HeartRateLab · series-2 Top 2 · Tick-Comb Mini</div>
  <h1>The comb, shrunk to an icon</h1>
  <p class="lead">Top 1 put the comb <i>under</i> the word. Top 2 takes that same comb, <b>drops the gray ticks</b>,
  keeps the three colour ticks + circles, <b>compresses them horizontally</b> (gap = our margin <code>m</code>), and
  sets the result as an <b>icon to the left</b> of the wordmark — all on the solved ratios (Ø:m:tick), the gray rail,
  <b>JuliaMono&nbsp;Black</b>. Hover a card to light up each rule on the mark.</p>
  <div class="herobox">@HERO@</div>
  <div class="cards">@CARDS@</div>
</header>

<section>
  <div class="tag">01 · Where it came from</div>
  <h2>Comb → drop grays → shrink to m → move left</h2>
  <div class="answer"><b>The shrink rule.</b> In top 1 the three colour ticks sat at the letters' optical centres
  (~2400–3000 apart). Here they collapse to <b>adjacent cells, gap = m</b> — the same margin that separates circle
  from tick and circle from rail. One constant <code>m</code> governs every gap in the mark. The rail stays the
  <code>#8A8F98</code> gray (3.3:1); only the ticks are coloured now.</div>
</section>

<section>
  <div class="tag">02 · Colour combinations</div>
  <h2>Where the colour goes</h2>
  <p class="lead" style="font-size:17px">Two switches — <b>letters</b> {ink · coloured} × <b>icon ticks</b>
  {colour · gray (dots only)}. The three circles stay the Julia anchor in all four:</p>
  <div class="matrix">@MATRIX@</div>
  <p class="hint">Ink letters + colour ticks keeps the icon as the only colour event — cleanest for an icon-left lockup; colouring the caps too makes the word echo the icon (bolder, busier).</p>
</section>

<section>
  <div class="tag">03 · My picks</div>
  <h2>Top 1 &amp; Top 2</h2>
  <p class="lead" style="font-size:17px">Tick heights are fixed to the <b>tachogram</b> in both — the three dots read
  as three inter-beat intervals. The picks differ only in how far the colour spreads:</p>
  <div class="tops">
    <div class="top"><h3><span class="badge b1">TOP 1</span>Ink &amp; anchored</h3>
      <p class="rat">Ink letters · colour ticks · tachogram heights · gray rail (<code>#8A8F98</code>).
      The icon is the single colour event; the word stays calm and legible. My recommendation for the icon-left lockup —
      it shrinks cleanly to a favicon.</p>
      <div class="herobox" style="margin-top:12px">@TOP1@</div></div>
    <div class="top"><h3><span class="badge b2">TOP 2</span>Echoed caps</h3>
      <p class="rat">Coloured caps · colour ticks · tachogram heights · lighter rail (<code>#9AA0A6</code>).
      The H·R·L caps echo the icon's colours — bolder and more expressive, better for hero/marketing than dense body use.</p>
      <div class="herobox" style="margin-top:12px">@TOP2@</div></div>
  </div>
  <div class="props">@PARAMS@</div>
</section>

<footer>
  series-2 top 2 (lock-02 "Tick-Comb Mini"), rebuilt on the solved comb ratios · geometry from
  <code>metrics_900.json</code> via <code>build_comb3.py</code> · gray #8A8F98 · palette #9558B2 #CB3C33 #389826 · self-contained.
</footer>
</div>
<script>
(function(){
  const svg=document.getElementById('hero');
  document.querySelectorAll('.mcard').forEach(c=>{const k=c.dataset.hl;
    c.addEventListener('mouseenter',()=>{c.classList.add('active');svg.classList.add('focus');
      svg.querySelectorAll('.anno').forEach(a=>a.classList.toggle('on',a.dataset.k===k));});
    c.addEventListener('mouseleave',()=>{c.classList.remove('active');svg.classList.remove('focus');
      svg.querySelectorAll('.anno').forEach(a=>a.classList.remove('on'));});
  });
  const HM=location.hash.match(/hl=([a-z]+)/);
  if(HM){const k=HM[1];document.querySelectorAll('.mcard').forEach(c=>c.classList.toggle('active',c.dataset.hl===k));
    svg.classList.add('focus');svg.querySelectorAll('.anno').forEach(a=>a.classList.toggle('on',a.dataset.k===k));}
})();
</script>
</body></html>"""

html=(TPL.replace("@HERO@",hero()).replace("@CARDS@",cards()).replace("@MATRIX@",combo_matrix())
        .replace("@TOP1@",TOP1).replace("@TOP2@",TOP2).replace("@PARAMS@",params()))
(H/"comb_icon_left.html").write_text(html)
print("wrote comb_icon_left.html")
