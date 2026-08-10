# Design: Model Documentation

**Date:** 2026-03-01
**Status:** Approved
**Approach:** Pure Documenter.jl Markdown

---

## Goal

Replace the single `docs/src/models.md` page with a 7-page model documentation section covering:
- Framework introduction (AbstractHRVModel, ModelFitResult)
- How to add custom models
- Full theory + API + examples for each of the 4 models

---

## File Structure

```
docs/src/models/
├── index.md         # HRV Models overview; links to all pages
├── framework.md     # AbstractHRVModel, ModelFitResult, fitting methods
├── extending.md     # How to implement your own model
├── lif.md           # Leaky Integrate-and-Fire
├── vanderpol.md     # Van der Pol oscillator
├── lorenz.md        # Lorenz chaotic attractor
└── dmd.md           # Dynamic Mode Decomposition
```

The existing `docs/src/models.md` is **deleted**. `docs/make.jl` is updated with nested sidebar entries.

---

## make.jl Change

```julia
pages=[
    "Home" => "index.md",
    "Getting Started" => "getting_started.md",
    "Features" => "features.md",
    "Models" => [
        "Overview"        => "models/index.md",
        "Framework"       => "models/framework.md",
        "LIF"             => "models/lif.md",
        "Van der Pol"     => "models/vanderpol.md",
        "Lorenz"          => "models/lorenz.md",
        "DMD"             => "models/dmd.md",
        "Extending"       => "models/extending.md",
    ],
    "Visualization" => "visualization.md",
    "Tutorials" => "tutorials.md",
],
```

---

## Tooling Decisions

- **Math:** LaTeX via `$...$` / `$$...$$` (Documenter HTML renders MathJax)
- **API blocks:** `@docs` for specific functions; docstrings already present in source
- **Doctests:** `@doctest` for verifiable examples (model creation, parameter access)
- **Code examples:** Regular ```julia blocks for fit/simulate calls (deps too heavy for doctest)
- **Visualization examples:** Code-only blocks with inline comments about expected output

---

## Per-Page Content Plan

### models/index.md — "Heart Rate Variability Models"

1. 2-paragraph intro: what HRV models are and why they matter
2. Model summary table (name, type, stochastic, fit methods, page link)
3. Brief interface overview: `simulate`, `fit`, `parameter_space`
4. `@docs AbstractHRVModel ModelFitResult`

### models/framework.md — "Model Framework"

1. `AbstractHRVModel` interface contract (required vs optional methods)
2. `ModelFitResult` field-by-field explanation
3. Three fitting methods: `:analytical` (LIF only), `:gradient`, `:bayesian`
4. `parameter_series` helper for posterior access
5. `@docs` for all framework symbols
6. `@doctest` showing `ModelFitResult` field access pattern

### models/extending.md — "Adding Your Own Model"

1. Step-by-step guide: define struct → `simulate` → optional `fit` + `parameter_space`
2. Minimal working example: `GaussianIBI` model (stdlib only, no heavy deps)
3. Checklist: what makes a model valid
4. Doctest verifying the custom model integrates with the ecosystem

### models/lif.md — "Leaky Integrate-and-Fire (LIF)"

**Theory section:**
- Sinoatrial node as biological pacemaker
- LIF ODE: `τ dV/dt = -(V - V_rest) + R·I`
- Threshold-crossing spike detection → IBI
- Analytical period formula: `T = τ · ln(R·I / (R·I - ΔV))`
- Why I is the only fitted parameter (fixed physiology)

**Parameter table:** τ=200ms, V_rest=-65mV, V_reset=-65mV, V_threshold=-60mV, R=10MΩ

**Fitting methods:**
- `:analytical` — per-beat inversion of period formula; returns I series
- `:gradient` — Brent univariate minimization of RMSE
- `:bayesian` — NUTS sampler with truncated-Normal prior on I

**API:** `@docs LIF parameter_space(::LIF) simulate(::LIF,...) fit(::LIF,...)`

**Examples:**
1. Create and simulate (doctest-able)
2. Fit with `:analytical` and inspect per-beat I series
3. Fit with `:gradient` and check convergence diagnostics

### models/vanderpol.md — "Van der Pol Oscillator"

**Theory section:**
- Self-sustaining nonlinear oscillator (van der Pol 1926)
- ODE system: `dV/dt = W`, `dW/dt = μ(1-V²)W - V`
- Limit cycle: trajectories converge to stable oscillation
- μ effect: small μ → near-sinusoidal; large μ → relaxation oscillation

**Parameters:** μ (0.1–3.0), heart_rate (40–120 BPM)

**Fitting methods:** `:gradient` (LBFGS, feature-space distance), `:bayesian` (NUTS)

**API:** `@docs VanDerPol parameter_space(::VanDerPol) simulate(::VanDerPol,...) fit(::VanDerPol,...)`

**Examples:**
1. Create and simulate
2. Fit with `:bayesian` and inspect posterior
3. Generate synthetic and compare SDNN/RMSSD

### models/lorenz.md — "Lorenz Chaotic Attractor"

**Theory section:**
- Lorenz (1963) convection system; deterministic chaos
- ODE: `dX/dt = σ(Y-X)`, `dY/dt = X(ρ-Z)-Y`, `dZ/dt = XY-βZ`
- Butterfly attractor; sensitive dependence on initial conditions
- IBI extraction: z-coordinate upward threshold crossings → inter-event times
- Chaos onset: ρ > 24.7 (subcritical pitchfork → Hopf → chaos)

**Parameters:** σ (5–15), ρ (20–35), β (1–4), threshold (5–15)

**Fitting methods:** `:bayesian` only (non-differentiable chaotic map)

**API:** `@docs Lorenz parameter_space(::Lorenz) simulate(::Lorenz,...) fit(::Lorenz,...) simulate_lorenz_trajectory`

**Examples:**
1. Create and simulate
2. Visualize Lorenz trajectory with `simulate_lorenz_trajectory`
3. Bayesian fit and diagnostics

### models/dmd.md — "Dynamic Mode Decomposition (DMD)"

**Theory section:**
- Data-driven spectral method (Schmid 2010)
- Hankel embedding of scalar IBI series → data matrix
- SVD truncation at rank r → reduced DMD operator
- Eigendecomposition → dynamic modes Φ and eigenvalues λ
- Reconstruction: `x(t) = Σ aᵢ φᵢ λᵢᵗ`
- Rank controls complexity: low rank = dominant oscillations; high rank = fine detail

**Parameters:** `rank` (single integer, 1 to n/2)

**No fitting methods** beyond the SVD decomposition itself (data-driven)

**API:** `@docs DMD fit(::DMD,...) simulate(::DMD,...)`

**Examples:**
1. Fit DMD and simulate reconstruction
2. Compare reconstruction quality at rank=2, 5, 10

---

## Source Modifications

- `docs/make.jl` — update `pages` to nested structure (delete `models.md` entry)
- `docs/src/models.md` — **delete** (content replaced by models/ directory)
- `docs/src/models/*.md` — **create** (7 new files)
- Docstrings in `src/Models/*.jl` — **may need minor fixes** (LIF docstring has accurate content; VanDerPol struct docstring is sparse — will add without changing behavior)

---

## Out of Scope

- Model comparison / when-to-use guide (not requested)
- Quarto rendered notebooks (separate system)
- Visualization functions documentation (separate page)
- New model implementations (docs only, no code changes)
