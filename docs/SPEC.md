# HeartRateLab.jl — Specification Document

**Version:** 1.0
**Branch:** `cl`
**Date:** 2026-03-10
**Purpose:** Authoritative source of requirements for spec-driven development. Every
feature in this document must be implementable, testable, and verifiable before the
branch is merged to `main`.

---

## How To Use This Document

Each specification is written as a **testable statement**:

> **SPEC-{ID}:** _The system shall…_
> **Status:** `DONE` | `PARTIAL` | `TODO`
> **Acceptance criteria:** Numbered list of verifiable conditions.
> **Test:** Path to the test that verifies this spec (or `NONE` if missing).

A spec is considered **DONE** when all acceptance criteria pass in the standard
test runner (`julia --project=. -e 'using Pkg; Pkg.test()'`).

**Update this file** whenever a spec is implemented, a new requirement is discovered,
or a known gap is closed. This document is the ground truth for merge readiness.

---

## 0 · Conventions & Standards

### IBI Units & Sentinel Values
- All IBI values are in **milliseconds** throughout the entire package
- `NaN` is the sentinel value for missing/invalid IBI data in all functions
- Physiological range: 300–2000 ms (enforced at model output boundaries)

### API Conventions
- Preprocessing functions come in mutating (`!`) and non-mutating pairs
- All feature functions receive an `HRMeasurement` struct and are `@memoize`d
- Features are exported via dot notation (`HeartRateLab.Features.extract_feature_set`)
- Input/Preprocessing functions are exported directly

### `HRMeasurement` Struct
All feature functions receive an `HRMeasurement` struct (not a raw `Vector`). This
struct packages the IBI data with metadata (window info, sampling rate) and enables
memoization across features computed on the same recording.

### Testing Conventions
- Baseline comparisons use `isapprox` (not `isequal`) for floating-point values
- Test data: `test/testdata/example.txt` (4,193 IBI samples)
- No `try/catch` blocks to silently skip unimplemented features (anti-pattern)
- Unimplemented features marked with `@test_skip` or `@test_broken`
- Fixed random seeds for all probabilistic tests

### Version Note
Current `Project.toml` declares `version = "1.0.0"` — this is premature. The package
should be versioned as `0.1.0` until all merge-readiness criteria are satisfied.

---

## 1 · Project Goals

**SPEC-G1:** HeartRateLab shall provide a comprehensive Julia package for Heart Rate
Variability (HRV) analysis based on Inter-Beat Intervals (IBIs).
**Status:** `PARTIAL` — core modules complete; Models and demo incomplete.

**SPEC-G2:** The package shall be usable both offline (batch analysis) and in online
settings (real-time biofeedback via LSL).
**Status:** `PARTIAL` — offline complete; LSL visualisation scripts exist but are not
exported as a clean API.

**SPEC-G3:** The package shall be reproducible via Docker and Nix.
**Status:** `PARTIAL` — Docker volume-mount works; `nix run .#build` broken (missing
`COPY Manifest.toml` in Dockerfile; DFA is a git-URL dep).
**Test:** `nix run .#test`

**SPEC-G4:** The package shall integrate open PhysioNet datasets as a normative
reference and scientific benchmark.
**Status:** `DONE`
**Test:** `test/tools/test_sha_integrity.jl`

---

## 2 · Input Module

**SPEC-I1:** `read_txt(path)` shall read IBI values from a plain-text file (one value
per line, milliseconds) and return a `Vector{Float64}`.
**Status:** `DONE`
**Acceptance criteria:**
1. Returns correct IBI count for `test/testdata/example.txt` (4193 values).
2. Values are in milliseconds (300–2000 ms range typical).
**Test:** `test/test_input.jl` → `read_txt`

**SPEC-I2:** `read_wfdb(path, annotator)` shall read beat annotations from WFDB-format
records and return IBIs in milliseconds.
**Status:** `DONE`
**Acceptance criteria:**
1. Reads records `e1304`, `100`, `16265` from `test/testdata/`.
2. Returns `Vector{Float64}` in milliseconds.
**Test:** `test/test_input.jl` → `read_wfdb`

