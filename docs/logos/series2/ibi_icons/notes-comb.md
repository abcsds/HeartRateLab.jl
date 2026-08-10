# IBI Comb — 10 icon variations (notes)

All: `viewBox="0 0 320 320"`, transparent background, three Julia dots
(purple `#9558B2`, red `#CB3C33`, green `#389826`) except comb-10 where the
three colors are carried by bars instead of circles (see risk note).

---

### comb-01 · "Rhythm Comb"
- **concept:** Base A intensified — 12 ticks instead of 8, clustered in
  irregular groups (close-close-close, then a gap, then a pair, then a lone
  tick…) so the *rhythm* itself, not just three gaps, reads as variable. The
  three tallest ticks are capped by the Julia dots.
- **motif:** tick comb / event raster.
- **register:** dense, technical, "this is real signal data."
- **wordmark:** none (icon only).
- **why_it_works:** most literal refinement of the hero motif; scales the
  density up without losing the baseline-and-ticks read.
- **risk:** busiest of the ten; at 32px the non-dot ticks fuzz into a grey
  band — acceptable since the three dots still pop, but don't shrink further.

### comb-02 · "Interval Calipers"
- **concept:** three beat-dots sit directly on the baseline; two engineering-
  style dimension brackets (⟷ as flat-capped brackets, not arrows) span
  beat1→beat2 and beat2→beat3 at different heights/lengths, explicitly
  measuring the unequal IBI gaps.
- **motif:** interval brackets / calipers.
- **why_it_works:** most explicit "this measures a duration" read — good for
  a docs/API icon context where the measurement idea should be legible
  instantly.
- **risk:** could be mistaken for a bar-chart/table icon if colors are
  stripped; keep the three dot colors to anchor it as HRV-specific.

### comb-03 · "Cardiac Arc"
- **concept:** the comb bent along a gentle upward arc — one cycle read
  left-to-right along a curve instead of a straight line. Ticks radiate
  outward from the arc; three of them (irregular angular spacing) carry the
  Julia dots.
- **motif:** comb bent into an arc.
- **why_it_works:** softens the motif (less "ruler," more "pulse"), reads
  well as a badge/favicon silhouette (smile-shaped skyline).
- **risk:** faint resemblance to a crown/rainbow icon at a glance; the dot
  colors and tick texture disambiguate it.

### comb-04 · "Cycle Ring"
- **concept:** the comb bent into a full ring — ticks radiate outward from a
  circle at irregular angular gaps (cyclic cardiac cycle), three of them
  extended and capped with the Julia dots.
- **motif:** comb bent into a full ring.
- **why_it_works:** distinct silhouette from every other icon in the set
  (radial vs linear), reads well as an app icon / favicon at any size.
- **risk:** could look clock-like; mitigated by irregular (non-12-hour)
  angular spacing and the dot colors breaking any clock association.

### comb-05 · "Vertical Raster"
- **concept:** the comb rotated 90° — a vertical baseline with horizontal
  ticks stacked top-to-bottom at irregular vertical spacing, reading as a
  stacked event raster (e.g. multiple beats logged over time, top-down).
  Three ticks extend further and end in the Julia dots.
- **motif:** vertical comb / stacked raster.
- **why_it_works:** useful alternate orientation for sidebar/vertical-nav
  icon slots where a horizontal comb wouldn't fit.
- **risk:** less immediately "cardiac" than the horizontal version on first
  glance; the ladder/raster read needs the dots to anchor it as beats.

### comb-06 · "Tachogram"
- **concept:** classic tachogram — beat number on x, interval duration as
  point height on y, consecutive points joined by a step/line. Three of the
  points are enlarged and colored (Julia dots) as identity anchors among
  smaller grey beat-points.
- **motif:** tachogram (point series + connecting line).
- **why_it_works:** the most "real HRV analysis output" of the set — anyone
  who's plotted NN-intervals will recognize this instantly; strong fit for
  a docs/analysis-focused mark.
- **risk:** the zig-zag line could brush up against "ECG" associations if
  drawn too spiky/sharp; kept the vertices rounded and the amplitude modest,
  and it's explicitly whitelisted IBI vocabulary in BRIEF2.

### comb-07 · "Poincaré"
- **concept:** NN(n) vs NN(n+1) scatter — axes, a 45° diagonal guide, a
  scatter of grey interval-pairs inside a faint ellipse (SD1/SD2 footprint)
  rotated onto the diagonal, with three colored points as identity anchors.
- **motif:** Poincaré plot.
- **why_it_works:** signals analytical depth (this is a real HRV metric
  plot) and is visually the most distinctive icon in the set — good as a
  "documentation" or "advanced analysis" companion mark.
- **risk:** the most detail-heavy icon; axis lines and scatter dots thin out
  at 32px (verified still legible, but this is the one to bump size on if
  used very small, e.g. a favicon).

### comb-08 · "Minimal Gaps"
- **concept:** stripped to just three large Julia dots on a barely-there
  baseline, with two small bracket/caliper marks between them making the
  unequal gaps explicit — no other ticks at all, comb fully implied.
- **motif:** ultra-minimal beats + explicit gap marks.
- **why_it_works:** cleanest of the ten, best candidate for a true favicon /
  app-icon at very small sizes since there's nothing to lose in downscaling.
- **risk:** loses some of the "comb" texture that makes Base A distinctive;
  reads more generic-dots-on-a-line if the caliper marks are removed.

### comb-09 · "Floating Beats"
- **concept:** a plain, perfectly regular tick timeline underneath (the
  "clock" reading beats could occur on) with three Julia dots floating above
  at irregular heights, each linked to its tick by a thin dashed stem — the
  floating heights are the visual variability signal, layered over a neutral
  raster.
- **motif:** event markers above a plain tick timeline.
- **why_it_works:** clearly separates "when" (regular raster below) from
  "how variable" (floating heights above), a distinct two-layer composition
  from the rest of the set.
- **risk:** dashed stems can vanish at 32px; the floating-dot heights still
  read as the hero signal even if the stems fuzz out.

### comb-10 · "Interval Barcode"
- **concept:** only vertical bars, packed edge to edge — bar *width* encodes
  IBI duration. Most bars are ink/grey; three are colored purple/red/green
  in the Julia palette standing in for the three identity beats.
- **motif:** barcode of intervals.
- **why_it_works:** boldest, most graphic/brandable icon in the set; reads
  as a "waveform of durations" rather than any ECG shape, honestly IBI.
- **risk:** intentionally has **no literal dot circles** — the brief's own
  example for this variant specifies "only bars, three colored," so the
  Julia identity is carried by color, not by circular dots. Flag this as a
  deliberate exception if a reviewer expects circles in every tile.

---

## Strongest picks
1. **comb-06 (Tachogram)** — most authentic HRV-analysis read, strong
   docs/technical fit.
2. **comb-04 (Cycle Ring)** — most distinctive silhouette, excellent as a
   standalone app icon/favicon.
3. **comb-01 (Rhythm Comb)** — safest, most direct evolution of the proven
   Base A hero motif.
