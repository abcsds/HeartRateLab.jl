# HeartRateLab wordmark & logo — design guidelines

The mark is **`HeartRateLab`** set in **JuliaMono Black**, with the three capitals
**H · R · L** tinted in the three Julia colours. The three capitals are the
consonant onsets of *Heart · Rate · Lab* — three capitals, three Julia dots,
three heartbeats — mapping the Julia logo's three-dot identity onto the name.

There are **three lockups** built from this: **comb-under** (balls under the
word), **icon-left** (a compact tick-comb to the side), and the **HRL Ring**
(balls all-around). All share the same rules below.

All geometry is in **em units (font-size = 1000)**; multiply by `size/1000` for
any render size. Every number is measured (headless-Chromium canvas metrics) and
lives in [`metrics_900.json`](metrics_900.json). The interactive studies and the
final animated showcase are linked from [`index.html`](index.html).

---

## 1. Typeface — JuliaMono **Black (900)**

| | |
|---|---|
| Family | **JuliaMono Black** — weight **900**, the heaviest JuliaMono face |
| Class | monospaced technical Roman |
| Why | it *is* the Julia code font → reads "scientific/technical"; the fixed grid turns three capitals into three predictable beats; Black gives the wordmark maximum presence |

**The weight ladder** (measured `usWeightClass`): Light 300 · Regular 400 ·
Medium 500 · SemiBold 600 · Bold 700 · ExtraBold 800 · **Black 900 ← chosen**.
(Bold is *not* the chunkiest — Black is two steps heavier. ExtraBold 800 is the
safer choice if counters clog at small sizes; compare all three in the
`comb_animated_{,_800,_900}.html` reports.)

**Vertical metrics** (weight-independent, em 1000): cap-height **734** ·
x-height **562** (0.77·cap) · ascender **797** · descender **203**.
**Advance / glyph: 600, identical for all 12 letters** (monospace). At Black the
*ink* width varies **500–578** (≈15 %, up from ≈10 % at Bold), so a capital's
optical centre is **not** its cell centre — always place on the ink centre (§3).

## 2. Colours — the Julia palette

| role | hex | used for |
|---|---|---|
| Julia purple | `#9558B2` | **H** |
| Julia red | `#CB3C33` | **R** |
| Julia green | `#389826` | **L** |
| Julia blue | `#4063D8` | reserved accent (not in the mark) |
| ink | `#1b1b1f` | word body / black-lettered variants |
| comb gray | `#8A8F98` | comb rail + ticks (cool blue-gray, ~3.3:1 on white, recessive) |
| ring gray | `#9aa0a8` | the ring circle + its radial ticks |

Only the three capitals are tinted; the lowercase stays ink. Three of the four
brand hexes are used, so the mark reads Julia-family at a glance. The comb/ring
gray is deliberately recessive — it *underlines*, it doesn't compete.

## 3. The three capitals — optical centres (Black 900)

Tint and align to the **ink (optical) centre** of each capital, never the
600-cell centre:

| capital | optical centre x | ink span |
|---|---|---|
| **H** | **305** | 47 – 563 |
| **R** | **3313** | 3031 – 3594 |
| **L** | **5705** | 5447 – 5963 |

Word ink span **47 – 7163**; word optical centre **3605**. (At Bold these were
297 · 3305 · 5720; Black's heavier stems shift each centre a few units — re-measure
per weight.)

## 4. The dots / balls (beats)

| parameter | value | note |
|---|---|---|
| dot diameter Ø | **516** = **0.70·cap** | *word-bounded*: the largest dot centred on H that stays inside the word's left ink edge (`2·(H−wL)`). Bold's was 468; Black's heavier H sits further right, so the bound grows |
| gap above/below cap line | **132** = **0.18·cap** | balanced float; range 0.12–0.22·cap |
| horizontal placement | on the optical centres **305 · 3313 · 5705** | not the cell centres |
| colour | H purple · R red · L green | — |

**Do not** use Ø = cap (734): centred on H it **overhangs the word's left edge by
≈109**. Ø ≤ 516 keeps the triplet inside the word.

## 5. Balance

