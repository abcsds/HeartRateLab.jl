#!/usr/bin/env python3
"""Build hrl_report.html — a self-standing JuliaCon-style report on the
HeartRateLab wordmark in JuliaMono Bold and how it plays with Julia design.
All geometry from full_metrics.json (measured). Fonts linked from fonts/."""
import json, pathlib
H = pathlib.Path(__file__).resolve().parent
M = json.loads((H/"full_metrics.json").read_text())
r = lambda x: round(x)

cap,xh,asc,desc = M['cap'],M['xh'],M['asc'],M['desc']
advC,advW = M['advChar'],M['advWidth']
wL,wR = M['wL'],M['wR']
Hc,Rc,Lc = M['H'],M['R'],M['L']
gHR,gRL,ratio = M['gHR'],M['gRL'],M['ratio']
LET = M['letters']
inkWs=[l['inkW'] for l in LET]; minW,maxW=round(min(inkWs)),round(max(inkWs))
centroid=(Hc+Rc+Lc)/3; wordCtr=(wL+wR)/2; offset=wordCtr-centroid
d_word=2*(Hc-wL); r_word=d_word/2; gap=0.18*cap
d_cap=cap; overhang=wL-(Hc-d_cap/2)
h_ratio=ratio*ratio
PU,GN,RD,BL="#9558B2","#389826","#CB3C33","#4063D8"; INK="#1b1b1f"

# ---------- SVG helpers (em=1000 space) ----------
def ln(x1,y1,x2,y2,c,w,d="",extra=""):
    return f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" stroke="{c}" stroke-width="{w}"{f" stroke-dasharray=\"{d}\"" if d else ""} {extra}/>'
def tx(x,y,s,sz,c,a="start",w=400):
    return f'<text x="{x:.0f}" y="{y:.0f}" font-family="JMBold,monospace" font-size="{sz}" font-weight="{w}" fill="{c}" text-anchor="{a}">{s}</text>'
def wordtext(fill=INK,fam="JMBold"):
    return f'<text x="0" y="0" font-family="{fam},monospace" font-size="1000" fill="{fill}">HeartRateLab</text>'
def bracket(x,y1,y2,c,label):  # vertical measure bracket
    return (f'<line x1="{x}" y1="{y1}" x2="{x}" y2="{y2}" stroke="{c}" stroke-width="4"/>'
            f'<line x1="{x-30}" y1="{y1}" x2="{x+30}" y2="{y1}" stroke="{c}" stroke-width="4"/>'
            f'<line x1="{x-30}" y1="{y2}" x2="{x+30}" y2="{y2}" stroke="{c}" stroke-width="4"/>'
            f'{tx(x-46,(y1+y2)/2+16,label,52,c,"end",700)}')

# ---------- Anatomy SVG (interactive layers) ----------
def anatomy():
    S=[]
    vbX,vbW,vbY,vbH = -520,advW+1040,-1180,1180+desc+560
    S.append(f'<svg id="anatomy" class="anatomy" viewBox="{vbX} {vbY} {vbW} {vbH}">')
    # advance grid layer
    g=['<g class="layer" data-k="advance">']
    for i in range(13):
        x=i*advC
        g.append(ln(x,-cap-40,x,desc+120,"#c9cdd6",2,"4 10"))
    for i in range(12):
        g.append(f'<rect x="{i*advC}" y="{-cap}" width="{advC}" height="{cap}" fill="{"#eef0f4" if i%2 else "#f6f7fa"}" opacity="0.6"/>')
    g.append(tx(advW/2,desc+300,f"advance 600 × 12 (monospace — identical)",50,"#7a8091","middle",700))
    g.append('</g>'); S+=g
    # ink-width boxes layer
    g=['<g class="layer" data-k="ink">']
    for l in LET:
        g.append(f'<rect x="{l["inkL"]}" y="{-cap}" width="{l["inkW"]}" height="{cap}" fill="none" stroke="#8a90a0" stroke-width="2" stroke-dasharray="4 6" opacity="0.8"/>')
    g.append(tx(advW/2,desc+300,f"ink width varies {minW:.0f}–{maxW:.0f} (≈10%)",50,"#7a8091","middle",700))
    g.append('</g>'); S+=g
    # reference lines layers
    S.append(f'<g class="layer" data-k="baseline">{ln(vbX+40,0,advW+300,0,INK,4)}{tx(vbX+40,-14,"baseline y=0",50,INK)}</g>')
    S.append(f'<g class="layer" data-k="cap">{ln(vbX+40,-cap,advW+300,-cap,RD,3,"16 10")}{bracket(-160,0,-cap,RD,f"cap {cap:.0f}")}{tx(vbX+40,-cap-16,f"cap-height {cap:.0f}",50,RD)}</g>')
    S.append(f'<g class="layer" data-k="xh">{ln(vbX+40,-xh,advW+300,-xh,"#b06a1e",2,"6 12")}{bracket(647-60,0,-xh,"#b06a1e",f"x {xh:.0f}")}{tx(vbX+40,-xh-14,f"x-height {xh:.0f}",46,"#b06a1e")}</g>')
    S.append(f'<g class="layer" data-k="asc">{ln(vbX+40,-asc,advW+300,-asc,BL,2,"3 12")}{tx(vbX+40,-asc-14,f"ascender {asc:.0f}",46,BL)}</g>')
    S.append(f'<g class="layer" data-k="desc">{ln(vbX+40,desc,advW+300,desc,"#8a90a0",2,"3 12")}{tx(vbX+40,desc+56,f"descender {desc:.0f} — none occur in the word",44,"#8a90a0")}</g>')
    # word ink span
    S.append(f'<g class="layer" data-k="wordink">'
             f'{ln(wL,-cap-120,wL,desc+60,"#5b6472",2,"10 8")}{ln(wR,-cap-120,wR,desc+60,"#5b6472",2,"10 8")}'
             f'{tx(wL,-cap-134,f"ink L {wL:.0f}",44,"#5b6472","middle")}{tx(wR,-cap-134,f"ink R {wR:.0f}",44,"#5b6472","middle")}</g>')
    # optical centres
    cg=['<g class="layer" data-k="centers">']
    for cx,c,nm in [(Hc,PU,"H"),(Rc,RD,"R"),(Lc,GN,"L")]:
        cg.append(ln(cx,-cap-90,cx,desc+120,c,3,"2 8"))
        cg.append(tx(cx,desc+230,f"{nm} centre {cx:.0f}",48,c,"middle",700))
    cg.append('</g>'); S+=cg
    # hops
    hy=desc+430
    def dim(x1,x2,y,label,c):
        return (ln(x1,y,x2,y,c,3)+ln(x1,y-26,x1,y+26,c,3)+ln(x2,y-26,x2,y+26,c,3)+
                tx((x1+x2)/2,y-14,label,50,c,"middle",700))
    S.append(f'<g class="layer" data-k="hops">{dim(Hc,Rc,hy,f"H→R {gHR:.0f}",INK)}{dim(Rc,Lc,hy,f"R→L {gRL:.0f}",INK)}'
             f'{tx((Hc+Lc)/2,hy+72,f"ratio {ratio:.2f} : 1",50,INK,"middle",700)}</g>')
    # the word (always visible, on top)
    S.append(f'<g class="wordlayer">{wordtext(INK)}</g>')
    S.append('</svg>')
    return "".join(S)

