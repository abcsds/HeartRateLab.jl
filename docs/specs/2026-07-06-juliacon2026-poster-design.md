# JuliaCon 2026 Poster — Design Spec

**Title:** *Using The HeartRateLab.jl for Normative Evaluation of Heart Rate
Variability from Open Datasets*
**Author:** Alberto Barradas (abcsds) · **Venue:** JuliaCon Global 2026, Johannes
Gutenberg University, Mainz, Germany · Aug 10–15 2026
**Format:** Portrait A0 (841 × 1189 mm), custom `tcolorbox` LaTeX layout.
**Date:** 2026-07-06

## Goal

A conference poster demonstrating that HeartRateLab.jl can answer the contextual
question *"Is this new experimental data normal?"* by contrasting HRV features
against normative distributions fitted from open PhysioNet datasets. The poster
shows two side-by-side cases and doubles as a demonstration of HRL as a **personal
daily HRV monitor**.

## Design system (extracted from the JuliaCon 2026 template)

> The `manavarya09/design-extract` skill requested by the user does **not exist**
> (GitHub returns "Repository not found"; user has no public repos). The design was
> instead extracted directly from the supplied JuliaCon 2026 poster-template image
> via palette sampling (ImageMagick) + the canonical Julia brand colors.

| Token | Hex | Use |
|-------|-----|-----|
| `jcindigo` | `#38376C` | primary background |
| `jcindigodk` | `#322E5E` | background gradient bottom |
| `jcpurple` | `#4B518C` | section rails / mid band |
| `jclav` | `#F3E8F2` | footer / light card band |
| `jcgreen` | `#389826` | badge, photo ring, positive accent (Julia green) |
| `jured` | `#CB3C33` | data series / alert accent (Julia red) |
| `jupurple` | `#9558B2` | data series accent (Julia purple) |
| `jublue` | `#4063D8` | data series accent (Julia blue) |

Typography: a bold sans (Fira Sans / TeX Gyre Heros / Lato) for headings, matching
the template's heavy geometric sans; regular weight for body. White text on indigo,
indigo text on lavender. Rounded `tcolorbox` cards with subtle shadow; a faint
bubble/gradient tikz layer echoes the template background.

## Layout (top → bottom)

1. **Header band** (indigo, bubble bg): POSTER badge (green), title (white bold),
   author line, QR to `github.com/abcsds/HeartRateLab.jl`.
2. **Intro row** (2 cards): Abstract (accepted text, **verbatim**) | Description /
   "Why context matters".
3. **Methods band** (full width): IBI → preprocess → 53 features → window
   (360 beats / 120 stride) → fit priors (Normal/Gamma/Beta/LogNormal) → z-equiv vs
   **56,472** pooled healthy windows (nsrdb + nsr2db). Includes the small
   between-dataset KDE figure as a validity check (two healthy DBs agree).
4. **Results row** (2 columns, side by side):
   - **Case A — Meditation cohort** (PhysioNet *Heart Rate Oscillations during
     Meditation*, 58 records). TikZ z-score forest of the 4 headline features from
     the abstract.
   - **Case B — Anonymous longitudinal participant** ("daily monitor"): 88 recording
     dates, 148 windows, 2019–2025. TikZ z-score forest of 9 features + the hero
     9-feature participant-vs-normative KDE + two over-time panels (LF/HF elevated,
     RMSSD typical).
5. **Takeaway strip**: selective LF-band inflation = the resonance signature; HRL
   answers "is this normal?" in context.
6. **Footer band** (lavender): juliacon global 2026 wordmark, Mainz/date, repo URL.

## Figures (all real HeartRateLab output, extracted from the participant report)

| File | Source | Role |
|------|--------|------|
| `figs/hero_participant_vs_normative.png` | report fig "Resonant_Breathing vs All Normal reference" | hero, 9-feature KDE w/ 68/95/99.7% bands |
| `figs/lfhf_over_time.png` | report "LF/HF over time" | Case B — sessions above +2σ |
| `figs/rmssd_over_time.png` | report "RMSSD over time" | Case B — inside ±1σ |
| `figs/between_dataset_kde.png` | report "Between-dataset comparison" | Methods — nsrdb vs nsr2db agreement |

Two z-score **forest plots** are drawn natively in TikZ (no external figure-gen):
horizontal σ axis (−3…+3) with ±1σ (blue) / ±2σ (gold) / beyond (red) bands and
lollipop markers per feature — echoing the report's band coloring.

## Data (verified)

**Case B — personal participant** (real HRL z-equiv from the w360/s120 report):

| Feature | z | Feature | z | Feature | z |
|---|---|---|---|---|---|
| LF/HF | +2.64 | SDNN | +1.12 | RMSSD | +0.03 |
| LF Power | +2.55 | pNN50 | +0.74 | SD1 | +0.03 |
| SD2 | +1.19 | Mean IBI | +0.07 | HF Power | −0.17 |

**Case A — meditation cohort** (FINAL — reproducible from the shipped data). The
poster forest now draws the **reproducible recompute**, not the accepted-abstract
numbers: **Mean IBI +1.02, pNN50 +1.32, RMSSD +0.94, SDNN +0.90.**

**Exact aggregation used** (identical to the poster's stated method): for each
feature take the **median across all 2686 windows** of
`meditation/windowed_w360_s120_features.csv`, then the **quantile z-equivalent**
`z = Φ⁻¹(F_prior(median))`, where `F_prior` is the fitted healthy prior from
`docs/normative_priors.csv` (mean = Normal(778.07, 143.71); pnn50 = Beta(0.4272,
10.3405); rmssd = Gamma(2.7000, 12.1746); sdnn = Gamma(4.0192, 13.1164); pooled
nsrdb+nsr2db, 56 472 windows). Every drawn value is reproducible from the two
shipped CSVs — no display/WFDB needed. Full audit: `docs/poster/zscore-reconciliation.html`.

> **Reconciliation outcome (2026-07-29).** The accepted abstract's
> **RMSSD +0.624 / SDNN +0.776 are stale** — they map to observed medians (~42–45 /
> ~70–73 ms) *below* what the shipped CSV yields (49.98 / 74.68 ms), i.e. they came
> from an earlier meditation feature extraction not committed to this repo and are
> **not recoverable** under any aggregation × method. Mean IBI +1.019 reproduces
> exactly; the abstract's pNN50 +1.353 reproduces only under *moment* z (quantile z
> gives +1.32, used here for method consistency). The abstract phrase "reduced
> pNN50" is also wrong — +1.3σ is an **increase**. The forest and captions were
> updated accordingly; because RMSSD/SDNN now read ~+0.9σ, the caption "stays within
> the typical band" was softened to "modestly elevated but under 1σ". The Abstract
> quotation card retains the accepted submission wording (already de-contradicted to
> "increased pNN50").

## Deliverables

- `docs/poster/juliacon2026_poster.tex` — source
- `docs/poster/juliacon2026_poster.pdf` — compiled A0
- `docs/poster/figs/*.png` — real HRL figures
- `docs/poster/README.md` — build instructions
- A full self-review with prioritized improvement suggestions.

## Build

`lualatex` (or `pdflatex`) via local TeX Live 2025 (`tikzposter`, `tcolorbox`,
`beamerposter` all present). QR generated with `qrencode` if available.
