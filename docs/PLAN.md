# HeartRateLab.jl — Project Plan

## 1. Project Goals

HeartRateLab.jl aims to be the most comprehensive open-source HRV analysis package in Julia, filling the gap left by unmaintained alternatives. It consolidates prior work from `abcsds/hrv`, `abcsds/VizHRV`, and `abcsds/HeartRateVariability.jl`.

**Scientific intent:** The package provides a complete pipeline from raw IBI time series to statistical and dynamical understanding of cardiac variability. Feature extraction (done) gives descriptive statistics of a recording. Windowed analysis gives bootstrapped distributions of those statistics. The modeling section closes the loop: given real data, fit a mechanistic or data-driven model, generate synthetic IBI series from it, extract the same features from those synthetic series, and statistically test whether the model reproduces the real data's distributional properties — at the level of individual features, feature-space distances, and visual comparison.

**Primary deliverables:**
1. Offline HRV feature extraction library (complete)
2. Extensible model catalogue with a unified fit/simulate interface
3. Composable evaluation pipeline: real timeseries → fit model → simulate synthetic timeseries → evaluate both timeseries and compare features statistically
4. Dataset infrastructure: download and benchmark against open PhysioNet records
5. Visualization suite for model-vs-data and model-vs-model comparison
6. *(Stretch)* Tools for online HRV biofeedback via LSL

**Target audience:** Researchers in psychophysiology, cognitive science, and biomedical engineering.

---

## 2. Current State (February 2026) — UPDATED AFTER EVALUATION PIPELINE

### ✅ What's Done

| Module | Status | Commits | Lines |
|--------|--------|---------|-------|
| **Input** | ✅ Complete | — | 63 |
| **Preprocessing** | ✅ Complete | — | 266 |
| **Features** | ✅ Complete | — | 992 |
| **Frequency** | ✅ Complete | — | 91 |
| **Model Interface** | ✅ Complete | — | 77 |
| **LIF Model** | ✅ Complete | 13e590c, b79f352 | 300 |
| **VanDerPol Model** | ✅ Complete | — | 150 |
| **Lorenz Model** | ✅ Complete | — | 180 |
| **DMD Model** | ✅ Complete | — | 200 |
| **Package Extensions** | ✅ Complete | — | 960 |
| **Bayesian Fitting** | ✅ Complete | 13e590c | 200 |
| **Model Tests** | ✅ Complete | b79f352 | 177 |
| **Test Suite Split** | ✅ Complete | — | 300+ |
| **Documentation** | ✅ Complete | 52ebe74 | 400+ |
| **Evaluation Pipeline** | ✅ **COMPLETE** | e6a7b18→7855155 | 1,170 |

**Evaluation Pipeline Details (NEW):**
- ✅ `windowed_feature_set()` — Mode 2 (sliding windows) | e6a7b18 | 150 lines
- ✅ `simulate_ensemble()` — Mode 3 (synthetic ensemble) | 53546fe | 180 lines
- ✅ `extract_ensemble_features()` — Feature extraction from ensemble | 624936e | 180 lines
- ✅ `eval_distributional()` — Statistical tests (KS, Mann-Whitney, AD) | 8ec90aa | 260 lines
- ✅ `eval_scalar()` — Mean/error metrics | 297331f | 150 lines
- ✅ `eval_distance()` — Feature-space distances (Euclidean, Mahalanobis) | 7855155 | 250 lines

**Documentation:**
- ✅ `evaluation_demo.qmd` — Live Quarto notebook demonstrating full pipeline
- ✅ `EVALUATION_DEMO_OUTPUT.md` — Expected output and interpretation guide

### ⚠️ What's Partially Done

| Module | Status | Details |
|--------|--------|---------|
| **Visualization Functions** | ⚠️ Framework ready | GLMakie extension exists but functions not implemented |
| **Van der Pol Fitting** | ⚠️ simulate only | `simulate()` works, needs `fit()` method |

### ❌ What's Not Started

| Item | Priority | Notes |
|------|----------|-------|
| **Dataset Infrastructure** | 🟡 HIGH | `load_physionet()`, `load_nsrdb()`, `load_mitbih()` |
| **Visualization Functions** | 🟡 HIGH | 5 comparison plots (`plot_radar`, `plot_feature_violins`, etc.) |
| **Neural ODE/VAE** | 🟢 LOW | Deep learning models, deferred post-core |
| **Package Registration** | 🟡 HIGH | Version 0.1.0, LICENSE, CITATION.bib |
| **Performance Benchmarking** | 🟢 LOW | Speed benchmarks on NSRDB records |