# metric cards: (key, title, value, description)
CARDS=[
 ("baseline","Baseline","y = 0","The line the letters sit on and the origin for every vertical measure."),
 ("cap",f"Cap-height","%d"%r(cap),"Height of the capitals H, R, L — how tall the three coloured “beats” reach."),
 ("xh","x-height","%d"%r(xh),"Body height of the lowercase. %d%% of cap — a tall x-height gives JuliaMono its even, technical texture."%r(xh/cap*100)),
 ("asc","Ascender","%d"%r(asc),"Top of tall lowercase (b, t, l). Sits just above the cap line."),
 ("desc","Descender","%d"%r(desc),"Depth below the baseline (g, p, y). None of HeartRateLab's letters descend, so the baseline edge stays clean."),
 ("advance","Advance / char","600 ×12","The fixed cell every glyph occupies — the defining monospace property. Identical for all twelve letters."),
 ("wordink","Word ink span","%d–%d"%(r(wL),r(wR)),"Left-most to right-most actual ink: H's stem to b's bowl."),
 ("ink","Ink width","%d–%d"%(minW,maxW),"The real black width of each glyph inside its 600 cell — it varies ≈10% even though the advance never does."),
 ("centers","Optical centres","%d · %d · %d"%(r(Hc),r(Rc),r(Lc)),"The visual middle of each capital's ink — where a dot must sit to look centred (not the cell centre)."),
 ("hops","Hops H→R · R→L","%d · %d"%(r(gHR),r(gRL)),"Centre-to-centre distance between the capitals. Ratio %.2f : 1 — exactly Heart(5) : Rate(4)."%ratio),
]
def cards_html():
    out=[]
    for k,t,v,d in CARDS:
        out.append(f'<div class="mcard" data-hl="{k}"><div class="mtop"><span class="mtitle">{t}</span>'
                   f'<span class="mval">{v}</span></div><p>{d}</p></div>')
    return "\n".join(out)

# ---------- letter width visuals ----------
def widths_svg():
    S=[f'<svg viewBox="-40 -240 {advW+80} 560" class="wfig">']
    # advance cells (equal)
    for i,l in enumerate(LET):
        S.append(f'<rect x="{i*advC}" y="-200" width="{advC}" height="200" fill="#eef0f4" stroke="#cfd3db" stroke-width="2"/>')
        c = PU if l['c']=='H' and i==0 else RD if l['c']=='R' and i==5 else GN if l['c']=='L' and i==9 else "#3a3f4a"
        S.append(f'<rect x="{l["inkL"]}" y="-200" width="{l["inkW"]}" height="200" fill="{c}" opacity="0.5"/>')
        S.append(tx(i*advC+advC/2,150,l['c'],120,"#3a3f4a" if c=="#3a3f4a" else c,"middle",700))
        S.append(tx(i*advC+advC/2,-60,f"{l['inkW']:.0f}",60,"#fff","middle",700))
    S.append(tx(advW/2,300,"grey cell = advance 600 (same for all) · filled = ink width (varies)",56,"#7a8091","middle"))
    S.append('</svg>')
    return "".join(S)

# ---------- gallery ----------
WEIGHTS=[("Light","JMLight"),("Regular","JMRegular"),("Medium","JMMedium"),
         ("SemiBold","JMSemiBold"),("Bold","JMBold"),("ExtraBold","JMExtraBold")]
def colored_word(fam,size=54,dark=False):
    col="#e9e9ee" if dark else INK
    return (f'<span class="cw" style="font-family:{fam},monospace;font-size:{size}px;color:{col}">'
            f'<b style="color:{PU}">H</b>eart<b style="color:{RD}">R</b>ate<b style="color:{GN}">L</b>ab</span>')
def gallery_ladder():
    rows=[f'<div class="grow"><span class="glab">{n}</span>{colored_word(f)}</div>' for n,f in WEIGHTS]
    return "".join(rows)
