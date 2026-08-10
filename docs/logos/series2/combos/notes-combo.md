# HeartRateLab.jl — Series 2 Combos (Comb × Lockup Fusions)

Ten fusions of Base A (IBI Comb) and Base B (Triad + name lockup). Every mark
keeps the wordmark legible, keeps the three Julia dots, and stays strictly
IBI-honest (no ECG/QRS anywhere). Tech spec followed throughout: `viewBox="0 0
640 220"` (horizontal, 8 marks) or `"0 0 360 300"` (stacked, 2 marks),
`font-family="Arial, Helvetica, sans-serif" font-weight="700"` with
`textLength`+`lengthAdjust="spacingAndGlyphs"`.

---

### combo-01 · "Comb Underline"
- **concept:** the plain rule under a wordmark is replaced by the actual IBI
  comb — irregular ticks on a baseline, three of them dot-capped — so the
  underline itself *is* the beat raster.
- **motif:** tick comb / event raster (dot-capped ticks).
- **register:** horizontal, 640×220.
- **wordmark:** "HeartRateLab" single lockup, condensed bold, sits directly
  above the comb.
- **why_it_works:** closest 1:1 reuse of Base A's own vocabulary; instantly
  reads as "comb become underline" — very on-brief, very legible.
- **risk:** the underline could be mistaken for pure decoration if scaled too
  small; keep dot caps visible at minimum size.

### combo-02 · "Ticks Rising Into the Triad"
- **concept:** a sparse row of minor grey ticks sits above the name; three of
  them grow tall and terminate in the Julia dots, so the triad reads as the
  "peaks" of the comb, floating as an accent row over the wordmark.
- **motif:** tick comb / event raster, dots as tick terminals.
- **register:** horizontal, 640×220.
- **wordmark:** large single-line "HeartRateLab" anchoring the bottom half.
- **why_it_works:** inverts combo-01's placement (comb above, not below),
  giving the set variety while reusing the same honest ticks+dots language.
- **risk:** at very small sizes the thin grey ticks may disappear, leaving
  only 3 isolated dots — acceptable fallback, but worth a bolder-tick variant
  for favicon use.

### combo-03 · "Beat Timeline"
- **concept:** the three Julia dots sit directly on a timeline that runs
  under the wordmark, with clearly unequal gaps between them (and a few minor
  uncolored ticks) — the timeline itself is the hero, dots are beat events
  in time, not decoration.
- **motif:** beat-event dots on a timeline with visible unequal gaps.
- **register:** horizontal, 640×220.
- **wordmark:** single-line "HeartRateLab" above the timeline.
- **why_it_works:** most literal expression of "IBI" — variable gap *is* the
  message; very clean, calm composition.
- **risk:** could read as "just 3 dots on a line" if the minor ticks are
  removed; keep at least 2–3 minor ticks for comb texture.

### combo-04 · "Interval Ruler"
- **concept:** a thin ruler line runs under the single continuous wordmark
  with three colored caliper marks positioned at the syllable boundaries
  (Heart|Rate|Lab) — measuring the word itself like a sequence of intervals.
