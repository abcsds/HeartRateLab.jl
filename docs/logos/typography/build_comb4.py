#!/usr/bin/env python3
"""Build comb_animated.html — the three designs together: the bounce animation
combined with TOP 1 (comb-under) and TOP 2 (icon-left). Every bounce transitions
a letter (colour + a little squash). Many variants (colour/ink, build-up/blink,
bounce-across-word / bounce-only-in-the-tiny-tachogram / remote-squash-ball-stays-in-icon).
Geometry from full_metrics.json + the solved comb/icon (JuliaMono Bold, em=1000)."""
import json, pathlib, math, os
H = pathlib.Path(__file__).resolve().parent
# weight-parameterized: HRL_W = 700 (Bold) | 800 (ExtraBold) | 900 (Black)
W = os.environ.get("HRL_W", "700")
WMAP = {"700":("Bold","JuliaMono Bold","JuliaMono-Bold.ttf","full_metrics.json","comb_animated.html"),
        "800":("ExtraBold","JuliaMono ExtraBold","JuliaMono-ExtraBold.ttf","metrics_800.json","comb_animated_800.html"),
        "900":("Black","JuliaMono Black","JuliaMono-Black.ttf","metrics_900.json","comb_animated_900.html")}
WNAME, WLOCAL, WTTF, WMETRICS, WOUT = WMAP[W]
M = json.loads((H/WMETRICS).read_text())
A   = M['advChar']; cap = M['cap']; advW = M['advWidth']
wL, wR = M['wL'], M['wR']; Hc, Rc, Lc = M['H'], M['R'], M['L']
PU, GN, RD, INK, GRAY = "#9558B2", "#389826", "#CB3C33", "#1b1b1f", "#8A8F98"

# ---- TOP 1 (comb under) geometry ----
m=132.0; Rr=300.0; cCy1=m+Rr; combNear1=2*m+2*Rr; combFar1=combNear1+280; tW=84.0
# ---- TOP 2 (icon left) geometry ----
R_M, R_TK = 132/600, 280/600
Oi = cap/(1+R_M+R_TK); Rri=Oi/2; mi=R_M*Oi; tki=R_TK*Oi; wi=0.14*Oi
spacing=Oi+mi; GAP=320.0
c3x=wL-GAP-Rri; c2x=c3x-spacing; c1x=c2x-spacing
railX0i, railX1i = c1x-Rri, c3x+Rri
TACHO=[0.82,1.0,0.58]
CY=[-(l*tki+mi+Rri) for l in TACHO]           # per-dot centres (tachogram)
ICONX=[c1x,c2x,c3x]

# ---------- static SVG pieces ----------
def glyphs(cid):
    out=[]; capcol={0:PU,5:RD,9:GN}
    for i,ch in enumerate("HeartRateLab"):
        x=i*A
        if i in capcol:
            out.append(f'<g id="{cid}-cap{i}" data-cx="{i*A+A/2:.1f}">'
                       f'<text x="{x:.0f}" y="0" font-family="JMBold,monospace" font-size="1000" fill="{INK}">{ch}</text></g>')
        else:
            out.append(f'<text x="{x:.0f}" y="0" font-family="JMBold,monospace" font-size="1000" fill="{INK}">{ch}</text>')
    return "".join(out)

def _tlen(i):   # gray tick length — the tachogram (same law as comb_teeth_up); accents stay at max
    h=170+80*math.sin(i*0.9+0.5)+45*math.sin(i*2.3+1.1)
    return max(70.0,min(272.0,h))
def comb_under():
    s=[f'<line x1="{wL-40:.0f}" y1="{combFar1}" x2="{wR+40:.0f}" y2="{combFar1}" stroke="{GRAY}" stroke-width="{tW}" stroke-linecap="round"/>']
    for i in range(12):
        if i==0: x,col=Hc,PU
        elif i==5: x,col=Rc,RD
        elif i==9: x,col=Lc,GN
        else: x,col=i*A+A/2,GRAY
        w=tW if i in (0,5,9) else tW*0.72
        tip = combNear1 if i in (0,5,9) else combFar1-_tlen(i)
        s.append(f'<line x1="{x:.0f}" y1="{combFar1}" x2="{x:.0f}" y2="{tip:.1f}" stroke="{col}" stroke-width="{w:.0f}" stroke-linecap="round"/>')
    return "".join(s)