**SPEC-I3:** `read_xdf(path)` shall read XDF files and return IBI streams.
**Status:** `PARTIAL` — basic read works; multi-stream support in `Input_bkp.jl` not
yet merged.
**Test:** `test/test_input.jl` → `read_xdf`

---

## 3 · Preprocessing Module

**SPEC-P1:** `replace_zeros(ibis)` / `replace_zeros!(ibis)` shall replace zero values
with `NaN`.
**Status:** `DONE`
**Test:** `test/test_preprocessing.jl`

**SPEC-P2:** `replace_bio_outliers(ibis)` / `replace_bio_outliers!(ibis)` shall replace
physiologically implausible IBI values (< 200 ms or > 3000 ms) with `NaN`.
**Status:** `DONE`
**Test:** `test/test_preprocessing.jl`

**SPEC-P3:** `replace_statistical_outliers(ibis)` / `replace_statistical_outliers!(ibis)`
shall replace values more than N standard deviations from the mean with `NaN`.
**Status:** `DONE`
**Test:** `test/test_preprocessing.jl`

**SPEC-P4:** `replace_ectopic_beats(ibis)` / `replace_ectopic_beats!(ibis)` shall detect
and replace ectopic beats using a threshold on successive differences.
**Status:** `PARTIAL` — 1 error in current test suite.
**Test:** `test/test_preprocessing.jl` → `replace_ectopic_beats`

**SPEC-P5:** `strip_extremes(ibis)` shall remove leading/trailing NaN-padded values.
**Status:** `DONE`
**Test:** `test/test_preprocessing.jl`

**SPEC-P6:** `interpolate_nans(ibis; method)` shall interpolate NaN values using one of
11 methods: `constant, linear, quadratic, cubic, spline, pchip, akima, hermite,
lagrange, fourier, poly`.
**Status:** `DONE`
**Test:** `test/test_preprocessing.jl` → `interpolate_nans`

**SPEC-P7:** Windowed analysis (`windowed(ibis; window, stride, unit)`) shall partition
an IBI series into overlapping windows by `:beats` or `:ms` units and return a vector of
sub-series suitable for per-window feature extraction.
**Status:** `DONE`
**Test:** `test/test_preprocessing.jl` → `Windowed`

---

## 4 · Features Module

**SPEC-F1:** The package shall expose a **feature registry** (`feature_registry`) mapping
feature names to `HRFeature` structs that include: name, aliases, domains, docstring,
and analytical distribution family (`Normal`, `Gamma`, `Beta`, `LogNormal`).
**Status:** `DONE`

**SPEC-F2:** Feature extraction (`extract_feature_set(m; features)`) shall return a
`DataFrame` with one column per requested feature.
**Status:** `DONE`

**SPEC-F3:** Features shall be declared with the `@register` macro and be `@memoize`d.
**Status:** `DONE`

**SPEC-F4:** The registry exposes **53 scalar features** + **11 representations**. The names below
are reconciled against the actual `@register` set (d-19 landed 2026-06-12); SPEC names that never
existed are corrected to their real names/aliases.

**Implemented (53 scalar features), grouped by domain:**

| Domain | Features |
|--------|---------|
| Time / statistics | `mean`, `median`, `min`, `max`, `range`, `r`, `sdnn`, `rmssd`, `sdsd`, `cvsd`, `cvnni`, `sdann`, `pnn20`, `pnn50`, `mean_hr`, `median_hr`, `std_hr` (alias `sdhr`), `min_hr`, `max_hr`, `range_hr` |
| Frequency | `ulf`, `vlf`, `lf`, `hf`, `tp` (alias `total_power`), `lf_hf_ratio`, `lf_peak`, `hf_peak`, `lf_percentage`, `hf_percentage`, `lf_relative`, `hf_relative` |
| Nonlinear (Poincaré) | `sd1`, `sd2`, `sd2_sd1` (alias `csi`), `sd1_sd2_area`, `ccsi` (alias `modified_csi`), `cvi` |
| Complexity / entropy | `apen`, `sampen`, `fuzzyen`, `shan_en`, `svd_en`, `spec_en`, `perm_en`, `mse`, `renyi0`, `renyi1`, `renyi2` |
| Geometric | `triangular_index` (alias `tri_index`), `tinn` |
| Fractal | `dfa2`, `hurst` |

