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

## 2. Current State (February 2026)

### What's Done

| Module | Status | Lines | Details |
|--------|--------|-------|---------|
| **Input** | Complete | 63 | `read_xdf`, `read_txt`, `read_wfdb` — 3 formats |
| **Preprocessing** | Complete | 266 | 10 functions: outlier removal (4 methods), interpolation (4 methods), windowing |
| **Features** | Complete | 992 | 44 features across 6 domains via `@register` macro system |
| **Frequency** | Complete | 91 | Welch + Lomb-Scargle periodograms, band power, peak finding |
| **CI/CD** | Complete | 117 | GitHub Actions, WFDB setup, Codecov |
| **Tests** | Complete | 303 | Input, preprocessing, features, frequency — with baseline CSVs |
| **Reproducibility** | Complete | — | Dockerfile + flake.nix |

### What's Partially Done

| Module | Status | Lines | Details |
|--------|--------|-------|---------|
| **Visualization** | Scripts exist, not modular | ~900 | 5 GLMakie+LSL scripts with global state; not reusable functions |
| **Models/LIF** | Simulation works, inference skeleton | 153 | Uses old `HeartRateVariability` package; Turing code untested |
| **Models/Neural ODE** | Demo only | 64 | Flux+DiffEqFlux; synthetic sine data; not connected to HRV |
| **Models/Van der Pol** | Interactive viz works | 41 | GLMakie sliders; standalone script; no fitting |
| **Documentation** | Auto-generated only | — | Documenter.jl skeleton exists; no written content |
| **Examples** | Macro demos only | 5 files | Show feature registry; no end-to-end workflows |

### What's Not Started

| Item | Notes |
|------|-------|
| **Models/VAE** | Empty file. Planned for ectopic beat detection via Koopman eigenfunctions |
| **Lorenz oscillator** | As a *generative model* (ODE system with σ, ρ, β). Note: Esperer 2008 paper uses Lorenz *plots* (visualization), not the oscillator — both are wanted |
| **Dynamic Mode Decomposition** | As a predictive/generative model. Note: Yeh 2010 actually uses EMD (not DMD) — the README citation is a mismatch; DMD is included as an independent choice |
| **Evaluation pipeline** | fit → simulate ensemble → extract features → statistical tests |
| **Dataset infrastructure** | URL-based PhysioNet loading; no stored data in codebase |
| **Model-comparison visualizations** | Radar, violin, heatmap, pairplots, Poincaré overlays |
| **Signal length-based feature selection** | Needed before model evaluation can work |
| **Package extensions** | Models and Visualization not yet made optional |
| **API documentation** | Docstrings exist but no written guides or tutorials |
| **Package registration** | Not registered in Julia General registry |

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

### 3.2 Evaluation Pipeline

Composable functions — user chains them. No pipeline object.

```julia
# Step 1: generate ensemble of synthetic IBI series from a fitted model
ensemble = simulate_ensemble(model, fit_result.params, n_beats; n_sim=100)
# Returns: Vector{Vector{Float64}} — n_sim synthetic series each of length ~n_beats

# Step 2: extract features from ensemble (parallel, using valid_features filter)
ensemble_features = extract_ensemble_features(ensemble; features=valid_features(n_beats))
# Returns: DataFrame of (n_sim rows × n_features cols)

# Step 3: compare against real data's windowed feature distribution
real_features = windowed_feature_set(data; window_size=n_beats, ...)

# Three composable evaluation metrics:
eval_distributional(real_features, ensemble_features; test=:ks)
# → DataFrame: feature × {statistic, p_value, effect_size}

eval_scalar(real_features, ensemble_features)
# → DataFrame: feature × {real_mean, sim_mean, relative_error, within_ci}

eval_distance(real_features, ensemble_features; metric=:mahalanobis)
# → NamedTuple: {distance, feature_contributions}
```

### 3.3 Signal Length-Based Feature Selection (BLOCKING)

Required before model evaluation can work. Each feature in the registry needs a `minimum_length` annotation:

```julia
# In @register macro — new field:
@register "dfa" [] [:nonlinear] minimum_length=500 """..."""

# New public function:
valid_features(n_beats::Int) -> Vector{String}
# Returns features from the registry whose minimum_length ≤ n_beats
```