def hero_lockup():
    # word (black) + three colour dots above the caps at measured centres
    rr=170; gp=140; cy=-(cap+gp+rr)
    dots="".join(f'<circle cx="{c:.0f}" cy="{cy:.0f}" r="{rr}" fill="{col}"/>' for c,col in [(Hc,PU),(Rc,RD),(Lc,GN)])
    vb=f"-60 {cy-rr-40:.0f} {advW+120} {(cy-rr-40)*-1+desc+60:.0f}"
    return f'<svg class="hero-svg" viewBox="{vb}">{dots}<g>{wordtext(INK)}</g></svg>'

# ---------- balance ----------
def balance_svg():
    rr=r_word; gp=gap; cy=-(cap+gp+rr)
    vbTop=-(cap+gp+d_cap)-130; vbBot=desc+700
    S=[f'<svg id="balance" class="anatomy" viewBox="-520 {vbTop:.0f} {advW+1040} {vbBot-vbTop:.0f}">']
    S.append(f'<g>{wordtext("#c9ccd3")}</g>')                      # word — always visible
    S.append(ln(-520,0,advW+300,0,INK,4))                          # baseline — always visible
    # optical layer
    g=['<g class="layer" data-k="optical">']
    for c,col in [(Hc,PU),(Rc,RD),(Lc,GN)]:
        g.append(ln(c,-cap-40,c,desc+140,col,2.5,"3 9"))
        g.append(f'<circle cx="{c:.0f}" cy="{cy:.0f}" r="{rr:.0f}" fill="{col}" stroke="#fff" stroke-width="6"/>')
    g.append(tx((Hc+Lc)/2,cy-rr-40,f"dots on ink centres {Hc:.0f} · {Rc:.0f} · {Lc:.0f}  (not the 600-cell)",50,INK,"middle",700))
    g.append('</g>'); S+=g
    # collision layer
    g=['<g class="layer" data-k="collision">']
    for c,col in [(Hc,PU),(Rc,RD),(Lc,GN)]:
        g.append(f'<circle cx="{c:.0f}" cy="{-(cap+gp+d_cap/2):.0f}" r="{d_cap/2:.0f}" fill="none" stroke="{col}" stroke-width="3" stroke-dasharray="7 9"/>')
    hxl=Hc-d_cap/2
    g.append(f'<rect x="{hxl:.0f}" y="{-(cap+gp+d_cap):.0f}" width="{wL-hxl:.0f}" height="{d_cap:.0f}" fill="{RD}" opacity="0.30"/>')
    g.append(ln(wL,-(cap+gp+d_cap),wL,desc+40,"#555",2,"8 8"))
    g.append(tx(Hc,-(cap+gp+d_cap)-35,f"Ø=cap ({d_cap:.0f}) overhangs word-left by {overhang:.0f}",50,RD,"middle",700))
    g.append('</g>'); S+=g
    # leftpull layer
    g=['<g class="layer" data-k="leftpull">']
    g.append(ln(centroid,-cap-40,centroid,desc+300,"#333",3,"2 8"))
    g.append(ln(wordCtr,-cap-40,wordCtr,desc+300,"#999",3,"2 8"))
    g.append(f'<line x1="{centroid:.0f}" y1="{desc+210:.0f}" x2="{wordCtr:.0f}" y2="{desc+210:.0f}" stroke="{RD}" stroke-width="4"/>')
    g.append(tx(centroid,desc+380,f"dots centroid {centroid:.0f}",48,"#333","middle",700))
    g.append(tx(wordCtr,desc+440,f"word centre {wordCtr:.0f}  (beats sit {offset:.0f} left)",48,"#999","middle"))
    g.append('</g>'); S+=g
    # which layer
    g=['<g class="layer" data-k="which">']
    abL=LET[10]["inkL"]; abR=LET[11]["inkR"]
    g.append(f'<rect x="{abL:.0f}" y="{-cap:.0f}" width="{abR-abL:.0f}" height="{cap:.0f}" fill="#c9a227" opacity="0.28"/>')
    g.append(tx((abL+abR)/2,desc+130,"bare “ab” tail — no beat",50,"#a9820a","middle",700))
    g.append(f'<circle cx="{Hc:.0f}" cy="{cy:.0f}" r="{rr:.0f}" fill="none" stroke="{PU}" stroke-width="5"/>')
    g.append(tx(Hc,cy-rr-35,"H hugs the left edge",48,PU,"middle",700))
    g.append('</g>'); S+=g
    S.append('</svg>')
    return "".join(S)

# ---------- animation + path geometry (contact line sits ABOVE the letters) ----------
DOTR,DOTM = 200,120
Afloor = -(cap+DOTM+DOTR)                 # dot centre / contact line, clear of the caps
mL=mR = 520
leftEdge,rightEdge = -mL, advW+mR
Abase,gref = 680.0, gRL
apexOf = lambda d: Abase*(d/gref)**2
apH,apG = apexOf(gHR), apexOf(gRL)
sr,sl = rightEdge-Lc, Hc-leftEdge
Dw = sr+sl; apW = apexOf(Dw); maxAp = max(apH,apG,apW)
AVBX = f"{leftEdge-140:.0f} {Afloor-maxAp-DOTR-140:.0f} {rightEdge-leftEdge+280:.0f} {(-(Afloor-maxAp-DOTR-140))+desc+200:.0f}"