**Representations (11, non-scalar — return series/matrices for plotting):** `diff`, `length`,
`duration`, `max_t`, `pgram`, `px`, `py`, `histogram`, `renyi`, `dfa`, `dfa1`.

**Planned post-v1:** `lyapunov` (largest Lyapunov exponent).

**Status:** `DONE` — 53 features, baseline regression green in `test/test_features.jl` (175/175).
Cross-library parity validation tracked in d-11. DFA α1/α2 windows corrected to the Peng/Francis
4–16 / 16–64 convention (d-06; Francis et al. 2002, Vest et al. 2018) — `dfa2` baseline regenerated.
**Test:** `test/test_features.jl`

**SPEC-F5:** `windowed_feature_set(ibis; window, stride)` shall extract features for
each window and return a `DataFrame` with metadata columns (`window_id`, `window_size`,
`stride`, `dataset`, `participant_id`).
**Status:** `DONE`
**Test:** `test/tools/collect_normative_datasets.jl` (integration)

---

## 5 · Frequency Module

**SPEC-FR1:** Frequency analysis shall support Lomb-Scargle spectral estimation for
unevenly sampled IBI series.
**Status:** `DONE`

**SPEC-FR2:** The module shall define and integrate four HRV frequency bands:
- ULF: 0–0.003 Hz
- VLF: 0.003–0.04 Hz
- LF: 0.04–0.15 Hz
- HF: 0.15–0.4 Hz
**Status:** `DONE`

**SPEC-FR3:** `find_peak(spectrum, band)` shall return the frequency of the spectral peak
within the given band.
**Status:** `PARTIAL` — incorrect index bug at `Frequency.jl:88`.
**Test:** `test/test_frequency.jl`

---

## 6 · Models Module

### 6.1 Framework

**SPEC-M1:** All HRV models shall implement the `AbstractHRVModel` interface:
- `simulate(model, params, n_beats) → Vector{Float64}` — generate synthetic IBI series
- `fit(model, data; method) → ModelFitResult` — fit model to real IBI data
- `parameter_space(model) → NamedTuple` — return parameter bounds/priors
**Status:** `DONE` (LIF, VanDerPol, Lorenz implemented; DMD data-driven, no `parameter_space` needed)

**SPEC-M2:** `ModelFitResult` shall carry: `model`, `method`, `params`, `posterior`,
`diagnostics`, `data`.
**Status:** `DONE`

**SPEC-M3:** The fitting interface shall support three methods:
- `:analytical` — closed-form inversion (LIF only)
- `:gradient` — Optim.jl LBFGS/Brent minimisation
- `:bayesian` — Turing.jl NUTS MCMC sampler
**Status:** `DONE`

**SPEC-M4:** The model catalogue shall be extensible: a user-defined struct that subtypes
`AbstractHRVModel` and implements `simulate` and `fit` shall work with the evaluation
pipeline without changes to the core library.
**Status:** `DONE` — documented in `docs/src/models/extending.md`

### 6.2 Leaky Integrate-and-Fire (LIF)

**SPEC-M5:** `LIF(; τ, V_rest, V_reset, V_threshold, R)` shall implement the cardiac
pacemaker model:
`τ dV/dt = -(V - V_rest) + R·I`
with threshold-crossing → IBI extraction.
Default parameters: τ=200ms, V_rest=−65mV, V_reset=−65mV, V_threshold=−60mV, R=10MΩ.
**Status:** `DONE`

**SPEC-M6:** `simulate(::LIF, params, n_beats)` shall return a physiologically plausible
IBI series (300–2000 ms).
**Status:** `DONE`

**SPEC-M7:** `fit(::LIF, data; method=:analytical)` shall invert the analytical period
formula `T = τ·ln(R·I / (R·I − ΔV))` per beat, returning an I time series.
**Status:** `DONE`

**SPEC-M8:** `fit(::LIF, data; method=:bayesian)` shall sample the posterior over I
using NUTS.
**Status:** `DONE`
**Known issue:** `Models/LIF.jl:61` references old `HeartRateVariability` package.