- **Front-loaded.** The three dots' centroid is **3107**; the word's optical
  centre is **3605** — the beats sit **≈497 left** of centre. The tail "**ab**"
  carries no beat.
- **Consequences.** Prefer left-aligned lockups; if centring the whole mark,
  expect the dots to sit left of the geometric middle. Counterweight the bare
  "ab" tail rather than moving the dots off their capitals.
- **H at the edge.** H hugs the left ink edge (47), so large dots on H overhang
  first — the binding constraint for dot size (§4).

## 6. Rhythm

| hop | centre→centre | cluster |
|---|---|---|
| **H → R** (cell centres) | **3000** | "Heart" (5 glyphs) |
| **R → L** (cell centres) | **2400** | "Rate" (4 glyphs) |

**Cell-centre ratio = exactly 1.25 : 1 = 5 : 4** (monospace makes it exact and
weight-independent). Measured on the *optical* centres it is **3008 : 2392 ≈
1.26 : 1** — the slight wobble is the ink-centre shift. Spoken, `HEART·RATE·LAB`
is three equal stresses — a **molossus** (— — —); in motion a gently **swung /
dotted triplet**.

## 7. The three lockups

| lockup | file (static) | build | stack |
|---|---|---|---|
| **comb-under** ("balls under") | `final/logo_under.svg/.png` | [`comb_teeth_up.html`](comb_teeth_up.html) | letters → circles → comb (teeth up), equal margins `m` |
| **icon-left** ("balls to the side") | `final/logo_side.svg/.png` | [`comb_icon_left.html`](comb_icon_left.html) | tick-comb icon (gap = m) then the word; icon = cap-height |
| **HRL Ring** ("balls all-around") | `final/logo_ring.svg/.png` | series-3 `hrl-ring.svg` | HRL centred in a ticked ring, three beats at 150°·120°·90° |

Shared rule: **one margin `m = 132` (0.18·cap)** governs every gap — letter↔circle,
circle↔comb, and circle↔circle when the comb is compressed. Icon circle Ø = 435
(sized so the icon equals cap-height); the comb-under circle Ø = 600.

## 8. Motion (animation spec)

The bounce is one engine across all three marks (reference:
[`comb_animated_900.html`](comb_animated_900.html), 16 live variants):

- **Physics — constant horizontal speed ⇒ time of flight ∝ distance**; apex ∝
  distance²; contact is an **elastic squash** (no full stop) that launches into
  the next hop. On the **ring** the bounce becomes an **orbit** (time ∝ arc).
- **Ball colour = the colour it is about to stamp** (anticipation).
- **Letter transition** on each bounce: colour + a small squash — **build-up**
  (light H→R→L, reset on the wrap) or **blink** (flash per bounce). A **remote**
  variant keeps the ball in the icon/ring and squashes the far letter.
- **Deposit modes:** *accumulate* (fade on wrap), *single* (one beat at a time,
  continuous handoff), *persist* (never fades).
- Respects `prefers-reduced-motion`; loops seamlessly.

Final black-lettered animated GIFs: `final/anim_under.gif`,
`final/anim_side.gif`, `final/anim_ring.gif`.

## 9. Files & reproduction

| file | purpose |
|---|---|
| `GUIDELINES.md` | this document |
| `metrics_900.json` | measured JuliaMono **Black** geometry (source of truth) |
| `metrics_700/800.json`, `full_metrics.json` | Bold / ExtraBold for comparison |
| `measure_weight.html` | re-measures any weight → `metrics_<n>.json` (headless Chromium) |
| `build_comb2.py` · `build_comb3.py` | the comb-under / icon-left studies |
| `build_comb4.py` | the animated report (`HRL_W=700\|800\|900`) |
| `build_final.py` | the final static logos + standalone animations |
| `index.html` | the design-process report + final showcase |
| `final/` | logos (svg+png) and animated gifs |
| `fonts/get-fonts.sh` | vendors all JuliaMono weights (or system fallback) |

**Rebuild:** `bash fonts/get-fonts.sh && HRL_W=900 python3 build_comb4.py &&
python3 build_final.py` (reports also render against a system JuliaMono via
`@font-face local()`, so the `.ttf` files are gitignored).
