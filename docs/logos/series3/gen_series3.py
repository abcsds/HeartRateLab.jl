#!/usr/bin/env python3
"""Generate Series 3 — typography-driven, animation-ready logos.

All coordinates are JuliaMono em-units (font-size 1000), straight from
typography/full_metrics.json, so every mark is metric-exact and maps 1:1 onto the
bounce spec in GUIDELINES.md. Text stays as real <text font-family="JuliaMono">
(NOT outlined) so letter fills can be animated later.
"""
import json, math, pathlib
HERE = pathlib.Path(__file__).resolve().parent
SVGD = HERE / "svg"; SVGD.mkdir(exist_ok=True)

# ---- measured metrics (em = 1000) ----
CAP, ASC, DESC = 734, 797, 203
ADV = 600
INKL, INKR = 62, 7147
H, R, L = 297, 3305, 5720                    # optical centres in "HeartRateLab"
GAP = 132
DOTW = 468; DOTR = DOTW / 2                  # word-bounded dot
CELLC = [300 + 600 * i for i in range(12)]   # 12 equal time-ticks (one per letter)
BEAT_CELLS = [0, 5, 9]                        # H,R,L → 5:4 rhythm
HRL_C = [297, 905, 1520]                      # "HRL" string optical centres
HRL_INKL, HRL_INKR = 62, 1763

P, RD, GN, BL, INK = "#9558B2", "#CB3C33", "#389826", "#4063D8", "#1b1b1f"
ORG, GREY = "#E8802B", "#9aa0a8"
COLS = [P, RD, GN]

def wordmark(colored=True, ink=INK, size=1000, x=0, y=0):
    cH, cR, cL = (P, RD, GN) if colored else (ink, ink, ink)
    return (f'<text x="{x}" y="{y}" font-family="JuliaMono, monospace" '
            f'font-weight="700" font-size="{size}" xml:space="preserve">'
            f'<tspan fill="{cH}">H</tspan><tspan fill="{ink}">eart</tspan>'
            f'<tspan fill="{cR}">R</tspan><tspan fill="{ink}">ate</tspan>'
            f'<tspan fill="{cL}">L</tspan><tspan fill="{ink}">ab</tspan></text>')

def hrl(colored=True, ink=INK, size=1000, x=0, y=0):
    cH, cR, cL = (P, RD, GN) if colored else (ink, ink, ink)
    return (f'<text x="{x}" y="{y}" font-family="JuliaMono, monospace" '
            f'font-weight="700" font-size="{size}" xml:space="preserve">'
            f'<tspan fill="{cH}">H</tspan><tspan fill="{cR}">R</tspan>'
            f'<tspan fill="{cL}">L</tspan></text>')

def dots(centers, cy, r=DOTR, cols=COLS, stroke=False):
    s = ""
    for cx, col in zip(centers, cols):
        if stroke:
            s += f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{r:.0f}" fill="none" stroke="{col}" stroke-width="92"/>'
        else:
            s += f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{r:.0f}" fill="{col}"/>'
    return s

def comb(floorY, ticks=CELLC, tick_len=120, w=26, col=GREY,
         beat_centers=None, beat_cols=COLS, beat_r=170, x0=INKL, x1=INKR):
    s = (f'<line x1="{x0}" y1="{floorY}" x2="{x1}" y2="{floorY}" stroke="{col}" '
         f'stroke-width="16" stroke-linecap="round" opacity="0.6"/>')
    for cx in ticks:
        s += (f'<line x1="{cx}" y1="{floorY}" x2="{cx}" y2="{floorY+tick_len}" '
              f'stroke="{col}" stroke-width="{w}" stroke-linecap="round"/>')
    if beat_centers:
        for cx, c2 in zip(beat_centers, beat_cols):
            s += f'<circle cx="{cx:.0f}" cy="{floorY-beat_r:.0f}" r="{beat_r:.0f}" fill="{c2}"/>'
    return s