### 6.3 Van der Pol Oscillator

**SPEC-M9:** `VanDerPol(; μ, heart_rate, σ_noise)` shall implement the nonlinear
relaxation oscillator. Parameters: μ ∈ (0.1, 3.0), heart_rate ∈ (40, 120) BPM.
**Status:** `DONE`

**SPEC-M10:** `fit(::VanDerPol, data; method=:gradient)` shall minimise a feature-space
distance loss using LBFGS.
**Status:** `DONE`

**SPEC-M11:** `fit(::VanDerPol, data; method=:bayesian)` shall sample with NUTS.
**Status:** `DONE`

### 6.4 Lorenz Chaotic Attractor

**SPEC-M12:** `Lorenz(; σ, ρ, β, threshold)` shall implement the Lorenz system;
IBIs extracted from z-coordinate upward threshold crossings.
Default: σ=10, ρ=28, β=8/3, threshold=10.
**Status:** `DONE`

**SPEC-M13:** `fit(::Lorenz, data; method=:bayesian)` shall be the only supported fit
method (non-differentiable chaotic map precludes gradient methods).
**Status:** `DONE`

### 6.5 Dynamic Mode Decomposition (DMD)

**SPEC-M14:** `DMD(; rank)` shall construct a Hankel-matrix SVD decomposition of the
input IBI series. `rank` controls complexity.
**Status:** `DONE`

**SPEC-M15:** `fit(::DMD, data)` shall compute modes, eigenvalues, and amplitudes from
the SVD.
**Status:** `DONE`

**SPEC-M16:** `simulate(::DMD, nothing, n_beats)` shall reconstruct an IBI series from
stored modes. `DMD` must be fitted before `simulate` is called.
**Status:** `DONE`

---

## 7 · Evaluation Pipeline

**SPEC-E1:** `eval_distributional(real_df, synthetic_df; features)` shall compute
statistical distribution-level comparison metrics (KS test, Wasserstein distance) for
each feature.
**Status:** `DONE`
**Test:** `test/test_evaluation.jl` (via `collect_normative_datasets.jl` integration)

**SPEC-E2:** `eval_scalar(real_df, synthetic_df; features)` shall compute mean and error
(MAE, RMSE, relative error) between real and synthetic feature sets.
**Status:** `DONE`

**SPEC-E3:** `eval_distance(real_df, synthetic_df; features)` shall compute feature-space
distance metrics (Mahalanobis, Euclidean, cosine).
**Status:** `DONE`

**SPEC-E4:** `simulate_ensemble(model, params, n, n_beats)` shall generate a set of N
synthetic IBI series.
**Status:** `DONE`

**SPEC-E5:** `extract_ensemble_features(ensemble; features)` shall extract features
from each series in an ensemble and return a `DataFrame`.
**Status:** `DONE`

---

## 8 · Normative Dataset Infrastructure

**SPEC-N1:** `collect_normative_datasets.jl` shall download and process PhysioNet
datasets (nsrdb, nsr2db, mvtdb, mitbih) and store windowed feature CSVs and metadata.
**Status:** `DONE`

**SPEC-N2:** `metadata.toml` shall record **all** collection runs as a TOML array of
tables (`[[analyses]]`), each entry carrying: date, window_size, stride,
windowed_features filename, heartrateLab_version, and record counts.
Multiple runs with different window/stride parameters shall **append**, not overwrite.
**Status:** `DONE` (implemented 2026-03-10)

**SPEC-N3:** `test_sha_integrity.jl` shall verify SHA-256 checksums for all downloaded
dataset files.
**Status:** `DONE`

**SPEC-N4:** `fit_normative_distributions.jl` shall fit statistical distributions to
per-feature normative data and save results to
`test/testdata/normative_distribution_fits.toml`.
**Status:** `DONE`

**SPEC-N5:** `generate_normative_report.jl` shall produce a HTML report comparing
participant HRV to the normative reference for each PhysioNet dataset.
**Status:** `DONE`

**SPEC-N6:** `generate_participant_report.jl` shall produce a personalised participant
HRV report with three tabs: All Normal, Training HRV, and Timeline.
**Status:** `DONE`

---

