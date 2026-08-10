# HeartRateLab.jl — Logo Design Brief (shared by all studios)

## The package
`HeartRateLab.jl` is a Julia package for **Heart Rate Variability (HRV)** analysis
from time series of **inter-beat intervals (IBIs / NN intervals)**. It does
feature extraction (time-domain, frequency-domain, nonlinear, entropy, fractal),
dynamical modeling (leaky integrate-and-fire, Van der Pol oscillator, Lorenz
system), and interactive visualization (NN time series, Poincaré plots, frequency
domain, phase-space plots). Author: Alberto Barradas. FOSS, scientific, high-
performance. Repo: HeartRateLab.jl.

## The job
Design a package logo in the tradition of the Julia ecosystem. Output is **SVG**.

## Julia logo conventions (respect them)
- The Julia language mark is **three circles** ("dots") arranged as a triangle:
  one on top-ish, two below, in the three Julia colors.
- Julia package logos riff on this three-dot / three-color identity.
- **Official Julia brand colors** (use these exact hexes):
  - Julia Purple `#9558B2`
  - Julia Green  `#389826`
  - Julia Red    `#CB3C33`
  - Julia Blue   `#4063D8`  (accent / fourth color; use sparingly)
  - Darker shade helpers if you need depth: purple `#6A3D82`, green `#2A7A1E`,
    red `#A62F27`, ink `#1A1A1A`.

## HRV visual vocabulary (draw from these)
- **ECG / heartbeat waveform**: the P-QRS-T complex; the tall spiky R-peak is the
  most iconic silhouette of "heartbeat".
- **Inter-beat interval (IBI/NN)**: the *gap* between two R-peaks — spacing,
  brackets, the distance ⟷ between beats. This is literally what the package
  measures. Negative space / rhythm.
- **Poincaré plot**: scatter of NN(n) vs NN(n+1); forms an **elongated ellipse
  cloud along the 45° diagonal** (SD1 short axis, SD2 long axis). Extremely
  recognizable to HRV people.
- **Nonlinear dynamics attractors**: Lorenz butterfly, Van der Pol **limit cycle**
  (a closed loop in phase space), spirals.
- **Pulse**: concentric rings radiating, a beat propagating.
- **Heart glyph**: abstract/geometric heart, ideally constructed from dots/curves
  rather than a cliché valentine.

## Canvas & technical spec (MANDATORY — every SVG must comply)
- Root: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 320" ...>`
  Square 320×320. **No `width`/`height`** on root (let it scale), or if present,
  make them equal.
- **Transparent background** (no opaque full-canvas rect). If a logo needs a
  filled tile, use a rounded-rect that leaves a margin.
- Keep the mark **centered** with ~24px of breathing room from edges.
- **Must stay legible at 32×32 px** (favicon). No hairline text, no >~5 tiny
  elements that merge into mush at small size.
- **Fully self-contained**: no external fonts (convert text to a common web-safe
  stack AND keep it large/bold, OR use paths), no external images, no scripts,
  no `<use xlink:href>` to outside files. Inline everything.
- Valid, well-formed XML. Prefer crisp geometry (circles, paths, strokes) over
  giant machine-generated path dumps.
- Optional: a subtle gradient or a single soft shadow is fine; don't overdo it.

## Per-logo documentation (write into your studio notes.md)
For **every** SVG you keep, record:
- `id` (matches filename, e.g. `A-jn-03`)
- `title` (short evocative name)
- `concept` (1–2 sentences: what HRV idea + how Julia identity is expressed)
- `motif` (ECG / Poincaré / IBI-gap / attractor / pulse / heart / three-dot / …)
- `colors` (which Julia colors and why)
- `register` (minimalist | scientific | illustrative | typographic)
- `wordmark` (icon-only | includes text)
- `why_it_works` (1 sentence of argumentation)
- `risk` (1 honest sentence: where it might fail — small size, cliché, etc.)

## Quality bar (what "good" means here)
- A stranger sees it and reads **"heart / pulse / rhythm"** AND **"Julia
  package"** within a second.
- Distinct from every other logo in the set — no near-duplicates.
- Confident use of negative space; no clutter.
- Scientifically honest (a Poincaré cloud actually looks like an ellipse on the
  diagonal; an ECG actually has the QRS shape).

## Mostly icon-only
Most logos are icon-only. Include a **small number** with the wordmark
"HeartRateLab", "HRL", or a ♥ monogram — clearly label those `wordmark: includes text`.
