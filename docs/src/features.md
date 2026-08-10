# Heart Rate Variability Features

HeartRateLab extracts **53 HRV features** across **4 analysis domains** from inter-beat-interval (IBI) time series data.

Every feature has a full "Pokédex" entry in the [HRV Variable Zoo](zoo/index.md) — definition, equation, normative distribution, resource cost, and seminal citation.

## Feature Domains

### 1. Time Domain (20 features)

Statistics of the NN/RR intervals and their successive differences — the classic, cheapest, most-reported HRV panel:

- [`mean`](zoo/mean.md) — Mean inter-beat interval
- [`sdnn`](zoo/sdnn.md) — Standard deviation of NN intervals
- [`median`](zoo/median.md) — Median inter-beat interval
- [`max`](zoo/max.md) — Maximum inter-beat interval
- [`min`](zoo/min.md) — Minimum inter-beat interval
- [`mean_hr`](zoo/mean_hr.md) — Mean heart rate (BPM)
- [`std_hr`](zoo/std_hr.md) — Standard deviation of heart rate
- [`max_hr`](zoo/max_hr.md) — Maximum heart rate
- [`min_hr`](zoo/min_hr.md) — Minimum heart rate
- [`median_hr`](zoo/median_hr.md) — Median heart rate (BPM)
- [`range_hr`](zoo/range_hr.md) — Range (max − min) of instantaneous heart rate
- [`sdsd`](zoo/sdsd.md) — Standard deviation of successive differences
- [`range`](zoo/range.md) — Range of inter-beat intervals
- [`rmssd`](zoo/rmssd.md) — Root mean square of successive differences
- [`sdann`](zoo/sdann.md) — Standard deviation of 5-min average NN intervals
- [`pnn50`](zoo/pnn50.md) — Proportion of successive differences > 50 ms
- [`pnn20`](zoo/pnn20.md) — Proportion of successive differences > 20 ms
- [`cvsd`](zoo/cvsd.md) — Coefficient of variation of successive differences
- [`cvnni`](zoo/cvnni.md) — Coefficient of variation of NN intervals (SDNN / mean)
- [`rRR`](zoo/rRR.md) — Median relative RR interval distance

### 2. Frequency Domain (12 features)

Power in the ULF/VLF/LF/HF bands of the RR power spectrum, plus band ratios and peak frequencies:

- [`ulf`](zoo/ulf.md) — Ultra-low frequency power (0–0.003 Hz)
- [`vlf`](zoo/vlf.md) — Very low frequency power (0.003–0.04 Hz)
- [`lf`](zoo/lf.md) — Low frequency power (0.04–0.15 Hz)
- [`hf`](zoo/hf.md) — High frequency power (0.15–0.4 Hz)
- [`tp`](zoo/tp.md) — Total power (0.003–0.4 Hz)
- [`lf_peak`](zoo/lf_peak.md) — Peak frequency in the LF band
- [`hf_peak`](zoo/hf_peak.md) — Peak frequency in the HF band
- [`lf_hf_ratio`](zoo/lf_hf_ratio.md) — LF/HF power ratio
- [`lf_relative`](zoo/lf_relative.md) — LF power as proportion of total power
- [`hf_relative`](zoo/hf_relative.md) — HF power as proportion of total power
- [`lf_percentage`](zoo/lf_percentage.md) — LF power as percentage of total power
- [`hf_percentage`](zoo/hf_percentage.md) — HF power as percentage of total power

### 3. Geometric (8 features)

Shape descriptors of the Poincaré / Lorenz return map and the RR histogram — robust to occasional artifacts:

- [`sd1`](zoo/sd1.md) — Poincaré plot short-term variability
- [`sd2`](zoo/sd2.md) — Poincaré plot long-term variability
- [`sd2_sd1`](zoo/sd2_sd1.md) — Ratio of SD2 to SD1 (cardiac sympathetic index)
- [`sd1_sd2_area`](zoo/sd1_sd2_area.md) — Poincaré plot ellipse area
- [`cvi`](zoo/cvi.md) — Cardiac vagal index
- [`ccsi`](zoo/ccsi.md) — Corrected cardiac sympathetic index
- [`triangular_index`](zoo/triangular_index.md) — HRV triangular index
- [`tinn`](zoo/tinn.md) — Triangular interpolation of the NN interval histogram

### 4. Nonlinear (13 features)

Entropy, complexity, and fractal-scaling measures probing the nonlinear structure of cardiac control (need adequate record length):

- [`apen`](zoo/apen.md) — Approximate entropy
- [`sampen`](zoo/sampen.md) — Sample entropy
- [`hurst`](zoo/hurst.md) — Hurst exponent
- [`renyi0`](zoo/renyi0.md) — Rényi entropy of order 0
- [`renyi1`](zoo/renyi1.md) — Rényi entropy of order 1 (Shannon)
- [`renyi2`](zoo/renyi2.md) — Rényi entropy of order 2
- [`shan_en`](zoo/shan_en.md) — Shannon entropy of the IBI histogram
- [`svd_en`](zoo/svd_en.md) — Singular value decomposition entropy
- [`fuzzyen`](zoo/fuzzyen.md) — Fuzzy entropy
- [`spec_en`](zoo/spec_en.md) — Spectral entropy
- [`perm_en`](zoo/perm_en.md) — Permutation entropy
- [`mse`](zoo/mse.md) — Multiscale entropy complexity index
- [`dfa2`](zoo/dfa2.md) — Detrended fluctuation analysis long-term scaling exponent (α₂)

!!! note "DFA α₁"
    The short-term DFA exponent α₁ is available as the `dfa1` *representation* (`HeartRateLab.Features.function_registry["dfa1"](m)`), a building block rather than a registry feature — it does not appear in `extract_feature_set` output.

## Feature Extraction

### Basic Usage

`extract_feature_set` returns a one-row `DataFrame` with one column per feature. The `features` keyword selects a preset set (`:default`, `:fast`, `:all`, `:nonlinear`) or an explicit vector of feature names:

```julia
using HeartRateLab

# Load data
ibis = read_txt("data.txt")

# Default set (time, frequency, geometric — excludes nonlinear and ulf)
features = extract_feature_set(ibis)

# All 53 features (adds the expensive nonlinear set)
features_all = extract_feature_set(ibis; features=:all)

# Only the nonlinear features
features_nl = extract_feature_set(ibis; features=:nonlinear)

# Custom subset by name
features_custom = extract_feature_set(ibis; features=["mean", "sdnn", "rmssd", "lf", "hf"])
```

### Signal Length Requirements

Different features require minimum signal lengths:

```julia
# Check valid features for a given signal length
valid = valid_features(length(ibis))

# Features table
# Signal length 10:  14 features
# Signal length 50:  30 features
# Signal length 100: 41 features
# Signal length 128: 53 features (all)
```

### Feature Preprocessing

Features are automatically computed with preprocessing:

```julia
# Preprocessing steps (automatic)
# 1. Replace outliers with NaN
# 2. Interpolate missing values
# 3. Compute features from clean IBI series
# 4. Return NaN for invalid features

# Note: ensure input IBIs are in milliseconds
```

## API Reference

```@autodocs
Modules = [HeartRateLab.Features]
Private = false
```
