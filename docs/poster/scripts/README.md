# Poster figure generators

Julia scripts that produce the figures and data tables for
`docs/poster/juliacon2026_poster.tex`. They are **documentation of how each
figure was made** — the poster itself is built from the committed PNGs by
`../build.sh` / `../watch.sh`, so you only need these when you want to
*regenerate* a figure.

Run any of them from the repo root with the project active (headless GR is used,
`ENV["GKSwstype"]="100"`, so no display is required):

```bash
julia --project=. docs/poster/scripts/<name>.jl
```

Paths are resolved relative to the script (`@__DIR__`), so they work from any
checkout location.

## What each script produces

| Script | Output | Inputs |
|--------|--------|--------|
| `model.jl` | `../model_results.csv` — L1-logistic **stability selection** (meditation vs healthy, subject-grouped resamples) + CV AUC | `test/testdata/{nsrdb,nsr2db,meditation}/windowed_w360_s120_features.csv` (tracked) |
| `figs_model.jl` | `../figs/stability_selection.png`, `../figs/three_way_comparison.png` (+ `feature_correlation.png`) | `../model_results.csv`, the windowed refs, and `pdf_all_cache.csv` (P1) |
| `clustermap.jl` | `../figs/feature_clustermap.png` — clustered \|correlation\| + dendrogram | `../model_results.csv`, nsrdb/nsr2db windowed refs |
| `zscores.jl` | `../zscores.csv` — P1 median feature values + z vs healthy prior **and** vs meditator prior | `docs/normative_priors.csv`, meditation windowed, `pdf_all_cache.csv` (P1) |
| `zscore_fig.jl` | `../figs/participant_zscores.png` — the dumbbell figure | `../zscores.csv` |
| `pipeline_fig.jl` | `../figs/pipeline_chain.png` — one-recording walkthrough | P1 raw recordings (see note) |
| `regen_participant_figs.jl` | `../figs/hero_participant_vs_normative.png`, `lfhf_over_time.png`, `rmssd_over_time.png`; **builds `pdf_all_cache.csv`** | P1 raw recordings, priors, windowed refs |

## Dependency order

```
model.jl ─▶ model_results.csv ─▶ clustermap.jl, figs_model.jl
regen_participant_figs.jl ─▶ pdf_all_cache.csv ─▶ zscores.jl ─▶ zscores.csv ─▶ zscore_fig.jl
                                          └────────────────────▶ figs_model.jl (3-way panel)
```

## Note on Participant P1 (personal data)

P1 is the author's own self-tracked recordings. The **raw** recordings
(`test/testdata/export/Resonant_Breathing/`) are **not** in this public repo, and
`pdf_all_cache.csv` — P1's derived per-window HRV features + recording dates — is
git-ignored (see `.gitignore` here). `regen_participant_figs.jl` rebuilds the
cache from the local recordings; the scripts that consume it
(`figs_model.jl`, `zscores.jl`) need that cache present to run.
