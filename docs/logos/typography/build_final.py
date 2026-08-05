#!/usr/bin/env python3
"""Build the FINAL brand assets on JuliaMono Black (900), re-measured:
  final/logo_{under,side,ring}.svg   — static, black-lettered logos (colour balls)
  final/anim_{under,side,ring}.html  — standalone ink-variant animations (for GIF capture)
  final/manifest.json                — sizes + animation cycle (ms) for the render step
Geometry from metrics_900.json. Colours: Julia palette; comb/ring gray recessive."""
import json, pathlib, math
H = pathlib.Path(__file__).resolve().parent
F = H/"final"; F.mkdir(exist_ok=True)
M = json.loads((H/"metrics_900.json").read_text())
A=M['advChar']; cap=M['cap']; advW=M['advWidth']; wL=M['wL']; wR=M['wR']
Hc,Rc,Lc = M['H'],M['R'],M['L']
PU,GN,RD,INK,GRAY = "#9558B2","#389826","#CB3C33","#1b1b1f","#8A8F98"
RGRAY="#9aa0a8"

# ---- UNDER (comb-under, teeth up) ----
m=132.0; Rr=300.0; cCy1=m+Rr; combNear1=2*m+2*Rr; combFar1=combNear1+280; tW=84.0
# ---- SIDE (icon left) ----
Oi=cap/(1+132/600+280/600); Rri=Oi/2; mi=(132/600)*Oi; tki=(280/600)*Oi; wi=0.14*Oi
spacing=Oi+mi; GAP=320.0
c3x=wL-GAP-Rri; c2x=c3x-spacing; c1x=c2x-spacing; railX0i=c1x-Rri; railX1i=c3x+Rri
TACHO=[0.82,1.0,0.58]; CY=[-(l*tki+mi+Rri) for l in TACHO]; ICONX=[c1x,c2x,c3x]
# ---- RING (all-around) ----
RINGR=760.0; RDOT=150.0
RING_TICKS=[(0,-690,0,-830),(345,-598,415,-719),(598,-345,719,-415),(690,0,830,0),
 (598,345,719,415),(345,598,415,719),(0,690,0,830),(-345,598,-415,719),
 (-598,345,-719,415),(-690,0,-830,0),(-598,-345,-719,-415),(-345,-598,-415,-719)]
RING_DOTS=[(0,-760,PU),(380,658,RD),(-760,0,GN)]
RANG=[math.atan2(y,x) for (x,y,_) in RING_DOTS]

FONTCSS="@font-face{font-family:JMB;src:local('JuliaMono Black'),url('../fonts/JuliaMono-Black.ttf')}"
def word_ink():   return f'<text x="0" y="0" font-size="1000" fill="{INK}">HeartRateLab</text>'
def hrl_ink():
    return (f'<text x="-565.75" y="227.54" font-size="620" font-weight="900" fill="{INK}">HRL</text>')

# ---------- static logo builders ----------
def comb_under_static():
    s=[f'<line x1="{wL-40:.0f}" y1="{combFar1}" x2="{wR+40:.0f}" y2="{combFar1}" stroke="{GRAY}" stroke-width="{tW}" stroke-linecap="round"/>']
    for i in range(12):
        if i==0: x,col=Hc,PU
        elif i==5: x,col=Rc,RD
        elif i==9: x,col=Lc,GN
        else: x,col=i*A+A/2,GRAY
        s.append(f'<line x1="{x:.0f}" y1="{combFar1}" x2="{x:.0f}" y2="{combNear1}" stroke="{col}" stroke-width="{(tW if i in(0,5,9) else tW*0.72):.0f}" stroke-linecap="round"/>')
    for x,col in [(Hc,PU),(Rc,RD),(Lc,GN)]:
        s.append(f'<circle cx="{x:.0f}" cy="{cCy1:.0f}" r="{Rr:.0f}" fill="{col}"/>')
    return "".join(s)
