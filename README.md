# HeartRateLab.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://abcsds.github.io/HeartRateLab.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://abcsds.github.io/HeartRateLab.jl/dev/)
[![Build Status](https://github.com/abcsds/HeartRateLab.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/abcsds/HeartRateLab.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/abcsds/HeartRateLab.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/abcsds/HeartRateLab.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

A comprehensive Julia package for **Heart Rate Variability (HRV) analysis** combining feature extraction, mechanistic modeling, data-driven methods, and interactive visualization.

## Quick Start

Extract 53 HRV features from inter-beat-interval (IBI) time series in 3 lines:

```julia
using HeartRateLab

ibis = read_txt("your_data.txt")           # Load IBI data (milliseconds)
features = extract_feature_set(ibis)       # Fast features (time, frequency, geometric)
features_all = extract_feature_set(ibis; features=:all)  # All 53 features (adds nonlinear)
```

Fit a mechanistic model and generate synthetic HRV data:

```julia
using DifferentialEquations
model = LIF(τ=50, I_base=0.5, threshold=1.0, noise_amp=0.1)
result = fit(model, ibis; method=:gradient)
synthetic = simulate(result.model, result.params, n_beats=1000)
```

Visualize HRV analysis results:

```julia
using GLMakie
fig = plot_ibi_series(ibis)
fig_compare = plot_comparison(ibis, synthetic; model_name="LIF")
display(fig)
```

## Installation

```julia
julia> using Pkg
julia> Pkg.add("HeartRateLab")
```

For visualization, optionally install:
```julia
julia> Pkg.add("GLMakie")  # For interactive plots
julia> Pkg.add("DifferentialEquations")  # For mechanistic models
julia> Pkg.add("Turing")  # For Bayesian inference
```

## Features

- **53 HRV Features** across 5 domains (time, statistics, frequency, geometric, nonlinear)
- **Input/Output**: Read/write TXT, WFDB, XDF formats
- **Preprocessing**: Handle outliers, ectopic beats, interpolation
- **4 Mechanistic Models**: LIF, Van der Pol, Lorenz, DMD
- **13 Visualization Functions**: Analysis, comparison, normative, and 3D plots
- **Modular Extensions**: Load only what you need (DifferentialEquations, Turing, GLMakie optional)

## Documentation

- **[API Documentation](https://abcsds.github.io/HeartRateLab.jl/dev/)** - Complete function reference
- **[Flagship demo](docs/flagship_demo.qmd)** - End-to-end worked example (rendered via `nix run .#render`)

## Key Components

### Feature Extraction (53 Features)

Extract comprehensive HRV metrics across multiple domains:

```julia
# Default: extract the default feature set (time, frequency, geometric — excludes nonlinear + ulf)
features = extract_feature_set(ibis)               # ← DEFAULT_FEATURES

# Fast set: same but includes ulf (needs ≥24h recording for meaningful ulf)
features_fast = extract_feature_set(ibis; features=:fast)

# Full 53-feature extraction (adds nonlinear: apen, sampen, hurst, dfa, rényi)
features_all = extract_feature_set(ibis; features=:all)

# Only the expensive nonlinear features
features_nl = extract_feature_set(ibis; features=:nonlinear)

# Custom subset
features_custom = extract_feature_set(ibis; features=["mean", "sdnn", "rmssd", "lf", "hf"])
```

#### Feature Sets and Computational Cost

Features are organized into two tiers based on computational complexity:

| Set | Count | Complexity | Domains | Safe length |
|-----|-------|------------|---------|-------------|
| **`DEFAULT_FEATURES`** (default) | 39 | O(n) – O(n log n) | time, frequency, geometric | Any |
| **`FAST_FEATURES`** | 40 | O(n) – O(n log n) | time, frequency, geometric | Any |
| **`NONLINEAR_FEATURES`** | 14 | O(n²) or worse | nonlinear, entropy | < 5 000 beats |
| **`ALL_FEATURES`** | 53 | O(n²) | all | < 5 000 beats |

`DEFAULT_FEATURES` = `FAST_FEATURES` minus `ulf` (ultra-low frequency power requires ≥ 24-hour recordings to be physiologically meaningful).

The **nonlinear features** (`apen`, `sampen`, `fuzzyen`, `shan_en`, `svd_en`, `spec_en`, `perm_en`, `mse`, `hurst`, `dfa1`, `dfa2`, `renyi0`, `renyi1`, `renyi2`) use algorithms whose time and memory consumption grow quadratically (or worse) with signal length. On recordings longer than ~5 000 beats they become slow; above ~50 000 beats they can exhaust available RAM.

The default `features=:default` setting is safe for any recording length and covers the most commonly reported HRV metrics in the literature (RMSSD, SDNN, pNN50, LF/HF ratio, Poincaré SD1/SD2, etc.).

#### Windowed Analysis and Bootstrapping

For long recordings, **windowed analysis** avoids the nonlinear scaling problem entirely — each window is short enough for even `ALL_FEATURES`:

```julia
# Windowed extraction (60-beat windows, stride 30) — default uses FAST_FEATURES
df = windowed_feature_set(ibis; window_size=60, stride=30, time=:beats)

# Windowed with ALL features (safe: each window is only 60 beats)
df_all = windowed_feature_set(ibis; window_size=60, stride=30, features=:all)
```

**Bootstrapping normative ranges from windowed features:**

A practical workflow for building normative reference statistics from long or many recordings:

```julia
using Statistics, DataFrames

# 1. Extract windowed features across a cohort
ibis = read_txt("long_recording.txt")
ibis = replace_zeros(ibis) |> replace_bio_outliers |> interpolate_nans

df = windowed_feature_set(ibis; window_size=60, stride=30, features=:all)

# 2. Compute per-feature normative statistics (μ ± σ)
stats = describe(df, :mean, :std, :min, :max, :median)

# 3. Flag outlier windows: |x − μ| > 4σ
μ = describe(df, :mean).mean
σ = describe(df, :std).std
for col in names(df)
    outliers = abs.(df[!, col] .- μ[col]) .> 4 * σ[col]
    println("$col: $(sum(outliers)) outlier windows out of $(nrow(df))")
end

# 4. Aggregate to participant level (robust to recording length)
participant_features = combine(
    df,
    names(df) .=> mean .=> names(df),       # mean across windows
)
```

This approach gives you:
- **Length-invariant features**: A 5-minute and a 24-hour recording both produce comparable per-window statistics.
- **Distributional information**: You get the spread of each feature across time, not just a point estimate.
- **Robust normative ranges**: Aggregate across participants for population-level μ and σ.
- **Efficient computation**: Each 60-beat window runs in O(1) even with `ALL_FEATURES`.

#### Analytical Feature Distributions

Every feature in the registry carries an **analytical distribution family** derived from the computational graph that transforms IBIs into feature values.  Given that IBIs come from a normally distributed random variable, the distribution of each derived feature follows from the mathematical operations applied:

| Transform | Distribution | Features |
|-----------|-------------|----------|
| Mean / sum of Normals | **Normal** | `mean`, `median`, `max`, `min`, `mean_hr`, `max_hr`, `min_hr`, `lf_peak`, `hf_peak`, `cvi` |
| √Var (sample std dev) | **Gamma** | `sdnn`, `rmssd`, `sdsd`, `sdann`, `range`, `cvsd`, `rRR`, `std_hr`, `sd1`, `sd2`, `triangular_index`, `tinn` |
| ∫\|P(f)\|² df (spectral band power: sum of squared spectral components → sum of Exp → Gamma) | **Gamma** | `ulf`, `vlf`, `lf`, `hf`, `tp`, `lf_percentage`, `hf_percentage` |
| Proportion in \[0,1\] | **Beta** | `pnn50`, `pnn20`, `lf_relative`, `hf_relative`, `hurst` |
| Ratio of Gamma RVs (log is ≈ Normal) | **LogNormal** | `lf_hf_ratio`, `sd2_sd1`, `sd1_sd2_area`, `ccsi` |
| Entropy / regression slope (CLT) | **Normal** | `apen`, `sampen`, `dfa1`, `dfa2`, `renyi0`, `renyi1`, `renyi2` |

Distribution families are stored in each `HRFeature.distribution` field and are accessible via the feature registry:

```julia
using HeartRateLab

# Inspect a feature's distribution family
feat = feature_registry["sdnn"]
feat.distribution  # Distributions.Gamma
```

##### Fitting normative priors from data

The script `test/tools/fit_normative_distributions.jl` fits MLE parameters for each feature's distribution family using windowed normative datasets (nsrdb + nsr2db by default).  It produces:

- **TOML file** with fitted parameters (usable as normative priors)
- **CSV file** with parameters, sample sizes, and KS goodness-of-fit p-values

```bash
# Fit distributions from 360-beat windowed normative data
julia --project=. test/tools/fit_normative_distributions.jl

# Or with custom datasets and window size
DATASETS=nsrdb,nsr2db WINDOW_SIZE=360 STRIDE=120 \
  julia --project=. test/tools/fit_normative_distributions.jl
```

The fitted distributions encode population-level normative ranges.  For example, if `sdnn ~ Gamma(α=3.2, θ=16.5)`, you can compute percentiles, z-scores, and probability of observing a given SDNN value under the healthy-population reference:

```julia
using Distributions
d = Gamma(3.2, 16.5)       # Fitted normative distribution for SDNN
cdf(d, 30.0)               # P(SDNN ≤ 30 ms) under normative reference
quantile(d, [0.05, 0.95])  # 90% normative interval
```

### Mechanistic Models

Fit and simulate from data-driven HRV models:

```julia
# Available models:
# - LIF (Leaky Integrate-and-Fire): stochastic spiking neuron
# - VanDerPol: nonlinear oscillator with relaxation dynamics
# - Lorenz: chaotic system with sensitive dependence on initial conditions
# - DMD: data-driven spectral decomposition

result = fit(LIF(), ibis; method=:gradient)
synthetic = simulate(result.model, result.params, n_beats=1000)
```

### Visualization

Create publication-quality HRV analysis plots:

```julia
# Core analysis
plot_ibi_series(ibis)                    # Time series with statistics
plot_poincare(ibis)                      # Beat-to-beat scatter plot
plot_spectrum(ibis)                      # Frequency domain with HRV bands
plot_flagship(ibis, fit_result)          # Combined flagship visualization

# Model comparison
plot_comparison(real, synthetic)         # Real vs synthetic comparison
plot_model_heatmap(results)             # Model × feature reproduction heatmap
plot_lorenz_3d(ibis)                    # Interactive 3D dynamics visualization
plot_radar(datasets)                    # Radar/spider chart for feature comparison
plot_correlations(feature_sets)         # Cross-dataset feature correlations
plot_feature_violins(real, ensembles)   # Violin plots of feature distributions

# Normative analysis
plot_normative_kde_comparison(datasets, features)  # KDE overlay with σ-bands
plot_feature_correlogram(df, features)             # Pearson correlation heatmap
plot_normative_pairplot(datasets, features)        # Scatter matrix (pairplot)
```

## Motivation

While several open-source HRV packages exist (NeuroKit in Python), most Julia options are unmaintained. HeartRateLab provides:

- **Comprehensive**: 53 features across 5 analysis domains
- **Performant**: Leverages Julia's speed for batch processing
- **Extensible**: Modular architecture with optional dependencies
- **Modern**: Interactive GLMakie visualizations and ODE-based models
- **Research-focused**: Publication-ready analysis and comparison plots

This work builds upon tools developed during PhD research:
- [hrv](https://github.com/abcsds/hrv): Real-time biofeedback tools
- [VizHRV](https://github.com/abcsds/VizHRV): Advanced visualization
- [HeartRateVariability.jl](https://github.com/abcsds/HeartRateVariability.jl): Feature extraction foundation

# Abstract
Heart Rate Variability (HRV) analysis involves examining variations in heart Inter-Beat-Intervals (IBIs). These variations can be extracted using various features. The devices for measuring and recording IBIs are one of the most economic and widely available form of biosignal acquisition. Additionally, there exist experimental and clinical evidence that HRV features are related to the autonomic nervous system (ANS) and can be used to assess its state, providing a valuable insight into cognitive processes. However, available tools for HRV analysis are mainly focused on feature extraction as a numeric value, often neglect to model and visualize many features, and fail to communicate the underlying processes. In this work, we present a comprehensive set of tools for HRV analysis: The Free and Open Source (FOSS) package HeartRateLab. It leverages the power of julia's high performance computing capabilities, FOSS scientific computing libraries, modeling, machine learning, signal processing, and visualization tools to provide a complete set of features for HRV extraction, models for data-driven HRV analysis, and visualizations. The package is designed to be used in an offline setting, as a feature extraction library, but can also be used in online settings for teaching, communication, or HRV biofeedback.

## Implementation Status

| Component | Status | Details |
|-----------|--------|---------|
| **Core Features** | ✅ Complete | 53 HRV features across 5 domains |
| **Input/Output** | ✅ Complete | TXT, WFDB, XDF formats |
| **Preprocessing** | ✅ Complete | Outlier removal, interpolation, windowing |
| **Mechanistic Models** | ✅ Complete | LIF, Van der Pol, Lorenz (ODE-based) |
| **Spectral Models** | 🧪 Beta | DMD (data-driven; reconstructs dynamics about the mean) |
| **Bayesian Inference** | ✅ Available | Turing.jl MCMC fitting (`:bayesian`) + convergence (`rhat`) |
| **Real-time Streaming** | ✅ Available | LSL RR/PP live HRV via `nix run .#viz` |
| **Visualizations** | 🚧 Expanding | Offline + live LSL plots; entropy/fractal/DMD + 3D views in progress |
| **Deep Learning Models** | ⏳ Planned | Neural ODE, VAE (Flux.jl) |

## Contributing

Contributions are welcome! To get started:

1. Fork and clone the repository
2. Build the dev/test image: `nix run .#build`
3. Run the suite: `nix run .#test` (WFDB tools + X11 display via Docker)
4. Make your changes in a feature branch
5. Submit a pull request

## Citation

If you use HeartRateLab in your research, please cite:

```bibtex
@software{barradas2025heartrateLab,
  author = {Barradas, Alberto},
  title = {HeartRateLab.jl: Comprehensive Heart Rate Variability Analysis},
  version = {0.1.0},
  year = {2025},
  url = {https://github.com/abcsds/HeartRateLab.jl}
}
```

## References

Key papers implemented in this package:

- **Büzás et al. (2022)**: LIF model for HRV analysis
- **Lopez-Chamorro et al. (2018)**: Van der Pol oscillator modeling
- **Esperer et al. (2008)**: Lorenz plot analysis
- **Malik et al. (1996)**: HRV standards and frequency domains
- **Poincaré plot analysis**: Guzik et al., Brennan et al.

### Reproducibility
A Dockerfile and a flake.nix are provided to reproduce the development environment and workflow:
```bash
nix run .#build # build development environment docker image
nix run .#test # run tests
nix run # Open the julia REPL
nix run .#act # Test github workflows
```
