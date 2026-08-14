# JuliaCon 2026 Poster

Portrait-A0 poster: **Using The HeartRateLab.jl for Normative Evaluation of Heart
Rate Variability from Open Datasets** (Alberto Barradas, abcsds).

## Files

| File | What |
|------|------|
| `juliacon2026_poster.tex` | LaTeX source (custom `tcolorbox` A0, portrait) |
| `juliacon2026_poster.pdf` | Compiled poster (single A0 page) |
| `juliacon2026_poster_preview.png` | Raster preview (150 dpi) |
| `figs/hero_participant_vs_normative.png` | 9-feature participant-vs-normative KDE |
| `figs/lfhf_over_time.png` | LF/HF over 88 recording dates |
| `figs/rmssd_over_time.png` | RMSSD over 88 recording dates |
| `figs/between_dataset_kde.png` | nsrdb vs nsr2db agreement (validity) |
| `figs/juliacon2026_prospectus.png` | JuliaCon 2026 brand reference (not placed) |

All four placed figures are **real HeartRateLab output**, extracted from
`docs/reports/participant_Resonant_Breathing_w360s120_report.html`. The two
z-score forest plots are drawn natively in TikZ from the numbers in the spec.

## Build

Needs a TeX Live with `FiraSans`, `tcolorbox`, `qrcode`, `fontawesome5`
(all in `texlive-full`). Run `pdflatex` **twice** (the full-page background uses
`remember picture`/`overlay`, and the QR/refs settle on the second pass):

```bash
pdflatex juliacon2026_poster.tex
pdflatex juliacon2026_poster.tex
```

Rasterise a preview (Ghostscript):

```bash
gs -sDEVICE=png16m -r150 -dNOPAUSE -dBATCH -dQUIET \
   -sOutputFile=juliacon2026_poster_preview.png juliacon2026_poster.pdf
```

## Design

Brand extracted from the JuliaCon 2026 template + the site source
(`github.com/JuliaCon/www.juliacon.org`, `franklin` branch): indigo bubble
background, Julia-logo accent colors (red `#CB3C33`, green `#389826`, purple
`#9558B2`, blue `#4063D8`), Fira Sans. Full rationale and the data table:
`docs/specs/2026-07-06-juliacon2026-poster-design.md`.

## Regenerating the source figures at higher DPI (optional)

The placed PNGs are report-resolution (~1500 px wide). For large-format print you
may want to re-render them from the report generator inside the HRL Docker image:

```bash
# from repo root, with hrlab:latest built (nix run .#build)
docker run --rm -v "$PWD:/workdir" hrlab:latest \
  "julia --project=. test/tools/generate_participant_report.jl Resonant_Breathing 360 120"
```

then re-extract / copy the emitted PNGs into `figs/`.