def icon_static(deposit_ids=False):
    s=[f'<line x1="{railX0i:.1f}" y1="0" x2="{railX1i:.1f}" y2="0" stroke="{GRAY}" stroke-width="{wi:.1f}" stroke-linecap="round"/>']
    for j in range(3):
        x=ICONX[j]; col=[PU,RD,GN][j]; tip=CY[j]+Rri+mi
        s.append(f'<line x1="{x:.1f}" y1="0" x2="{x:.1f}" y2="{tip:.1f}" stroke="{col}" stroke-width="{wi:.1f}" stroke-linecap="round"/>')
        idv=f' id="d{j}"' if deposit_ids else ''
        s.append(f'<circle{idv} cx="{x:.1f}" cy="{CY[j]:.1f}" r="{Rri:.1f}" fill="{col}"/>')
    return "".join(s)
def ring_static(deposit_ids=False):
    s=[f'<circle cx="0" cy="0" r="{RINGR:.0f}" fill="none" stroke="{RGRAY}" stroke-width="26" opacity="0.7"/>']
    for x1,y1,x2,y2 in RING_TICKS:
        s.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{RGRAY}" stroke-width="26" stroke-linecap="round"/>')
    for j,(x,y,col) in enumerate(RING_DOTS):
        idv=f' id="d{j}"' if deposit_ids else ''
        s.append(f'<circle{idv} cx="{x:.0f}" cy="{y:.0f}" r="{RDOT:.0f}" fill="{col}"/>')
    return s if deposit_ids else "".join(s)

def svg_file(vb, wpx, hpx, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" width="{wpx}" height="{hpx}">'
            f'<style>{FONTCSS} text{{font-family:JMB,monospace}}</style>{body}</svg>')

# geometry-derived viewBoxes (static, tight)
UNDER_VB=(-100, -cap-60, advW+200, (combFar1+60)-(-cap-60))
SIDE_VB =(railX0i-100, min(CY)-Rri-60, (wR+120)-(railX0i-100), (60)-(min(CY)-Rri-60))
RING_VB =(-980,-980,1960,1960)
def px(vb, wpx): return wpx, round(wpx*vb[3]/vb[2])
def vbstr(vb): return f"{vb[0]:.0f} {vb[1]:.0f} {vb[2]:.0f} {vb[3]:.0f}"

statics={
 'under': (UNDER_VB, comb_under_static()+f'<g>{word_ink()}</g>'),
 'side' : (SIDE_VB,  icon_static()+f'<g>{word_ink()}</g>'),
 'ring' : (RING_VB,  "".join(ring_static())+f'<g>{hrl_ink()}</g>'),
}
manifest={}
for name,(vb,body) in statics.items():
    w,h = px(vb, 1800 if name!='ring' else 1100)
    (F/f"logo_{name}.svg").write_text(svg_file(vbstr(vb),w,h,body))
    manifest.setdefault(name,{}).update(static_w=w, static_h=h)

# ---------- animations (ink: black letters, colour balls deposit) ----------
def cycle_linear(xs, tu):
    xs=xs+[xs[0]]; durs=[max(260,tu*abs(xs[i+1]-xs[i])) for i in range(len(xs)-1)]
    return round(sum(durs))
def cycle_ring(tu):
    d=[]; a=RANG+[RANG[0]]
    for i in range(3):
        dd=a[i+1]-a[i]
        while dd<=1e-6: dd+=2*math.pi
        d.append(max(260,tu*RINGR*dd))
    return round(sum(d))

def anim_page(name, vb, static_body, ball_r, ball_xy, cfg):
    w,h = px(vb, 1200 if name!='ring' else 900)
    svg=(f'<svg viewBox="{vbstr(vb)}" preserveAspectRatio="xMidYMid meet">'
         f'{static_body}'
         f'<ellipse class="ball" cx="{ball_xy[0]:.1f}" cy="{ball_xy[1]:.1f}" rx="{ball_r}" ry="{ball_r}" fill="{cfg["targets"][0]["col"]}"/>'
         f'</svg>')
    html=("<!doctype html><html><head><meta charset='utf-8'><style>"+FONTCSS+
          " html,body{margin:0;background:#fff}svg{display:block;width:100vw;height:100vh}text{font-family:JMB,monospace}"
          "</style></head><body>"+svg+
          "<script>const CFG="+json.dumps(cfg)+";"+ENGINE+"</script></body></html>")
    (F/f"anim_{name}.html").write_text(html)
    return w,h