## 9 · Visualization Module

All nine plot functions shall accept a `title` keyword argument and return a renderable
figure object.

**SPEC-V1:** `plot_flagship(data, fit_result)` shall produce a 2×2 grid: IBI series,
Poincaré plot, power spectrum, model comparison.
**Status:** `DONE`
**Test:** visual — `test/tools/generate_participant_report.jl`

**SPEC-V2:** `plot_ibi_series(data)` shall plot the IBI time series with ±1σ envelope.
**Status:** `DONE`

**SPEC-V3:** `plot_poincare(data)` shall plot RRₙ vs RRₙ₊₁ with a fit ellipse.
**Status:** `DONE`

**SPEC-V4:** `plot_spectrum(ibis; method=:lomb)` shall display the Lomb-Scargle power
spectrum with labelled VLF/LF/HF band regions.
**Status:** `PARTIAL` — requires GLMakie; stubs present.
**Action required:** Verify the Plots.jl path works headlessly.

**SPEC-V5:** `plot_comparison(real, models)` shall overlay real and multiple synthetic
IBI series for side-by-side model comparison.
**Status:** `PARTIAL` — Dict version implemented; single-model overload stubs out with
GLMakie error.

**SPEC-V6:** `plot_model_heatmap(results)` shall display a model × feature quality
matrix (colour = reproduction error).
**Status:** `PARTIAL` — DataFrame version implemented; Dict overload stubs with
GLMakie error.

**SPEC-V7:** `plot_lorenz_3d(lorenz_result)` shall render the Lorenz phase-space
trajectory from fitted parameters.
**Status:** `DONE` (Plots.jl path)

**SPEC-V8:** `plot_radar(datasets)` shall display a spider/radar chart of normalised
feature z-scores across multiple datasets or models.
**Status:** `DONE`

**SPEC-V9:** `plot_correlations(feature_sets)` shall display a feature correlation
heatmap.
**Status:** `DONE`

**SPEC-V10:** `plot_feature_violins(real, ensembles)` shall display per-feature
violin-plot distributions for real data vs model ensembles.
**Status:** `DONE`

**SPEC-V11:** `plot_normative_kde_comparison`, `plot_feature_correlogram`,
`plot_normative_pairplot` shall support the participant report generation workflow.
**Status:** `DONE`

---

## 10 · Flagship Demo

**SPEC-D1:** `docs/flagship_demo.qmd` shall be a Quarto notebook that loads real IBI
data, preprocesses it, extracts features, fits all four models, evaluates them, and
produces all nine visualisation types. The notebook shall render to HTML without errors.
**Status:** `PARTIAL` — notebook exists; rendering pipeline (Docker + Quarto) needs
final verification.

**SPEC-D2:** The flagship demo shall include:
- LIF model explanation with analytical fitting
- Van der Pol phase-space animation / static plot
- Lorenz 3D attractor
- DMD spectrum reconstruction
- Feature comparison across models (radar + violin)
- Normative reference overlay
**Status:** `PARTIAL`

---

## 11 · Presentation Slides

**SPEC-S1:** A presentation slide deck shall be produced (format TBD: Quarto revealjs
or equivalent) covering: project motivation, architecture, model catalogue, evaluation
results, normative datasets.
**Status:** `TODO`

---

## 12 · Testing Infrastructure

**SPEC-T1:** The test suite shall be split into independent files that can be run in
isolation without blocking each other:
- `test/test_input.jl`
- `test/test_preprocessing.jl`
- `test/test_features.jl`
- `test/test_frequency.jl`
- `test/test_models.jl`
- `test/test_visualization.jl`
- `test/test_evaluation.jl`
**Status:** `DONE` — all listed files exist and are wired in `runtests.jl` (the sham
`test_datasets.jl` was removed 2026-06-12; loaders moved to `test/tools/`).

**SPEC-T2:** Feature baseline comparisons shall use `isapprox` (not `isequal`) to avoid
floating-point precision failures.
**Status:** `DONE` — baselines compare with `isapprox`.