def deposits_top1(cid):
    return "".join(f'<circle id="{cid}-c{j}" cx="{x:.0f}" cy="{cCy1:.0f}" r="{Rr:.0f}" fill="{col}" opacity="0"/>'
                   for j,(x,col) in enumerate([(Hc,PU),(Rc,RD),(Lc,GN)]))

def icon(cid, dot_ids=False, dot_hidden=False):
    s=[f'<line x1="{railX0i:.1f}" y1="0" x2="{railX1i:.1f}" y2="0" stroke="{GRAY}" stroke-width="{wi:.1f}" stroke-linecap="round"/>']
    for j in range(3):
        x=ICONX[j]; col=[PU,RD,GN][j]; cyj=CY[j]; tip=cyj+Rri+mi
        s.append(f'<line x1="{x:.1f}" y1="0" x2="{x:.1f}" y2="{tip:.1f}" stroke="{col}" stroke-width="{wi:.1f}" stroke-linecap="round"/>')
        ids=f' id="{cid}-i{j}"' if dot_ids else ''
        op='0' if dot_hidden else '1'
        s.append(f'<circle{ids} cx="{x:.1f}" cy="{cyj:.1f}" r="{Rri:.1f}" fill="{col}" opacity="{op}"/>')
    return "".join(s)

def ballel(R,x0,y0,col=PU):
    return f'<ellipse class="ball" cx="{x0:.1f}" cy="{y0:.1f}" rx="{R:.0f}" ry="{R:.0f}" fill="{col}"/>'

# ---- HRL Ring (series 3, hrl-ring.svg) ----
RINGR=760.0; RDOT=150.0; RGRAY="#9aa0a8"
RING_TICKS=[(0,-690,0,-830),(345,-598,415,-719),(598,-345,719,-415),(690,0,830,0),
 (598,345,719,415),(345,598,415,719),(0,690,0,830),(-345,598,-415,719),
 (-598,345,-719,415),(-690,0,-830,0),(-598,-345,-719,-415),(-345,-598,-415,-719)]
RING_DOTS=[(0,-760,PU),(380,658,RD),(-760,0,GN)]        # purple top, red lower-right, green left
RANG=[math.atan2(y,x) for (x,y,_) in RING_DOTS]          # ball orbits clockwise through these
def ring_static():
    s=[f'<circle cx="0" cy="0" r="{RINGR:.0f}" fill="none" stroke="{RGRAY}" stroke-width="26" opacity="0.7"/>']
    for x1,y1,x2,y2 in RING_TICKS:
        s.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{RGRAY}" stroke-width="26" stroke-linecap="round"/>')
    return "".join(s)
def ring_letters(cid):
    base=227.54; adv=620*0.6
    data=[('H',-565.75,'capH'),('R',-565.75+adv,'capR'),('L',-565.75+2*adv,'capL')]
    out=[]
    for ch,x,key in data:
        out.append(f'<g id="{cid}-{key}" data-cx="{x+adv/2:.1f}" data-by="{base}">'
                   f'<text x="{x:.2f}" y="{base}" font-family="JMBold,monospace" font-weight="700" font-size="620" fill="{INK}">{ch}</text></g>')
    return "".join(out)
def ring_deposits(cid):
    return "".join(f'<circle id="{cid}-i{j}" cx="{x:.0f}" cy="{y:.0f}" r="{RDOT:.0f}" fill="{col}" opacity="0"/>'
                   for j,(x,y,col) in enumerate(RING_DOTS))
def canvas_ring(cid):
    inner=ring_static()+ring_deposits(cid)+ballel(RDOT,0,-760)+f'<g>{ring_letters(cid)}</g>'
    return f'<svg class="anim" id="{cid}" viewBox="-1050 -1050 2100 2100">{inner}</svg>'
def tg_ring(cid,caps):
    keys=['capH','capR','capL']; out=[]
    for j,(x,y,col) in enumerate(RING_DOTS):
        cp=f"{cid}-{keys[j]}" if caps else None
        out.append({"x":round(x,1),"y":round(y,1),"col":col,"cap":cp,"circ":f"{cid}-i{j}","ang":round(RANG[j],5)})
    return out
def C_ring(targets,colorL,squashL,mode,depositMode='accumulate'):
    return {"ball":{"r":RDOT,"x0":0,"y0":-760},"timeUnit":0.42,"apexK":0,"apexMin":0,"wrapApexK":0,
            "colorLetters":colorL,"squashLetters":squashL,"mode":mode,"wrapFade":True,"depositMode":depositMode,
            "ring":{"cx":0,"cy":0,"r":RINGR},"targets":targets}