def ring_svg(cx=0, cy=0, Rr=760, n=12, beat_cells=(0, 5, 9), clean=False, center=True):
    s = f'<circle cx="{cx}" cy="{cy}" r="{Rr}" fill="none" stroke="{GREY}" stroke-width="26" opacity="0.7"/>'
    if not clean:
        for i in range(n):
            a = -math.pi/2 + 2*math.pi*i/n
            x1, y1 = cx+(Rr-70)*math.cos(a), cy+(Rr-70)*math.sin(a)
            x2, y2 = cx+(Rr+70)*math.cos(a), cy+(Rr+70)*math.sin(a)
            s += (f'<line x1="{x1:.0f}" y1="{y1:.0f}" x2="{x2:.0f}" y2="{y2:.0f}" '
                  f'stroke="{GREY}" stroke-width="26" stroke-linecap="round"/>')
    cells = list(beat_cells) if not clean else [0, n//3, 2*n//3]
    for k, i in enumerate(cells[:3]):
        a = -math.pi/2 + 2*math.pi*i/n
        x, y = cx+Rr*math.cos(a), cy+Rr*math.sin(a)
        s += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="150" fill="{COLS[k]}"/>'
    if center:
        sz = 620
        tx = cx - (HRL_INKL + (HRL_INKR-HRL_INKL)/2)*sz/1000
        ty = cy + CAP*sz/1000/2
        s += hrl(size=sz, x=tx, y=ty)
    return s

def svg(vb, body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">{body}</svg>\n'

DESIGNS = []
def add(id_, group, title, dot_pos, concept, why, risk, anim, prints, color,
        body, vb, rank=99, top3=None, top3_reason=None):
    DESIGNS.append(dict(id=id_, group=group, title=title, dot_pos=dot_pos,
        concept=concept, why=why, risk=risk, anim=anim, prints=prints, color=color,
        rank=rank, top3=top3, top3_reason=top3_reason, file=f"svg/{id_}.svg"))
    (SVGD/f"{id_}.svg").write_text(svg(vb, body))

PAD = 150
def vbw(top, bot):
    return f"{INKL-PAD} {top} {(INKR-INKL)+2*PAD} {bot-top}"
def vbh(top, bot):
    return f"{HRL_INKL-PAD} {top} {(HRL_INKR-HRL_INKL)+2*PAD} {bot-top}"

# ============ Bucket W — full "HeartRateLab" wordmark systems ============
add("word-dots-above", "wordmark", "Dots Above — the measured mark", "above",
    "The canonical wordmark: three word-bounded dots (Ø468 = 0.64·cap, gap 132) resting on the optical centres of H·R·L.",
    "The exact baseline mark the typography study converged on — instantly Julia-family, perfectly balanced above the caps.",
    "Front-loaded: the beats' centroid sits ~497 left of the word centre; prefer left-aligned lockups.",
    "Each dot is a bounce-landing point; the three fade in H→R→L as the ball stamps them.",
    "Reads in 1 colour if the dots become ink outlines.",
    "H purple · R red · L green; the only three-colour element.",
    wordmark() + dots([H, R, L], -(CAP+GAP+DOTR)),
    vbw(-(CAP+GAP+DOTW)-PAD, DESC+PAD), rank=1)

add("word-comb-below", "wordmark", "Comb Below — 12 ticks of time, 3 beats", "below",
    "The hero idea: a comb of 12 equal ticks (one per letter = equal time) runs under the word; three beats rest on it at cells 0·5·9 — the letters H·R·L, an inter-beat pattern of 5:4.",
    "The name becomes a recording: regular time grid + irregular beats = HRV, encoded in the monospace itself.",
    "The comb adds height; a header/hero mark, not a square favicon.",
    "The three balls bounce along the comb floor and colour H·R·L on contact; the 12 ticks are the metronome.",
    "Excellent 1-colour: ticks + word ink, beats filled or outlined.",
    "Beats H purple · R red · L green on a neutral grey comb.",
    wordmark() + comb(360, beat_centers=[H, R, L]),
    vbw(-CAP-PAD, 360+140), rank=2, top3=2,
    top3_reason="Your comb-at-bottom concept, made exact: 12 equal ticks are time, the three beats land on H·R·L at a real 5:4 interval, so the wordmark *is* an HRV trace. Purpose-built for the bounce.")

add("word-dots-comb", "wordmark", "Full System — dots above + comb below", "above",
    "Both registers: beats float above the caps AND a faint time-comb underlines the word with three colour-matched beat-ticks under H·R·L.",
    "The most complete statement — beats, letters and time grid in one balanced stack.",
    "Busiest of the set; keep the comb faint so the dots lead.",
    "Two-phase: ball bounces along the comb, then stamped beats rise to rest above the caps.",
    "The faint comb drops cleanly in 1-colour; dots carry the colour.",
    "Three hues twice; keep comb ticks grey to avoid four-colour noise.",
    wordmark() + dots([H, R, L], -(CAP+GAP+DOTR)) +
    comb(360, tick_len=90, w=20, beat_centers=[H, R, L], beat_r=120),
    vbw(-(CAP+GAP+DOTW)-PAD, 360+120), rank=3)

add("word-comb-underline", "wordmark", "Comb Underline — the signature", "below",
    "Series-2's favourite, re-fitted: the whole wordmark is underlined by the equal comb; the three ticks under H·R·L are dot-capped in colour, inline with the type.",
    "Reads as a data-signature rather than decoration, and now the tick spacing is the true monospace grid.",
    "At small sizes the underline can merge into a solid rule; fall back to an icon for favicons.",
    "The dot-caps are the deposited beats: they pop in on the bounce while the grey ticks stay static as the time axis.",
    "One-colour friendly: whole comb + word ink, only the three caps tinted.",
    "Only the three beat-caps carry colour — a restrained, editorial palette use.",
    wordmark() + comb(300, tick_len=150, w=22, beat_centers=[H, R, L], beat_r=110),
    vbw(-CAP-PAD, 300+170), rank=4, top3=1,
    top3_reason="My overall pick. It fuses both things you liked into one metric-exact mark — the wordmark riding its own inter-beat comb — and is the most animation-ready: grey ticks hold as the time axis while the three colour caps stamp in on the bounce. Best for README/docs headers.")

add("word-bounce-still", "wordmark", "Bounce Still — ball in flight", "above",
    "A frozen frame of the motion spec: purple beat already stamped on H; the ball (now red, about to stamp R) at the apex of the H→R arc with float-stretch and a smear ghost; comb floor beneath.",
    "Sells the animation in one static image — the mark is alive and rule-driven (apex ∝ distance²).",
    "A motion still, not a resting logo; use for animated contexts.",
    "This IS the key-frame; arc, squash and colour hand-off are all in GUIDELINES §7.",
    "Motion stills rarely print; use word-dots-above as the print fallback.",
    "Ball colour = the colour it is about to stamp (red for R); trailing ghost at lower opacity.",
    wordmark() + dots([H], -(CAP+GAP+DOTR), cols=[P])
      + f'<circle cx="1550" cy="{-(CAP+GAP+DOTR)-360:.0f}" r="200" fill="{RD}" opacity="0.28"/>'
      + f'<circle cx="1750" cy="{-(CAP+GAP+DOTR)-430:.0f}" r="200" fill="{RD}" opacity="0.55"/>'
      + f'<ellipse cx="1950" cy="{-(CAP+GAP+DOTR)-470:.0f}" rx="232" ry="188" fill="{RD}"/>'
      + comb(360),
    vbw(-(CAP+GAP+DOTW)-470-PAD, 360+140), rank=7)

add("word-orange", "wordmark", "Orange Middle — the open question", "below",
    "The comb-below mark with the middle beat in a literal orange (#E8802B) instead of Julia red — the alternative the guidelines left open.",
    "Warmer, higher-contrast triad (purple·orange·green); resolves the open colour question for direct comparison.",
    "Orange isn't an official Julia hex; reads slightly less 'Julia-family'.",
    "Same bounce; only the R stamp colour changes — one variable to A/B (RD→ORG).",
    "Orange prints more vividly than the muted red on coated stock.",
    "Purple · orange · green — one-place change if adopted (middle beat only).",
    wordmark() + comb(360, beat_centers=[H, R, L], beat_cols=[P, ORG, GN]),
    vbw(-CAP-PAD, 360+140), rank=8)

add("word-mono", "wordmark", "Monochrome — 1-colour / print", "above",
    "A single-ink cut: all letters ink, the three beats as ink outline-rings above the caps so the triad survives with no colour.",
    "Guarantees one-colour use — engraving, embossing, stamps, dark-mode knockout.",
    "Loses the Julia colour identity; pair with a colour version where colour exists.",
    "Rings can animate by stroke-dashoffset (draw-on) instead of fill — a different elegant motion.",
    "Purpose-built for print: 1 ink, thick strokes, no fine ticks; knocks out to white on dark.",
    "Zero colour; the three-dot rhythm carries identity through form alone.",
    wordmark(colored=False) + dots([H, R, L], -(CAP+GAP+DOTR), cols=[INK, INK, INK], stroke=True),
    vbw(-(CAP+GAP+DOTW)-PAD, DESC+PAD), rank=6)

# ============ Bucket H — "HRL" monogram + round ============
add("hrl-dots-above", "hrl", "HRL — dots above", "above",
    "The compact monogram: three tinted capitals H·R·L with three beats resting above their optical centres.",
    "The smallest mark still carrying the three-letter / three-beat / three-colour story; a natural app icon.",
    "Three equal letters lose the 5:4 variability story; this is identity, not data.",
    "Same bounce over three (equal) hops; colours stamp H→R→L.",
    "Clean 1-colour with outline dots.",
    "H purple · R red · L green.",
    hrl() + dots(HRL_C, -(CAP+GAP+DOTR)),
    vbh(-(CAP+GAP+DOTW)-PAD, DESC+PAD), rank=2)

add("hrl-comb-below", "hrl", "HRL — comb below", "below",
    "HRL over a three-tick comb (one tick per letter, equal width = time); three beats rest on the ticks.",
    "The comb-at-bottom idea in favicon form; balls bounce on three ticks and colour each letter.",
    "With only three equal ticks the time grid reads more decorative than data.",
    "The perfect tiny bounce loop: three ticks, three landings, three colour stamps.",
    "1-colour safe.",
    "Beats and caps share the three hues.",
    hrl() + comb(360, ticks=HRL_C, beat_centers=HRL_C, beat_r=150,
                 x0=HRL_C[0]-150, x1=HRL_C[2]+150),
    vbh(-CAP-PAD, 360+120), rank=3, top3=3,
    top3_reason="The compact companion to the wordmark and the cleanest home for the bounce loop you described: three balls drop onto three time-ticks and light up H·R·L in turn. Crops to a favicon and is the obvious thing to animate.")

add("hrl-ring", "hrl", "HRL Ring — the round logo", "ring",
    "The round version: HRL centred inside a ring of 12 equal ticks (time folded into a circle); three beats sit at the angles for cells 0·5·9 — the 5:4 pattern, wrapped.",
    "A distinct circular emblem that still encodes the exact rhythm; the natural seal / avatar form.",
    "Ticks are small on the ring; keep above ~48px or use the clean ring.",
    "KEY animation: the ring unrolls into the straight comb and the beats slide to H·R·L — a round intro that resolves into the wordmark.",
    "Round marks centre well on pins/coins/stickers; strong square crop.",
    "Three beats on a grey ring, HRL tinted in the centre.",
    ring_svg(), "-1000 -1000 2000 2000", rank=4)

add("hrl-ring-dots", "hrl", "HRL Ring — clean (favicon-round)", "ring",
    "The ring stripped to essentials: HRL centred, three evenly-spaced beats on a plain ring, no minor ticks.",
    "The most favicon-proof round mark — reads at 16px where the ticked ring would mush.",
    "Even 120° spacing drops the 5:4 story for legibility; the folded, tidied logo.",
    "Beats orbit the ring, then it opens into the line for the wordmark reveal.",
    "Cleanest round mark for tiny/print use.",
    "Three hues on a neutral ring.",
    ring_svg(clean=True), "-1000 -1000 2000 2000", rank=5)

add("hrl-favicon", "hrl", "HRL — favicon", "above",
    "Ultra-compact: HRL with three small beats above, sized for 16–32px.",
    "The smallest legible carrier of the identity; what actually ships as the favicon.",
    "No comb/time story — pure identity at tiny size.",
    "Too small to animate meaningfully; static.",
    "Holds at 16px in 1 or 3 colours.",
    "Three hues or ink.",
    hrl() + dots(HRL_C, -(CAP+GAP+210), r=210),
    vbh(-(CAP+GAP+210)-210-PAD, DESC+PAD), rank=6)

add("hrl-unroll-still", "hrl", "Unroll Still — ring → line", "ring",
    "A mid-transition frame: the ring has partly opened into an arc, three beats strung along it approaching their H·R·L positions — the concept key-frame for the round→linear reveal.",
    "Documents the signature animation move for later production; also a lively in-motion badge.",
    "Transitional by nature — not a resting logo.",
    "The storyboard frame for the round-intro → wordmark animation.",
    "Not for print.",
    "Beats keep their hues through the unroll.",
    f'<path d="M -700 260 A 760 760 0 1 1 700 260" fill="none" stroke="{GREY}" stroke-width="26" opacity="0.6"/>'
      + ''.join(f'<circle cx="{-500+500*k}" cy="{120-k*40}" r="150" fill="{COLS[k]}"/>' for k in range(3))
      + hrl(size=520, x=-(HRL_INKL+(HRL_INKR-HRL_INKL)/2)*0.52, y=CAP*0.52/2+520),
    "-1000 -720 2000 1520", rank=7)

# ============ Bucket C — combinations / lockups fixed + more ============
add("combo-stacked", "combos", "Stacked — HRL emblem over wordmark", "above",
    "A two-tier lockup: the compact HRL-triad monogram (dots above three tinted caps) floats centred above the full 'HeartRateLab' wordmark.",
    "Gives a real vertical brand lockup (icon over name) for square cards, splash screens and app stores — distinct from the flat dots-above mark.",
    "Two focal tiers need vertical breathing room; not for short banners.",
    "The monogram can animate first (its own mini-bounce), then the wordmark rises in beneath it.",
    "1-colour safe (both tiers).",
    "Three hues in the monogram; the wordmark caps repeat them.",
    '<g transform="translate(3149 -994) scale(0.5)">' + hrl() + dots(HRL_C, -(CAP+GAP+DOTR)) + '</g>' + wordmark(),
    vbw(-1811, DESC+PAD), rank=5)

add("combo-caliper", "combos", "Caliper — the 5:4, measured", "below",
    "The wordmark with two dimension calipers under it spanning H→R (3008) and R→L (2416) — measuring the two inter-beat intervals and showing the 5:4 ratio.",
    "The most explicit 'this measures intervals' lockup; a teaching mark for docs and papers.",
    "More diagram than logo; best where the story can breathe.",
    "Calipers draw on after the beats land, annotating the rhythm — a great explanatory animation.",
    "Fine linework; keep ≥200px or thicken for print.",
    "Beats tinted; calipers ink/grey.",
    wordmark() + dots([H, R, L], -(CAP+GAP+DOTR), r=170)
      + f'<g stroke="{INK}" stroke-width="18" fill="none" opacity="0.85">'
      + f'<path d="M{H} 300 V360 M{L} 300 V360 M{R} 300 V470"/>'
      + f'<path d="M{H} 330 H{R} M{R} 440 H{L}"/></g>'
      + f'<text x="{(H+R)//2}" y="300" font-family="JuliaMono,monospace" font-weight="700" font-size="150" fill="{INK}" text-anchor="middle">5</text>'
      + f'<text x="{(R+L)//2}" y="560" font-family="JuliaMono,monospace" font-weight="700" font-size="150" fill="{INK}" text-anchor="middle">4</text>',
    vbw(-(CAP+GAP+2*170)-PAD, 610), rank=8)

add("combo-ticks-rising", "combos", "Ticks Rising — beats grow from the comb", "below",
    "Series-2's 'ticks rising' idea, fixed to the grid: 12 equal grey ticks under the word; the three under H·R·L grow tall and terminate in coloured beats.",
    "Ties each beat to its exact time-tick, so the marks read as events on the axis, not free-floating dots.",
    "The tall coloured ticks can look like stems; keep beat radius clearly larger than tick width.",
    "The three ticks extend upward on the beat, launching the balls — a growth-into-bounce transition.",
    "1-colour degrades gracefully (ticks ink, beats outline).",
    "Grey grid + three hue beats.",
    wordmark() + comb(300, tick_len=110, w=20)
      + ''.join(f'<line x1="{c}" y1="300" x2="{c}" y2="110" stroke="{COLS[k]}" stroke-width="34"/>'
                f'<circle cx="{c}" cy="110" r="120" fill="{COLS[k]}"/>' for k, c in enumerate([H, R, L])),
    vbw(-CAP-PAD, 300+130), rank=7)

add("combo-min-underline", "combos", "Minimal Underline — three ticks only", "below",
    "The most restrained lockup: a thin baseline under the word with just three coloured ticks at H·R·L, the rest of the comb implied.",
    "The quietest way to carry the beat identity horizontally — great for dense UI and README badges.",
    "Without the full comb it reads as three marks, not a grid; the data story is implicit.",
    "The three ticks blink in on the bounce; minimal motion, maximal restraint.",
    "Superb 1-colour and tiny-size behaviour (three short strokes).",
    "Only three tinted ticks — the leanest palette use in the set.",
    wordmark()
      + f'<line x1="{INKL}" y1="320" x2="{INKR}" y2="320" stroke="{GREY}" stroke-width="16" opacity="0.5"/>'
      + ''.join(f'<line x1="{c}" y1="300" x2="{c}" y2="420" stroke="{COLS[k]}" stroke-width="50" stroke-linecap="round"/>'
                for k, c in enumerate([H, R, L])),
    vbw(-CAP-PAD, 460), rank=6)

add("combo-round-badge", "combos", "Round Badge — emblem + wordmark", "ring",
    "A lockup pairing the clean beat-ring emblem (left) with the 'HeartRateLab' wordmark (right).",
    "A formal emblem-plus-name lockup for headers, papers and about-pages; the round mark also stands alone.",
    "Two focal shapes need careful spacing; provided at the measured alignment.",
    "The ring spins/unrolls on load, then the wordmark fades in beside it.",
    "Both elements hold in 1 colour.",
    "Ring beats + word caps share the three hues.",
    f'<g transform="translate(-700 -300) scale(0.62)">{ring_svg(clean=True)}</g>' + wordmark(),
    "-1321 -921 8618 1274", rank=9)

def main():
    man = []
    for d in DESIGNS:
        e = {k: d[k] for k in ("id","group","title","dot_pos","concept","why","risk",
                               "anim","prints","color","rank","file")}
        if d.get("top3"):
            e["top3"] = d["top3"]; e["top3_reason"] = d["top3_reason"]
        man.append(e)
    (HERE/"manifest3.json").write_text(json.dumps(man, indent=2, ensure_ascii=False))
    from collections import Counter
    print("series3:", dict(Counter(d["group"] for d in DESIGNS)), "total", len(DESIGNS))
    print("top3:", sorted(e["id"] for e in man if e.get("top3")))

if __name__ == "__main__":
    main()