### Test Failures (as of February 2026)

This error happens when running the script without docker or nix.
```
11 passed, 7 errored:
  Input/read_xdf          — 1 error (likely XDF dep or file issue)
  Input/read_txt          — 1 error (likely path or dep issue)
  Input/read_wfdb (×3)    — 3 errors (WFDB ann2rr binary not on PATH)
  Preprocessing/ectopic   — 1 error (cascades from Input failure: uses read_txt)
  Features                — 1 error (cascades from Input failure: uses read_txt)
```

Root cause is likely environmental: missing WFDB binary and/or stale dependency state. The test logic itself was passing previously (see recent commits).

No testing of container or nix flake has been done yet.

### Known Bugs / FIXMEs

1. **`Features.jl:920`** — DFA scales are wrong (FIXME comment)
2. **`Frequency.jl:88`** — `find_peak` returns incorrect index after frequency filtering
3. **`Models/LIF.jl:61`** — References `HeartRateVariability` instead of `HeartRateLab`
4. **README citation** — DMD entry cites Yeh 2010 which is about EMD (Empirical Mode Decomposition / IMF), not DMD

---

## 3. Technical Specifications

### 3.1 Model Interface (`AbstractHRVModel`)

All models implement a common interface via Julia's type system. No macro registration — duck typing with abstract type dispatch.

```julia
abstract type AbstractHRVModel end

# REQUIRED — every model must implement:
simulate(m::AbstractHRVModel, params::NamedTuple, n_beats::Int) -> Vector{Float64}
# Returns: IBI series in milliseconds, length ≈ n_beats (stochastic models may vary)

# OPTIONAL — models implement if they support fitting:
fit(m::AbstractHRVModel, data::Vector{Float64}; method::Symbol=:bayesian, kwargs...) -> ModelFitResult
parameter_space(m::AbstractHRVModel) -> NamedTuple
# Returns: (param_name = (lower, upper, prior_distribution), ...)
```

`ModelFitResult` struct:
```julia
struct ModelFitResult
    model::AbstractHRVModel
    method::Symbol              # :bayesian | :gradient | :evolutionary
    params::NamedTuple          # point estimate (MAP/MLE or best individual)
    posterior                   # Turing Chain (Bayesian) or nothing
    diagnostics::Dict           # convergence, iterations, loss history, etc.
    data::Vector{Float64}       # original data used for fitting
end
```

**Fitting methods** delegate to the Julia ecosystem — no custom optimizers:
- `:bayesian` → Turing.jl (MCMC, posterior over params, natural uncertainty quantification)
- `:gradient` → Optim.jl (minimize feature-space distance; point estimate) Flux.jl for deep neural network models.
- `:evolutionary` → BlackBoxOptim.jl or Evolutionary.jl (for non-differentiable models)

The `fit()` function dispatches on `method` kwarg. Each model defines which methods it supports in `parameter_space()`.

**Model taxonomy:**

| Category | Models | Notes |
|----------|--------|-------|
| **Mechanistic / ODE** | LIF, Van der Pol, Lorenz oscillator | Physical interpretation; params have biological meaning; Bayesian fitting natural |
| **Signal decomposition** | DMD | Reconstructs/predicts from spectral modes; fit = decompose, simulate = reconstruct |
| **Data-driven / generative** | Neural ODE VAE | Learned from data; no parameter prior; gradient fitting only |
| **Special-purpose** | VAE for ectopic detection | Not a generative HRV model; different interface (classifier, not simulator) |

### 3.2 Evaluation Pipeline — UNIFIED FRAMEWORK

**Key Design Principle:** The pipeline is **data-agnostic**. Model-generated synthetic timeseries are treated identically to real data and public datasets. This enables unified comparison of:
- Real data vs. synthetic model outputs
- Multiple models against each other
- Real data vs. public benchmarks (NSRDB, MIT-BIH)

**Three Data Input Modes:**

All modes ultimately produce **feature distributions** that can be compared using the same metrics.