# ---------- canvases ----------
def canvas_top1(cid):
    vb=f"-160 -900 {advW+320:.0f} 2204"
    inner=comb_under()+deposits_top1(cid)+ballel(Rr,Hc,cCy1)+f'<g>{glyphs(cid)}</g>'
    return f'<svg class="anim" id="{cid}" viewBox="{vb}">{inner}</svg>'

CONTACTW=-(cap+180)
def canvas_word(cid):
    vb=f"-1880 -1420 {advW+2040:.0f} 1560"
    inner=icon(cid)+f'<g>{glyphs(cid)}</g>'+ballel(200,Hc,CONTACTW)
    return f'<svg class="anim" id="{cid}" viewBox="{vb}">{inner}</svg>'

def canvas_icon(cid):
    vb=f"-1880 -900 {advW+2040:.0f} 1040"
    inner=icon(cid,dot_ids=True,dot_hidden=True)+f'<g>{glyphs(cid)}</g>'+ballel(Rri,c1x,CY[0])
    return f'<svg class="anim" id="{cid}" viewBox="{vb}">{inner}</svg>'

# ---------- targets & configs ----------
def T(x,y,col,cap_=None,circ=None): return {"x":round(x,1),"y":round(y,1),"col":col,"cap":cap_,"circ":circ}
def tg_top1(cid): return [T(Hc,cCy1,PU,f"{cid}-cap0",f"{cid}-c0"),T(Rc,cCy1,RD,f"{cid}-cap5",f"{cid}-c1"),T(Lc,cCy1,GN,f"{cid}-cap9",f"{cid}-c2")]
def tg_word(cid): return [T(Hc,CONTACTW,PU,f"{cid}-cap0"),T(Rc,CONTACTW,RD,f"{cid}-cap5"),T(Lc,CONTACTW,GN,f"{cid}-cap9")]
def tg_icon(cid,caps):
    cp=[f"{cid}-cap0",f"{cid}-cap5",f"{cid}-cap9"] if caps else [None,None,None]
    return [T(c1x,CY[0],PU,cp[0],f"{cid}-i0"),T(c2x,CY[1],RD,cp[1],f"{cid}-i1"),T(c3x,CY[2],GN,cp[2],f"{cid}-i2")]

def C(targets,R,start,typ,colorL,squashL,mode,depositMode='accumulate'):
    tu,ak,am,wk=(0.40,0.085,60,0.14) if typ=='big' else (0.55,0.22,40,0.16)
    return {"ball":{"r":R,"x0":round(start[0],1),"y0":round(start[1],1)},"timeUnit":tu,"apexK":ak,
            "apexMin":am,"wrapApexK":wk,"colorLetters":colorL,"squashLetters":squashL,"mode":mode,
            "wrapFade":True,"depositMode":depositMode,"targets":targets}

CONFIGS={
 't1c': C(tg_top1('t1c'),Rr,(Hc,cCy1),'big', True, True,'buildup'),
 't1k': C(tg_top1('t1k'),Rr,(Hc,cCy1),'big', True, True,'blink'),
 't1i': C(tg_top1('t1i'),Rr,(Hc,cCy1),'big', False,False,'buildup'),
 't2wc':C(tg_word('t2wc'),200,(Hc,CONTACTW),'big', True, True,'buildup'),
 't2wk':C(tg_word('t2wk'),200,(Hc,CONTACTW),'big', True, True,'blink'),
 't2wi':C(tg_word('t2wi'),200,(Hc,CONTACTW),'big', False,False,'buildup'),
 't2t': C(tg_icon('t2t',False),Rri,(c1x,CY[0]),'icon',False,False,'buildup'),
 't2tp':C(tg_icon('t2tp',False),Rri,(c1x,CY[0]),'icon',False,False,'buildup','persist'),
 't2rc':C(tg_icon('t2rc',True),Rri,(c1x,CY[0]),'icon',True, True,'buildup'),
 't2rk':C(tg_icon('t2rk',True),Rri,(c1x,CY[0]),'icon',True, True,'blink'),
 'rgc': C_ring(tg_ring('rgc',True), True, True, 'buildup'),
 'rgc2':C_ring(tg_ring('rgc2',True),True, False,'buildup'),
 'rgk': C_ring(tg_ring('rgk',True), True, True, 'blink'),
 'rgk2':C_ring(tg_ring('rgk2',True),True, False,'blink'),
 'rgi': C_ring(tg_ring('rgi',False),False,False,'buildup'),
 'rgis':C_ring(tg_ring('rgis',False),False,False,'buildup','single'),
}
CANVAS={'t1c':canvas_top1,'t1k':canvas_top1,'t1i':canvas_top1,
        't2wc':canvas_word,'t2wk':canvas_word,'t2wi':canvas_word,
        't2t':canvas_icon,'t2tp':canvas_icon,'t2rc':canvas_icon,'t2rk':canvas_icon,
        'rgc':canvas_ring,'rgc2':canvas_ring,'rgk':canvas_ring,'rgk2':canvas_ring,'rgi':canvas_ring,'rgis':canvas_ring}