ENGINE=r"""
(function(){const c=CFG,el=document.querySelector('svg'),ball=el.querySelector('.ball');
const T=c.targets,n=T.length,lerp=(a,b,u)=>a+(b-a)*u,hops=[];
if(c.ring){for(let i=0;i<n;i++){const a=T[i],b=T[(i+1)%n];let d=b.ang-a.ang;while(d<=1e-6)d+=2*Math.PI;
  hops.push({ang0:a.ang,dang:d,col:b.col,dur:Math.max(260,c.timeUnit*c.ringR*d)});}}
else{for(let i=0;i<n;i++){const a=T[i],b=T[(i+1)%n],dx=b.x-a.x,dist=Math.abs(dx)||1,wrap=(i===n-1);
  hops.push({a,b,col:b.col,dist,dur:Math.max(260,c.timeUnit*dist),apex:(wrap?c.wrapApexK:c.apexK)*dist+c.apexMin});}}
let acc=0;hops.forEach(h=>{h.t0=acc;acc+=h.dur;});
const cycle=acc,wrapStart=hops[n-1].t0,wrapDur=hops[n-1].dur;
const arrive=new Array(n);arrive[0]=0;for(let i=0;i<n-1;i++)arrive[i+1]=hops[i].t0+hops[i].dur;
T.forEach(t=>{const q=el.querySelector('#'+t.circ);if(q)q.setAttribute('opacity','0');});
const SQ=190;window.__cycle=cycle;
function render(t){let hi=n-1;for(let i=0;i<hops.length;i++){if(t<hops[i].t0+hops[i].dur){hi=i;break;}}
 const h=hops[hi],u=Math.min(1,Math.max(0,(t-h.t0)/h.dur));let x,y;
 if(c.ring){const th=h.ang0+h.dang*u;x=c.ringR*Math.cos(th);y=c.ringR*Math.sin(th);}
 else{x=lerp(h.a.x,h.b.x,u);y=lerp(h.a.y,h.b.y,u)-4*h.apex*u*(1-u);}
 const since=t-h.t0,bs=since<SQ?Math.exp(-4.5*since/SQ):0,R=c.ball.r;let rx,ry,cy;
 if(c.ring){rx=R*(1+0.16*bs);ry=R*(1-0.16*bs);cy=y;}else{rx=R*(1+0.26*bs);ry=R*(1-0.32*bs);cy=y+(R-ry);}
 ball.setAttribute('cx',x.toFixed(1));ball.setAttribute('cy',cy.toFixed(1));ball.setAttribute('rx',rx.toFixed(1));ball.setAttribute('ry',ry.toFixed(1));ball.setAttribute('fill',h.col);ball.setAttribute('opacity','1');
 T.forEach((tg,j)=>{const q=el.querySelector('#'+tg.circ);if(!q)return;let o=(t>=arrive[j])?1:0;if(t>=wrapStart)o*=Math.max(0,1-(t-wrapStart)/wrapDur);q.setAttribute('opacity',o.toFixed(3));});}
const HM=location.hash.match(/[#&]t=(\d+)/);
if(HM){render((+HM[1])%cycle);}else{let t0=null;function fr(ts){if(t0===null)t0=ts;render((ts-t0)%cycle);requestAnimationFrame(fr);}requestAnimationFrame(fr);}
})();
"""

# UNDER anim: ball on the circle row, deposits circles below the ink word
under_body = comb_under_static_noballs = (
    (lambda: (lambda s:s)(None)) and None)  # placeholder
def comb_under_noballs():
    s=[f'<line x1="{wL-40:.0f}" y1="{combFar1}" x2="{wR+40:.0f}" y2="{combFar1}" stroke="{GRAY}" stroke-width="{tW}" stroke-linecap="round"/>']
    for i in range(12):
        if i==0: x,col=Hc,PU
        elif i==5: x,col=Rc,RD
        elif i==9: x,col=Lc,GN
        else: x,col=i*A+A/2,GRAY
        s.append(f'<line x1="{x:.0f}" y1="{combFar1}" x2="{x:.0f}" y2="{combNear1}" stroke="{col}" stroke-width="{(tW if i in(0,5,9) else tW*0.72):.0f}" stroke-linecap="round"/>')
    return "".join(s)