def path_svg():
    F=Afloor; S=[f'<svg viewBox="{AVBX}" class="rfig">']
    S.append(f'<g>{wordtext("#d8dbe2")}</g>')
    S.append(ln(leftEdge-120,0,rightEdge+120,0,"#c3c7d0",3))
    S.append(ln(leftEdge-120,F,rightEdge+120,F,"#9aa0aa",2,"12 10"))
    S.append(tx(leftEdge-90,F-24,"contact line — the dot sits here, on top of the letter (margin above the caps)",50,"#8a90a0"))
    for x,lab in [(leftEdge,f"left margin {mL}"),(rightEdge,f"right margin {mR}")]:
        S.append(ln(x,F-maxAp-40,x,desc+70,"#c9a227",2,"7 8"))
        S.append(tx(x,desc+150,lab,50,"#a9820a","middle",700))
    # hops H->R, R->L
    S.append(f'<path d="M {Hc:.0f} {F:.0f} Q {(Hc+Rc)/2:.0f} {F-2*apH:.0f} {Rc:.0f} {F:.0f}" fill="none" stroke="{RD}" stroke-width="8"/>')
    S.append(f'<path d="M {Rc:.0f} {F:.0f} Q {(Rc+Lc)/2:.0f} {F-2*apG:.0f} {Lc:.0f} {F:.0f}" fill="none" stroke="{GN}" stroke-width="8"/>')
    # wrap: right half (L -> right edge, apex) and left half (left edge, apex -> H)
    S.append(f'<path d="M {Lc:.0f} {F:.0f} Q {(Lc+rightEdge)/2:.0f} {F-apW:.0f} {rightEdge:.0f} {F-apW:.0f}" fill="none" stroke="{PU}" stroke-width="8"/>')
    S.append(f'<path d="M {leftEdge:.0f} {F-apW:.0f} Q {(leftEdge+Hc)/2:.0f} {F-apW:.0f} {Hc:.0f} {F:.0f}" fill="none" stroke="{PU}" stroke-width="8"/>')
    S.append(ln(rightEdge,F-apW,leftEdge,F-apW,PU,4,"16 10"))
    S.append(f'<path d="M {leftEdge+70:.0f} {F-apW:.0f} l 70 -46 l 0 92 z" fill="{PU}"/>')
    S.append(tx((leftEdge+rightEdge)/2,F-apW-30,"wrap — exits the right edge, re-enters the left at the same height",54,PU,"middle",700))
    # deposit dots
    for x,c,nm in [(Hc,PU,"H"),(Rc,RD,"R"),(Lc,GN,"L")]:
        S.append(f'<circle cx="{x:.0f}" cy="{F:.0f}" r="{DOTR}" fill="{c}" stroke="#fff" stroke-width="6"/>')
        S.append(tx(x,F+DOTR+80,nm,70,c,"middle",700))
    S.append(tx((Hc+Rc)/2,F-2*apH-34,f"H→R {gHR:.0f} · red",52,RD,"middle",700))
    S.append(tx((Rc+Lc)/2,F-2*apG-34,f"R→L {gRL:.0f} · green",52,GN,"middle",700))
    S.append(tx(Lc+sr/2,F-apW*0.5,f"sr {sr:.0f}",50,PU,"middle",700))
    S.append(tx(leftEdge+sl/2,F-apW*0.5,f"sl {sl:.0f}",50,PU,"middle",700))
    S.append('</svg>'); return "".join(S)

def bounce_svg():
    F=Afloor; S=[f'<svg id="bounce" class="rfig" viewBox="{AVBX}">']
    S.append(ln(leftEdge-120,0,rightEdge+120,0,"#1b1b1f",4))
    S.append(f'<g>{wordtext("#d0d3da")}</g>')
    S.append(ln(leftEdge-120,F,rightEdge+120,F,"#e3e5eb",2,"12 12"))
    for nm,x,c in [("H",Hc,PU),("R",Rc,RD),("L",Lc,GN)]:
        S.append(f'<circle id="d{nm}" cx="{x:.0f}" cy="{F:.0f}" r="{DOTR}" fill="{c}" opacity="0"/>')
    S.append('<g id="ghosts"></g>')
    S.append(f'<ellipse id="wball" cx="0" cy="{F:.0f}" rx="{DOTR}" ry="{DOTR}" fill="{PU}" opacity="0"/>')
    S.append(f'<ellipse id="ball" cx="{Hc:.0f}" cy="{F:.0f}" rx="{DOTR}" ry="{DOTR}" fill="{PU}"/>')
    S.append('</svg>'); return "".join(S)

TPL_VARS=dict(
  cap=r(cap),xh=r(xh),asc=r(asc),desc=r(desc),advC=advC,advW=advW,wL=r(wL),wR=r(wR),
  Hc=r(Hc),Rc=r(Rc),Lc=r(Lc),gHR=r(gHR),gRL=r(gRL),ratio=f"{ratio:.2f}",hratio=f"{h_ratio:.3f}",
  minW=minW,maxW=maxW,centroid=r(centroid),wordCtr=r(wordCtr),offset=r(offset),
  d_word=r(d_word),d_cap=r(d_cap),overhang=r(overhang),
  anatomy=anatomy(),cards=cards_html(),widths=widths_svg(),ladder=gallery_ladder(),
  hero=hero_lockup(),balance=balance_svg(),
  capfrac=f"{cap/1000:.2f}", xfrac=f"{xh/cap*100:.0f}",
  # animation timing (ms), t ∝ distance
  tHR=r(gHR/ (gHR+gRL) * 1600), tRL=r(gRL/(gHR+gRL)*1600),
)
# bounce viewBox
TPL_VARS.update(bvY=-2500, bvW=advW+120, bvH=2500+desc+220)