def cv(cid): return CANVAS[cid](cid)

TPL=r"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeartRateLab · animated · @WLABEL@</title>
<style>
@FONTFACE@
:root{--pu:#9558B2;--gn:#389826;--rd:#CB3C33;--ink:#1b1b1f;--mut:#6b7280;--bg:#fbfbfd;--card:#fff;--line:#e7e8ee;--soft:#f3f4f8}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:1120px;margin:0 auto;padding:0 24px}
.mono{font-family:JMBold,ui-monospace,monospace}code{font-family:JMBold,monospace}
.kick{font-family:JMBold,monospace;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--pu)}
h1{font-size:clamp(28px,5vw,46px);margin:.15em 0 .1em;letter-spacing:-.02em}
h2{font-size:24px;margin:.1em 0 .3em}
.lead{font-size:18px;color:#3b3f46;max-width:840px}
.hero{padding:48px 0 6px}
.dots{display:flex;gap:9px;margin-bottom:16px}.dots i{width:24px;height:24px;border-radius:50%}
.dots i:nth-child(1){background:var(--pu)}.dots i:nth-child(2){background:var(--rd)}.dots i:nth-child(3){background:var(--gn)}
section{padding:30px 0;border-top:1px solid var(--line)}
.tag{font-family:JMBold,monospace;font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--mut)}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:14px}
.cell{border:1px solid var(--line);border-radius:16px;padding:14px 16px;background:#f7f7f9}
.cap{font-family:JMBold,monospace;font-size:12px;letter-spacing:.05em;text-transform:uppercase;color:var(--mut);margin-bottom:8px;display:flex;justify-content:space-between;gap:8px}
.cap b{color:var(--ink)}
svg.anim{width:100%;height:auto;display:block}
.desc{font-size:13.5px;color:#4b5563;margin:.5em 0 0}
.controls{display:flex;gap:10px;align-items:center;margin-top:8px}
button.pp{font-family:JMBold,monospace;font-size:13px;border:1px solid var(--line);background:#fff;border-radius:999px;padding:7px 16px;cursor:pointer}
.note{background:var(--soft);border-left:4px solid var(--gn);border-radius:0 10px 10px 0;padding:12px 16px;margin:14px 0;font-size:15px}.note b{color:var(--gn)}
footer{padding:26px 0 60px;color:var(--mut);font-size:13px;border-top:1px solid var(--line)}
@media(max-width:820px){.grid{grid-template-columns:1fr}}
</style></head>
<body>
<div class="wrap">
<header class="hero">
  <div class="dots"><i></i><i></i><i></i></div>
  <div class="kick">HeartRateLab · three designs, animated · JuliaMono @WLABEL@</div>
  <h1>The bounce, applied to both logos</h1>
  <p class="lead">The <b>bounce animation</b> applied across every mark: <b>Top&nbsp;1</b> (the comb <i>under</i> the word),
  <b>Top&nbsp;2</b> (the tick-comb icon at the <i>left</i>), and the <b>HRL&nbsp;Ring</b> (series&nbsp;3, where the ball
  <i>orbits</i>). On every bounce a letter transitions —
  <b>colour</b> and a small <b>squash</b>, as if the ball nudged it. Shown across variants: letters change colour or
  don't; the colour <b>builds up</b> or <b>blinks</b>; the ball travels the word, or stays home in the tiny tachogram
  and hits the letters from afar. <span class="mono" style="color:var(--mut)">All loop; respect reduced-motion.</span></p>
  <div class="controls"><button class="pp" id="pauseAll">⏸ pause all</button>
    <span class="mono" style="font-size:12px;color:var(--mut)">time ∝ distance · elastic squash · JuliaMono @WLABEL@</span></div>
</header>

<section>
  <div class="tag">Top 1 · comb under · the ball rides the circle row and deposits each dot</div>
  <div class="grid">
    <div class="cell"><div class="cap"><b>colour · build-up</b><span>caps light H→R→L, reset on wrap</span></div>@t1c@
      <p class="desc">Ball bounces along the circle row; each capital colours + squashes on its bounce and stays lit until the wrap.</p></div>
    <div class="cell"><div class="cap"><b>colour · blink</b><span>each cap flashes only on its bounce</span></div>@t1k@
      <p class="desc">Same motion, but each capital flashes to colour just for its own bounce, then falls back to ink.</p></div>
    <div class="cell"><div class="cap"><b>ink · letters unchanged</b><span>only the circles colour</span></div>@t1i@
      <p class="desc">The control: letters stay ink, only the three deposited circles carry colour.</p></div>
    <div class="cell" style="display:flex;align-items:center;justify-content:center;color:var(--mut)">
      <p class="desc" style="text-align:center;max-width:280px">Top 1 keeps the comb static underneath; the animation is the <b>assembly</b> of the mark — dots dropping onto the beats.</p></div>
  </div>
</section>

<section>
  <div class="tag">Top 2 · icon left · the ball can travel the word — or stay in the tiny tachogram</div>
  <div class="grid">
    <div class="cell"><div class="cap"><b>ball on word · colour build-up</b><span>icon static at left</span></div>@t2wc@
      <p class="desc">The ball leaves home and bounces across the big capitals, colouring each; the tick-comb icon sits static at the left.</p></div>
    <div class="cell"><div class="cap"><b>ball on word · colour blink</b><span>icon static at left</span></div>@t2wk@
      <p class="desc">Same, but the caps blink per bounce instead of building up.</p></div>
    <div class="cell"><div class="cap"><b>ball on word · ink</b><span>letters unchanged</span></div>@t2wi@
      <p class="desc">The ball traverses the word but the letters stay ink — motion only.</p></div>
    <div class="cell"><div class="cap"><b>bounce only in the tachogram</b><span>word fully static</span></div>@t2t@
      <p class="desc">The ball hops only among the three tiny dots inside the icon, depositing them; the word doesn't move.</p></div>
    <div class="cell"><div class="cap"><b>bounce in the tachogram · persist</b><span>beats never fade</span></div>@t2tp@
      <p class="desc">Same in-icon bounce, but each deposited dot stays lit for good — after the first pass all three remain, colour never fading out.</p></div>
    <div class="cell"><div class="cap"><b>remote squash · build-up</b><span>ball stays in the icon</span></div>@t2rc@
      <p class="desc">The ball keeps bouncing in the tiny logo, but on every bounce the matching capital colours <b>and squashes</b> — as if remotely nudged. View stays on the whole lockup.</p></div>
    <div class="cell"><div class="cap"><b>remote squash · blink</b><span>ball stays in the icon</span></div>@t2rk@
      <p class="desc">Same remote hit, but the capital flashes its colour per bounce rather than building up.</p></div>
  </div>
  <div class="note"><b>The odd one you asked for.</b> In <b>remote squash</b> the ball never leaves the little icon — each
  bounce reaches out and bumps a letter of the word: it flips to its Julia colour and gives a quick squash-and-recover,
  as though the ball had bounced on it, while the ball itself stays home on the left.</div>
</section>

<section>
  <div class="tag">HRL Ring · series 3 · the ball ORBITS the ring and taps the centred letters</div>
  <p class="lead" style="font-size:17px;margin-top:6px">On the round mark the ball can't travel a line — it
  <b>orbits the ring</b>, hitting the three beats at their unequal clock-spacings (150°·120°·90° — the same rhythm),
  and each pass taps the matching centred letter (colour + squash). Because the ball always stays on the ring, the
  colour variants <i>are</i> the remote-squash behaviour by nature.</p>
  <div class="grid">
    <div class="cell"><div class="cap"><b>orbit · colour build-up</b><span>colour + squash</span></div>@rgc@
      <p class="desc">Each pass over a beat colours + squashes the matching centred letter, and it stays lit until the orbit closes.</p></div>
    <div class="cell"><div class="cap"><b>colour build-up · colour only</b><span>no squash</span></div>@rgc2@
      <p class="desc">The same build-up, but the letters only change colour — no bounce/squash on the type.</p></div>
    <div class="cell"><div class="cap"><b>orbit · colour blink</b><span>colour + squash</span></div>@rgk@
      <p class="desc">Each centred letter flashes to colour as the ball passes its beat, with a squash, then falls back to ink.</p></div>
    <div class="cell"><div class="cap"><b>colour blink · colour only</b><span>no squash</span></div>@rgk2@
      <p class="desc">The blink, colour only — the letter flips to its Julia hue on each pass without the squash.</p></div>
    <div class="cell"><div class="cap"><b>ink · beats accumulate</b><span>all fade on the wrap</span></div>@rgi@
      <p class="desc">HRL stays ink; the three beats deposit around the ring and fade together as the orbit closes.</p></div>
    <div class="cell"><div class="cap"><b>ink · single beat</b><span>one at a time, continuous</span></div>@rgis@
      <p class="desc">Only one beat is lit at a time — as the next appears the previous vanishes, so nothing ever blinks off all at once; the orbit stays continuous.</p></div>
  </div>
</section>

<footer>
  16 live variants · one bounce engine (time ∝ distance, elastic squash, ring orbit) · <b>JuliaMono @WLABEL@</b> ·
  geometry from <code>@WMETRICS@</code> via <code>build_comb4.py</code> · palette #9558B2 #CB3C33 #389826 · gray #8A8F98 · self-contained.
</footer>
</div>
<script>
const CONFIGS = @CONFIGS@;
const INK="#1b1b1f", SQ=190, LSQ=250, BLINK=360;
let PAUSED=false;
function initAnim(el){
  const cfg=CONFIGS[el.id]; if(!cfg) return;
  cfg.targets.forEach((t,i)=>t._idx=i);
  const ball=el.querySelector('.ball'), T=cfg.targets, n=T.length, lerp=(a,b,u)=>a+(b-a)*u;
  const hops=[];
  if(cfg.ring){                                           // orbital: ball rides the ring, time ∝ arc
    for(let i=0;i<n;i++){const a=T[i], b=T[(i+1)%n]; let d=b.ang-a.ang; while(d<=1e-6) d+=2*Math.PI;
      hops.push({ang0:a.ang,dang:d,col:b.col,dur:Math.max(260,cfg.timeUnit*cfg.ring.r*d)});}
  } else {
    for(let i=0;i<n;i++){const a=T[i], b=T[(i+1)%n], dx=b.x-a.x, dist=Math.abs(dx)||1, wrap=(i===n-1);
      hops.push({a,b,col:b.col,dist,wrap,dur:Math.max(260,cfg.timeUnit*dist),apex:(wrap?cfg.wrapApexK:cfg.apexK)*dist+cfg.apexMin});}
  }
  let acc=0; hops.forEach(h=>{h.t0=acc; acc+=h.dur;});
  const cycle=acc, wrapStart=hops[n-1].t0, wrapDur=hops[n-1].dur;
  const arrive=new Array(n); arrive[0]=0; for(let i=0;i<n-1;i++) arrive[i+1]=hops[i].t0+hops[i].dur;
  const dMode=cfg.depositMode||'accumulate', everSeen=new Array(n).fill(false);
  cfg.targets.forEach(t=>{ if(t.circ){const c=el.querySelector('#'+CSS.escape(t.circ)); if(c) c.setAttribute('opacity','0');}});
  function letterState(tg,t){ const aj=arrive[tg._idx]; const dt=t-aj; let colored,sq=0;
    if(cfg.mode==='blink'){ colored=(dt>=0&&dt<BLINK); }
    else { colored=(t>=aj); if(cfg.wrapFade && t>=wrapStart && (t-wrapStart)/wrapDur>0.45) colored=false; }
    if(dt>=0&&dt<LSQ) sq=Math.exp(-5*dt/LSQ);
    return {colored,sq}; }
  function applyLetter(tg,t){ if(!tg.cap) return; if(!(cfg.colorLetters||cfg.squashLetters)) return;
    const g=el.querySelector('#'+CSS.escape(tg.cap)); if(!g) return; const te=g.querySelector('text'); const st=letterState(tg,t);
    if(cfg.colorLetters) te.setAttribute('fill', st.colored? tg.col : INK);
    if(cfg.squashLetters){const cx=+g.dataset.cx, by=+(g.dataset.by||0), sx=1+0.18*st.sq, sy=1-0.32*st.sq;
      g.setAttribute('transform','translate('+cx+','+by+') scale('+sx.toFixed(3)+','+sy.toFixed(3)+') translate('+(-cx)+','+(-by)+')');}}
  function applyDeposit(tg,t,hi){ if(!tg.circ) return; const c=el.querySelector('#'+CSS.escape(tg.circ)); if(!c) return;
    const j=tg._idx; let o;
    if(dMode==='single'){ o=(hi===j)?1:0; }                                  // only the current beat, continuous handoff
    else if(dMode==='persist'){ if(t>=arrive[j]) everSeen[j]=true; o=everSeen[j]?1:0; }  // never fades
    else { o=(t>=arrive[j])?1:0; if(cfg.wrapFade && t>=wrapStart) o*=Math.max(0,1-(t-wrapStart)/wrapDur); }
    c.setAttribute('opacity',o.toFixed(3)); }
  function render(t){
    let hi=n-1; for(let i=0;i<hops.length;i++){ if(t<hops[i].t0+hops[i].dur){hi=i;break;} }
    const h=hops[hi], u=Math.min(1,Math.max(0,(t-h.t0)/h.dur));
    let x,y; if(cfg.ring){const th=h.ang0+h.dang*u; x=cfg.ring.cx+cfg.ring.r*Math.cos(th); y=cfg.ring.cy+cfg.ring.r*Math.sin(th);}
    else { x=lerp(h.a.x,h.b.x,u); y=lerp(h.a.y,h.b.y,u)-4*h.apex*u*(1-u); }
    const since=t-h.t0; const bs=since<SQ?Math.exp(-4.5*since/SQ):0;
    const R=cfg.ball.r; let rx,ry,cy;
    if(cfg.ring){rx=R*(1+0.16*bs);ry=R*(1-0.16*bs);cy=y;} else {rx=R*(1+0.26*bs);ry=R*(1-0.32*bs);cy=y+(R-ry);}
    if(ball){ball.setAttribute('cx',x.toFixed(1));ball.setAttribute('cy',cy.toFixed(1));
      ball.setAttribute('rx',rx.toFixed(1));ball.setAttribute('ry',ry.toFixed(1));ball.setAttribute('fill',h.col);ball.setAttribute('opacity','1');}
    cfg.targets.forEach(tg=>{applyLetter(tg,t);applyDeposit(tg,t,hi);});
  }
  const HM=location.hash.match(/[#&]t=(\d+)/);
  if(HM){ render((+HM[1])%cycle); return; }
  if(matchMedia('(prefers-reduced-motion: reduce)').matches){
    if(ball) ball.setAttribute('opacity','0');
    cfg.targets.forEach(tg=>{ if(tg.circ){const c=el.querySelector('#'+CSS.escape(tg.circ));if(c)c.setAttribute('opacity','1');}
      if(tg.cap&&cfg.colorLetters){const g=el.querySelector('#'+CSS.escape(tg.cap));if(g)g.querySelector('text').setAttribute('fill',tg.col);}});
    return;
  }
  let t0=null,last=0;
  function frame(ts){ if(t0===null)t0=ts; if(!PAUSED){ last=(ts-t0)%cycle; render(last);} else { t0=ts-last; } requestAnimationFrame(frame); }
  requestAnimationFrame(frame);
}
document.querySelectorAll('.anim').forEach(initAnim);
const pb=document.getElementById('pauseAll');
if(pb) pb.onclick=function(){PAUSED=!PAUSED;this.textContent=PAUSED?'▶ play all':'⏸ pause all';};
</script>
</body></html>"""

html=TPL.replace("@CONFIGS@", json.dumps(CONFIGS))
for cid in CONFIGS: html=html.replace("@"+cid+"@", cv(cid))
html=html.replace("@FONTFACE@", "@font-face{font-family:JMBold;font-weight:%s;src:local('%s'),url('fonts/%s')}"%(W,WLOCAL,WTTF))
html=html.replace("@WLABEL@", "%s %s"%(WNAME,W)).replace("@WMETRICS@", WMETRICS)
(H/WOUT).write_text(html)
print("wrote %s   (JuliaMono %s %s · metrics %s · unreplaced @tokens: %d)"%(
    WOUT, WNAME, W, WMETRICS, html.count("@t1c@")+html.count("@FONTFACE@")+html.count("@WLABEL@")))
