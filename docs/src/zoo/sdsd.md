# `sdsd`

> **Standard Deviation Of Successive Differences**

| | |
|---|---|
| **Aliases** | `sdsd` |
| **Domain** | `time` · `statistics` |
| **Distribution family** | `Gamma` |
| **Equation** | `std(diff(IBI))` |
| **Resource intensity** | ◍◍◌◌◌  low — _Level 1–2 (base statistics over successive differences)._ (measured, see §Resources) |

## Definition

Standard deviation of successive differences. Formally: `std(diff(IBI))`.

## What does *normal* look like?

Fitted normative prior: **Gamma(α = 2.7, θ = 12.19)**  —  KS p = 7.7e-66, n = 56472.

![Normative distribution of sdsd](figs/sdsd.png)

Empirical distribution over the **pooled nsrdb+nsr2db** normative windows (360-beat windows, 120-beat stride), overlaid with the fitted `Gamma` prior density. Vertical lines mark the median and the 5–95% range.

### Normal-range summary (pooled nsrdb+nsr2db)

| statistic | value |
|---|---|
| median | 25.4 |
| IQR (25–75%) | 17.57 – 38.08 |
| 5–95% range | 12.06 – 78.39 |
| mean ± sd | 32.92 ± 27.47 |
| n windows | 56472 |

_n varies by feature: pooled time/frequency/geometric features use the full nsrdb+nsr2db table (up to n = 56 472); the 13 nonlinear/entropy features are O(N²)/template-matching and are fit on a fixed-seed ≈3000-window subsample instead (`test/tools/collect_extended_features.jl`, seed 20260729); `ulf` uses a long-window NSRDB-only extraction (see its own page)._

## Use cases

- Short-term variability from successive differences (closely tracks RMSSD/SD1).
- Vagal-tone screening on short segments.
- Preprocessing sanity check against RMSSD.

## Applications by area

*Evidence is reported at the measure-family level; a specific variant may not be the exact index measured in every cited study.*

### Clinical

**Coverage: statistics** — a large/pooled literature (reviews or meta-analyses exist).

RMSSD/pNN50 are among the most heavily studied HRV measures in psychiatry: two independent meta-analyses converge on significantly reduced RMSSD/pNN50 in major depression vs. healthy controls (g ≈ −0.46 to −0.51, thousands of patients pooled), extending to broader cardiovascular-risk and mental-disorder populations.

*Dominant reported direction:* down — reduced in depression/anxiety (g ≈ −0.3 to −0.5).

**Key references:** [koch2019](@cite); [wu2023](@cite).

### Sports & peak performance

**Coverage: statistics** — a large/pooled literature (reviews or meta-analyses exist).

RMSSD is the dominant, most-meta-analyzed short-term vagal index in sports science for training-load, recovery and overreaching monitoring — but its direction under overload is genuinely context-dependent: it can rise *or* fall depending on overload type/timing, an ambiguity documented across multiple competing meta-analyses rather than settled.

*Dominant reported direction:* context-dependent — rises with some overreaching patterns, falls with others (pre-competition taper).

**Key references:** [bellenger2016](@cite).

### Meditation & contemplation

**Coverage: individual papers** — a small, scattered literature (no pooled meta-analysis).

The one dedicated meta-analysis pooled only 3 studies and found a null RMSSD effect, explicitly citing too few large RCTs — yet several individually-reported trials claim significant RMSSD/pNN50 increases with practice, the largest reported-vs-pooled gap of the three application domains.

*Dominant reported direction:* contested — meta-analytic null vs. positive individual trials.

**Key references:** [radmark2019](@cite).

See the [effect-distribution meta-analysis](../usecases/effect-distributions.md) page for the harvested per-study effect sizes/p-values behind these domain summaries (`docs/zoo_gen/effect_stats.csv`).

## Resources

Resource-intensity rank **◍◍◌◌◌  low** is **measured** — median wall-clock time + allocations over a 360-beat window on synthetic realistic RR (`docs/zoo_gen/bench_resources.jl`; full grid in `resource_bench.csv`).

| metric (360-beat window) | value |
|---|---|
| cold median wall-time | 0.009077 ms |
| warm median wall-time | 0.0055 ms |
| allocations (cold) | 7.9 KiB |

*Cold* = fresh memoization caches (builds every shared representation from scratch); *warm* = shared representations (`diff`, periodogram, Poincaré coords, DFA fluctuation) already cached, so only this feature is recomputed. The tier is derived from the cold cost; see `Level 1–2 (base statistics over successive differences).`

## Citation

SD of successive differences, Task Force (1996) short-term panel. Successive-difference HRV measures predate the Task Force standard: Ewing et al. (1984) used them clinically, and the underlying statistic traces to von Neumann's (1941) mean-square successive difference (not independently on file here).

**Seminal reference(s):** [taskforce1996](@cite); [ewing1984](@cite).

See the [References](references.md) page for the full bibliography.
