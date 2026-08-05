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

# Extract all 53 HRV features
features = extract_feature_set(ibis)

# Extract specific domains
time_features = extract_feature_set(ibis; domains=[:time])
freq_features = extract_feature_set(ibis; domains=[:frequency])
nonlinear_features = extract_feature_set(ibis; domains=[:nonlinear])
```

### Fit Mechanistic Models

```julia
using DifferentialEquations

# Create and fit an LIF model
model = LIF()
result = fit(model, ibis; method=:gradient)

# Generate synthetic HRV data
synthetic = simulate(result.model, result.params, n_beats=1000)

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
- **9 Visualization Functions**: Analysis, comparison, 3D interactive plots
- **Modular Extensions**: Load only what you need

## Installation

```julia
julia> using Pkg
julia> Pkg.add("HeartRateLab")

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

## Citation

If you use HeartRateLab in your research, please cite:

```bibtex
@software{barradas2024heartrateLab,
  author = {Barradas, Alberto},
  title = {HeartRateLab.jl: Comprehensive Heart Rate Variability Analysis},
  year = {2024},
  url = {https://github.com/abcsds/HeartRateLab.jl}
}
```
