# `hf`

> **High Frequency Power (0.15-0.4 Hz)**

| | |
|---|---|
| **Aliases** | `high_frequency` |
| **Domain** | `frequency` |
| **Distribution family** | `Gamma` |
| **Equation** | `integral(PSD; 0.15; 0.4) Hz` |
| **Resource intensity** | ◍◍◍◌◌  moderate — _Frequency subgraph (requires a Welch/Lomb–Scargle periodogram first). Warm (shared representation cached) is 12× cheaper._ (measured, see §Resources) |

## Definition

High frequency power (0.15-0.4 Hz). Formally: `integral(PSD; 0.15; 0.4) Hz`.

## What does *normal* look like?

Fitted normative prior: **Gamma(α = 0.6916, θ = 460.9)**  —  KS p = 1.1e-188, n = 56472.

![Normative distribution of hf](figs/hf.png)

Empirical distribution over the **pooled nsrdb+nsr2db** normative windows (360-beat windows, 120-beat stride), overlaid with the fitted `Gamma` prior density. Vertical lines mark the median and the 5–95% range.

### Normal-range summary (pooled nsrdb+nsr2db)

| statistic | value |
|---|---|
| median | 130 |
| IQR (25–75%) | 56.86 – 287.6 |
| 5–95% range | 19.57 – 1073 |
| mean ± sd | 318.7 ± 829.2 |
| n windows | 56472 |

_n varies by feature: pooled time/frequency/geometric features use the full nsrdb+nsr2db table (up to n = 56 472); the 13 nonlinear/entropy features are O(N²)/template-matching and are fit on a fixed-seed ≈3000-window subsample instead (`test/tools/collect_extended_features.jl`, seed 20260729); `ulf` uses a long-window NSRDB-only extraction (see its own page)._

## Use cases

- Respiratory sinus arrhythmia; a spectral index of vagal (parasympathetic) tone.
- Paced-breathing and respiratory-coupling studies.
- Vagal-withdrawal detection under stress.

## Applications by area

*Evidence is reported at the measure-family level; a specific variant may not be the exact index measured in every cited study.*

### Clinical

**Coverage: statistics** — a large/pooled literature (reviews or meta-analyses exist).

LF, HF and total power are consistently reduced in disease states (cardiac mortality risk, depression, anxiety, T2DM autonomic neuropathy) across large meta-analyses — but the LF/HF *ratio* itself is repeatedly non-significant in the very same datasets where its components move significantly, undercutting its billing as the most sensitive "sympathovagal balance" composite.

*Dominant reported direction:* down — LF/HF/TP reduced in disease; the LF/HF ratio specifically is often null.

**Key references:** [rueda2024](@cite); [wu2023](@cite); [chalmers2014](@cite).

### Sports & peak performance

**Coverage: statistics** — a large/pooled literature (reviews or meta-analyses exist).

Heavily used for training-load/overreaching monitoring, anchored by a 27-study meta-analysis; the intuitive "LF up / HF down under overload" model is directly contradicted by a body of work reporting paradoxical parasympathetic hyperactivity in overreached athletes, and the popular LF/HF > 4 "overtraining" cutoff is shown to be driven mainly by spontaneous breathing frequency rather than training state.

*Dominant reported direction:* contested — sympathetic-dominance model vs. parasympathetic-hyperactivity counter-evidence, confounded by respiration.

**Key references:** [bellenger2016](@cite).

### Meditation & contemplation

**Coverage: statistics** — a large/pooled literature (reviews or meta-analyses exist).

Commonly measured but shows null-to-mixed effects: the most direct meta-analysis (4 pooled trials) found no significant LF/HF change, and a well-powered 10-day mindfulness RCT likewise found no HF/LF-HF effect even though RMSSD rose — individual intensive-retreat studies show more mixed, technique- and task-dependent patterns confounded by voluntary breath-rate change.

*Dominant reported direction:* null-to-mixed, confounded by breathing.

**Key references:** [radmark2019](@cite).

See the [effect-distribution meta-analysis](../usecases/effect-distributions.md) page for the harvested per-study effect sizes/p-values behind these domain summaries (`docs/zoo_gen/effect_stats.csv`).

## Resources

Resource-intensity rank **◍◍◍◌◌  moderate** is **measured** — median wall-clock time + allocations over a 360-beat window on synthetic realistic RR (`docs/zoo_gen/bench_resources.jl`; full grid in `resource_bench.csv`).

| metric (360-beat window) | value |
|---|---|
| cold median wall-time | 0.06091 ms |
| warm median wall-time | 0.00506 ms |
| allocations (cold) | 30.0 KiB |

*Cold* = fresh memoization caches (builds every shared representation from scratch); *warm* = shared representations (`diff`, periodogram, Poincaré coords, DFA fluctuation) already cached, so only this feature is recomputed. The tier is derived from the cold cost; see `Frequency subgraph (requires a Welch/Lomb–Scargle periodogram first). Warm (shared representation cached) is 12× cheaper.`

## Citation

Akselrod et al. (1981) / Task Force (1996) HF band (0.15–0.4 Hz), the respiratory-sinus-arrhythmia band.

**Seminal reference(s):** [akselrod1981](@cite); [taskforce1996](@cite).

See the [References](references.md) page for the full bibliography.