This is **blocking** because: generated series from short model simulations may not support all 44 features, and calling invalid features silently produces garbage values.

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

## 6. Required Actions

### Phase 1: Stabilize (fix what's broken)

1. **Split test suite** — Refactor `runtests.jl` into independent test files (see `WORKFLOW.md`). Gate WFDB tests on `ann2rr`, network tests on env var, visualization on `DISPLAY`.
2. **Fix false test failures** — Switch feature baseline comparisons from `isequal` to `isapprox(rtol=1e-10)` (currently 2 false failures from floating-point precision).
3. **Fix test environment** — Resolve remaining test errors. WFDB tests skip gracefully when `ann2rr` not on PATH.
4. **Fix known bugs** — DFA scales (`Features.jl:920`), `find_peak` indexing (`Frequency.jl:88`).
5. **Fix reproducibility** — Dockerfile: copy `Manifest.toml` (DFA is unregistered). Nix: add Docker fallback to `test` app.
6. **Clean uncommitted state** — `Input_bkp.jl` → move to separate branch or delete. Commit `Models/`.
7. **Correct README citation** — DMD entry cites Yeh 2010 (EMD paper). Replace with accurate citation or note DMD as independent.
8. **Update dependencies** — `Pkg.update()`, fix compat bounds in `Project.toml`.

### Phase 2: Foundation for Models (structural, before any model code)

6. **Implement `minimum_length` annotations** — Add to each `@register` call in `Features.jl`. This unblocks model evaluation.
7. **Implement `valid_features(n::Int)`** — Returns subset of registry valid for a signal of `n` beats.
8. **Design package extension structure** — Create `ext/` directory, split `Project.toml` into core + weakdeps. At minimum: `HeartRateLabModelsExt` (DifferentialEquations, Turing, Optim, BlackBoxOptim) and `HeartRateLabVisualizationExt` (GLMakie).
9. **Define `AbstractHRVModel` and `ModelFitResult`** — Core types, can live in main package (just type definitions, no heavy deps).

### Phase 3: Models

10. **Refactor LIF** — Convert to `AbstractHRVModel`. Remove globals. Fix `HeartRateVariability` → `HeartRateLab`. Implement `simulate(LIF(), params, n_beats)`. Fix Turing inference.
11. **Refactor Van der Pol** — Convert to `AbstractHRVModel`. Implement `simulate()`. Add fitting via Optim.jl or BlackBoxOptim.jl.
12. **Implement Lorenz oscillator** — ODE system (σ, ρ, β). `simulate()` extracts IBI-like inter-threshold-crossing intervals from chaotic attractor trajectory.
13. **Implement DMD** — Fit = decompose IBI series into DMD modes. Simulate = reconstruct/propagate from modes. Wraps an existing Julia DMD package if available.
14. **Implement evaluation pipeline** — `simulate_ensemble`, `extract_ensemble_features`, `eval_distributional`, `eval_scalar`, `eval_distance`.
15. **Implement dataset infrastructure** — `load_physionet`, `load_nsrdb`, `load_mitbih`. Network tests tagged `:network`, skipped offline.
16. **Neural ODE** — Connect to real HRV data; move to `HeartRateLabDeepExt`.
17. **VAE for ectopic detection** — Separate interface; move to `HeartRateLabDeepExt`.
18. **Add model tests** — Unit tests per model: `simulate()` produces valid IBIs (positive, plausible range), `fit()` converges on synthetic data.

### Phase 4: Visualization

19. **Create `HeartRateLabVisualizationExt`** — Move GLMakie code to extension. Existing scripts become its initial content.
20. **Refactor existing scripts** — Remove global state from `default.jl` and siblings. Convert to functions in `Visualization.online`.
21. **Implement offline comparison plots** — `plot_radar`, `plot_feature_violins`, `plot_comparison`, `plot_model_heatmap`, `plot_correlations`.
22. **Add Lorenz 3D scatter (Lorenz plot)** — IBI[n] vs IBI[n+1] vs IBI[n+2] as a visualization of any IBI series in `Visualization.offline`.
23. **Add model phase-space plots** — LIF: V(t) trajectory with spike resets. VdP/Lorenz: phase portrait.

