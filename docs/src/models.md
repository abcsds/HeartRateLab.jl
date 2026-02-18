# Heart Rate Variability Models

HeartRateLab provides **4 mechanistic and data-driven models** for HRV synthesis and analysis:

1. **LIF** (Leaky Integrate-and-Fire) - Stochastic neuron model
2. **Van der Pol** - Deterministic oscillator
3. **Lorenz** - Chaotic attractor
4. **DMD** (Dynamic Mode Decomposition) - Data-driven spectral method

## Model Interface

All models conform to the `AbstractHRVModel` interface with two key methods:

### `simulate(model, params, n_beats)`
Generate synthetic IBI time series from model parameters.

**Arguments:**
- `model` - AbstractHRVModel instance
- `params` - NamedTuple with model parameters
- `n_beats` - Number of beats to generate

**Returns:**
- `Vector{Float64}` - Inter-beat-intervals in milliseconds

### `fit(model, data; method=:gradient, kwargs...)`
Fit model parameters to real IBI data.

**Arguments:**
- `model` - AbstractHRVModel instance
- `data` - Real IBI time series
- `method` - Fitting method (`:gradient` for most models)
- `kwargs...` - Method-specific options

**Returns:**
- `ModelFitResult` - Fitted model with parameters and diagnostics

## 1. LIF (Leaky Integrate-and-Fire)

Stochastic spiking neuron model generating IBIs through threshold-crossing dynamics.

### Model Equations

```
dV/dt = (V_rest - V + I_base) / τ + noise
```

When V ≥ threshold: spike event (heartbeat) + reset to V_rest

### Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `τ` | 1-100 ms | 50 | Membrane time constant |
| `I_base` | 0.1-2.0 | 0.5 | Baseline input current (firing rate) |
| `threshold` | 0.1-3.0 V | 1.0 | Spike threshold |
| `noise_amp` | 0.01-1.0 | 0.1 | Stochastic noise amplitude |

### Usage

```julia
using HeartRateLab, DifferentialEquations

# Create model
lif = LIF(τ=50, I_base=0.5, threshold=1.0, noise_amp=0.1)

# Fit to data
ibis = read_txt("data.txt")
result = fit(lif, ibis; method=:gradient, max_iter=1000)

# Generate synthetic data
synthetic = simulate(result.model, result.params, n_beats=1000)

# Check convergence
println("Converged: $(result.diagnostics["converged"])")
println("Final loss: $(result.diagnostics["loss_final"])")
```

## 2. Van der Pol Oscillator

Deterministic nonlinear oscillator with self-sustaining oscillations and adjustable damping.

### Model Equations

```
dV/dt = W
dW/dt = μ(1 - V²)W - V
```

### Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `μ` | 0.5-3.0 | 1.5 | Non-linearity (damping strength) |
| `heart_rate` | 40-150 BPM | 70 | Target heart rate for time scaling |

### Behavior

- **Small μ (0.5-1.0)**: Nearly sinusoidal, weakly nonlinear
- **Moderate μ (1.5-2.5)**: Strong relaxation oscillations (cardiac range)
- **Large μ (>3.0)**: Sharp peaks with slow return (extreme nonlinearity)

### Usage

```julia
using HeartRateLab, DifferentialEquations

# Create model
vdp = VanDerPol(μ=1.5, heart_rate=70.0)

# Simulate
params = (μ=1.5, heart_rate=70.0)
ibis = simulate(vdp, params, n_beats=500)

# Fit to data
result = fit(vdp, real_ibis; method=:gradient)
```

## 3. Lorenz Attractor

3D chaotic system with sensitive dependence on initial conditions, generating complex HRV patterns.

### Model Equations

```
dX/dt = σ(Y - X)
dY/dt = X(ρ - Z) - Y
dZ/dt = XY - βZ
```

### Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `σ` | 5-15 | 10 | Rayleigh parameter (flow structure) |
| `ρ` | 20-40 | 28 | Convection parameter (chaos control) |
| `β` | 1-3 | 8/3 | Dissipation parameter |
| `threshold` | 0-50 | 10 | Z-crossing detection threshold |

