# HeartRateLab.jl — Focused Logo Run #2 (IBI-first)

We picked two winners from run #1 and are iterating ONLY on these two ideas:

## Base A — "IBI Comb" (icon, 320×320)
Irregular vertical tick marks on a baseline = beat EVENTS; the *unequal spacing
between ticks* is the inter-beat-interval variability. Three of the ticks are
capped by the Julia dots.
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320">
  <line x1="34" y1="230" x2="286" y2="230" stroke="#1A1A1A" stroke-width="3" opacity="0.4" stroke-linecap="round"/>
  <line x1="52"  y1="230" x2="52"  y2="194" stroke="#8A8F98" stroke-width="5" stroke-linecap="round"/>
  <line x1="80"  y1="230" x2="80"  y2="170" stroke="#1A1A1A" stroke-width="7" stroke-linecap="round"/>
  <line x1="104" y1="230" x2="104" y2="194" stroke="#8A8F98" stroke-width="5" stroke-linecap="round"/>
  <line x1="164" y1="230" x2="164" y2="170" stroke="#1A1A1A" stroke-width="7" stroke-linecap="round"/>
  <line x1="190" y1="230" x2="190" y2="194" stroke="#8A8F98" stroke-width="5" stroke-linecap="round"/>
  <line x1="222" y1="230" x2="222" y2="170" stroke="#1A1A1A" stroke-width="7" stroke-linecap="round"/>
  <line x1="258" y1="230" x2="258" y2="194" stroke="#8A8F98" stroke-width="5" stroke-linecap="round"/>
  <circle cx="80"  cy="160" r="18" fill="#9558B2"/>
  <circle cx="164" cy="160" r="18" fill="#CB3C33"/>
  <circle cx="222" cy="160" r="18" fill="#389826"/>
</svg>
```

## Base B — "Triad + name Lockup" (640×220)
Three Julia dots as beats + full "HeartRateLab" wordmark to the right. The
CURRENT version uses an ECG QRS spike as the baseline — **that must be replaced**
(see the hard rule below).
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 220">
  <path d="M20,178 H70 L84,152 L98,204 L112,178 H200" fill="none" stroke="#1A1A1A" stroke-width="8" stroke-linejoin="round" stroke-linecap="round"/>
  <circle cx="110" cy="68" r="27" fill="#9558B2"/>
  <circle cx="74" cy="126" r="25" fill="#CB3C33"/>
  <circle cx="146" cy="126" r="25" fill="#389826"/>
  <text x="220" y="140" font-family="Arial, Helvetica, sans-serif" font-weight="700" font-size="70" textLength="390" lengthAdjust="spacingAndGlyphs" fill="#1A1A1A">HeartRateLab</text>
</svg>
```

## ⛔ HARD RULE — IBI, not ECG
The package analyses **inter-beat intervals (IBIs / NN intervals)**, NOT raw
ECG. So **NO ECG / QRS waveform squiggles anywhere** (no P-QRS-T, no "hospital
monitor" zigzag spike). Represent the heartbeat *honestly* as a point process of
beat events and the intervals between them. Allowed IBI vocabulary:
- **Tick comb / event raster** — vertical ticks at irregular spacing; the *gaps*
  are the intervals. (This is the hero idea — lean into it.)
- **Beat-event dots** on a timeline with visibly unequal gaps.
- **Interval brackets / calipers** measuring the ⟷ gap between two beats.
- **Tachogram** — interval *duration* vs beat number (bars / steps / point series;
  heights = interval length). Honest and on-brand.
- **Poincaré** — NN(n) vs NN(n+1) scatter (ellipse on the 45° diagonal).
- The **gap / spacing itself** as the hero (negative space, distance).

## Keep
- The **three Julia dots** (purple `#9558B2`, red `#CB3C33`, green `#389826`) as
  identity; blue `#4063D8` as sparing accent; ink `#1A1A1A`, muted grey `#8A8F98`.
- Confident negative space; legible at 32px (icons) / ~200px wide (lockups).

## Tech spec (mandatory)
- Icons: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320">`.
- Lockups: `viewBox="0 0 640 220"` (horizontal) or `0 0 360 300` (stacked).
- Transparent background, centered, self-contained (no external fonts/images/
  scripts). For text use `font-family="Arial, Helvetica, sans-serif"
  font-weight="700"` at large size with `textLength`+`lengthAdjust` for stable fit.
- Valid XML; crisp geometry.

## Per-logo notes (into your notes-*.md)
id · title · concept (how it expresses IBI + Julia) · motif · register · wordmark ·
why_it_works · risk.
