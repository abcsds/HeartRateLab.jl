# Model Documentation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace `docs/src/models.md` with a 7-page model documentation section covering the framework, each of the 4 HRV models, and a guide for adding custom models.

**Architecture:** Pure Documenter.jl Markdown. Each model gets its own page with theory, parameter tables, API `@docs` blocks, and code examples. A framework page covers the shared interface. No Quarto, no rendered outputs.

**Tech Stack:** Documenter.jl, Julia 1.11, `docs/make.jl` sidebar navigation

---

## Prerequisites

- Working directory: repo root
- Read the design doc first: `docs/plans/2026-03-01-model-documentation-design.md`
- Key source files: `src/Models/LIF.jl`, `src/Models/VanDerPol.jl`, `src/Models/Lorenz.jl`, `src/Models/DMD.jl`, `src/Models/Models.jl`
- Docs build command: `julia --project=docs/ docs/make.jl` (requires Documenter.jl to be installed in docs environment)

## Accuracy Notes

Read before writing any content:

**LIF model:**
- Has NO default constructor. Must use `LIF(τ, V_rest, V_reset, V_threshold, R, I)`.
- Task 1 adds a keyword constructor `LIF(; ...)` (1-line code change) to enable `LIF()`.
- Fixed physiology: τ=200.0 ms, V_rest=-65.0 mV, V_reset=-65.0 mV, V_threshold=-60.0 mV, R=10.0 MΩ
- Fitted param: I ∈ [1.48, 1.56] μA
- Three fit methods: `:analytical`, `:gradient`, `:bayesian`
- `:analytical` inverts period formula per-beat; stores I_series in `result.posterior["I"]`
- `:gradient` uses Brent 1D optimization (not LBFGS — it's univariate)

**VanDerPol model:**
- Empty struct: `struct VanDerPol <: AbstractHRVModel end` → `VanDerPol()` works fine
- Parameters: μ (nonlinearity), heart_rate (BPM)
- fit methods: `:gradient` (LBFGS, feature-space distance), `:bayesian` (NUTS)
- The simulate() uses a harmonic approximation (not a full ODE solver)

**Lorenz model:**
- Keyword constructor: `Lorenz(; σ=10.0, ρ=28.0, β=8/3, threshold=10.0)`
- IBIs from z-coordinate upward threshold crossings × 1000 (converts to ms)
- fit method: `:bayesian` only
- `simulate_lorenz_trajectory(params; duration=100.0)` exists but is NOT exported from HeartRateLab; access via `HeartRateLab.Models.simulate_lorenz_trajectory`

**DMD model:**
- Keyword constructor: `DMD(; rank=5)`
- Must call `fit` before `simulate` (modes empty until fitted)
- No `parameter_space` method
- Uses Hankel embedding + SVD; rank ≤ n/2

---

## Task 1: Add LIF Default Constructor (1 line of code)

**Files:**
- Modify: `src/Models/LIF.jl` (after the struct definition, ~line 37)

**Context:** Without a default constructor, `LIF()` throws a MethodError. This is a 1-line fix that enables clean documentation examples and consistent API with other models.

**Step 1: Add keyword constructor after the struct definition**

In `src/Models/LIF.jl`, after line 37 (end of struct), add:

```julia
LIF(; τ=200.0, V_rest=-65.0, V_reset=-65.0, V_threshold=-60.0, R=10.0, I=1.52) =
    LIF(τ, V_rest, V_reset, V_threshold, R, I)
```

**Step 2: Verify in a Julia REPL (or note for later testing)**

```julia
julia> include("src/Models/Models.jl")
julia> lif = Models.LIF()
# Should print: LIF(200.0, -65.0, -65.0, -60.0, 10.0, 1.52)
```

**Step 3: Commit**

```bash
git add src/Models/LIF.jl
git commit -m "feat: add LIF() keyword constructor with physiological defaults"
```

---

## Task 2: Setup Directory and Update make.jl

**Files:**
- Create: `docs/src/models/` directory
- Modify: `docs/make.jl`
- Delete: `docs/src/models.md`

**Step 1: Create the models directory**

```bash
mkdir docs/src/models
```

**Step 2: Update `docs/make.jl` — replace the `"Models" => "models.md"` line**

Old content (lines 15–22):
```julia
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Features" => "features.md",
        "Models" => "models.md",
        "Visualization" => "visualization.md",
        "Tutorials" => "tutorials.md",
    ],
```

New content:
```julia
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Features" => "features.md",
        "Models" => [
            "Overview"     => "models/index.md",
            "Framework"    => "models/framework.md",
            "LIF"          => "models/lif.md",
            "Van der Pol"  => "models/vanderpol.md",
            "Lorenz"       => "models/lorenz.md",
            "DMD"          => "models/dmd.md",
            "Extending"    => "models/extending.md",
        ],
        "Visualization" => "visualization.md",
        "Tutorials" => "tutorials.md",
    ],
```

**Step 3: Remove the old models.md**

```bash
git rm docs/src/models.md
```

**Step 4: Commit setup**

```bash
git add docs/make.jl
git commit -m "docs: restructure Models section into per-model pages"
```

---

## Task 3: Create `docs/src/models/index.md`

**Files:**
- Create: `docs/src/models/index.md`

**Step 1: Write the file**

```markdown
# Heart Rate Variability Models

```@meta
CurrentModule = HeartRateLab
```

HeartRateLab provides four models for synthesizing and analyzing inter-beat interval (IBI)
time series. Two are mechanistic (grounded in physiology or physics), one is chaotic
(deterministic but sensitive to parameters), and one is purely data-driven.

| Model | Type | Stochastic | Fit Methods | Page |
|-------|------|:----------:|-------------|------|
| [LIF](@ref lif-page) | Mechanistic (ODE) | — | `:analytical`, `:gradient`, `:bayesian` | [→](@ref lif-page) |
| [Van der Pol](@ref vdp-page) | Mechanistic (ODE) | — | `:gradient`, `:bayesian` | [→](@ref vdp-page) |
| [Lorenz](@ref lorenz-page) | Chaotic (ODE) | — | `:bayesian` | [→](@ref lorenz-page) |
| [DMD](@ref dmd-page) | Data-driven (SVD) | — | SVD decomposition | [→](@ref dmd-page) |

## Shared Interface

All models implement a common interface via `AbstractHRVModel`:

```julia
# Create a model
model = LIF()           # or VanDerPol(), Lorenz(), DMD(rank=5)

# Fit to IBI data (milliseconds)
result = fit(model, ibis; method=:gradient)

# Generate synthetic IBIs
synthetic = simulate(result.model, result.params, 500)
```

See [Framework](@ref framework-page) for the full interface specification.

```@docs
AbstractHRVModel
ModelFitResult
```
```

**Step 2: Commit**

```bash
git add docs/src/models/index.md
git commit -m "docs: add models overview index page"
```

---

## Task 4: Create `docs/src/models/framework.md`

**Files:**
- Create: `docs/src/models/framework.md`

**Step 1: Write the file**

```markdown
# [Model Framework](@id framework-page)

```@meta
CurrentModule = HeartRateLab
```

All HRV models in HeartRateLab inherit from `AbstractHRVModel` and share a unified API.

## AbstractHRVModel Interface

Every model must implement `simulate`. `fit` and `parameter_space` are optional.

```julia
# Required
simulate(model::AbstractHRVModel, params::NamedTuple, n_beats::Int) -> Vector{Float64}

# Optional (for models that support parameter fitting)
fit(model::AbstractHRVModel, data::Vector{Float64}; method::Symbol, kwargs...) -> ModelFitResult
parameter_space(model::AbstractHRVModel) -> NamedTuple
```

`simulate` always returns a `Vector{Float64}` of IBI values in **milliseconds**.

## ModelFitResult

`fit` returns a `ModelFitResult` containing:

| Field | Type | Description |
|-------|------|-------------|
| `model` | `AbstractHRVModel` | The fitted model |
| `method` | `Symbol` | Fitting method used (`:analytical`, `:gradient`, `:bayesian`) |
| `params` | `NamedTuple` | Point estimates (MAP for Bayesian, minimizer for gradient) |
| `posterior` | `Dict` or `nothing` | Posterior samples (Bayesian) or per-beat series (analytical) |
| `diagnostics` | `Dict` | Convergence info, iterations, loss, R-hat, etc. |
| `data` | `Vector{Float64}` | Original IBI data used for fitting |

```@doctest
julia> using HeartRateLab

julia> vdp = VanDerPol()
VanDerPol()

julia> typeof(vdp) <: AbstractHRVModel
true
```

## Fitting Methods

### `:analytical`

Available on LIF only. Inverts the period formula for each IBI individually, returning
a per-beat `I` series. Instantaneous — no simulation or optimization required.

```julia
result = fit(LIF(), ibis; method=:analytical)
# result.params.I        → mean I across all beats
# result.posterior["I"] → Vector of per-beat I values (same length as ibis)
```

### `:gradient`

Minimizes a distance function (RMSE or feature-space distance) using gradient-free
or gradient-based optimization via Optim.jl.

```julia
result = fit(VanDerPol(), ibis; method=:gradient)
result.diagnostics["converged"]   # Bool
result.diagnostics["iterations"]  # Int
result.diagnostics["loss_final"]  # Float64
```

### `:bayesian`

NUTS MCMC sampler via Turing.jl. Returns full posterior distributions over parameters.
Requires more computation but provides uncertainty estimates.

```julia
result = fit(LIF(), ibis; method=:bayesian, chains=4, samples=1000)
result.params.I              # Posterior mean
result.posterior["I"]        # Vector of 4000 MCMC samples
result.diagnostics["rhat_I"] # R-hat convergence diagnostic (target < 1.1)
```

## Accessing Posterior Samples

Use `parameter_series` to retrieve samples or per-beat series from a fit result:

```julia
result = fit(LIF(), ibis; method=:analytical)
I_series = parameter_series(result, :I)  # per-beat Vector{Float64}

result_bayes = fit(LIF(), ibis; method=:bayesian)
I_samples = parameter_series(result_bayes, :I)  # MCMC samples
```

## API Reference

```@docs
AbstractHRVModel
ModelFitResult
parameter_series
```
```

**Step 2: Commit**

```bash
git add docs/src/models/framework.md
git commit -m "docs: add Models framework reference page"
```

---

## Task 5: Create `docs/src/models/lif.md`

**Files:**
- Create: `docs/src/models/lif.md`

**Step 1: Write the file**

````markdown
# [Leaky Integrate-and-Fire (LIF)](@id lif-page)

```@meta
CurrentModule = HeartRateLab
```

The LIF model treats the heart's sinoatrial node as a biological pacemaker neuron.
Each heartbeat corresponds to a membrane voltage threshold crossing.

## Theory

The sinoatrial node drives the heart's rhythm by spontaneously depolarizing and
resetting. The leaky integrate-and-fire model captures this with a single ODE:

$$\tau \frac{dV}{dt} = -(V - V_{rest}) + R \cdot I$$

When $V$ rises to $V_{threshold}$ (upward crossing), a **spike** (heartbeat) is
recorded and $V$ is immediately reset to $V_{reset}$.

The inter-beat interval (IBI) is the time between consecutive spikes, directly in
milliseconds — the model's time unit is physiological time.

### Analytical Period Formula

For constant $I$ with $V^* = V_{rest} + R \cdot I > V_{threshold}$ (the fixed-point
voltage exceeds threshold, ensuring repetitive firing):

$$T = \tau \cdot \ln\!\left(\frac{R \cdot I}{R \cdot I - \Delta V}\right), \quad
  \Delta V = V_{threshold} - V_{rest}$$

Inverting for the current that produces a desired period $T$:

$$I(T) = \frac{\Delta V}{R \cdot \left(1 - e^{-T/\tau}\right)}$$

This inverse formula is used by the `:analytical` fitting method to compute a
per-beat $I$ value from each measured IBI.

## Parameters

### Fixed Physiological Parameters

These are set at construction and not fitted. They reflect biologically plausible
values for the sinoatrial node.

| Parameter | Value | Unit | Description |
|-----------|-------|------|-------------|
| `τ` | 200.0 | ms | Membrane time constant |
| `V_rest` | −65.0 | mV | Resting potential |
| `V_reset` | −65.0 | mV | Post-spike reset potential |
| `V_threshold` | −60.0 | mV | Spike threshold |
| `R` | 10.0 | MΩ | Membrane resistance |

### Fitted Parameter

| Parameter | Range | Description |
|-----------|-------|-------------|
| `I` | 1.48 – 1.56 μA | Input current; encodes autonomic drive and heart rate |

`I ≈ 1.48` → slow rate (~20 bpm), `I ≈ 1.56` → fast rate (~200 bpm).
A typical resting value is `I ≈ 1.52` (~75 bpm).

## Fitting Methods

- **`:analytical`** — Exact per-beat inversion using $I(T)$. Instantaneous. Returns
  a distribution of I values across beats, capturing beat-to-beat variability.
- **`:gradient`** — Brent's univariate method minimizing RMSE of simulated IBIs.
  Fast and reliable for this 1-parameter problem.
- **`:bayesian`** — NUTS sampler (Turing.jl) with a truncated-Normal prior on $I$.
  Provides a posterior distribution over $I$.

## Examples

### Create and Simulate

```julia
using HeartRateLab

# Create model with physiological defaults
lif = LIF()

# Simulate 500 inter-beat intervals
params = (I = 1.52,)
ibis = simulate(lif, params, 500)

# Check physiological range (should be ~700-900 ms at rest)
using Statistics
println("Mean IBI: ", mean(ibis), " ms")
println("Heart rate: ", round(60000 / mean(ibis)), " bpm")
```

### Fit with Analytical Method

The analytical method is the fastest option. It returns a per-beat current series
that captures how autonomic drive varies across the recording.

```julia
using HeartRateLab

lif = LIF()
ibis = read_txt("data.txt")

result = fit(lif, ibis; method=:analytical)

println("Mean I: ", result.params.I)
println("Std of I: ", result.diagnostics["I_std"])

# Per-beat current series
I_series = parameter_series(result, :I)
println("I range: ", extrema(I_series))

# Generate synthetic from mean I
synthetic = simulate(result.model, result.params, length(ibis))
```

### Fit with Gradient Method

```julia
using HeartRateLab

lif = LIF()
ibis = read_txt("data.txt")

result = fit(lif, ibis; method=:gradient)

println("Fitted I: ", result.params.I)
println("Converged: ", result.diagnostics["converged"])
println("Final RMSE: ", result.diagnostics["loss_final"])

# Generate synthetic IBIs
synthetic = simulate(result.model, result.params, length(ibis))
```

## API Reference

```@docs
LIF
parameter_space(::LIF)
simulate(::LIF, ::NamedTuple, ::Int)
fit(::LIF, ::Vector{Float64})
```
````

**Step 2: Commit**

```bash
git add docs/src/models/lif.md
git commit -m "docs: add LIF model documentation page"
```

---

## Task 6: Create `docs/src/models/vanderpol.md`

**Files:**
- Create: `docs/src/models/vanderpol.md`

**Step 1: Write the file**

````markdown
# [Van der Pol Oscillator](@id vdp-page)

```@meta
CurrentModule = HeartRateLab
```

The Van der Pol oscillator is a nonlinear self-sustaining oscillator originally
developed to model vacuum tube circuits. Its limit-cycle dynamics bear structural
similarities to cardiac rhythm generation.

## Theory

The Van der Pol system is:

$$\frac{dV}{dt} = W$$
$$\frac{dW}{dt} = \mu(1 - V^2)W - V$$

The nonlinearity $\mu(1 - V^2)$ acts as **negative damping** near $V=0$
(amplifying small oscillations) and **positive damping** far from $V=0$
(suppressing large ones). This produces a self-sustaining **limit cycle** — the
trajectory converges to a closed orbit regardless of initial conditions.

### Effect of μ

| μ range | Behavior | HRV analogy |
|---------|----------|-------------|
| 0.1 – 1.0 | Near-sinusoidal, weakly nonlinear | Regular, low-variability rhythm |
| 1.5 – 2.5 | Strong relaxation oscillations | Normal cardiac range |
| > 3.0 | Sharp peaks with slow return | Extreme nonlinearity |

### IBI Generation

The simulation uses a harmonic approximation of the Van der Pol oscillation.
Given a base heart rate `heart_rate` (BPM), the mean IBI is `60000 / heart_rate` ms.
The parameter μ controls the amplitude and shape of beat-to-beat modulation.

## Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `μ` | 0.1 – 3.0 | 1.0 | Nonlinearity / oscillation strength |
| `heart_rate` | 40 – 120 BPM | 70 | Base heart rate in beats per minute |

## Fitting Methods

- **`:gradient`** — LBFGS with box constraints (Optim.jl). Minimizes a
  normalized feature-space distance over `[mean, sdnn, rmssd]`.
- **`:bayesian`** — NUTS sampler (Turing.jl). Truncated-Normal priors on μ
  and heart_rate; Exponential prior on observation noise σ.

## Examples

### Create and Simulate

```@doctest
julia> using HeartRateLab

julia> vdp = VanDerPol()
VanDerPol()

julia> params = (μ = 1.5, heart_rate = 70.0);

julia> ibis = simulate(vdp, params, 10);

julia> length(ibis)
10
```

### Fit with Gradient Method

```julia
using HeartRateLab

vdp = VanDerPol()
ibis = read_txt("data.txt")

result = fit(vdp, ibis; method=:gradient)

println("Fitted μ: ", result.params.μ)
println("Fitted heart rate: ", result.params.heart_rate, " bpm")
println("Converged: ", result.diagnostics["converged"])

# Generate synthetic
synthetic = simulate(result.model, result.params, length(ibis))
```

### Fit with Bayesian Inference

```julia
using HeartRateLab

vdp = VanDerPol()
ibis = read_txt("data.txt")

result = fit(vdp, ibis; method=:bayesian, chains=4, samples=1000)

println("Posterior mean μ: ", result.params.μ)
println("R-hat μ: ", result.diagnostics["rhat_mu"])

# Posterior samples
μ_samples = parameter_series(result, :μ)
println("95% CI for μ: ", quantile(μ_samples, [0.025, 0.975]))
```

## API Reference

```@docs
VanDerPol
parameter_space(::VanDerPol)
simulate(::VanDerPol, ::NamedTuple, ::Int)
fit(::VanDerPol, ::Vector{Float64})
```
````

**Step 2: Commit**

```bash
git add docs/src/models/vanderpol.md
git commit -m "docs: add Van der Pol oscillator documentation page"
```

---

## Task 7: Create `docs/src/models/lorenz.md`

**Files:**
- Create: `docs/src/models/lorenz.md`

**Step 1: Write the file**

````markdown
# [Lorenz Chaotic Attractor](@id lorenz-page)

```@meta
CurrentModule = HeartRateLab
```

The Lorenz system is a 3-dimensional ODE exhibiting **deterministic chaos** — its
trajectories are bounded and aperiodic, with sensitive dependence on initial conditions.
IBIs are extracted from threshold crossings of the z-coordinate.

## Theory

The Lorenz equations model atmospheric convection (Lorenz, 1963):

$$\frac{dX}{dt} = \sigma(Y - X)$$
$$\frac{dY}{dt} = X(\rho - Z) - Y$$
$$\frac{dZ}{dt} = XY - \beta Z$$

The trajectory traces the famous **butterfly attractor** — two lobes in 3D phase
space with chaotic switching between them.

### IBI Extraction

Heartbeat events are identified by **upward threshold crossings** of the
z-coordinate. Each time $Z$ rises through `threshold`, a beat is recorded.
The IBI is the time between consecutive crossings, converted to milliseconds.

$$\text{IBI}_i = (t_{i+1} - t_i) \times 1000 \quad \text{[ms]}$$

### Chaos Onset

| ρ value | Behavior |
|---------|----------|
| ρ < 1 | Stable fixed point at origin |
| 1 < ρ < 24.7 | Two stable fixed points (no chaos) |
| ρ = 28 (default) | Classical chaotic regime |
| ρ > 40 | Complex high-dimensional chaos |

### Why Bayesian Fitting Only

The Lorenz system is non-differentiable with respect to its parameters in any
practical sense: small parameter changes cause qualitative trajectory reorganization.
Gradient-based methods are ineffective. NUTS MCMC explores the parameter space
stochastically.

## Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `σ` | 5 – 15 | 10.0 | Prandtl number (flow structure) |
| `ρ` | 20 – 35 | 28.0 | Rayleigh number (chaos control) |
| `β` | 1 – 4 | 8/3 ≈ 2.667 | Aspect ratio (dissipation) |
| `threshold` | 5 – 15 | 10.0 | Z-value for IBI detection |

## Fitting Methods

- **`:bayesian`** — NUTS sampler (Turing.jl) with truncated-Normal priors on all
  four parameters. Each MCMC step simulates the Lorenz ODE, so sampling is slow.

## Examples

### Create and Simulate

```julia
using HeartRateLab

# Standard chaotic parameters
lorenz = Lorenz()                              # defaults: σ=10, ρ=28, β=8/3, threshold=10
lorenz_custom = Lorenz(σ=10.0, ρ=28.0, β=8/3, threshold=12.0)

params = (σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
ibis = simulate(lorenz, params, 200)

using Statistics
println("Mean IBI: ", mean(ibis), " ms")
println("SDNN: ", std(ibis), " ms")
```

### Visualize the Lorenz Trajectory

The full 3D trajectory (not just the IBIs) can be retrieved for visualization.
This requires DifferentialEquations.jl to be loaded.

```julia
using HeartRateLab

params = (σ=10.0, ρ=28.0, β=8/3)
sol = HeartRateLab.Models.simulate_lorenz_trajectory(params; duration=50.0)

# sol is a DifferentialEquations solution object
# sol[1, :] → x-coordinates
# sol[2, :] → y-coordinates
# sol[3, :] → z-coordinates

# Example: plot with Plots.jl or GLMakie
# plot(sol[1,:], sol[2,:], sol[3,:])  # 3D butterfly attractor
```

### Bayesian Fit

```julia
using HeartRateLab

lorenz = Lorenz()
ibis = read_txt("data.txt")

result = fit(lorenz, ibis; method=:bayesian, chains=4, samples=500)

println("Fitted σ: ", result.params.σ)
println("Fitted ρ: ", result.params.ρ)
println("Fitted β: ", result.params.β)
println("Fitted threshold: ", result.params.threshold)

# Check convergence (R-hat < 1.1 indicates convergence)
println("R-hat σ: ", result.diagnostics["rhat_sigma"])
println("R-hat ρ: ", result.diagnostics["rhat_rho"])
```

## API Reference

```@docs
Lorenz
parameter_space(::Lorenz)
simulate(::Lorenz, ::NamedTuple, ::Int)
fit(::Lorenz, ::Vector{Float64})
```
````

**Step 2: Commit**

```bash
git add docs/src/models/lorenz.md
git commit -m "docs: add Lorenz chaotic attractor documentation page"
```

---

## Task 8: Create `docs/src/models/dmd.md`

**Files:**
- Create: `docs/src/models/dmd.md`

**Step 1: Write the file**

````markdown
# [Dynamic Mode Decomposition (DMD)](@id dmd-page)

```@meta
CurrentModule = HeartRateLab
```

DMD is a purely data-driven spectral method. It decomposes an IBI time series into
spatial modes and temporal eigenvalues, then uses them to reconstruct or forecast the
signal. No mechanistic model of the heart is assumed.

## Theory

### Hankel Embedding

A scalar IBI series $\mathbf{x} = [x_1, x_2, \ldots, x_n]$ is lifted into a
data matrix via **delay embedding** (Hankel matrix):

$$X = \begin{bmatrix}
  x_1 & x_2 & \cdots & x_{n-m} \\
  x_2 & x_3 & \cdots & x_{n-m+1} \\
  \vdots & & & \vdots \\
  x_m & x_{m+1} & \cdots & x_n
\end{bmatrix}$$

where $m = \lfloor n/2 \rfloor$ is the embedding dimension.

### SVD Truncation and DMD Operator

The matrix is split into shifted snapshots $X_1 = X[:, 1\!:\!end\!-\!1]$ and
$X_2 = X[:, 2\!:\!end]$. DMD finds the best-fit linear operator $A$ such that
$X_2 \approx A X_1$.

Using a rank-$r$ SVD of $X_1$:

$$X_1 \approx U_r \Sigma_r V_r^T$$

The reduced operator $\tilde{A} = U_r^T X_2 V_r \Sigma_r^{-1}$ is computed,
then diagonalized:

$$\tilde{A} W = W \Lambda$$

The **dynamic modes** are $\Phi = X_2 V_r \Sigma_r^{-1} W$ and the
**eigenvalues** are $\lambda_i$ (diagonal of $\Lambda$).

### Reconstruction

$$x(t) \approx \sum_{i=1}^{r} a_i \, \phi_i \, \lambda_i^{t-1}$$

where $a_i$ are mode amplitudes fitted by least squares. The rank $r$ controls
how many modes contribute:

- **Low rank (r = 2–3):** Captures dominant oscillatory trends only.
- **Moderate rank (r = 5):** Balances fidelity and generalization (default).
- **High rank (r = 10+):** Closely reproduces the training signal; may not generalize.

## Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `rank` | 1 – ⌊n/2⌋ | 5 | SVD truncation rank (number of modes) |

DMD has no `parameter_space` — it is not a parametric model. The decomposition
adapts entirely to the input data.

## Workflow

DMD must be **fitted before simulating**. The `fit` call decomposes the data;
`simulate` reconstructs from the learned modes.

```
DMD(rank=5)  →  fit(dmd, ibis)  →  simulate(result.model, nothing, n)
```

## Examples

### Fit and Reconstruct

```julia
using HeartRateLab

ibis = read_txt("data.txt")

dmd = DMD(rank=5)
result = fit(dmd, ibis)

println("Rank used: ", result.diagnostics["rank"])
println("Reconstruction error: ", result.diagnostics["reconstruction_error"])

# Reconstruct the training signal
reconstructed = simulate(result.model, nothing, length(ibis))
```

### Effect of Rank on Reconstruction

Higher rank captures more signal detail but may overfit short recordings.

```julia
using HeartRateLab

ibis = read_txt("data.txt")

for r in [2, 5, 10, 20]
    result = fit(DMD(rank=r), ibis)
    recon  = simulate(result.model, nothing, length(ibis))
    rmse   = sqrt(sum((ibis .- recon).^2) / length(ibis))
    println("rank=$r  RMSE=$(round(rmse; digits=2)) ms")
end
```

## API Reference

```@docs
DMD
fit(::DMD, ::Vector{Float64})
simulate(::DMD, ::Union{NamedTuple, Nothing}, ::Int)
```
````

**Step 2: Commit**

```bash
git add docs/src/models/dmd.md
git commit -m "docs: add DMD documentation page"
```

---

## Task 9: Create `docs/src/models/extending.md`

**Files:**
- Create: `docs/src/models/extending.md`

**Step 1: Write the file**

````markdown
# Extending: Adding Your Own Model

```@meta
CurrentModule = HeartRateLab
```

HeartRateLab's model system is designed for easy extension. Any struct that inherits
from `AbstractHRVModel` and implements `simulate` integrates automatically with
`simulate_ensemble`, `extract_ensemble_features`, and the evaluation pipeline.

## Minimal Implementation

### Step 1: Define a struct

```julia
using HeartRateLab

struct GaussianIBI <: AbstractHRVModel
    mean_ibi::Float64   # Mean IBI in milliseconds
    std_ibi::Float64    # Standard deviation in milliseconds
end

GaussianIBI(; mean_ibi=800.0, std_ibi=50.0) = GaussianIBI(mean_ibi, std_ibi)
```

### Step 2: Implement `simulate`

The only required method. Must return a `Vector{Float64}` of IBIs in milliseconds.

```julia
using HeartRateLab, Random

function HeartRateLab.simulate(model::GaussianIBI, params::NamedTuple, n_beats::Int)
    μ = get(params, :mean_ibi, model.mean_ibi)
    σ = get(params, :std_ibi, model.std_ibi)
    ibis = randn(n_beats) .* σ .+ μ
    # Clip to physiological range
    return clamp.(ibis, 300.0, 2000.0)
end
```

### Step 3: (Optional) Implement `parameter_space`

Required if you want Bayesian fitting to work:

```julia
using Distributions

function HeartRateLab.parameter_space(model::GaussianIBI)
    return (
        mean_ibi = (
            lower = 300.0,
            upper = 2000.0,
            prior = truncated(Normal(800.0, 100.0), 300.0, 2000.0)
        ),
        std_ibi = (
            lower = 1.0,
            upper = 200.0,
            prior = Exponential(50.0)
        )
    )
end
```

### Step 4: Use it

Once `simulate` is defined, the model works with the full ecosystem:

```julia
model = GaussianIBI(mean_ibi=820.0, std_ibi=45.0)
params = (mean_ibi=820.0, std_ibi=45.0)

# Simulate
ibis = simulate(model, params, 500)

# Use in ensemble evaluation
ensemble = simulate_ensemble(model, params, 500; n_sim=100)
features = extract_ensemble_features(ensemble)
```

## Interface Checklist

| Item | Required? | Notes |
|------|-----------|-------|
| `struct MyModel <: AbstractHRVModel` | ✓ | Any fields you need |
| Default keyword constructor `MyModel(; ...)` | Recommended | Makes API ergonomic |
| `simulate(::MyModel, params, n_beats) -> Vector{Float64}` | ✓ | IBIs in ms |
| `parameter_space(::MyModel) -> NamedTuple` | For `:bayesian` fit | Bounds + priors |
| `fit(::MyModel, data; method, ...)` | Optional | Use Optim.jl / Turing.jl |

## Implementing `fit`

For gradient-based fitting, minimize a distance between real and simulated features:

```julia
using Optim, Statistics

function HeartRateLab.fit(model::GaussianIBI, data::Vector{Float64};
                          method::Symbol=:gradient, kwargs...)
    function loss(x)
        params = (mean_ibi=x[1], std_ibi=x[2])
        synthetic = simulate(model, params, length(data))
        return (mean(synthetic) - mean(data))^2 + (std(synthetic) - std(data))^2
    end

    x0     = [model.mean_ibi, model.std_ibi]
    lower  = [300.0, 1.0]
    upper  = [2000.0, 200.0]
    result = optimize(loss, lower, upper, x0, Fminbox(LBFGS()))

    params_map = (mean_ibi=result.minimizer[1], std_ibi=result.minimizer[2])
    diagnostics = Dict("converged" => Optim.converged(result),
                       "loss_final" => result.minimum)

    return ModelFitResult(model, :gradient, params_map, nothing, diagnostics, data)
end
```

## Notes

- Always dispatch on the `HeartRateLab` namespace (e.g., `HeartRateLab.simulate`)
  when defining methods outside the package to avoid method ambiguity.
- IBIs must be in **milliseconds**. All features, evaluation, and comparisons assume ms.
- Physiological bounds (300–2000 ms) should be enforced in `simulate` to prevent
  downstream evaluation failures.
````

**Step 2: Commit**

```bash
git add docs/src/models/extending.md
git commit -m "docs: add guide for implementing custom HRV models"
```

---

## Task 10: Fix `@docs` Dispatch Signatures

**Context:** Documenter.jl `@docs` blocks need exact method signatures when there are
multiple methods with the same name. The generic `fit` and `simulate` are overloaded;
we need to specify the correct type signatures.

**Step 1: Verify the actual exported signatures**

Check `src/Models/LIF.jl`, `VanDerPol.jl`, `Lorenz.jl`, `DMD.jl`:

- `fit(model::LIF, data::Vector{Float64}; ...)` → `fit(::LIF, ::Vector{Float64})`
- `simulate(model::LIF, params::NamedTuple, n_beats::Int)` → `simulate(::LIF, ::NamedTuple, ::Int)`
- `fit(model::DMD, data::Vector{Float64}; ...)` → `fit(::DMD, ::Vector{Float64})`
- `simulate(model::DMD, params::Union{NamedTuple,Nothing}, n_beats::Int)` → `simulate(::DMD, ::Union{NamedTuple, Nothing}, ::Int)`

**Step 2: In each model's .md file, ensure `@docs` uses the correct module path**

If `@docs` can't resolve `fit(::LIF, ...)`, use fully qualified:

```
@docs
HeartRateLab.Models.fit(::LIF, ::Vector{Float64})
```

Or use the `CurrentModule = HeartRateLab.Models` meta tag on a model-specific page.

**Step 3: Update meta tag in each model .md if needed**

If docstring resolution fails, change the `@meta` block in each model page from:
```
CurrentModule = HeartRateLab
```
to:
```
CurrentModule = HeartRateLab.Models
```

This step may require iteration after testing the build in Task 11.

---

## Task 11: Build and Validate Docs

**Files:** No new files.

**Step 1: Install docs dependencies**

```bash
julia --project=docs/ -e 'using Pkg; Pkg.instantiate()'
```

**Step 2: Run the docs build**

```bash
julia --project=docs/ docs/make.jl
```

**Expected output:**
```
[ Info: SetupBuildDirectory: setting up build directory.
[ Info: Doctest: running doctests.
[ Info: ExpandTemplates: expanding markdown templates.
...
[ Info: HTMLWriter: rendering HTML pages.
[ Info: Success
```

**Step 3: Triage any errors**

Common issues:
- `@docs` block references unresolvable symbol → fix `CurrentModule` or use full path
- `@doctest` block fails → check exact output format expected
- Missing page in `make.jl` sidebar → add to `pages` array

**Step 4: Fix issues iteratively**

For each error:
1. Identify the failing block and file
2. Fix the specific error
3. Re-run `julia --project=docs/ docs/make.jl`
4. Commit when clean

**Step 5: Final commit**

```bash
git add docs/src/models/
git commit -m "docs: complete model documentation — all 7 pages, docs build clean"
```

---

## Summary

| Task | Files | Commit |
|------|-------|--------|
| 1 | `src/Models/LIF.jl` | `feat: LIF() keyword constructor` |
| 2 | `docs/make.jl`, rm `docs/src/models.md` | `docs: restructure Models section` |
| 3 | `docs/src/models/index.md` | `docs: models overview page` |
| 4 | `docs/src/models/framework.md` | `docs: Models framework page` |
| 5 | `docs/src/models/lif.md` | `docs: LIF page` |
| 6 | `docs/src/models/vanderpol.md` | `docs: Van der Pol page` |
| 7 | `docs/src/models/lorenz.md` | `docs: Lorenz page` |
| 8 | `docs/src/models/dmd.md` | `docs: DMD page` |
| 9 | `docs/src/models/extending.md` | `docs: extending guide` |
| 10 | Various (fix @docs signatures) | included in per-page commits |
| 11 | — | `docs: complete model documentation` |