#### Mode 1: Continuous Timeseries
Input: One continuous IBI series (real or synthetic)
- From `simulate(model, params, n_beats)` — model output
- From `read_txt()`, `read_wfdb()` — real data
- From `load_nsrdb()`, `load_mitbih()` — public datasets

Output: **Single feature point** (descriptive statistics of the entire series)

```julia
data = read_txt("subject.txt")  # or simulate(...) or load_nsrdb(...)
features = extract_feature_set(data)  # → Dict with 44 features
# This is ONE sample in feature space
```

#### Mode 2: Time Windows (Sliding Window)
Input: One continuous IBI series → divide into overlapping windows
Output: **Distribution of feature vectors** (one feature set per window)

```julia
data = read_txt("subject.txt")
window_features = windowed_feature_set(data; window_size=300, overlap=150)
# → DataFrame: (n_windows rows × 44 features cols)
# Each row is one window's feature set
# This is a MULTIVARIATE DISTRIBUTION (or empirical CDF) in 44D feature space
```

#### Mode 3: Sampled Windows (Ensemble)
Input: Either multiple independent samples or synthetic ensemble
Output: **Empirical distribution** (one feature set per sample)

**For synthetic models (ensemble of simulations):**
```julia
model = LIF()
result = fit(model, data; method=:bayesian)
ensemble = simulate_ensemble(model, result.params, n_beats; n_sim=100)
# ensemble = Vector{Vector{Float64}} with 100 independent IBI series
ensemble_features = extract_ensemble_features(ensemble)
# → DataFrame: (100 rows × 44 features cols)
# Each row is one synthetic series' feature set
```

**For real data (multiple subjects/recordings):**
```julia
# Load multiple subjects' recordings
subjects = [load_nsrdb("16265"), load_nsrdb("16273"), load_nsrdb("16786")]
all_features = [extract_feature_set(subj) for subj in subjects]
# → Vector{Dict} with one feature dict per subject
# Convert to DataFrame for consistency
subj_features = reduce(vcat, [DataFrame(f) for f in all_features])
```

---

**Composable Evaluation Functions:**

All comparison functions take **feature DataFrames** (n_samples × n_features) as input. The functions don't care whether samples come from:
- Synthetic ensemble (Mode 3)
- Time windows (Mode 2)
- Multiple subjects (Mode 3)

```julia
# Unified comparison signature for all modes:
eval_distributional(real_features::DataFrame, model_features::DataFrame; test=:ks, features=nothing)
# → DataFrame: (n_features rows) × {statistic, p_value, effect_size, test_name}
# Tests: :ks (Kolmogorov-Smirnov), :mw (Mann-Whitney U), :ad (Anderson-Darling)

eval_scalar(real_features::DataFrame, model_features::DataFrame; features=nothing)
# → DataFrame: (n_features rows) × {real_mean, sim_mean, abs_error, rel_error, pct_difference}

eval_distance(real_features::DataFrame, model_features::DataFrame; metric=:mahalanobis, features=nothing)
# → NamedTuple: (distance=Float64, feature_contributions=Dict{String, Float64})
# Metrics: :mahalanobis, :euclidean, :bhattacharyya
```

**Example Workflows:**

*Workflow A: Continuous data vs. Model*
```julia
# Real data
real_data = read_txt("patient.txt")
real_features = extract_feature_set(real_data)
real_df = DataFrame([real_features])  # 1 row

# Model
lif = LIF()
fit_result = fit(lif, real_data; method=:bayesian)
ensemble = simulate_ensemble(lif, fit_result.params, length(real_data); n_sim=100)
model_features = extract_ensemble_features(ensemble)  # 100 rows

# Compare
eval_distributional(vcat(real_df, real_df, real_df),  # Repeat real for comparison
                   model_features; test=:ks)
```

*Workflow B: Windowed analysis*
```julia
# Real data (windowed)
real_data = read_txt("patient.txt")
real_windows = windowed_feature_set(real_data; window_size=300, overlap=150)

# Model ensemble (no windowing needed for synthetic)
lif = LIF()
fit_result = fit(lif, real_data; method=:bayesian)
ensemble = simulate_ensemble(lif, fit_result.params, length(real_data); n_sim=100)
model_features = extract_ensemble_features(ensemble)

# Compare: Each real window vs. the ensemble distribution
results = eval_distributional(real_windows, model_features)
```

