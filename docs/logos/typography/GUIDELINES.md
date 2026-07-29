# HeartRateLab wordmark — design guidelines

The wordmark is **`HeartRateLab`** set in **JuliaMono Bold**, with the three
capitals **H · R · L** tinted in the three Julia colours. The three capitals are
the consonant onsets of the three syllables *Heart · Rate · Lab* — three
capitals, three Julia dots, three heartbeats — mapping the Julia logo's
three-dot identity directly onto the name.

All geometry below is in **em units (font-size = 1000)**; multiply by
`size/1000` for any render size. Every number is measured (headless-Chromium
canvas metrics) and lives in [`full_metrics.json`](full_metrics.json); the
interactive study is [`hrl_report.html`](hrl_report.html) (open in a browser).

---

## 1. Typeface

| | |
|---|---|
| Family | **JuliaMono Bold** (cormullion) — the official Julia typeface |
| Class | monospaced ("serifless" technical Roman) |
| Why | it *is* the Julia code font → reads "scientific/technical"; the fixed grid turns three capitals into three predictable beats |

**Vertical metrics** (em 1000): cap-height **734** · x-height **562**
(0.77·cap) · ascender **797** · descender **203**.
**Advance / glyph: 600, identical for all 12 letters** (that is what monospace
means). *Ink* width varies **469–516** (≈10 %), so a capital's optical centre is
**not** its cell centre — always place on the ink centre (below).

## 2. Colours — the Julia palette

| role | hex | used for |
|---|---|---|
| Julia purple | `#9558B2` | **H** |
| Julia red | `#CB3C33` | **R** |
| Julia green | `#389826` | **L** |
| Julia blue | `#4063D8` | reserved accent (not in the wordmark) |
| ink | `#1b1b1f` | word body (lowercase) |

Only the three capitals are tinted; the lowercase stays ink. Three of the four
brand hexes are used, so the mark reads Julia-family at a glance.

## 3. The three capitals — optical centres

Tint and align to the **ink (optical) centre** of each capital, never the
600-cell centre:

| capital | optical centre x | ink span |
|---|---|---|
| **H** | **297** | 62 – 531 |
| **R** | **3305** | 3047 – 3563 |
| **L** | **5720** | 5478 – 5963 |

Word ink span **62 – 7147**; word optical centre **3605**.

## 4. The three dots (beats)

When the mark carries dots above the capitals:

| parameter | value | note |
|---|---|---|
| dot diameter Ø | **468** = **0.64·cap** | *word-bounded*: the largest dot centred on H that stays inside the word's left ink edge |
| gap above cap line | **132** = **0.18·cap** | balanced float; range 0.12–0.22·cap |
| horizontal placement | on the optical centres **297 · 3305 · 5720** | not the cell centres |
| colour | H purple · R red · L green | — |

**Do not** use Ø = cap (734): centred on H it **overhangs the word's left edge by
133**. Ø ≤ 468 keeps the triplet inside the word. (The bouncing-ball animation
uses its own slightly smaller moving dot, Ø 400 — see §7.)

## 5. Balance

- **Front-loaded.** The three dots' centroid is **3107**, but the word's optical
  centre is **3605** — the beats sit **≈497 left** of centre. The tail "**ab**"
  carries no beat.
- **Consequences.** Prefer left-aligned lockups; if centring the whole mark,
  expect the dots to sit left of the geometric middle. If a symmetric feel is
  needed, counterweight the bare "ab" tail rather than moving the dots off their
  capitals.
- **H at the edge.** H hugs the left ink edge (62), so large dots on H overhang
  first — the binding constraint for dot size (§4).

## 6. Rhythm

The horizontal gaps between the capitals are intrinsic to the word and drive any
motion:

| hop | distance (centre→centre) | cluster |
|---|---|---|
| **H → R** | **3008** | "Heart" (5 glyphs) |
| **R → L** | **2416** | "Rate" (4 glyphs) |

**Ratio 1.25 : 1 = exactly 5 : 4** (monospace makes it exact). Spoken,
`HEART·RATE·LAB` is three equal stresses — a **molossus** (— — —); in motion it
reads as a gently **swung / dotted triplet**.

## 7. Bounce animation (motion spec)

One ball bounces H → R → L, deposits a Julia dot **on top of** each capital
(with margin), then **wraps** off the right edge and re-enters the left to close
the loop. Reference implementation: the `<script>` in `hrl_report.html`.

**Physics — constant horizontal speed ⇒ time of flight ∝ distance** (a
frictionless bounce), so the two long hops genuinely hang longer than the short
one; apex height ∝ distance².

| parameter | value |
|---|---|
| pace | `Tunit` = **0.5 ms / em-unit** (horizontal speed = 1/Tunit) |
| time of flight | H→R **1504 ms** · R→L **1208 ms** · wrap **1408 ms** |
| apex height | ∝ distance² → height ratio **1.562 : 1** |
| contact | **elastic squash** (no stop) that launches straight into the next hop |
| ball colour | the colour it is **about to stamp**: purple → red → green → wrap → purple |
| deposited dot | Ø **400** (r 200), margin **120** above the cap line |
| wrap | exits right, re-enters left at the same height |
| margins | left = right = **520** → spans `sr` = **2000** (L→right), `sl` = **817** (left→H), total **2817** — the margins set the wrap arc's height & time |
| loop | the three dots fade out during the wrap → seamless |
| extras | horizontal float-stretch at the apex; smear ghosts on the fast arcs; respects `prefers-reduced-motion` |

## 8. Files & reproduction

| file | purpose |
|---|---|
| `GUIDELINES.md` | this document |
| `full_metrics.json` | measured glyph geometry (source of truth) |
| `measure_full.html` | re-measures JuliaMono Bold → `full_metrics.json` (headless Chromium) |
| `build_report.py` | regenerates `hrl_report.html` from `full_metrics.json` |
| `hrl_report.html` | the interactive study (anatomy · widths · colour/weight gallery · balance · bounce) |
| `hrl_measure.html` | standalone annotated metrics report |
| `fonts/get-fonts.sh` | vendors the JuliaMono weights (or falls back to system JuliaMono) |

**Rebuild:** `bash fonts/get-fonts.sh && python3 build_report.py`
(the report also renders against a system-installed JuliaMono via `@font-face
local()`, so the `.ttf` files are gitignored, not vendored).

**Open question, deliberately left open:** the middle stamp colour is Julia red
`#CB3C33` (the R brand colour). A literal *orange* was discussed as an
alternative — change in one place (`RD`) if desired.
