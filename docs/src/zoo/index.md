# The HRV Variable Zoo

A browsable **"Pokédex"** of every heart-rate-variability feature HeartRateLab
computes: **53 registered measures** across four domains. Each entry answers the
same three questions:

1. **What is it?** — definition, equation, aliases, and declared distribution family.
2. **What does *normal* look like?** — the empirical distribution over the pooled
   [nsrdb](https://physionet.org/content/nsrdb/) + [nsr2db](https://physionet.org/content/nsr2db/)
   normal-sinus-rhythm cohorts (360-beat windows, n up to 61 715), overlaid with a
   fitted normative prior, plus a normal-range table.
3. **What does it cost, and who introduced it?** — a *measured* wall-clock + allocation
   resource tier, curated use-cases, and the seminal citation.

Priors and normal-range statistics are descriptive references from a healthy cohort,
**not** clinical thresholds. See the [References](references.md) page for the full
bibliography. Resource tiers are measured on synthetic realistic RR at a 360-beat
window (`docs/zoo_gen/bench_resources.jl`).

**Resource tiers:** `◍◌◌◌◌` very low · `◍◍◌◌◌` low · `◍◍◍◌◌` moderate · `◍◍◍◍◌` high · `◍◍◍◍◍` very high.

**Fields** — each entry's *Applications by area* and *Citation* sections tie it to the
four fields of the consolidated [HRV knowledge base](references.md): the `C S P M`
column below marks per-field evidence coverage for **C**linical, **S**ports &
peak-performance, contemplative **P**ractice (● pooled/meta-analytic literature ·
◐ individual papers · ○ sparse/none), and **M**ethods & foundations (✔ seminal
reference on file).

## Time domain (20)

Statistics of the NN/RR intervals and their successive differences — the classic, cheapest, most-reported HRV panel.

| Feature | Definition | Dist. family | Resource tier | C S P M |
|---------|------------|--------------|---------------|---------|
| [`mean`](mean.md) | Mean inter-beat interval | `Normal` | ◍◌◌◌◌  very low | ● ● ● ✔ |
| [`sdnn`](sdnn.md) | Standard deviation of NN intervals | `Gamma` | ◍◌◌◌◌  very low | ● ◐ ◐ ✔ |
| [`median`](median.md) | Median inter-beat interval | `Normal` | ◍◍◌◌◌  low | ● ● ● ✔ |
| [`max`](max.md) | Maximum inter-beat interval | `Normal` | ◍◌◌◌◌  very low | ● ● ● ✔ |
| [`min`](min.md) | Minimum inter-beat interval | `Normal` | ◍◌◌◌◌  very low | ● ● ● ✔ |
| [`mean_hr`](mean_hr.md) | Mean heart rate | `Normal` | ◍◍◌◌◌  low | ● ● ● ✔ |
| [`std_hr`](std_hr.md) | Standard deviation of heart rate | `Gamma` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`max_hr`](max_hr.md) | Maximum heart rate | `Normal` | ◍◍◌◌◌  low | ● ● ● ✔ |
| [`min_hr`](min_hr.md) | Minimum heart rate | `Normal` | ◍◍◌◌◌  low | ● ● ● ✔ |
| [`median_hr`](median_hr.md) | Calculate the median heart rate in BPM from the Inter-Beat-Interval… | `Normal` | ◍◍◌◌◌  low | ● ● ● ✔ |
| [`range_hr`](range_hr.md) | Calculate the range (max − min) of the instantaneous heart rate in BPM | `Gamma` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`sdsd`](sdsd.md) | Standard deviation of successive differences | `Gamma` | ◍◍◌◌◌  low | ● ● ◐ ✔ |
| [`range`](range.md) | Range of inter-beat intervals | `Gamma` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`rmssd`](rmssd.md) | Root mean square of successive differences | `Gamma` | ◍◍◌◌◌  low | ● ● ◐ ✔ |
| [`sdann`](sdann.md) | Standard deviation of 5-min average NN intervals | `Gamma` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`pnn50`](pnn50.md) | Proportion of successive differences > 50 ms | `Beta` | ◍◍◌◌◌  low | ● ● ◐ ✔ |
| [`pnn20`](pnn20.md) | Proportion of successive differences > 20 ms | `Beta` | ◍◍◌◌◌  low | ● ● ◐ ✔ |
| [`cvsd`](cvsd.md) | Coefficient of variation of successive differences | `Gamma` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`cvnni`](cvnni.md) | Calculate the coefficient of variation of the NN intervals (SDNN / … | `Normal` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`rRR`](rRR.md) | Median relative RR interval distance | `Gamma` | ◍◍◌◌◌  low | ○ ○ ○ ✔ |

## Frequency domain (12)

Power in the ULF/VLF/LF/HF bands of the RR power spectrum — Welch periodogram on the resampled series by default (`config["freq_method"] == :welch`), with Lomb–Scargle on the raw unevenly-sampled series available as an alternative — plus band ratios and peak frequencies.

