# `rRR`

> **Median Relative Rr Interval Distance**

| | |
|---|---|
| **Aliases** | `rRR` |
| **Domain** | `time` · `statistics` |
| **Distribution family** | `Gamma` |
| **Equation** | `median(euclidean_dist(relRR; mean(relRR)))*100` |
| **Resource intensity** | ◍◍◌◌◌  low — _Level 1–2 (base statistics over successive differences)._ (measured, see §Resources) |

## Definition

Median relative RR interval distance. Formally: `median(euclidean_dist(relRR; mean(relRR)))*100`.

## What does *normal* look like?

Fitted normative prior: **Gamma(α = 4.63, θ = 0.7846)**  —  KS p = 2.9e-215, n = 56472.

![Normative distribution of rRR](figs/rRR.png)

Empirical distribution over the **pooled nsrdb+nsr2db** normative windows (360-beat windows, 120-beat stride), overlaid with the fitted `Gamma` prior density. Vertical lines mark the median and the 5–95% range.

### Normal-range summary (pooled nsrdb+nsr2db)

| statistic | value |
|---|---|
| median | 3.064 |
| IQR (25–75%) | 2.437 – 4.092 |
| 5–95% range | 1.822 – 6.717 |
| mean ± sd | 3.633 ± 2.7 |
| n windows | 56472 |

_n varies by feature: pooled time/frequency/geometric features use the full nsrdb+nsr2db table (up to n = 56 472); the 13 nonlinear/entropy features are O(N²)/template-matching and are fit on a fixed-seed ≈3000-window subsample instead (`test/tools/collect_extended_features.jl`, seed 20260729); `ulf` uses a long-window NSRDB-only extraction (see its own page)._

## Use cases

- Artifact-robust HRV summary from relative RR intervals (Vollmer 2015).
- Field / wearable recordings with occasional ectopy or noise.
- Complements SDNN/RMSSD when data quality is uncertain.

## Applications by area

*Evidence is reported at the measure-family level; a specific variant may not be the exact index measured in every cited study.*

No applications literature was harvested for `rRR` in the 2026-07 clinical / sports / meditation literature sweep (`hrv-applications-bibliography` workflow) — treat this measure as **sparse-or-none** on real-world application evidence until a dedicated search is done. Its aliases and closest relatives may have their own applications; see the [HRV Variable Zoo](index.md) overview.

See the [effect-distribution meta-analysis](../usecases/effect-distributions.md) page for the harvested per-study effect sizes/p-values behind these domain summaries (`docs/zoo_gen/effect_stats.csv`).

## Resources

Resource-intensity rank **◍◍◌◌◌  low** is **measured** — median wall-clock time + allocations over a 360-beat window on synthetic realistic RR (`docs/zoo_gen/bench_resources.jl`; full grid in `resource_bench.csv`).

| metric (360-beat window) | value |
|---|---|
| cold median wall-time | 0.009818 ms |
| warm median wall-time | 0.009888 ms |
| allocations (cold) | 21.3 KiB |

*Cold* = fresh memoization caches (builds every shared representation from scratch); *warm* = shared representations (`diff`, periodogram, Poincaré coords, DFA fluctuation) already cached, so only this feature is recomputed. The tier is derived from the cold cost; see `Level 1–2 (base statistics over successive differences).`

## Citation

Vollmer (2015) — a robust, simple relative-RR measure of HRV.

**Seminal reference(s):** [vollmer2015](@cite).

See the [References](references.md) page for the full bibliography.
