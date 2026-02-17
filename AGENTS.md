# HeartRateLab.jl — Agent Context (CLAUDE.md)

## Project Overview

HeartRateLab is a Julia package (v1.0.0) for comprehensive Heart Rate Variability (HRV) analysis based on inter-beat intervals (IBIs). It provides feature extraction, preprocessing, frequency analysis, modeling, and real-time visualization.

- **Author**: Alberto Barradas <abcsds@gmail.com>
- **Repository**: `abcsds/HeartRateLab.jl`
- **Julia version**: 1.11+
- **Code style**: [BlueStyle](https://github.com/invenia/BlueStyle)
- **License**: MIT (pending)

## Architecture

```
src/
├── HeartRateLab.jl          # Main module entry point, exports, includes
├── input.jl                 # Input: read_xdf, read_txt, read_wfdb
├── preprocessing.jl         # Preprocessing: outlier removal, interpolation, windowing
├── Features.jl              # Feature registry + 44 HRV features via @register macro
├── Frequency.jl             # Frequency analysis: Welch, Lomb-Scargle, band power
├── Visualization/           # GLMakie + LSL real-time visualizations
│   ├── Visualization.jl     # Submodule with lazy loaders
│   ├── default.jl           # Full LSL dashboard (RR, NN, SDNN, Poincaré, spectrum)
│   ├── geometric.jl         # Poincaré plot with ellipse overlay
│   ├── heart_rate.jl        # BPM time series
│   ├── heart_rate_tt.jl     # BPM with time tags
│   └── distribution.jl      # Histogram / density
└── Models/                  # [NOT INTEGRATED] Experimental model scripts
    ├── Models.jl            # Empty — needs module definition
    ├── LIF.jl               # Leaky Integrate-and-Fire + Turing inference skeleton
    ├── neural_ODE.jl        # Neural ODE VAE with Flux/DiffEqFlux
    ├── van_der_pol_interactive.jl  # Van der Pol oscillator (GLMakie interactive)
    └── VAE.jl               # Empty — planned for ectopic beat detection
```

## Key Design Decisions

### Feature Registry System
Features are declared with a custom `@register` macro in `Features.jl`. Each feature is a memoized function that receives an `HRMeasurement` struct. The registry tracks name, aliases, domains, and documentation. Feature extraction returns DataFrames.

```julia
# Typical feature declaration pattern:
@register "feature_name" ["alias1"] [:time_domain] """
Documentation string with citation.
"""
feature_name(m::HRMeasurement) = # computation
```

Three registries: `feature_registry`, `representation_registry`, `function_registry`.

### Submodule Access Pattern
- Input and Preprocessing functions are directly exported from `HeartRateLab`
- Features, Frequency, and Visualization are accessed via dot notation:
  - `HeartRateLab.Features.extract_feature_set(data)`
  - `HeartRateLab.Frequency.welch(data)`
  - `HeartRateLab.Visualization.default()`
- Models module is commented out in `HeartRateLab.jl:10`

### Visualization Architecture
Visualizations are currently **executable scripts** loaded via `include()` at runtime through lazy loader functions. They depend on LSL for real-time streaming. They are NOT modular functions — they use global state and create their own figures.

## Running Tests

```bash
# From project root, using the WFDB tools:
julia --project=. -e 'using Pkg; Pkg.test()'

# Or via nix:
nix run .#test
```

Tests require:
- WFDB `ann2rr` binary on PATH (for `read_wfdb` tests)
- Test data in `test/testdata/`
- Baseline CSVs in `test/target/`

### Current Test Status (as of 2026-02-17)
- **11 pass, 7 error** — errors are in Input (5), Preprocessing/ectopic_beats (1), Features (1)
- Input errors likely due to missing WFDB binary or XDF dependency issues
- Features error likely cascades from Input failure

## Dependencies

**Core**: CSV, DataFrames, DataInterpolations, StatsBase, Memoization, MacroTools, Distributed
**Signal Processing**: DSP, LombScargle, Trapz, DFA ([abcsds/DFA.jl](https://github.com/abcsds/DFA.jl) — unregistered, installed via git URL), Hurst, EntropyHub
**Visualization**: GLMakie, Plots, LSL
**Input**: XDF
**Models (not in Project.toml yet)**: DifferentialEquations, Flux, DiffEqFlux, Optim, Turing

## Important Files

| File | Purpose |
|------|---------|
| `src/HeartRateLab.jl` | Main module — controls what's included and exported |
| `src/Features.jl` | Largest file (~992 lines) — feature registry + all 44 features |
| `src/Frequency.jl` | Welch/Lomb-Scargle periodograms + band power calculation |
| `test/runtests.jl` | Full test suite — comparison against baseline CSVs |
| `test/target/example.csv` | Baseline: 44 features for the example dataset |
| `Project.toml` | Dependencies — Models deps not yet added |
| `LOG.md` | Development diary — timeline and design decisions |
| `README.md` | Feature checklist (README-driven development) |

## Known Issues and TODOs

- `Features.jl:920` — FIXME: DFA scales are wrong
- `Frequency.jl:88` — FIXME: `find_peak` incorrect index after filtering
- `Features.jl:434` — TODO: all other interpolation methods via config
- `Features.jl:868-869` — TODO: DFA visualization
- `Models/Models.jl` — Empty, needs module definition
- `Models/VAE.jl` — Empty, planned for ectopic beat detection via Koopman eigenfunctions
- `Models/LIF.jl` — Uses `HeartRateVariability` (old package) instead of `HeartRateLab`
- Visualization scripts use global state and `include()` pattern — needs refactoring
- Missing models: Lorenz system, Dynamic Mode Decomposition
- Missing model deps in Project.toml: DifferentialEquations, Flux, DiffEqFlux, Turing

## Conventions

- Preprocessing functions come in mutating (`!`) and non-mutating pairs
- All feature functions receive `HRMeasurement` and are `@memoize`d
- NaN is used as sentinel for missing/invalid IBI values throughout the pipeline
- IBI values are in **milliseconds** throughout the package
- Test data: `test/testdata/example.txt` contains 4,193 IBI samples
- Windowed analysis uses `:beats` or `:ms` time units
- Frequency bands: ULF (0-0.003), VLF (0.003-0.04), LF (0.04-0.15), HF (0.15-0.4)

## Reproducibility

```bash
nix run .#build   # Build dev environment Docker image
nix run .#test    # Run tests
nix run           # Open Julia REPL
nix run .#act     # Test GitHub workflows locally
```

Docker alternative:
```bash
docker run --rm -it -v ".":/workdir -w /workdir julia:1.11 julia --project=.
```