- **motif:** interval brackets / calipers.
- **register:** horizontal, 640×220.
- **wordmark:** single "HeartRateLab" (not split into 3 words — kept as one
  fused string so it doesn't misread as 3 separate words).
- **why_it_works:** turns the wordmark into the "signal being measured" —
  a clever literal fusion of typography and IBI-measurement language.
- **risk:** the caliper metaphor is subtler than a literal comb; may need a
  caption/context on first exposure (works better once viewer knows the
  product).

### combo-05 · "Three Syllable Combs"
- **concept:** three small mini-combs (each with its own dot-capped tall
  tick) sit under the three syllables of Heart·Rate·Lab, joined by one shared
  baseline — so the comb is distributed under the word rather than
  concentrated in one place.
- **motif:** tick comb / event raster, distributed per-syllable.
- **register:** horizontal, 640×220.
- **wordmark:** single continuous "HeartRateLab"; comb positions are
  proportionally estimated under Heart / Rate / Lab.
- **why_it_works:** ties each Julia-color dot to a specific syllable,
  reinforcing "Heart-Rate-Lab" as three linked ideas under one shared
  timeline.
- **risk:** precise per-glyph alignment depends on font metrics; at other
  render engines the ticks may drift slightly off-syllable (cosmetic only).

### combo-06 · "Stacked Comb + Name" (stacked)
- **concept:** a compact vertical lockup — the IBI comb icon (near-verbatim
  Base A, scaled) sits above, the wordmark sits below, centered.
- **motif:** tick comb / event raster (icon form).
- **register:** stacked, 360×300.
- **wordmark:** "HeartRateLab" centered below the icon.
- **why_it_works:** most traditional "icon + name" structure of the set, but
  earns its place as a compact app-icon-adjacent lockup (square social
  avatars, favicons with room for a name underneath).
- **risk:** least "invented" fusion in the set — more juxtaposition than
  fusion; kept because the brief explicitly asks for 1–2 stacked compositions.

### combo-07 · "Diacritic Triad"
- **concept:** the three Julia dots perch above the H, R, and L like accent
  marks/diacritics on the wordmark's own ascenders; a plain grey comb runs
  beneath the full word as the "beat floor."
- **motif:** dots as letter accents + tick comb baseline.
- **register:** horizontal, 640×220.
- **wordmark:** single "HeartRateLab"; dot x-positions computed from the
  textLength scale factor to land cleanly on H/R/L without overlapping the
  glyphs.
- **why_it_works:** the most "typographic" fusion — the triad becomes part of
  the letterforms themselves, while the comb still carries the IBI honesty.
- **risk:** dot alignment over H/R/L is approximate (based on proportional
  string-length estimate, not real glyph metrics) — verify at final font
  render; nudge x by a few px if a different renderer shifts glyph spacing.

### combo-08 · "Cyclic Beat Arc"
- **concept:** the comb is bent into a shallow arc above the name (evoking a
  cyclic/rhythmic beat rather than a straight timeline); irregular ticks
  radiate off the arc and the three Julia dots sit on it at unequal angular
  spacing.
- **motif:** tick comb / event raster, bent into an arc; beat-event dots.
- **register:** horizontal, 640×220.
- **wordmark:** single-line "HeartRateLab" centered under the arc.
- **why_it_works:** most distinctive silhouette of the set — reads as a badge
  / seal from a distance while still resolving into comb+dots+timeline up
  close; strong differentiator versus the other 9.
- **risk:** the arc curvature is purely stylistic — must not be mistaken for
  a waveform; keep the radiating ticks straight (not curved) to avoid any
  ECG-adjacent read.

### combo-09 · "Stacked Tachogram" (stacked)
- **concept:** a tachogram (bars whose heights = interval durations, three
  colored by the triad) sits above the wordmark in a compact vertical lockup.
- **motif:** tachogram (interval duration vs. beat number).
- **register:** stacked, 360×300.
- **wordmark:** "HeartRateLab" centered below the bars.
- **why_it_works:** introduces a second IBI-honest vocabulary (bars, not
  ticks) into the stacked format, giving real variety versus combo-06 rather
  than a re-skin.
- **risk:** bars can look like a generic "analytics" bar chart if colors are
  muted too far; keep the 3 triad bars saturated and the greys clearly
  secondary.

### combo-10 · "Tachogram Baseplate"
- **concept:** the tachogram bars run directly under the full-width
  wordmark like a textured baseplate/EQ meter, integrated as one continuous
  horizontal mark rather than a separate stacked element.
- **motif:** tachogram (interval duration vs. beat number).
- **register:** horizontal, 640×220.
- **wordmark:** single-line "HeartRateLab" above the bar row.
- **why_it_works:** completes the set's coverage of all major allowed IBI
  motifs (ticks, dots, brackets, arc, tachogram) in horizontal-lockup form;
  reads well at small size since bars are chunkier than fine ticks.
- **risk:** at very small sizes the 14 thin bars can blur together; consider
  reducing bar count for a favicon-scale variant.

---

## Strongest picks
- **combo-08** (Cyclic Beat Arc) — most distinctive silhouette, memorable as
  a standalone badge.
- **combo-01** (Comb Underline) — safest, cleanest, most immediately legible
  fusion; best default/primary lockup candidate.
- **combo-04** (Interval Ruler) — cleverest conceptual fusion (the word
  itself becomes the measured signal); best for contexts where the story can
  be explained (docs header, README).
