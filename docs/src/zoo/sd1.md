# `sd1`

> **Poincare Plot Short-Term Variability**

| | |
|---|---|
| **Aliases** | `sd1`, `sd1_width` |
| **Domain** | `geometric` |
| **Distribution family** | `Gamma` |
| **Equation** | `std((IBI[1:end-1] - IBI[2:end]) / sqrt(2))` |
| **Resource intensity** | ◍◍◌◌◌  low — _Geometric subgraph (Poincaré coords / RR histogram + reductions). Warm (shared representation cached) is 5× cheaper._ (measured, see §Resources) |

## Definition

Poincare plot short-term variability. Formally: `std((IBI[1:end-1] - IBI[2:end]) / sqrt(2))`.

## What does *normal* look like?

Fitted normative prior: **Gamma(α = 2.7, θ = 8.621)**  —  KS p = 7.7e-66, n = 56472.

![Normative distribution of sd1](figs/sd1.png)

Empirical distribution over the **pooled nsrdb+nsr2db** normative windows (360-beat windows, 120-beat stride), overlaid with the fitted `Gamma` prior density. Vertical lines mark the median and the 5–95% range.

### Normal-range summary (pooled nsrdb+nsr2db)

| statistic | value |
|---|---|
| median | 17.96 |
| IQR (25–75%) | 12.42 – 26.93 |
| 5–95% range | 8.528 – 55.43 |
| mean ± sd | 23.28 ± 19.42 |
| n windows | 56472 |

_n varies by feature: pooled time/frequency/geometric features use the full nsrdb+nsr2db table (up to n = 56 472); the 13 nonlinear/entropy features are O(N²)/template-matching and are fit on a fixed-seed ≈3000-window subsample instead (`test/tools/collect_extended_features.jl`, seed 20260729); `ulf` uses a long-window NSRDB-only extraction (see its own page)._

## Use cases

- Short-term Poincaré-plot width; equals RMSSD/√2, a vagal marker.
- At-a-glance geometric read of beat-to-beat variability.
- Robust-to-artifact summary for noisy field recordings.

## Applications by area

*Evidence is reported at the measure-family level; a specific variant may not be the exact index measured in every cited study.*

### Clinical

**Coverage: statistics** — a large/pooled literature (reviews or meta-analyses exist).

A well-established clinical output across cardiology, endocrinology and psychiatry: lower SD1/SD2 (reduced beat-to-beat and long-term variability) consistently marks worse disease state, though most reported sample sizes are small (n = 18–95). SD1 is mathematically identical to RMSSD (SD1 = RMSSD/√2), so papers reporting both as independently "significant" double-count the same statistic, and the SD2/SD1 ratio's billing as a "sympathovagal balance" surrogate is directly contested.

*Dominant reported direction:* down — lower SD1/SD2 → worse disease state.

**Key references:** [ciccone2017](@cite); [rahman2018](@cite); [stuckey2014](@cite).

### Sports & peak performance

**Coverage: individual papers** — a small, scattered literature (no pooled meta-analysis).

Largely restates RMSSD-based vagal-tone monitoring in geometric form (SD1 = RMSSD/√2), plus an SD2/SD1 "stress score" aimed at overreaching detection; SD1 rises with aerobic training and falls with acute intensity/overtraining, though overtraining shows a non-monotonic pattern (higher than sedentary, far below trained) and no meta-analysis isolates a Poincaré-specific effect size distinct from RMSSD.

*Dominant reported direction:* up with training, down acutely/with overtraining (same underlying signal as RMSSD).

**Key references:** [bellenger2016](@cite); [ciccone2017](@cite).

### Meditation & contemplation

**Coverage: individual papers** — a small, scattered literature (no pooled meta-analysis).

A handful of small, likely underpowered studies (n = 8–18) report SD1/SD2-ratio changes across meditation traditions, but the direction of SD2 and total Poincaré-plot area disagrees between the two studies that report it — exploratory, not established.

*Dominant reported direction:* inconsistent across the two available small studies.

**Key references:** [ciccone2017](@cite).

!!! note
    **SD1 ≡ RMSSD/√2** — the two are mathematically identical statistics, yet much of the clinical/sports literature reports both as independently "significant" findings, which double-counts the same signal ([ciccone2017](@cite)).

See the [effect-distribution meta-analysis](../usecases/effect-distributions.md) page for the harvested per-study effect sizes/p-values behind these domain summaries (`docs/zoo_gen/effect_stats.csv`).

## Resources

Resource-intensity rank **◍◍◌◌◌  low** is **measured** — median wall-clock time + allocations over a 360-beat window on synthetic realistic RR (`docs/zoo_gen/bench_resources.jl`; full grid in `resource_bench.csv`).

| metric (360-beat window) | value |
|---|---|
| cold median wall-time | 0.02549 ms |
| warm median wall-time | 0.0054 ms |
| allocations (cold) | 25.4 KiB |

*Cold* = fresh memoization caches (builds every shared representation from scratch); *warm* = shared representations (`diff`, periodogram, Poincaré coords, DFA fluctuation) already cached, so only this feature is recomputed. The tier is derived from the cold cost; see `Geometric subgraph (Poincaré coords / RR histogram + reductions). Warm (shared representation cached) is 5× cheaper.`

## Citation

Tulppo et al. (1996) introduced ellipse-fitted SD1; Brennan et al. (2001) derived the closed form linking it to SDSD (primacy contested).

**Seminal reference(s):** [tulppo1996](@cite); [brennan2001](@cite).

See the [References](references.md) page for the full bibliography.