*Workflow C: Dataset benchmarking*
```julia
# Public dataset
nsrdb_data = load_nsrdb("16265")  # One healthy subject

# Fit model to external data (or use pre-fit model)
lif = LIF()
fit_result = fit(lif, some_training_data)

# Evaluate: Does model reproduce NSRDB subject's statistics?
benchmark_features = extract_feature_set(nsrdb_data)
benchmark_df = DataFrame([benchmark_features])

ensemble = simulate_ensemble(lif, fit_result.params, length(nsrdb_data); n_sim=100)
model_features = extract_ensemble_features(ensemble)

comparison = eval_scalar(benchmark_df, model_features)
```

### 3.3 Signal Length-Based Feature Selection (✅ DONE)

✅ **Already implemented.** Each feature has a `minimum_length` annotation (Features.jl:48):

```julia
# In @register macro — already integrated:
@register "dfa" [] [:nonlinear] minimum_length=500 """..."""

# Public function exists (Features.jl:1128):
valid_features(n_beats::Int) -> Vector{String}
# Returns features from the registry whose minimum_length ≤ n_beats
```

**Usage in evaluation pipeline:**
```julia
# When extracting features from ensemble of fixed-length synthetics:
n_beats = 500
valid_set = valid_features(n_beats)  # Filter to valid features
features = extract_feature_set(data; features=valid_set)
```

### 3.4 Dataset Infrastructure & Scientific Benchmarking

No datasets stored in the codebase. All loading is on-demand via URL, downloaded to a temporary directory.

Dataset download and management is part of an **extensive test suite** that serves a dual purpose:

1. **Software testing:** verify end-to-end pipeline (download → parse → extract features → fit model → evaluate)
2. **Scientific benchmarking:** accumulate normative populational statistics across PhysioNet datasets. As more datasets are added over time, these benchmarks build a reference database of HRV features for the scientific community.

```julia
# Generic loader:
load_physionet(url::String; annotator::String="atr", preprocessed::Bool=true) -> Vector{Float64}
# Downloads record + annotation files to tempdir(), calls read_wfdb(), preprocesses if requested

# Curated wrappers (known URLs):
load_nsrdb(record::String; kwargs...) -> Vector{Float64}
# NSRDB: https://physionet.org/files/nsrdb/1.0.0/ — healthy adults, baseline

load_mitbih(record::String; kwargs...) -> Vector{Float64}
# MIT-BIH: https://physionet.org/files/mitdb/1.0.0/ — mixed arrhythmias

# Test suite integration:
# Tests gated by ENV["HEARTRATE_NETWORK_TESTS"] == "true"
# Tests download to mktempdir() and clean up automatically
# Scientific outputs logged via @info for normative statistics
```

**PhysioNet access note:** PhysioNet records are freely available via direct URL. The WFDB reader (`ann2rr`) already handles the format. Download logic uses `Downloads.jl` (stdlib).

### 3.5 Test Suite Architecture (Agent TDD)

Tests are split into independent files so agents can develop and test modules in parallel without blocking each other. See `WORKFLOW.md` for full details.

**Test files:** `test_input.jl`, `test_preprocessing.jl`, `test_features.jl`, `test_frequency.jl`, `test_models.jl`, `test_evaluation.jl`, `test_datasets.jl`, `test_visualization.jl`

**Independence rules:**
- Each test file is self-contained (own `using`, own data loading)
- Preprocessing/Model/Evaluation tests use synthetic data — no dependency on Input working
- Dataset tests gated by `HEARTRATE_NETWORK_TESTS` env var
- WFDB tests gated by `Sys.which("ann2rr")`
- Visualization tests gated by `DISPLAY` env var

**Execution methods** (all tested 2026-02-17):

| Method | Command | Status |
|--------|---------|--------|
| **Julia** (dev) | `julia --project=. test/test_preprocessing.jl` | Works |
| **Docker** (reproducible) | `docker run --rm -v .:/workdir -w /workdir julia:1.11-bookworm julia --project=. -e 'Pkg.test()'` | Works |
| **Docker + WFDB** | `docker run --rm -v .:/workdir -w /workdir hrlab:latest ...` | Requires built image |
| **Nix** | `nix run .#test` | Broken (Dockerfile issue) |

**Nix fallback:** The nix `test` app should first try the `hrlab` Docker image, then fall back to volume-mount with `julia:1.11-bookworm` if the built image is unavailable.