TEMPLATE = r"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HeartRateLab · Wordmark Anatomy · JuliaMono Bold</title>
<style>
@font-face{font-family:JMLight;src:local('JuliaMono Light'),url('fonts/JuliaMono-Light.ttf')}
@font-face{font-family:JMRegular;src:local('JuliaMono Regular'),local('JuliaMono'),url('fonts/JuliaMono-Regular.ttf')}
@font-face{font-family:JMMedium;src:local('JuliaMono Medium'),url('fonts/JuliaMono-Medium.ttf')}
@font-face{font-family:JMSemiBold;src:local('JuliaMono SemiBold'),url('fonts/JuliaMono-SemiBold.ttf')}
@font-face{font-family:JMBold;src:local('JuliaMono Bold'),url('fonts/JuliaMono-Bold.ttf')}
@font-face{font-family:JMExtraBold;src:local('JuliaMono ExtraBold'),url('fonts/JuliaMono-ExtraBold.ttf')}
:root{--pu:#9558B2;--gn:#389826;--rd:#CB3C33;--bl:#4063D8;--ink:#1b1b1f;--mut:#6b7280;
--bg:#fbfbfd;--card:#fff;--line:#e7e8ee;--soft:#f3f4f8}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
font:16px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.wrap{max-width:1120px;margin:0 auto;padding:0 24px}
code,.mono{font-family:JMBold,ui-monospace,monospace}
.kick{font-family:JMBold,monospace;font-size:13px;letter-spacing:.14em;text-transform:uppercase;color:var(--pu)}
h1{font-size:clamp(30px,5vw,52px);margin:.15em 0 .1em;letter-spacing:-.02em}
h2{font-size:26px;margin:.2em 0 .3em}
.lead{font-size:19px;color:#3b3f46;max-width:760px}
section{padding:40px 0;border-top:1px solid var(--line)}
.tag{font-family:JMBold,monospace;font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--mut)}
/* hero */
.hero{padding:56px 0 30px;border:0}
.dots{display:flex;gap:9px;margin-bottom:16px}
.dots i{width:26px;height:26px;border-radius:50%;display:block}
.dots i:nth-child(1){background:var(--pu)}.dots i:nth-child(2){background:var(--rd)}.dots i:nth-child(3){background:var(--gn)}
.hero-svg{width:100%;max-width:900px;height:auto;margin:26px auto 0;display:block}
.chips{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}
.chip{background:var(--card);border:1px solid var(--line);border-radius:999px;padding:6px 14px;font-size:13px;color:var(--mut)}
.chip b{color:var(--ink)}
/* anatomy */
.hint{font-size:14px;color:var(--mut);margin:.2em 0 14px}
.anawrap{background:#f7f7f9;border:1px solid var(--line);border-radius:16px;padding:16px}
svg.anatomy{width:100%;height:auto;display:block}
.anatomy .layer{transition:opacity .16s}
.anatomy.focus .layer:not(.on){opacity:.06}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:12px;margin-top:18px}
.subtag{font-family:JMBold,monospace;font-size:12px;letter-spacing:.1em;text-transform:uppercase;color:var(--mut);margin:20px 0 6px}
.mcard{border:1px solid var(--line);border-radius:12px;padding:12px 14px;background:var(--card);cursor:default;transition:border-color .15s,box-shadow .15s,transform .1s}
.mcard:hover,.mcard.active{border-color:var(--pu);box-shadow:0 6px 20px rgba(149,88,178,.12);transform:translateY(-1px)}
.mtop{display:flex;justify-content:space-between;align-items:baseline;gap:10px}
.mtitle{font-weight:700}.mval{font-family:JMBold,monospace;color:var(--pu);font-size:15px;white-space:nowrap}
.mcard p{margin:.35em 0 0;font-size:14px;color:#4b5563}
/* figures */
.fig{background:#f7f7f9;border:1px solid var(--line);border-radius:16px;padding:14px;margin:16px 0}
svg.wfig,svg.bfig,svg.rfig{width:100%;height:auto;display:block}
.note{background:var(--soft);border-left:4px solid var(--gn);border-radius:0 10px 10px 0;padding:12px 16px;margin:14px 0;font-size:15px}
.note b{color:var(--gn)}
/* gallery */
.grow{display:flex;align-items:center;gap:20px;padding:12px 16px;border-bottom:1px solid var(--line)}
.glab{font-family:JMBold,monospace;font-size:12px;color:var(--mut);width:92px;flex:none;letter-spacing:.06em}
.cw b{font-weight:inherit}
.dark{background:#17171c;border-radius:14px;padding:26px;margin-top:16px;text-align:center}
.treat{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-top:16px}
.tile{border:1px solid var(--line);border-radius:14px;padding:22px;text-align:center;background:var(--card)}
.tile.dk{background:#17171c;border-color:#000}
.tcap{font-family:JMBold,monospace;font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:var(--mut);margin-top:12px}
/* two-col text */
.cols2{display:grid;grid-template-columns:1fr 1fr;gap:24px}
.stat{display:flex;gap:14px;align-items:baseline;padding:8px 0;border-bottom:1px dashed var(--line)}
.stat b{font-family:JMBold,monospace;color:var(--rd);min-width:120px;display:inline-block}
.big{font-family:JMBold,monospace;font-size:34px}
.playrow{display:flex;gap:12px;align-items:center;margin-top:10px}
button.pp{font-family:JMBold,monospace;font-size:13px;border:1px solid var(--line);background:var(--card);border-radius:999px;padding:7px 16px;cursor:pointer}
footer{padding:30px 0 60px;color:var(--mut);font-size:13px;border-top:1px solid var(--line)}
@media(max-width:820px){.anacols{grid-template-columns:1fr}.anawrap{position:static}.cols2{grid-template-columns:1fr}.treat{grid-template-columns:1fr}}
</style></head>
<body>
<div class="wrap">
<header class="hero">
  <div class="dots"><i></i><i></i><i></i></div>
  <div class="kick">JuliaCon 2026 · Type Study</div>
  <h1>Anatomy of a Wordmark</h1>
  <p class="lead"><b>HeartRateLab</b> set in <b>JuliaMono&nbsp;Bold</b> — the official Julia typeface — measured glyph by glyph, and lined up against Julia's three-dot, four-colour design language.</p>
  §hero§
  <div class="chips">
    <span class="chip"><b>Font</b> JuliaMono Bold · monospace</span>
    <span class="chip"><b>Cap-height</b> §cap§ / 1000 em</span>
    <span class="chip"><b>Hop ratio</b> §ratio§ : 1</span>
    <span class="chip"><b>Palette</b> purple · red · green</span>
  </div>
</header>

<section>
  <div class="tag">01 · The typeface</div>
  <h2>A monospaced Roman with an even, technical texture</h2>
  <p class="lead" style="font-size:17px">JuliaMono is the community's scientific/technical typeface. Every glyph sits in an identical <b>600-unit</b> cell, giving the wordmark a steady grid — the same evenness that makes it read as “code”, and the property that turns three capitals into three predictable beats.</p>
</section>

<section id="sec-metrics">
  <div class="tag">02 · Metrics</div>
  <h2>Every measure, described — hover to light it up</h2>
  <p class="hint">Hover a card → the matching guide is highlighted on the glyphs (everything else dims). All values in em units (font-size 1000).</p>
  <div class="anawrap">§anatomy§</div>
  <div class="cards">§cards§</div>
</section>

<section>
  <div class="tag">03 · Letter widths</div>
  <h2>Is every letter the same width? Advance yes — ink no</h2>
  <div class="fig">§widths§</div>
  <div class="note"><b>Answer.</b> The <b>advance</b> width is identical — <b>600</b> for all twelve glyphs; that <i>is</i> monospace. The <b>ink</b> (actual black) width varies from <b>§minW§</b> (H, t) to <b>§maxW§</b> (r, R), about 10%. So the letters are spaced on a perfect grid but drawn with slightly different amounts of black — which is exactly why the optical centre of a capital is not the same as its cell centre.</p></div>
</section>

<section>
  <div class="tag">04 · Colour &amp; weight</div>
  <h2>Colouring the three capitals</h2>
  <p class="lead" style="font-size:17px">The three caps H · R · L are the only uppercase in the word — the consonant onsets of <b>Heart · Rate · Lab</b>. Tint them in the three Julia colours and the triplet snaps forward as a heartbeat cadence, at every weight.</p>
  <div class="fig" style="padding:0">§ladder§</div>
  <div class="treat">
    <div class="tile"><span class="cw" style="font-family:JMBold;font-size:40px;color:#1b1b1f">HeartRateLab</span><div class="tcap">ink only</div></div>
    <div class="tile"><span class="cw" style="font-family:JMBold;font-size:40px"><b style="color:#9558B2">H</b>eart<b style="color:#CB3C33">R</b>ate<b style="color:#389826">L</b>ab</span><div class="tcap">coloured caps</div></div>
    <div class="tile dk"><span class="cw" style="font-family:JMBold;font-size:40px;color:#e9e9ee"><b style="color:#9558B2">H</b>eart<b style="color:#CB3C33">R</b>ate<b style="color:#389826">L</b>ab</span><div class="tcap" style="color:#888">on dark</div></div>
  </div>
  <div class="dark"><span class="cw" style="font-family:JMBold;font-size:52px;color:#e9e9ee"><b style="color:#9558B2">H</b>eart<b style="color:#CB3C33">R</b>ate<b style="color:#389826">L</b>ab</span></div>
</section>

<section id="sec-balance">
  <div class="tag">05 · Balance, pulls &amp; collisions</div>
  <h2>Where the three dots want to sit — and where they fight the word</h2>
  <p class="hint">Hover a concept → its variables light up on the figure (everything else dims).</p>
  <div class="anawrap">§balance§</div>
  <div class="cards">
    <div class="mcard" data-hl="optical"><div class="mtop"><span class="mtitle">Optical centres</span><span class="mval">§Hc§·§Rc§·§Lc§</span></div><p>Dots sit on each capital's <b>ink</b> centre, not its 600-cell centre — R and L especially would look off-centre on the grid.</p></div>
    <div class="mcard" data-hl="collision"><div class="mtop"><span class="mtitle">Collision</span><span class="mval">+§overhang§</span></div><p>A dot at <code>Ø=cap (§d_cap§)</code> on H <b>overhangs the word's left edge by §overhang§</b>. The largest that stays inside is <code>Ø=§d_word§</code>.</p></div>
    <div class="mcard" data-hl="leftpull"><div class="mtop"><span class="mtitle">Left pull</span><span class="mval">§offset§ left</span></div><p>The beats' centroid <code>§centroid§</code> sits <b>§offset§ left</b> of the word's centre <code>§wordCtr§</code> — the mark is front-loaded.</p></div>
    <div class="mcard" data-hl="which"><div class="mtop"><span class="mtitle">Which letters</span><span class="mval">H · “ab”</span></div><p>H hugs the left edge (overhang risk); the trailing <b>“ab”</b> adds right-side weight with no beat to answer it — the real balance decision.</p></div>
  </div>
</section>

<section>
  <div class="tag">06 · Rhythm, the path &amp; the bounce</div>
  <h2>Three beats, a wrap, and the loop that closes it</h2>
  <div class="cols2">
    <div>
      <p>The two gaps are <code>H→R = §gHR§</code> and <code>R→L = §gRL§</code> — ratio <span class="big" style="color:var(--pu)">§ratio§ : 1</span>, exactly Heart (5) : Rate (4).</p>
      <p><b>Constant horizontal speed ⇒ time of flight ∝ distance</b> (a frictionless bounce). So the two long hops genuinely hang longer than the short one: H→R <b>§t1ms§ ms</b>, R→L <b>§t2ms§ ms</b>, wrap <b>§t3ms§ ms</b>. Apex ∝ distance² (<b>height §hratio§ : 1</b>). The ball <b>never stops</b> — each contact is a quick <b>elastic squash</b> that launches straight into the next hop.</p>
      <p><b>Does the three-note rhythm have a name?</b> Spoken, <b>HEART·RATE·LAB</b> is three equal stresses — a <b>molossus</b> (— — —). Musically a <b>triplet</b>; the 1.25 spacing makes it a gently <b>swung / dotted</b> triplet. It rhymes with the cardiac cycle the package measures.</p>
    </div>
    <div>
      <p><b>The looping path.</b> One ball, four segments, all timed so speed is constant (<b>time ∝ distance</b>): H→R (red), R→L (green), then a <b>wrap</b> — it rises off the right edge and re-enters at the left edge at the same height — carrying it L→H (purple) to start again.</p>
      <p><b>Why the margins matter.</b> The wrap crosses the canvas edges, so the left/right margins set its two spans <code>sr=§sr§</code> (L→right) and <code>sl=§sl§</code> (left→H); together <code>§Dw§</code>, which fixes the wrap arc's height and duration. Wider margins → a bigger, slower return.</p>
      <p>The ball always wears the <b>colour it's about to stamp</b> (anticipation) and deposits its Julia dot <b>on top of the letter, with a margin</b>. The three dots fade out during the wrap, so the loop is seamless.</p>
    </div>
  </div>
  <div class="subtag">The path — trajectory, deposits &amp; the wrap (margins in gold)</div>
  <div class="fig">§path§</div>
  <div class="subtag">Live — it loops forever · stamps purple → red → green → wrap</div>
  <div class="fig">§bounce§</div>
  <div class="playrow"><button class="pp" id="pp">⏸ pause</button>
    <span style="font-size:13px;color:var(--mut)">one ball · no stop · time ∝ distance (§t1ms§ / §t2ms§ / §t3ms§ ms) · elastic squash · smear ghosts</span></div>
</section>

<section>
  <div class="tag">07 · How it plays with Julia design</div>
  <h2>Takeaways</h2>
  <div class="cols2">
    <div>
      <div class="stat"><b>Three &amp; three</b><span>Three Julia dots ↔ three capitals ↔ three syllables. The logo's core motif maps one-to-one onto the word.</span></div>
      <div class="stat"><b>Palette</b><span>Purple / red / green on H / R / L gives an instant Julia-family read using three of the four brand hexes; blue stays as an accent.</span></div>
    </div>
    <div>
      <div class="stat"><b>Monospace = identity</b><span>The even 600-grid reads “scientific/technical” — apt for an HRV analysis package, and it makes the rhythm exact (5:4).</span></div>
      <div class="stat"><b>Motion is built-in</b><span>The uneven hop is intrinsic to the word, so an animation doesn't impose rhythm — it reveals one.</span></div>
    </div>
  </div>
</section>

<footer>
  Measured from JuliaMono Bold (em 1000) with headless Chromium canvas metrics · all figures regenerate from <code>full_metrics.json</code> via <code>build_report.py</code> · Julia palette #9558B2 #389826 #CB3C33 #4063D8. Self-contained; fonts in <code>fonts/</code>.
</footer>
</div>

<script>
// hover-highlight — wired for metrics (sec 02) and balance (sec 05)
function wireHover(sel, svg){
  if(!svg) return;
  document.querySelectorAll(sel).forEach(c=>{ const k=c.dataset.hl;
    c.addEventListener('mouseenter',()=>{svg.classList.add('focus');
      svg.querySelectorAll('.layer').forEach(L=>L.classList.toggle('on',L.dataset.k===k));c.classList.add('active');});
    c.addEventListener('mouseleave',()=>{svg.classList.remove('focus');
      svg.querySelectorAll('.layer').forEach(L=>L.classList.remove('on'));c.classList.remove('active');});
  });
}
wireHover('#sec-metrics .mcard', document.getElementById('anatomy'));
wireHover('#sec-balance .mcard', document.getElementById('balance'));
// bounce animation — wraps L→H, ball wears the colour it will stamp, elastic + smear
(function(){
  const PU="#9558B2",RD="#CB3C33",GN="#389826";
  const F=§aflo§, Hc=§Hc§,Rc=§Rc§,Lc=§Lc§, DOTR=§dotR§;
  const ledge=§ledge§, redge=§redge§, sr=§sr§, sl=§sl§;
  const apH=§apH§, apG=§apG§, apW=§apW§, WW=redge-ledge;
  const byId=id=>document.getElementById(id);
  const ball=byId('ball'),wball=byId('wball'),ghosts=byId('ghosts');
  const dots={H:byId('dH'),R:byId('dR'),L:byId('dL')};
  if(!ball) return;
  const Tunit=0.5;                          // ms per unit distance ⇒ constant horizontal speed
  const hops=[                              // NO dwell: continuous hops; contact = a quick elastic squash
    {from:Hc,to:Rc,col:RD,dist:Rc-Hc,ap:apH,wrap:false,stamp:PU},  // leaves H (just stamped purple) → R
    {from:Rc,to:Lc,col:GN,dist:Lc-Rc,ap:apG,wrap:false,stamp:RD},  // leaves R (red) → L
    {from:Lc,to:Hc,col:PU,dist:sr+sl,ap:apW,wrap:true, stamp:GN},  // leaves L (green) → wrap → H
  ];
  hops.forEach(h=>h.t=Tunit*h.dist);        // time of flight ∝ distance
  let acc=0; hops.forEach(h=>{h.t0=acc; acc+=h.t;});
  const cycle=acc, wrap0=hops[2].t0, wrapT=hops[2].t;
  const depAt={H:0, R:hops[1].t0, L:hops[2].t0};   // dot deposited at each hop's launch contact
  let t0=null,paused=false,raf,hist=[];
  const reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;
  const lerp=(a,b,u)=>a+(b-a)*u;
  function hopPos(h,u){
    if(!h.wrap) return {x:lerp(h.from,h.to,u), y:F-4*h.ap*u*(1-u)};
    const d=u*(sr+sl);
    if(d<sr){const uu=d/sr; return {x:Lc+d, y:F-h.ap*(2*uu-uu*uu)};}
    const v=(d-sr)/sl; return {x:ledge+(d-sr), y:F-h.ap*(1-v*v)};
  }
  const elastic=x=>1-0.55*Math.cos(2*Math.PI*1.7*x)*Math.exp(-4.2*x);  // ry: 0.45 → overshoot → 1
  const pop=tau=>tau>=1?1:1+0.30*Math.exp(-8*tau)*Math.cos(9*tau);
  const SQ=230;                             // elastic contact window (ms)
  function shape(h,u,tau){
    const p=hopPos(h,u);
    const streak=Math.abs(1-2*u), af=1-streak;              // tall near contacts, wide float at apex
    let rx=DOTR*(1+0.30*af-0.14*streak), ry=DOTR*(1-0.28*af+0.22*streak), cy=p.y;
    if(tau<SQ){ const e=elastic(tau/SQ), w=1-tau/SQ;         // squash-and-launch just after contact
      rx=lerp(rx, DOTR/Math.sqrt(e), w); ry=lerp(ry, DOTR*e, w); cy+=(DOTR-ry)*0.5*w; }
    const col=(tau<110)? h.stamp : h.col;                   // hold stamped colour briefly, then switch
    return {x:p.x, y:cy, rx, ry, col};
  }
  function paintBall(x,y,rx,ry,col,smear){
    ball.setAttribute('cx',x);ball.setAttribute('cy',y);ball.setAttribute('rx',rx);ball.setAttribute('ry',ry);ball.setAttribute('fill',col);
    let wx=null; if(x>redge-DOTR*1.6)wx=x-WW; else if(x<ledge+DOTR*1.6)wx=x+WW;
    if(wx!==null){wball.setAttribute('cx',wx);wball.setAttribute('cy',y);wball.setAttribute('rx',rx);wball.setAttribute('ry',ry);wball.setAttribute('fill',col);wball.setAttribute('opacity',1);}
    else wball.setAttribute('opacity',0);
    hist.unshift({x,y,rx,ry,col}); if(hist.length>5)hist.pop();
    let g=''; if(smear){for(let i=1;i<hist.length;i++){const hh=hist[i];
      g+='<ellipse cx="'+hh.x.toFixed(0)+'" cy="'+hh.y.toFixed(0)+'" rx="'+(hh.rx*(1-i*0.05)).toFixed(0)+'" ry="'+(hh.ry*(1-i*0.05)).toFixed(0)+'" fill="'+hh.col+'" opacity="'+(0.24-i*0.045).toFixed(2)+'"/>';}}
    ghosts.innerHTML=g;
  }
  function paintDots(t){
    ['H','R','L'].forEach(k=>{ let o;
      if(t>=wrap0) o=Math.max(0,1-(t-wrap0)/wrapT);         // fade during wrap → seamless loop
      else o=(t>=depAt[k]-0.001)?1:0;
      let sc=1, cs=depAt[k]; if(t>=cs && t<cs+230 && t<wrap0) sc=pop((t-cs)/230);
      dots[k].setAttribute('opacity',o.toFixed(3)); dots[k].setAttribute('r',(DOTR*sc).toFixed(1));
    });
  }
  function render(t){
    let h=hops[2]; for(const q of hops){ if(t>=q.t0 && t<q.t0+q.t){h=q;break;} }
    const s=shape(h,(t-h.t0)/h.t, t-h.t0);
    paintBall(s.x,s.y,s.rx,s.ry,s.col,true);
    paintDots(t);
  }
  function frame(ts){ if(t0===null)t0=ts; render((ts-t0)%cycle); if(!paused)raf=requestAnimationFrame(frame); }
  const HM=location.hash.match(/f=(\d+)/);
  if(HM){ render((+HM[1])%cycle); }          // deterministic single-frame scrub for QA
  else if(reduce){['H','R','L'].forEach(k=>dots[k].setAttribute('opacity',1));}
  else raf=requestAnimationFrame(frame);
  const pp=byId('pp'); if(pp)pp.onclick=function(){paused=!paused;this.textContent=paused?'▶ play':'⏸ pause';
    if(!paused){t0=null;raf=requestAnimationFrame(frame);}};
})();
</script>
</body></html>"""

TPL_VARS.update(capNeg=-r(cap), path=path_svg(), bounce=bounce_svg(),
  aflo=r(Afloor), ledge=r(leftEdge), redge=r(rightEdge), sr=r(sr), sl=r(sl),
  Dw=r(Dw), apH=r(apH), apG=r(apG), apW=r(apW), dotR=DOTR,
  t1ms=r(0.5*gHR), t2ms=r(0.5*gRL), t3ms=r(0.5*Dw))
html = TEMPLATE
for k,v in TPL_VARS.items():
    html = html.replace("§"+k+"§", str(v))
(H/"hrl_report.html").write_text(html)
print("wrote hrl_report.html   (unreplaced tokens:", html.count("§"), ")")