| Feature | Definition | Dist. family | Resource tier | C S P M |
|---------|------------|--------------|---------------|---------|
| [`ulf`](ulf.md) | Ultra-low frequency power (0-0.003 Hz) | `Gamma` | ◍◍◍◌◌  moderate | ● ◐ ◐ ✔ |
| [`vlf`](vlf.md) | Very low frequency power (0.003-0.04 Hz) | `Gamma` | ◍◍◍◌◌  moderate | ● ◐ ◐ ✔ |
| [`lf`](lf.md) | Low frequency power (0.04-0.15 Hz) | `Gamma` | ◍◍◍◌◌  moderate | ● ● ● ✔ |
| [`hf`](hf.md) | High frequency power (0.15-0.4 Hz) | `Gamma` | ◍◍◍◌◌  moderate | ● ● ● ✔ |
| [`tp`](tp.md) | Total power (0.003-0.4 Hz) | `Gamma` | ◍◍◍◌◌  moderate | ● ● ● ✔ |
| [`lf_peak`](lf_peak.md) | Peak frequency in LF band | `Normal` | ◍◍◍◌◌  moderate | ● ● ● ✔ |
| [`hf_peak`](hf_peak.md) | Peak frequency in HF band | `Normal` | ◍◍◍◌◌  moderate | ● ● ● ✔ |
| [`lf_hf_ratio`](lf_hf_ratio.md) | LF/HF power ratio | `LogNormal` | ◍◍◍◌◌  moderate | ● ● ● ✔ |
| [`lf_relative`](lf_relative.md) | LF power as proportion of total power | `Beta` | ◍◍◍◌◌  moderate | ● ● ● ✔ |
| [`hf_relative`](hf_relative.md) | HF power as proportion of total power | `Beta` | ◍◍◍◌◌  moderate | ● ● ● ✔ |
| [`lf_percentage`](lf_percentage.md) | LF power as percentage of total power | `Gamma` | ◍◍◍◌◌  moderate | ● ● ● ✔ |
| [`hf_percentage`](hf_percentage.md) | HF power as percentage of total power | `Gamma` | ◍◍◍◌◌  moderate | ● ● ● ✔ |

## Geometric (8)

Shape descriptors of the Poincaré / Lorenz return map and the RR histogram — robust to occasional artifacts.

| Feature | Definition | Dist. family | Resource tier | C S P M |
|---------|------------|--------------|---------------|---------|
| [`sd1`](sd1.md) | Poincare plot short-term variability | `Gamma` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`sd2`](sd2.md) | Poincare plot long-term variability | `Gamma` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`sd2_sd1`](sd2_sd1.md) | Ratio of SD2 to SD1 (cardiac sympathetic index) | `LogNormal` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`sd1_sd2_area`](sd1_sd2_area.md) | Poincare plot ellipse area | `LogNormal` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`cvi`](cvi.md) | Cardiac vagal index | `Normal` | ◍◍◌◌◌  low | ◐ ◐ ○ ✔ |
| [`ccsi`](ccsi.md) | Corrected cardiac sympathetic index | `LogNormal` | ◍◍◌◌◌  low | ◐ ◐ ○ ✔ |
| [`triangular_index`](triangular_index.md) | HRV triangular index | `Gamma` | ◍◍◌◌◌  low | ● ◐ ○ ✔ |
| [`tinn`](tinn.md) | Triangular interpolation of NN interval histogram | `Gamma` | ◍◍◍◍◍  very high | ● ◐ ○ ✔ |

## Nonlinear (13)

Entropy, complexity and fractal-scaling measures probing the nonlinear structure of cardiac control (need adequate record length).

| Feature | Definition | Dist. family | Resource tier | C S P M |
|---------|------------|--------------|---------------|---------|
| [`apen`](apen.md) | Approximate entropy | `Normal` | ◍◍◍◍◌  high | ● ◐ ◐ ✔ |
| [`sampen`](sampen.md) | Sample entropy | `Normal` | ◍◍◍◍◌  high | ● ◐ ◐ ✔ |
| [`hurst`](hurst.md) | Hurst exponent | `Normal*` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`renyi0`](renyi0.md) | Renyi entropy of order 0 | `Normal` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`renyi1`](renyi1.md) | Renyi entropy of order 1 | `Normal` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`renyi2`](renyi2.md) | Renyi entropy of order 2 | `Normal` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`shan_en`](shan_en.md) | Calculate the Shannon entropy of the Inter-Beat-Interval histogram | `Normal` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`svd_en`](svd_en.md) | Calculate the Singular Value Decomposition (SVD) entropy of the IBI… | `Normal` | ◍◍◌◌◌  low | ● ◐ ◐ ✔ |
| [`fuzzyen`](fuzzyen.md) | Calculate the fuzzy entropy of the Inter-Beat-Intervals (IBIs) | `Normal` | ◍◍◍◍◍  very high | ● ◐ ◐ ✔ |
| [`spec_en`](spec_en.md) | Calculate the spectral entropy of the Inter-Beat-Intervals (IBIs): … | `Normal` | ◍◍◍◌◌  moderate | ● ◐ ◐ ✔ |
| [`perm_en`](perm_en.md) | Calculate the permutation entropy of the Inter-Beat-Intervals (IBIs) | `Normal` | ◍◍◍◌◌  moderate | ● ◐ ◐ ✔ |
| [`mse`](mse.md) | Calculate the Multiscale Entropy (MSE) complexity index of the IBIs… | `Normal` | ◍◍◍◍◌  high | ● ◐ ◐ ✔ |
| [`dfa2`](dfa2.md) | DFA long-term scaling exponent alpha2 | `Normal` | ◍◍◍◍◌  high | ◐ ○ ◐ ✔ |

\* `hurst` declares `Beta` (theoretically bounded to (0,1)); the table shows the empirically-fitted `Normal` family instead, since observed values leave that interval — see [`hurst`](hurst.md#What-does-*normal*-look-like?).

## All entries

The reference dex entry is [`rmssd`](rmssd.md). Full per-feature detail — figure,
normal-range table, resource benchmark, and citation — lives on each entry page
linked above.
