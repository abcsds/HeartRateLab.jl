# Direction C — Hybrid/Fusion: Wordmark & Lockup studio (c3word series)

Lane: typographic lockups fusing the HRV/Julia mark with the name. All eight
below carry text — either the full "HeartRateLab" wordmark or an "HRL" /
"H♥L" monogram — with the icon element built from HRV+Julia vocabulary
(three-dot triad, R-peak spike, ECG baseline, Poincaré-dot accent).

Text technique: bold system stack `font-family="Arial, Helvetica, sans-serif"`
`font-weight="700"`, sized large, with `textLength`+`lengthAdjust="spacingAndGlyphs"`
on every full-word instance to guarantee exact fit inside the viewBox
regardless of the font actually substituted at render time (Arial resolves to
Liberation Sans Bold on this system via fontconfig; textLength keeps the
composition stable even under a different fallback). Verified by rendering
every file with Inkscape at 400px and 32px and inspecting the PNGs.

---

## c3word-01 — Tri-Chrome HRL
- `title`: Tri-Chrome HRL
- `concept`: The initials H-R-L are each set in one Julia color (purple,
  red, green), echoing the three-dot triad through letter color instead of
  literal dots; a thick ECG line underlines the whole mark with a single
  R-peak spike roughly under the "R".
- `motif`: three-dot (via color) / ECG underline / R-peak
- `colors`: Julia purple #9558B2 (H), red #CB3C33 (R), green #389826 (L), ink #1A1A1A (ECG line)
- `register`: typographic
- `wordmark`: includes text ("HRL")
- `viewBox`: 320×320 (square)
- `why_it_works`: Reads instantly as an acronym mark and a heartbeat trace in one glance; strong at both large and favicon scale.
- `risk`: Three different letter colors could feel busy if reproduced on a busy background; needs a light/neutral backdrop.

## c3word-02 — Peak H
- `title`: Peak H
- `concept`: A blocky "H" monogram where the crossbar is a solid red bar
  interrupted by a sharp triangular spike — literally an R-peak drawn as the
  stroke of a letter — with the two verticals carrying Julia purple and green.
- `motif`: R-peak-as-letter-stroke / three-dot echo (dark dot capping the spike)
- `colors`: purple #9558B2, green #389826 (verticals), red #CB3C33 (crossbar/spike), ink #1A1A1A (accent dot)
- `register`: typographic / minimalist
- `wordmark`: includes text (stylized single letter "H")
- `viewBox`: 320×320 (square)
- `why_it_works`: Fuses HRV vocabulary directly into the letterform rather than beside it; unmistakably an "H" even at 32px after the crossbar was simplified from a zigzag to a single spike.
- `risk`: Reads as an abstract H, not the full "HRL" — best used alongside a full wordmark elsewhere, not as a standalone identifier of the package name.

## c3word-03 — Dot-Heart Badge
- `title`: Dot-Heart Badge
- `concept`: A geometric heart built from the Julia three-dot triangle idea —
  purple and green lobes plus a small red circle sitting at the cleft like a
  Poincaré-dot tittle — inside a badge ring, captioned with the "HRL" monogram.
- `motif`: heart / three-dot / Poincaré-dot-as-tittle
- `colors`: purple #9558B2, green #389826 (heart lobes), red #CB3C33 (cleft dot), ink #1A1A1A (ring + caption)
- `register`: typographic / scientific badge
- `wordmark`: includes text ("HRL")
- `viewBox`: 320×320 (square)
- `why_it_works`: Badge format reads as an official package emblem; heart + acronym both legible down to favicon size.
- `risk`: The "HRL" caption is the smallest text in the set — legible at 32px only as a texture, not as readable letters (heart+ring still carry the mark at that size).

## c3word-04 — H♥L
- `title`: H♥L
- `concept`: Bold "H" and "L" flank a geometric heart standing in for the
  middle of the name; a tiny diagonal dot cluster inside the heart nods to a
  Poincaré-plot ellipse cloud in miniature.
- `motif`: heart / Poincaré-cloud (miniature) / three-plus-dot
- `colors`: ink #1A1A1A (letters), red #CB3C33 (heart), purple/green/blue #9558B2 #389826 #4063D8 (cloud dots)
- `register`: typographic / playful
- `wordmark`: includes text ("H", "L")
- `viewBox`: 320×320 (square)
- `why_it_works`: Strongest square mark in the set — clean, bold, reads as letters+heart even at 32px; the "I ♥ NY"-style substitution is instantly parseable.
- `risk`: The internal dot cloud is a bonus detail invisible below ~64px; the mark still works without it being seen, so this is a minor risk only.

## c3word-05 — Triad Pulse Lockup
- `title`: Triad Pulse Lockup
- `concept`: The classic Julia three-dot triangle sits directly on an ECG
  baseline with a peak beneath it (three dots as beats + ECG underline
  combined), paired with the full "HeartRateLab" wordmark.