### Phase 5: Documentation and Publication

24. **Write API docs** — One page per module: Input, Preprocessing, Features, Frequency, Models, Evaluation, Visualization.
25. **Write tutorials** — End-to-end: (a) offline feature extraction, (b) windowed analysis, (c) model fitting and evaluation, (d) multi-dataset comparison.
26. **Create example notebooks** — Pluto or Jupyter, one per tutorial.
27. **Update README** — Current state, installation, quick-start usage.
28. **Deploy docs** — Uncomment CI docs workflow. Deploy to GitHub Pages.
29. **Register package** — Version to 0.1.0. Register via JuliaRegistrator. Add LICENSE, CITATION.bib.
30. **JOSS paper** — (Optional) Manuscript describing the package for Journal of Open Source Software.

---

## 7. Proposed Timeline

### Sprint 1 — Stabilize (Week 1-2)
- Split runtests.jl into independent test files (WORKFLOW.md)
- Fix 2 false failures (isequal → isapprox) and gate WFDB/network/display tests
- Fix DFA scales, find_peak bugs
- Fix Dockerfile (copy Manifest.toml) and nix fallback
- Correct README DMD citation
- Clean uncommitted files, commit Models/
- Update deps

### Sprint 2 — Foundation (Week 2-3)
- `minimum_length` annotations + `valid_features()`
- `AbstractHRVModel` + `ModelFitResult` types
- Package extension skeleton (`ext/` directory, `Project.toml` weakdeps)

### Sprint 3 — ODE Models (Week 3-5)
- LIF refactored + Turing fitting working
- Van der Pol refactored + Optim/BlackBoxOptim fitting
- Lorenz oscillator implemented
- DMD implemented
- Evaluation pipeline (`simulate_ensemble`, `eval_*` functions)
- Model tests

### Sprint 4 — Datasets + Evaluation (Week 5-6)
- `load_physionet`, `load_nsrdb`, `load_mitbih`
- End-to-end test: load NSRDB record → extract features → fit LIF → evaluate
- Network tests tagged and CI configured to skip them

### Sprint 5 — Visualization (Week 6-7)
- GLMakie moved to extension
- Offline refactor of existing scripts
- `plot_radar`, `plot_feature_violins`, `plot_comparison`, `plot_model_heatmap`, `plot_correlations`
- Lorenz 3D scatter plot
- Model phase-space plots

### Sprint 6 — Documentation + Publish (Week 8-9)
- API docs + 3 tutorial notebooks
- README update
- Version 0.1.0 + LICENSE + CITATION
- Julia General registry registration
- GitHub Pages deployment

---

## 8. Task List (todo.txt format)

Format: `(priority) date task +project @context`
Priority: A=blocking, B=high, C=medium, D=low/future