**SPEC-T3:** Test suite shall pass with **zero failures**. NOTE: the canonical command is
`nix run .#test` (WFDB + X11), **not** plain Julia (no WFDB → `ann2rr` ENOENT; no display →
GLMakie segfault). See AGENTS.md Golden Rule.
**Status:** `PARTIAL` — non-viz suite 620 pass / 0 fail / 1 `@test_broken` (DMD mean, intentional);
full Xvfb green is the v1 exit gate (task-15).

**SPEC-T4:** Tests shall not use `try/catch` to silently skip unimplemented
functionality (anti-pattern documented in `AGENTS.md`).
**Status:** `DONE` — sham tests removed (incl. `test_datasets.jl`, 2026-06-12).

**SPEC-T5:** `nix run .#test` shall succeed.
**Status:** `PARTIAL` — Dockerfile `COPY Manifest.toml` fixed (BUG-5 resolved); full green
pending the remaining test-floor + viz-test work (task-15).

---

## 12b · Performance Requirements

**SPEC-PERF1:** Feature extraction shall complete in **< 1 second** for a 4,000-beat
IBI series on standard hardware.
**Status:** `DONE` (memoization ensures first call pays cost; subsequent calls are free)

**SPEC-PERF2:** Bayesian model fitting (NUTS sampler, default settings) shall complete
in **< 60 seconds** for 1,000 samples × 4 chains on standard hardware.
**Status:** `DONE` — LIF ~10–30s; VDP/Lorenz longer; acceptable for offline use

**SPEC-PERF3:** Gradient-based model fitting shall complete in **< 30 seconds**.
**Status:** `DONE`

**SPEC-PERF4:** Bayesian chain R-hat diagnostic shall be **< 1.1** for all fitted
parameters, indicating MCMC convergence.
**Status:** `DONE` — checked in `ModelFitResult.diagnostics`

**SPEC-PERF5:** Ensemble simulation of 100 synthetic IBI series shall complete in
**< 10 seconds**.
**Status:** `DONE`

---

## 13 · Known Bugs (reconciled 2026-06-12)

| ID | Location | Description | Status |
|----|----------|-------------|--------|
| BUG-1 | `Features.jl` DFA | α1/α2 box params possibly off | **Under verification** vs other HRV libs (d-06) — not confirmed wrong |
| BUG-2 | `Frequency.jl` | `find_peak` returned wrong index | ✅ Fixed (task-10) |
| BUG-3 | `Models/LIF.jl` | Referenced old `HeartRateVariability` package | ✅ Fixed |
| BUG-4 | `test/test_features.jl` | `isequal` vs `isapprox` | ✅ Fixed |
| BUG-5 | `Dockerfile` | Missing `COPY Manifest.toml` | ✅ Fixed |

---

## 14 · Release Readiness Checklist (target = 0.1.0)

Reconciled 2026-06-12 against `backlog/docs/2026-06-12-v1-roadmap.md`. Resolved items checked.

- [x] **BUG-2** — `find_peak` fix
- [x] **BUG-3** — LIF package reference fix
- [x] **BUG-4** — `isapprox` baselines
- [x] **BUG-5** — Dockerfile `COPY Manifest.toml`
- [x] Version honest (0.1.0) + `[compat]` bounds complete (d-01)
- [x] Dead `ModelsExt` removed; sham `test_datasets.jl` removed (d-02 / d-10)
- [ ] **SPEC-T5** — `nix run .#test` fully green under Xvfb (task-15, the exit gate)
- [ ] **BUG-1** — DFA α1/α2 params verified vs other HRV libs (d-06)
- [ ] Missing features implemented (d-19); viz gallery (d-07/08/21/22); test floor (d-12–16)
- [ ] Viz tests skip cleanly headless (task-11 + d-17)
- [ ] Docs published (d-05); README/SPEC truthful (d-03 / d-04 — this pass)
- [ ] All `[[analyses]]` entries correct in normative dataset metadata (run `recollect_normative.sh`)

---

## 15 · Out of Scope for `cl` Branch

- VAE (Variational Autoencoder) model — documented as future work
- Live LSL visualization API — scripts exist but not exposed as package API
- GPU support in Nix/Docker — documented as future task
- Population hierarchical models — future work
- XDF multi-stream parser (`Input_bkp.jl`) — deferred to separate branch