- `motif`: three-dot / ECG underline
- `colors`: purple #9558B2, red #CB3C33, green #389826 (dots), ink #1A1A1A (ECG + text)
- `register`: typographic / scientific
- `wordmark`: includes text ("HeartRateLab")
- `viewBox`: 640×220 (wide lockup)
- `why_it_works`: The most "default" and safest lockup — instantly reads Julia package + heartbeat + full name; best choice for a README header or docs banner.
- `risk`: Closest in spirit to the seed-C reference icon; differentiated here by the ECG baseline running under the triad rather than through it, but still the least novel of the eight.

## c3word-06 — Poincaré Cloud Lockup
- `title`: Poincaré Cloud Lockup
- `concept`: A diagonal scatter of dots inside a thin ring stands for the
  NN(n) vs NN(n+1) ellipse cloud; a small purple dot floats above the
  wordmark's Heart/Rate seam like a Poincaré-dot accent mark.
- `motif`: Poincaré plot / Poincaré-dot-as-tittle
- `colors`: purple #9558B2, green #389826, red #CB3C33, blue #4063D8 (cloud dots), ink #1A1A1A (ring + text)
- `register`: scientific / typographic
- `wordmark`: includes text ("HeartRateLab")
- `viewBox`: 640×220 (wide lockup)
- `why_it_works`: Signals the nonlinear-analysis side of the package (not just heartbeat) while the floating dot gives the wordmark a distinctive, memorable accent.
- `risk`: The Poincaré-cloud icon is a more specialist/HRV-literate reference than an ECG or heart — a general audience may read it as "just dots" without caption context.

## c3word-07 — R-Peak Letter Lockup
- `title`: R-Peak Letter Lockup
- `concept`: A Van der Pol limit-cycle loop (closed orbit in phase space) as
  the icon; in the wordmark, the "R" of "Rate" is crowned by a sharp ECG
  spike sitting right on its cap — an R-peak literally on the stroke of a
  letter, the technique the brief calls out by name.
- `motif`: attractor/limit-cycle / R-peak-as-letter-stroke
- `colors`: blue #4063D8 (loop), green #389826 (trajectory dot), red #CB3C33 (R + spike), ink #1A1A1A (rest of text)
- `register`: typographic / scientific
- `wordmark`: includes text ("HeartRateLab", with stylized "R")
- `viewBox`: 640×220 (wide lockup)
- `why_it_works`: Doubles up on Julia-native (blue accent, closed-loop dynamics motif) and HRV vocabulary (R-peak) in a single detail without disturbing legibility of the rest of the word.
- `risk`: The crowned "R" is a subtle detail that reads best at ≥200px wide; at very small sizes it can look like a small accent mark rather than an intentional R-peak (verified still legible at 200px in testing).

## c3word-08 — Heart Badge Lockup
- `title`: Heart Badge Lockup
- `concept`: A two-tone geometric heart icon (purple/green halves, echoing
  the Julia palette) paired with "HeartRateLab" riding on a continuous ECG
  baseline that bumps into a single R-peak beneath "Rate" — an ECG literally
  underlining the word.
- `motif`: heart / ECG-underlining-the-word
- `colors`: purple #9558B2, green #389826 (heart), red #CB3C33 (cleft dot), ink #1A1A1A (baseline + text)
- `register`: typographic / warm
- `wordmark`: includes text ("HeartRateLab")
- `viewBox`: 640×220 (wide lockup)
- `why_it_works`: The most approachable/friendly lockup in the set — heart glyph reads instantly, and the underline literally ties the ECG motif to the name itself rather than sitting beside it.
- `risk`: Of the four lockups, this one leans most on the "heart" cliché; kept honest by pairing it with the Julia bicolor split and the ECG baseline rather than a plain red heart alone.

---

## Verification performed
- Rendered all 8 with `inkscape --export-type=png -w 400` and reviewed a
  4×2 contact sheet — all text renders with correct letters, no tofu/clipping.
- Re-rendered the four square marks at 32×32 and reviewed a contact sheet —
  all four remain legible/recognizable at favicon size (the "HRL" caption on
  c3word-03 is the one element that becomes texture-only at 32px; the heart
  and ring still carry the mark).
- Re-rendered the four lockups at 200px wide — "HeartRateLab" reads cleanly
  in all four; iterated `c3word-02` (crossbar simplified from a zigzag to a
  single spike for cleaner "H" legibility), `c3word-06` (dot nudged to sit
  over the Heart/Rate seam), and `c3word-07` (switched from a single-textLength
  run with a guessed offset to three explicit textLength segments so the
  R-peak crown sits precisely on the "R" glyph instead of floating beside it).

## Strongest picks
1. **c3word-04 (H♥L)** — cleanest, boldest square mark; works from favicon to billboard.
2. **c3word-05 (Triad Pulse Lockup)** — safest, most legible default horizontal lockup.
3. **c3word-07 (R-Peak Letter Lockup)** — most distinctive fusion technique (R-peak fused into the letterform itself), strong differentiator from the rest of the set.