```todo.txt
# ============================================================
# STABILIZE — Fix broken state before anything else
# ============================================================
(A) 2026-02-17 Fix test failures: resolve XDF dependency errors in read_xdf test +stabilize @tests
(A) 2026-02-17 Fix test failures: resolve read_txt error — verify path and parsing +stabilize @tests
(A) 2026-02-17 Fix test failures: make WFDB tests skip gracefully when ann2rr not on PATH +stabilize @tests
(A) 2026-02-17 Fix test failures: resolve ectopic beats error (cascades from read_txt) +stabilize @tests
(A) 2026-02-17 Fix test failures: resolve Features error (cascades from read_txt) +stabilize @tests
(A) 2026-02-17 Fix FIXME: DFA scales are wrong in Features.jl:920 +stabilize @bugs
(A) 2026-02-17 Fix FIXME: find_peak incorrect index after filtering in Frequency.jl:88 +stabilize @bugs
(B) 2026-02-17 Correct README: DMD citation (Yeh 2010) is actually an EMD paper; replace or note separately +stabilize @docs
(B) 2026-02-17 Clean uncommitted state: move Input_bkp.jl to its own branch as future feature work +stabilize @cleanup
(B) 2026-02-17 Delete flake_bkp.nix — worker/GPU content superseded by GPU task below +stabilize @cleanup
(B) 2026-02-17 Update flake.nix: detect available GPUs at runtime (nvidia-smi or /dev/nvidia*) and conditionally pass --gpus all; preserve X11 forwarding (-e DISPLAY, /tmp/.X11-unix, .Xauthority) for GLMakie; note Wayland and headless alternatives +stabilize @reproducibility
(B) 2026-02-17 Commit Models/ directory to git +stabilize @cleanup
(B) 2026-02-17 Fix Models/LIF.jl:61 — replace HeartRateVariability reference with HeartRateLab +stabilize @bugs
(B) 2026-02-17 Update Project.toml compat bounds for all dependencies +stabilize @deps
(B) 2026-02-17 Run Pkg.update() and fix any resulting breakage +stabilize @deps
(C) 2026-02-17 Remove deleted TU_Graz.png from git tracking +stabilize @cleanup

# ============================================================
# TEST INFRASTRUCTURE — Split tests for agent TDD
# ============================================================
(A) 2026-02-17 Split runtests.jl into independent test files: test_input, test_preprocessing, test_features, test_frequency +testing @architecture
(A) 2026-02-17 Make test_preprocessing.jl use only synthetic data — no dependency on read_txt +testing @independence
(A) 2026-02-17 Switch feature baseline comparisons from isequal to isapprox(rtol=1e-10) — fix 2 false failures +testing @bugs
(A) 2026-02-17 Gate WFDB tests on Sys.which("ann2rr") — skip gracefully when binary absent +testing @gating
(B) 2026-02-17 Create test_models.jl skeleton with synthetic IBI validity checks +testing @models
(B) 2026-02-17 Create test_evaluation.jl skeleton with mock model results +testing @evaluation
(B) 2026-02-17 Create test_datasets.jl gated by HEARTRATE_NETWORK_TESTS env var +testing @datasets
(B) 2026-02-17 Create test_visualization.jl gated by DISPLAY env var +testing @visualization
(B) 2026-02-17 Fix Dockerfile: copy Manifest.toml alongside Project.toml (DFA is unregistered) +testing @docker
(B) 2026-02-17 Fix flake.nix test app: add fallback from hrlab image to volume-mount julia:1.11-bookworm +testing @nix
(C) 2026-02-17 Add nix run .#test-quick app: runs only non-network, non-WFDB tests for fast iteration +testing @nix

# ============================================================
# FOUNDATION — Structural work that blocks models and evaluation
# ============================================================
(A) 2026-02-17 Add minimum_length annotation to every @register call in Features.jl +foundation @features
(A) 2026-02-17 Implement valid_features(n_beats::Int) -> Vector{String} using minimum_length registry +foundation @features
(A) 2026-02-17 Define AbstractHRVModel abstract type and ModelFitResult struct in src/ +foundation @models
(A) 2026-02-17 Design package extension structure: create ext/ directory and update Project.toml weakdeps +foundation @architecture
(B) 2026-02-17 Create ext/HeartRateLabModelsExt.jl skeleton — deps: DifferentialEquations, Turing, Optim, BlackBoxOptim +foundation @architecture
(B) 2026-02-17 Create ext/HeartRateLabVisualizationExt.jl skeleton — deps: GLMakie +foundation @architecture
(B) 2026-02-17 Create ext/HeartRateLabLSLExt.jl skeleton — deps: LSL +foundation @architecture
(C) 2026-02-17 Create ext/HeartRateLabDeepExt.jl skeleton — deps: Flux, DiffEqFlux +foundation @architecture

# ============================================================
# MODELS — ODE and signal-decomposition models
# ============================================================
(A) 2026-02-17 Refactor LIF: convert script to AbstractHRVModel, implement simulate(LIF, params, n_beats) +models @lif
(A) 2026-02-17 Refactor LIF: implement fit(LIF, data; method=:bayesian) using Turing.jl — fix existing skeleton +models @lif
(B) 2026-02-17 Refactor Van der Pol: convert to AbstractHRVModel, implement simulate() +models @vdp
(B) 2026-02-17 Refactor Van der Pol: implement fit() via BlackBoxOptim (evolutionary) and Optim (gradient) +models @vdp
(B) 2026-02-17 Implement Lorenz oscillator model: ODE (σ, ρ, β), extract IBIs from inter-crossing intervals +models @lorenz
(B) 2026-02-17 Implement Lorenz: parameter_space() with priors, fit() via Bayesian or evolutionary +models @lorenz
(B) 2026-02-17 Implement DMD model: fit = decompose IBI series into modes, simulate = reconstruct/propagate +models @dmd
(B) 2026-02-17 Survey Julia DMD ecosystem (e.g. DataDrivenDiffEq.jl) before implementing DMD from scratch +models @dmd
(C) 2026-02-17 Refactor Neural ODE: connect to real HRV data, move to HeartRateLabDeepExt +models @neuralode
(C) 2026-02-17 Implement VAE for ectopic detection: Koopman eigenfunction approach, move to HeartRateLabDeepExt +models @vae
(C) 2026-02-17 Implement fit() method :gradient for LIF via Optim.jl (feature-space loss) +models @lif
(C) 2026-02-17 Implement fit() method :evolutionary for LIF via BlackBoxOptim.jl +models @lif
(D) 2026-02-17 Implement populational hierarchical models (post multi-subject dataset work) +models @hierarchical
(B) 2026-02-17 Write tests: LIF simulate() produces valid IBIs (positive, 300-2000ms range) +models @tests
(B) 2026-02-17 Write tests: VdP simulate() produces valid IBIs +models @tests
(B) 2026-02-17 Write tests: Lorenz simulate() produces valid IBIs +models @tests
(B) 2026-02-17 Write tests: DMD fit() then simulate() on example data round-trips reasonably +models @tests
(B) 2026-02-17 Write tests: LIF fit() on synthetic data recovers approximate parameters +models @tests

# ============================================================
# EVALUATION — The core model-testing pipeline
# ============================================================
(A) 2026-02-17 Implement simulate_ensemble(model, params, n_beats; n_sim) -> Vector{Vector{Float64}} +evaluation @pipeline
(A) 2026-02-17 Implement extract_ensemble_features(ensemble; features) -> DataFrame +evaluation @pipeline
(B) 2026-02-17 Implement eval_distributional(real, ensemble; test=:ks) -> DataFrame with p_value, effect_size per feature +evaluation @pipeline
(B) 2026-02-17 Implement eval_scalar(real, ensemble) -> DataFrame with real_mean, sim_mean, relative_error per feature +evaluation @pipeline
(B) 2026-02-17 Implement eval_distance(real, ensemble; metric=:mahalanobis) -> NamedTuple +evaluation @pipeline
(B) 2026-02-17 Write end-to-end test: load example.txt -> fit LIF -> simulate_ensemble -> eval_distributional +evaluation @tests

# ============================================================
# DATASETS — Open dataset infrastructure + scientific benchmarking
# Dataset tests are part of an extensive test suite that produces
# normative populational statistics as scientific results.
# ============================================================
(B) 2026-02-17 Implement load_physionet(url; annotator, preprocessed) using Downloads.jl + read_wfdb +datasets @infrastructure
(B) 2026-02-17 Implement load_nsrdb(record; kwargs) — wrapper with known NSRDB URLs +datasets @nsrdb
(B) 2026-02-17 Implement load_mitbih(record; kwargs) — wrapper with known MIT-BIH URLs +datasets @mitbih
(B) 2026-02-17 Gate dataset tests on HEARTRATE_NETWORK_TESTS env var; configure CI to skip by default +datasets @ci
(C) 2026-02-17 Implement load_physionet_challenge(dataset, record; kwargs) for challenge datasets +datasets @challenge
(B) 2026-02-17 Write NSRDB normative benchmark: download records, extract features, log populational stats via @info +datasets @benchmarks
(B) 2026-02-17 Write MIT-BIH benchmark: same as NSRDB but for arrhythmia population +datasets @benchmarks
(C) 2026-02-17 Write cross-dataset comparison test: fit LIF to NSRDB, evaluate against MIT-BIH +datasets @benchmarks
(D) 2026-02-17 Design normative statistics output format: CSV/JSON export of populational feature distributions +datasets @science

# ============================================================
# VISUALIZATION — Comparison and analysis plots
# ============================================================
(A) 2026-02-17 Move GLMakie code to ext/HeartRateLabVisualizationExt.jl; remove from core +visualization @architecture
(A) 2026-02-17 Move LSL code to ext/HeartRateLabLSLExt.jl; remove from core +visualization @architecture
(B) 2026-02-17 Implement plot_radar(datasets; features) — spider chart of feature z-scores per model/dataset +visualization @comparison
(B) 2026-02-17 Implement plot_feature_violins(real, ensembles; features) — violin per feature, real vs each model +visualization @comparison
(B) 2026-02-17 Implement plot_comparison(real, synthetics) — IBI time series + Poincaré overlay per model +visualization @comparison
(B) 2026-02-17 Implement plot_model_heatmap(results::DataFrame) — model × feature reproduction quality heatmap +visualization @comparison
(B) 2026-02-17 Implement plot_correlations(feature_sets) — pairplot/correlation matrix across models and datasets +visualization @comparison
(B) 2026-02-17 Add Lorenz 3D scatter (IBI[n] vs IBI[n+1] vs IBI[n+2]) to Visualization.offline +visualization @analysis
(C) 2026-02-17 Add LIF phase-space plot: V(t) with spike resets +visualization @models
(C) 2026-02-17 Add VdP and Lorenz oscillator phase portrait visualizations +visualization @models
(C) 2026-02-17 Implement offline plot_rr(data), plot_poincare(data), plot_spectrum(data), plot_distribution(data) +visualization @offline
(C) 2026-02-17 Refactor default.jl: remove global state, convert to proper function in Visualization.online +visualization @refactor
(C) 2026-02-17 Refactor heart_rate.jl, heart_rate_tt.jl, geometric.jl, distribution.jl similarly +visualization @refactor
(D) 2026-02-17 Add breathing pace guidance visualization for biofeedback +visualization @biofeedback

# ============================================================
# DOCUMENTATION
# ============================================================
(B) 2026-02-17 Write API docs: Input module +docs @api
(B) 2026-02-17 Write API docs: Preprocessing module +docs @api
(B) 2026-02-17 Write API docs: Features module with full feature table and minimum_length column +docs @api
(B) 2026-02-17 Write API docs: Frequency module +docs @api
(B) 2026-02-17 Write API docs: Models module — interface spec + each model's parameter table +docs @api
(B) 2026-02-17 Write API docs: Evaluation module — pipeline functions and metric descriptions +docs @api
(B) 2026-02-17 Write API docs: Visualization module +docs @api
(B) 2026-02-17 Write tutorial: end-to-end offline HRV analysis +docs @tutorials
(B) 2026-02-17 Write tutorial: windowed feature extraction and bootstrapped distributions +docs @tutorials
(C) 2026-02-17 Write tutorial: model fitting, ensemble evaluation, and plot_model_heatmap +docs @tutorials
(C) 2026-02-17 Write tutorial: multi-dataset comparison with plot_radar +docs @tutorials
(C) 2026-02-17 Create Pluto notebooks for each tutorial +docs @notebooks
(C) 2026-02-17 Ensure all exported functions have complete docstrings +docs @docstrings
(B) 2026-02-17 Update README: installation, quickstart, current feature checklist +docs @readme
(B) 2026-02-17 Uncomment and fix docs deployment in CI.yml +docs @ci
(C) 2026-02-17 Deploy documentation to GitHub Pages +docs @ci

# ============================================================
# PUBLISH
# ============================================================
(B) 2026-02-17 Set version to 0.1.0 in Project.toml (current 1.0.0 is premature) +publish @version
(B) 2026-02-17 Add LICENSE file (MIT) +publish @legal
(B) 2026-02-17 Add CITATION.bib +publish @legal
(B) 2026-02-17 Clean .gitignore: track examples/ +publish @cleanup
(B) 2026-02-17 Final code review: BlueStyle compliance, edge cases, docstring completeness +publish @review
(C) 2026-02-17 Register in Julia General registry via JuliaRegistrator +publish @registry
(C) 2026-02-17 Verify CI badges work: tests, coverage, docs +publish @ci
(D) 2026-02-17 Write JOSS paper draft +publish @paper
(D) 2026-02-17 Performance benchmarks: feature extraction speed on NSRDB records +publish @benchmarks
```