### Behavior

- **ρ < 24.7**: Stable fixed point (no oscillation)
- **ρ = 28**: Standard chaotic behavior (cardiac modeling)
- **ρ > 40**: Complex chaotic regime with extreme sensitivity

### Usage

```julia
using HeartRateLab, DifferentialEquations

# Create model (standard chaotic parameters)
lorenz = Lorenz(σ=10.0, ρ=28.0, β=8/3, threshold=10.0)

# Simulate chaotic HRV
params = (σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
chaotic_ibis = simulate(lorenz, params, n_beats=500)

# Fit to data
result = fit(lorenz, real_ibis; method=:gradient)
```

## 4. DMD (Dynamic Mode Decomposition)

Data-driven spectral method decomposing IBI time series into spatial modes and temporal dynamics.

### Method Overview

DMD decomposes the time series into:
- **Spatial modes** (wᵢ) - Eigenmodes capturing oscillatory patterns
- **Temporal dynamics** (λᵢ) - Eigenvalues controlling evolution

Reconstruction: x(t) = Σᵢ aᵢ wᵢ λᵢᵗ

### Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `rank` | 1-n | 5 | Truncation rank for SVD |

Higher rank captures more detail but risks overfitting.

### Usage

```julia
using HeartRateLab, LinearAlgebra

# Create and fit DMD model
dmd = DMD(rank=5)
result = fit(dmd, ibis)

# Reconstruct/forecast
reconstructed = simulate(result, nothing, length(ibis))

# Different ranks capture different complexity
dmd_low = DMD(rank=2)
dmd_high = DMD(rank=10)

fit_low = fit(dmd_low, ibis)
fit_high = fit(dmd_high, ibis)

recon_low = simulate(fit_low, nothing, length(ibis))
recon_high = simulate(fit_high, nothing, length(ibis))
```

## Model Comparison

| Model | Type | Stochastic | Deterministic | Parameters | Fitting Method |
|-------|------|-----------|---------------|-----------|----------------|
| **LIF** | Mechanistic | ✓ | - | 4 | Gradient (Optim.jl) |
| **Van der Pol** | Mechanistic | - | ✓ | 2 | Gradient (Optim.jl) |
| **Lorenz** | Mechanistic | - | ✓ | 4 | Gradient (Optim.jl) |
| **DMD** | Data-driven | - | - | 1 (rank) | SVD decomposition |

## Workflow: Model Selection

```julia
using HeartRateLab
using DifferentialEquations
using GLMakie

ibis = read_txt("data.txt")

# Fit all models
lif = fit(LIF(), ibis; method=:gradient)
vdp = fit(VanDerPol(), ibis; method=:gradient)
lorenz = fit(Lorenz(), ibis; method=:gradient)
dmd = fit(DMD(rank=5), ibis)

# Generate synthetic data
lif_syn = simulate(lif.model, lif.params, length(ibis))
vdp_syn = simulate(vdp.model, vdp.params, length(ibis))
lorenz_syn = simulate(lorenz.model, lorenz.params, length(ibis))
dmd_syn = simulate(dmd.model, nothing, length(ibis))

# Compare visualizations
plot_comparison(ibis, lif_syn; model_name="LIF")
plot_comparison(ibis, vdp_syn; model_name="Van der Pol")
plot_comparison(ibis, lorenz_syn; model_name="Lorenz")
plot_comparison(ibis, dmd_syn; model_name="DMD")
```

## API Reference

```@autodocs
Modules = [HeartRateLab.Models]
Private = false
```

## References

- **Büzás et al. (2022)** - LIF model for HRV: IEEE Access, 10, 36606–36615
- **Lopez-Chamorro et al. (2018)** - Van der Pol: BIOINFORMATICS, 96–106
- **Esperer et al. (2008)** - Lorenz plots: Ann Noninvasive Electrocardiol, 13(1), 44–60
- **Schmid (2010)** - DMD: J Fluid Mech, 656, 5–28
