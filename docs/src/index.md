```@meta
CurrentModule = HeartRateLab
```

# HeartRateLab.jl

A comprehensive Julia package for **Heart Rate Variability (HRV) analysis** combining feature extraction, mechanistic modeling, data-driven methods, and interactive visualization.

## Quick Start

### Extract HRV Features

```julia
using HeartRateLab

# Load IBI data (inter-beat-intervals in milliseconds)
ibis = read_txt("your_data.txt")

# Extract the default feature set (time, frequency, geometric) as a DataFrame
features = extract_feature_set(ibis)

# All 53 features (adds the nonlinear set)
features_all = extract_feature_set(ibis; features=:all)

# Only the nonlinear features, or a custom subset by name
nonlinear_features = extract_feature_set(ibis; features=:nonlinear)
custom_features = extract_feature_set(ibis; features=["mean", "sdnn", "rmssd"])
```

### Fit Mechanistic Models

```julia
using DifferentialEquations

# Create and fit an LIF model
model = LIF()
result = fit(model, ibis; method=:gradient)

# Generate synthetic HRV data
synthetic = simulate(result.model, result.params, 1000)   # n_beats is positional

# Compare real vs synthetic
using GLMakie
plot_comparison(ibis, synthetic; model_name="LIF")
```

### Visualize Results

```julia
using GLMakie

# Plot IBI time series with statistics
plot_ibi_series(ibis)

# Poincaré plot (beat-to-beat variability)
plot_poincare(ibis)

# Frequency spectrum with HRV bands
plot_spectrum(ibis)

# Interactive 3D Lorenz plot
plot_lorenz_3d(ibis)
```

## Core Features

- **53 HRV Features** across 4 analysis domains
- **Input/Output**: Read/write TXT, WFDB, XDF formats
- **Preprocessing**: Outlier removal, ectopic beats, interpolation
- **4 Mechanistic Models**: LIF, Van der Pol, Lorenz, DMD
- **18 Visualization Functions**: Analysis, comparison, normative, and 3D interactive plots
- **Modular Extensions**: Load only what you need

## Installation

```julia
julia> using Pkg
julia> Pkg.add(url="https://github.com/abcsds/HeartRateLab.jl")
```

HeartRateLab is not yet registered in the Julia General registry; registration is planned. Until then, install directly from the GitHub URL as above.

```julia
# For visualization (optional)
julia> Pkg.add("GLMakie")

# For mechanistic models (optional)
julia> Pkg.add("DifferentialEquations")

# For Bayesian inference (optional)
julia> Pkg.add("Turing")
```

## API Reference

```@index
```

```@autodocs
Modules = [HeartRateLab]
```

### Evaluation

Ensemble simulation, model evaluation, and information-criterion ranking
(`simulate_ensemble`, `extract_ensemble_features`, `eval_distributional`,
`eval_scalar`, `eval_distance`, `information_criteria`, `rank_models`):

```@autodocs
Modules = [HeartRateLab.Evaluation]
```

## Citation

If you use HeartRateLab in your research, please cite:

```bibtex
@software{barradas2026heartrateLab,
  author = {Barradas, Alberto},
  title = {HeartRateLab.jl: Comprehensive Heart Rate Variability Analysis},
  version = {0.1.0},
  year = {2026},
  url = {https://github.com/abcsds/HeartRateLab.jl}
}
```