UNDER_AVB=(-120,-900,advW+240,(combFar1+80)-(-900))
depU=("".join(f'<circle id="d{j}" cx="{x:.0f}" cy="{cCy1:.0f}" r="{Rr:.0f}" fill="{col}" opacity="0"/>' for j,(x,col) in enumerate([(Hc,PU),(Rc,RD),(Lc,GN)])))
u_static = comb_under_noballs()+depU+f'<g>{word_ink()}</g>'
u_cfg={"ring":False,"timeUnit":0.40,"apexK":0.085,"apexMin":60,"wrapApexK":0.14,"ball":{"r":Rr},
       "targets":[{"x":Hc,"y":cCy1,"col":PU,"circ":"d0"},{"x":Rc,"y":cCy1,"col":RD,"circ":"d1"},{"x":Lc,"y":cCy1,"col":GN,"circ":"d2"}]}
uw,uh=anim_page('under',UNDER_AVB,u_static,Rr,(Hc,cCy1),u_cfg)
manifest['under'].update(anim_w=uw,anim_h=uh,cycle=cycle_linear([Hc,Rc,Lc],0.40))

# SIDE anim: colour ticks static, dots deposit; ink word static
SIDE_AVB=(railX0i-120,-920,(wR+140)-(railX0i-120),(120)-(-920))
def icon_ticks_only():
    s=[f'<line x1="{railX0i:.1f}" y1="0" x2="{railX1i:.1f}" y2="0" stroke="{GRAY}" stroke-width="{wi:.1f}" stroke-linecap="round"/>']
    for j in range(3):
        x=ICONX[j]; col=[PU,RD,GN][j]; tip=CY[j]+Rri+mi
        s.append(f'<line x1="{x:.1f}" y1="0" x2="{x:.1f}" y2="{tip:.1f}" stroke="{col}" stroke-width="{wi:.1f}" stroke-linecap="round"/>')
        s.append(f'<circle id="d{j}" cx="{x:.1f}" cy="{CY[j]:.1f}" r="{Rri:.1f}" fill="{col}" opacity="0"/>')
    return "".join(s)
s_static = icon_ticks_only()+f'<g>{word_ink()}</g>'
s_cfg={"ring":False,"timeUnit":0.55,"apexK":0.22,"apexMin":40,"wrapApexK":0.16,"ball":{"r":Rri},
       "targets":[{"x":c1x,"y":CY[0],"col":PU,"circ":"d0"},{"x":c2x,"y":CY[1],"col":RD,"circ":"d1"},{"x":c3x,"y":CY[2],"col":GN,"circ":"d2"}]}
sw,sh=anim_page('side',SIDE_AVB,s_static,Rri,(c1x,CY[0]),s_cfg)
manifest['side'].update(anim_w=sw,anim_h=sh,cycle=cycle_linear([c1x,c2x,c3x],0.55))

# RING anim: ball orbits, dots deposit; ink HRL static
RING_AVB=(-1050,-1050,2100,2100)
ring_body=[f'<circle cx="0" cy="0" r="{RINGR:.0f}" fill="none" stroke="{RGRAY}" stroke-width="26" opacity="0.7"/>']
for x1,y1,x2,y2 in RING_TICKS:
    ring_body.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{RGRAY}" stroke-width="26" stroke-linecap="round"/>')
for j,(x,y,col) in enumerate(RING_DOTS):
    ring_body.append(f'<circle id="d{j}" cx="{x:.0f}" cy="{y:.0f}" r="{RDOT:.0f}" fill="{col}" opacity="0"/>')
r_static="".join(ring_body)+f'<g>{hrl_ink()}</g>'
r_cfg={"ring":True,"ringR":RINGR,"timeUnit":0.42,"ball":{"r":RDOT},
       "targets":[{"x":RING_DOTS[j][0],"y":RING_DOTS[j][1],"col":RING_DOTS[j][2],"ang":round(RANG[j],5),"circ":f"d{j}"} for j in range(3)]}
rw,rh=anim_page('ring',RING_AVB,r_static,RDOT,(0,-760),r_cfg)
manifest['ring'].update(anim_w=rw,anim_h=rh,cycle=cycle_ring(0.42))

(F/"manifest.json").write_text(json.dumps(manifest,indent=1))
print("wrote final/ assets:")
for k,v in manifest.items(): print(f"  {k:6} static {v['static_w']}x{v['static_h']}  anim {v['anim_w']}x{v['anim_h']}  cycle {v['cycle']}ms")
