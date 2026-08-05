# `svd_en`

> **Singular Value Decomposition (Svd) Entropy Of The Ibis: The Shannon**

| | |
|---|---|
| **Aliases** | `svd_entropy`, `svd_en` |
| **Domain** | `nonlinear` |
| **Distribution family** | `Normal` |
| **Equation** | `` |
| **Resource intensity** | ◍◍◌◌◌  low — _Nonlinear subgraph (template matching / embedding — O(N²) worst case)._ (measured, see §Resources) |

## Definition

Calculate the Singular Value Decomposition (SVD) entropy of the IBIs: the Shannon.

## What does *normal* look like?

Fitted normative prior: **Normal(μ = 0.1347, σ = 0.07358)**  —  KS p = 1.1e-59, n = 3000.

![Normative distribution of svd_en](figs/svd_en.png)

Empirical distribution over the **NSR2DB** normative windows (360-beat windows, 120-beat stride), overlaid with the fitted `Normal` prior density. Vertical lines mark the median and the 5–95% range.

### Normal-range summary (NSR2DB)

| statistic | value |
|---|---|
| median | 0.1139 |
| IQR (25–75%) | 0.08836 – 0.1563 |
| 5–95% range | 0.06946 – 0.2632 |
| mean ± sd | 0.1347 ± 0.07359 |
| n windows | 3000 |

_n varies by feature: pooled time/frequency/geometric features use the full nsrdb+nsr2db table (up to n = 56 472); the 13 nonlinear/entropy features are O(N²)/template-matching and are fit on a fixed-seed ≈3000-window subsample instead (`test/tools/collect_extended_features.jl`, seed 20260729); `ulf` uses a long-window NSRDB-only extraction (see its own page)._

## Use cases

- Complexity of the embedded RR trajectory via its singular spectrum.
- Dimensionality / structure of the dynamics.
- Nonlinear-dynamics research.

## Applications by area

*Evidence is reported at the measure-family level; a specific variant may not be the exact index measured in every cited study.*

### Clinical

**Coverage: statistics** — a large/pooled literature (reviews or meta-analyses exist).

Genuinely common here: a 2026 PRISMA review found 55 studies (2011–2025) applying fuzzy/Shannon/spectral/SVD/permutation/multiscale entropy, concentrated in diabetes, cardiovascular disease and neurological conditions, with classification accuracies up to 92.5%. The dominant direction is lower entropy/complexity in disease — with one notable reversal (higher multiscale entropy predicted incident stroke in atrial fibrillation).

*Dominant reported direction:* down — lower entropy/complexity in disease (one AF-stroke reversal).

**Key references:** [yang2026](@cite).

### Sports & peak performance

**Coverage: individual papers** — a small, scattered literature (no pooled meta-analysis).

Uncommon: no dedicated meta-analyses exist, and a 2025 systematic review of 19 soccer-overtraining studies found none used any nonlinear/entropy index at all. The handful of small papers that do exist (n = 9–27, sometimes animal models) give mixed directions.

*Dominant reported direction:* mixed / essentially unstudied.

**Key references:** [yang2026](@cite).

### Meditation & contemplation

**Coverage: individual papers** — a small, scattered literature (no pooled meta-analysis).

One dedicated review (26 studies) covers Shannon/ApEn/SampEn/permutation/Renyi/multiscale entropy in meditation/yoga: most studies report reduced complexity during meditation, but this is not unanimous (some report increases, especially multiscale entropy at long scales), and effect sizes are frequently small/non-significant.

*Dominant reported direction:* mostly down, with scale- and measure-dependent exceptions.

**Key references:** [deka2023](@cite).

See the [effect-distribution meta-analysis](../usecases/effect-distributions.md) page for the harvested per-study effect sizes/p-values behind these domain summaries (`docs/zoo_gen/effect_stats.csv`).

## Resources

Resource-intensity rank **◍◍◌◌◌  low** is **measured** — median wall-clock time + allocations over a 360-beat window on synthetic realistic RR (`docs/zoo_gen/bench_resources.jl`; full grid in `resource_bench.csv`).

| metric (360-beat window) | value |
|---|---|
| cold median wall-time | 0.01286 ms |
| warm median wall-time | 0.01279 ms |
| allocations (cold) | 20.2 KiB |

*Cold* = fresh memoization caches (builds every shared representation from scratch); *warm* = shared representations (`diff`, periodogram, Poincaré coords, DFA fluctuation) already cached, so only this feature is recomputed. The tier is derived from the cold cost; see `Nonlinear subgraph (template matching / embedding — O(N²) worst case).`

## Citation

SVD (singular-spectrum) entropy, Roberts, Penny & Rezek (1999).

**Seminal reference(s):** [roberts1999](@cite).

See the [References](references.md) page for the full bibliography.
