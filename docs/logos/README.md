# HeartRateLab.jl — logo explorations

This folder holds the full logo design exploration for the package. Open
`../index.html` in a browser to view the curated showcase (60 logos = 20 per
direction), each with its argumentation and documentation.

## What's here

- `BRIEF.md` — the shared design brief given to every studio (Julia logo
  conventions, HRV visual vocabulary, canvas spec, quality bar).
- `_seeds/` — three reference marks (one per direction) used to set the house
  style before the studios ran.
- `A_julia_native/` — **Direction A** (Julia-native, three-dot always present).
  30 raw SVG attempts + `notes-*.md` documentation.
- `B_hrv_first/` — **Direction B** (HRV-first: ECG, Poincaré, attractors,
  hearts). 30 raw SVG attempts + notes.
- `C_hybrid/` — **Direction C** (fusion + wordmark lockups). 28 raw SVG attempts
  + notes.
- `manifest.json` — the curated 60, ranked, with per-logo docs.
- `make_manifest.py` — regenerates `manifest.json` (edit the ranked list here).
- `build_index.py` — regenerates `../index.html` from `manifest.json`,
  inlining each SVG.

**All 91 raw attempts are preserved** (30 + 30 + 28 + 3 seeds); the showcase
presents the best 20 per direction.

## How the set was made

1. A shared brief + three seed references established the house style.
2. Nine design studios (three per direction) ran in parallel, each producing
   ~10 distinct SVGs and self-correcting via a render → view → fix loop.
3. An independent adversarial critic reviewed all 88, challenged the curation,
   flagged favicon (32px) failures and near-duplicates.
4. Final curation reconciled both, then built this showcase.

## Rebuild

```bash
python3 make_manifest.py   # -> manifest.json
python3 build_index.py     # -> ../index.html
```

## Colors (official Julia palette)

purple `#9558B2` · green `#389826` · red `#CB3C33` · blue `#4063D8` (accent)

## Picking a winner

If you settle on one mark, the SVG is production-ready as-is. For a favicon,
prefer the marks noted as robust at small size (e.g. `b3heart-03` Sonar Pulse,
`b1ecg-05` R-Peak Bolt, `c2lobe-08` Dot-Fused Heart, `a3pulse-07` Groove). I can
then generate a wordmark lockup, favicon set, and light/dark variants for it.