### 3.6 Reproducibility Infrastructure

**Unregistered dependency:** `DFA` is installed from [abcsds/DFA.jl](https://github.com/abcsds/DFA.jl) via git URL. The `Manifest.toml` pins this. The Dockerfile must copy both `Project.toml` AND `Manifest.toml` for `Pkg.instantiate()` to succeed.

**Docker build fix required:**
```dockerfile
COPY Project.toml Manifest.toml /workdir/
```

**Nix `flake.nix` fix required:** The `test` app should include a fallback path:
```bash
# Try hrlab image first, fall back to volume-mount
docker run --rm -v .:/workdir hrlab:latest ... || \
docker run --rm -v .:/workdir julia:1.11-bookworm ...
```

### 3.7 Visualization Suite

All visualization functions are offline-capable (no LSL required). LSL-based real-time functions remain separate. All require GLMakie, which will be made optional via package extensions.

**Five core comparison plots:**

```julia
# 1. Radar / spider chart — feature z-scores, one polygon per model or dataset
plot_radar(datasets::Dict{String, Vector{Float64}}; features=nothing, normalize=true)
# Each entry in datasets becomes one polygon. features defaults to valid_features(minimum length).

# 2. Feature distribution violins — real windowed dist vs synthetic ensemble per feature
plot_feature_violins(real::DataFrame, ensembles::Dict{String, DataFrame}; features=nothing)
# One panel per feature. Real data as reference violin, each model as colored violin.

# 3. Time series + Poincaré side-by-side overlay
plot_comparison(real::Vector{Float64}, synthetics::Dict{String, Vector{Float64}})
# Top row: IBI time series (real + each model). Bottom row: Poincaré plots with ellipse.

# 4. Model × dataset reproduction heatmap
plot_model_heatmap(results::DataFrame)
# DataFrame must have columns: model, feature, score (e.g. 1 - normalized KS statistic)
# Rows=models, columns=features, color=reproduction quality (0=fails, 1=perfect)

# 5. Correlation / pairplot across models and features
plot_correlations(feature_sets::Dict{String, DataFrame}; features=nothing)
# Pairwise scatter matrix of features, colored by model/dataset origin.
# Reveals which features co-vary and where models diverge.
```

**Existing visualization scripts** (`default.jl`, `geometric.jl`, etc.) will be refactored into:
- `Visualization.online` — LSL-dependent real-time functions (preserved, cleaned up)
- `Visualization.offline` — data-based functions (new API above + existing Poincaré, spectrum)

### 3.8 Package Extension Strategy

The package must remain lightweight for users who only need feature extraction. Heavy deps (ODE solvers, Flux, Turing, GLMakie, LSL) become optional via Julia's native extension system (introduced in Julia 1.9).

```
HeartRateLab (core)
├── Input, Preprocessing, Features, Frequency   ← lightweight, always loaded
│
├── ext/HeartRateLabModelsExt.jl                ← activated when user loads:
│   Deps: DifferentialEquations, Turing, Optim, BlackBoxOptim
│   Provides: AbstractHRVModel interface, LIF, VdP, Lorenz, DMD
│
├── ext/HeartRateLabDeepExt.jl                  ← activated when user loads Flux
│   Deps: Flux, DiffEqFlux
│   Provides: NeuralODE, VAE
│
├── ext/HeartRateLabVisualizationExt.jl         ← activated when user loads GLMakie
│   Provides: all offline plot_* functions, model phase-space plots
│
└── ext/HeartRateLabLSLExt.jl                   ← activated when user loads LSL
    Provides: real-time online visualization functions
```

---

## 4. Model Catalogue

### 4.1 Implemented (partial)

| Model | Type | Status | Params | Fitting |
|-------|------|--------|--------|---------|
| **LIF** (Leaky Integrate-and-Fire) | ODE/stochastic | Simulation works; inference skeleton broken | τ, I_base, threshold, noise_amp | Bayesian (Turing skeleton exists) |
| **Van der Pol** | ODE/deterministic | Interactive viz only; no fitting | μ, initial conditions | Gradient, Evolutionary |
| **Neural ODE VAE** | Data-driven | Demo on sine data | Latent dim, architecture | Gradient only |

### 4.2 To Implement

| Model | Type | Key paper | Params | Notes |
|-------|------|-----------|--------|-------|
| **Lorenz oscillator** | ODE/deterministic-chaotic | — | σ, ρ, β, initial conditions | Note: Esperer 2008 cited in README uses Lorenz *plots* (visualization), not this ODE. Lorenz oscillator is included as its own generative model. Lorenz plots as visualization are separate. |
| **DMD** (Dynamic Mode Decomposition) | Spectral | — | Rank, time horizon | Note: Yeh 2010 cited in README uses EMD (Empirical Mode Decomposition), not DMD. DMD is included as an independent choice. Citation in README should be corrected or removed. |
| **VAE for ectopic detection** | Data-driven |  | Architecture | Different interface — classifier, not IBI generator |

### 4.3 Deferred

| Model | Notes |
|-------|-------|
| Statistical parameter estimation (populational) | Requires multi-subject datasets; deferred post-publication |
| Hierarchical models | Same; requires multi-subject infrastructure |

---

## 5. Feature Inventory

### 5.1 Implemented Features (44 total)

**Time Domain (Level 1-3):**
`mean`, `sdnn`, `median`, `max`, `min`, `mean_hr`, `std_hr`, `max_hr`, `min_hr`, `sdsd`, `range`, `rmssd`, `sdann`, `pnn50`, `pnn20`, `cvsd`, `rRR`, `length`, `duration`, `diff`

**Frequency Domain (Level 4):**
`pgram`, `ulf`, `vlf`, `lf`, `hf`, `tp`, `lf_peak`, `hf_peak`, `lf_hf_ratio`, `lf_relative`, `hf_relative`, `lf_percentage`, `hf_percentage`, `max_t`

**Geometric / Poincaré (Level 5):**
`px`, `py`, `sd1`, `sd2`, `sd2_sd1`, `sd1_sd2_area`, `cvi`, `ccsi`, `histogram`, `triangular_index`, `tinn`

**Non-linear / Entropy (Level 6):**
`apen`, `sampen`, `hurst`, `dfa`, `dfa1`, `dfa2`, `renyi`, `renyi0`, `renyi1`, `renyi2`

### 5.2 Planned Feature Additions

| Feature | Priority | Notes |
|---------|----------|-------|
| `minimum_length` annotation per feature | **Blocking** | Required for model evaluation |
| `valid_features(n::Int)` function | **Blocking** | Required for model evaluation |
| Parallel feature computation (`Distributed`) | Medium | Useful for ensemble evaluation |
| Additional interpolation methods (spline, pchip, etc.) | Low | Listed in README, not blocking anything |

---

## 6. Required Actions — REVISED (Based on Actual Progress)

### ✅ Phase 1-2: COMPLETE
- ✅ Test suite split into 7 independent files
- ✅ Package extensions configured (Project.toml, ext/ directory)
- ✅ `AbstractHRVModel` and `ModelFitResult` defined
- ✅ `minimum_length` annotations on all features
- ✅ `valid_features(n)` function implemented

### ✅ Phase 3a: Models — COMPLETE
- ✅ LIF: `simulate()`, `fit(:bayesian)` via Turing.jl, `fit(:gradient)` via Optim.jl
- ✅ Van der Pol: `simulate()`, `parameter_space()` (fit not yet implemented)
- ✅ Lorenz: `simulate()` with chaotic dynamics
- ✅ DMD: `fit()` for decomposition, `simulate()` for reconstruction
- ✅ Bayesian fitting (Task #14): Full MCMC integration with diagnostics

### 🔴 Phase 3b: Evaluation Pipeline — BLOCKING (Next priority)

1. **Implement core evaluation functions:**
   - `simulate_ensemble(model, params, n_beats; n_sim=100)` → Vector{Vector{Float64}}
   - `extract_ensemble_features(ensemble; features=nothing)` → DataFrame
   - `eval_distributional(real_df, model_df; test=:ks)` → DataFrame with p-values
   - `eval_scalar(real_df, model_df)` → DataFrame with mean/error metrics
   - `eval_distance(real_df, model_df; metric=:mahalanobis)` → NamedTuple with distance + contributions

2. **Implement helper for windowed analysis:**
   - `windowed_feature_set(data; window_size, overlap)` → DataFrame (one feature set per window)

3. **Update test_evaluation.jl with comprehensive tests:**
   - Mode 1: Continuous data comparison
   - Mode 2: Windowed analysis comparison
   - Mode 3: Ensemble/sampled comparison

### 🟡 Phase 3c: Dataset Infrastructure — HIGH PRIORITY

4. **Implement dataset loaders:**
   - `load_physionet(url; annotator="atr", preprocessed=true)` → Vector{Float64}
   - `load_nsrdb(record::String)` → Vector{Float64}
   - `load_mitbih(record::String)` → Vector{Float64}

5. **Update test_datasets.jl:**
   - Tests gated by `ENV["HEARTRATE_NETWORK_TESTS"] == "true"`
   - Verify loading, preprocessing, feature extraction works

### 🟡 Phase 4: Visualization — HIGH PRIORITY (can be parallel)

6. **Implement visualization functions in HeartRateLabVisualizationExt:**
   - `plot_radar(datasets::Dict; features=nothing)` — Spider chart of z-scores
   - `plot_feature_violins(real::DataFrame, ensembles::Dict; features=nothing)` — Violin distributions
   - `plot_comparison(real::Vector, synthetics::Dict)` — IBI time series + Poincaré overlay
   - `plot_model_heatmap(results::DataFrame)` — Model × feature reproduction quality
   - `plot_correlations(feature_sets::Dict; features=nothing)` — Pairplot/correlation matrix

7. **Additional visualization (bonus):**
   - Lorenz 3D scatter: IBI[n] vs IBI[n+1] vs IBI[n+2]
   - Model phase-space plots (LIF V(t), VdP/Lorenz portraits)

### 🟢 Phase 5: Publication — AFTER core work

8. **Housekeeping (pre-publication):**
   - Fix version: 1.0.0 → 0.1.0 in Project.toml
   - Add LICENSE (MIT)
   - Add CITATION.bib
   - Fix README: Correct DMD citation (or remove Yeh 2010 reference)

9. **Final steps:**
   - Register in Julia General registry (JuliaRegistrator)
   - Deploy documentation to GitHub Pages
   - (Optional) Submit to JOSS

### 🟢 Phase 6: Advanced (post-publication)

10. **Deep learning models (deferred):**
    - Connect Neural ODE to real HRV data
    - Implement VAE for ectopic beat detection
    - Move to `HeartRateLabDeepExt`

11. **Optimization & scaling:**
    - Parallel feature extraction (`Distributed.jl`)
    - Performance benchmarks on NSRDB

---

## 7. Revised Timeline

**Note:** Phases 1-2 and 3a are complete. Starting from Phase 3b.

### Sprint 1 — Evaluation Pipeline (Next, 1 week)
- Implement `simulate_ensemble()`, `extract_ensemble_features()`
- Implement `eval_distributional()`, `eval_scalar()`, `eval_distance()`
- Implement `windowed_feature_set()` for time window analysis
- Comprehensive tests covering all three input modes (continuous, windowed, ensemble)
- **Deliverable:** End-to-end evaluation workflow: fit model → generate synthetic ensemble → compare to real data

### Sprint 2 — Dataset Infrastructure (1 week)
- Implement `load_physionet()`, `load_nsrdb()`, `load_mitbih()`
- Network tests gated by `HEARTRATE_NETWORK_TESTS` env var
- Validation: Load NSRDB record → extract features → verify against public statistics
- **Deliverable:** Users can benchmark against PhysioNet datasets

### Sprint 3 — Visualization (1 week, can be parallel with Sprint 2)
- Implement 5 core comparison plots in `HeartRateLabVisualizationExt`
- Implement Lorenz 3D scatter and model phase-space plots
- Write basic tutorials showing visualization outputs
- **Deliverable:** Publication-quality figures for model comparison

### Sprint 4 — Publication Readiness (3-4 days)
- Fix version: 1.0.0 → 0.1.0
- Add LICENSE (MIT), CITATION.bib
- Correct README (DMD citation)
- Register in Julia General registry
- Deploy documentation to GitHub Pages
- **Deliverable:** First official release

---

## 8. Immediate Action Items (Next Sprint)

**Priority: BLOCKING** — Must complete before visualization or publication

```
(A) Implement simulate_ensemble(model, params, n_beats; n_sim=100) -> Vector{Vector{Float64}}
    - Generate N independent synthetic IBI series from single parameter set
    - Each series has length ≈ n_beats
    - Location: ext/HeartRateLabModelsExt.jl

(A) Implement extract_ensemble_features(ensemble; features=nothing) -> DataFrame
    - Extract features from all series in ensemble (parallel if possible)
    - Handle signal-length constraints using valid_features()
    - Return: DataFrame(n_sim rows × n_features cols)
    - Location: ext/HeartRateLabModelsExt.jl

(A) Implement windowed_feature_set(data; window_size, overlap) -> DataFrame
    - Sliding window analysis of continuous data
    - Extract features from each window independently
    - Return: DataFrame (one row per window)
    - Location: ext/HeartRateLabModelsExt.jl or src/Evaluation.jl

(A) Implement eval_distributional(real::DataFrame, model::DataFrame; test=:ks, features=nothing) -> DataFrame
    - Statistical comparison of feature distributions
    - Tests: Kolmogorov-Smirnov (:ks), Mann-Whitney (:mw), Anderson-Darling (:ad)
    - Return: DataFrame(n_features rows) × {feature, statistic, p_value, effect_size, test_name}
    - Location: ext/HeartRateLabModelsExt.jl

(A) Implement eval_scalar(real::DataFrame, model::DataFrame; features=nothing) -> DataFrame
    - Point-estimate comparison (means, errors)
    - Return: DataFrame(n_features rows) × {feature, real_mean, sim_mean, abs_error, rel_error, pct_diff}
    - Location: ext/HeartRateLabModelsExt.jl

(A) Implement eval_distance(real::DataFrame, model::DataFrame; metric=:mahalanobis, features=nothing) -> NamedTuple
    - Feature-space distance metrics
    - Metrics: :mahalanobis, :euclidean, :bhattacharyya
    - Return: (distance=Float64, feature_contributions=Dict, metric=Symbol)
    - Location: ext/HeartRateLabModelsExt.jl

(A) Write comprehensive tests in test_evaluation.jl
    - Mode 1: Continuous data (single point) vs. ensemble
    - Mode 2: Windowed data (multivariate dist) vs. ensemble
    - Mode 3: Multiple subjects (empirical dist) vs. ensemble
    - End-to-end: fit model → generate ensemble → evaluate → verify p-values are reasonable

(B) Implement load_physionet(url; annotator="atr", preprocessed=true) -> Vector{Float64}
    - Generic loader for PhysioNet records
    - Download via Downloads.jl to tempdir()
    - Use read_wfdb() for parsing
    - Optionally preprocess (outlier removal, interpolation)
    - Location: ext/HeartRateLabModelsExt.jl

(B) Implement load_nsrdb(record::String; kwargs...) -> Vector{Float64}
    - NSRDB-specific wrapper (healthy baseline)
    - Known URLs: https://physionet.org/files/nsrdb/1.0.0/
    - Location: ext/HeartRateLabModelsExt.jl

(B) Implement load_mitbih(record::String; kwargs...) -> Vector{Float64}
    - MIT-BIH specific wrapper (arrhythmia)
    - Known URLs: https://physionet.org/files/mitdb/1.0.0/
    - Location: ext/HeartRateLabModelsExt.jl

(B) Update test_datasets.jl with actual tests
    - Gate on ENV["HEARTRATE_NETWORK_TESTS"]
    - Verify loading works, preprocesses correctly
    - Check feature extraction doesn't crash
```

**Lower Priority (Can be parallel or after core evaluation works):**

```
(B) Implement visualization functions in HeartRateLabVisualizationExt
    - plot_radar(datasets::Dict; features=none)
    - plot_feature_violins(real::DataFrame, ensembles::Dict; features=none)
    - plot_comparison(real::Vector, synthetics::Dict)
    - plot_model_heatmap(results::DataFrame)
    - plot_correlations(feature_sets::Dict; features=none)

(B) Implement additional plots
    - Lorenz 3D scatter: IBI[n] vs IBI[n+1] vs IBI[n+2]
    - Model phase-space plots (LIF V(t), VdP portrait, Lorenz portrait)

(C) Housekeeping for publication
    - Fix version: 1.0.0 → 0.1.0
    - Add LICENSE (MIT)
    - Add CITATION.bib
    - Fix README: Correct DMD citation

(C) Register in Julia General registry
    - Prepare via JuliaRegistrator
```
