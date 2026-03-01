```@meta
CurrentModule = HeartRateLab
```

# [Van der Pol Oscillator](@id vdp-page)

The Van der Pol oscillator is a nonlinear self-sustaining oscillator originally
developed to model vacuum tube circuits (van der Pol, 1926). Its limit-cycle
dynamics bear structural similarities to cardiac rhythm generation.

## Theory

The Van der Pol system is governed by a second-order ODE, written as two first-order
equations:

```math
\frac{dV}{dt} = W
```

```math
\frac{dW}{dt} = \mu(1 - V^2)W - V
```

The nonlinear damping term $\mu(1 - V^2)$ acts as **negative damping** near $V = 0$
(amplifying small oscillations) and **positive damping** far from $V = 0$
(suppressing large excursions). This produces a **limit cycle** — a stable closed
orbit that trajectories converge to regardless of initial conditions.

### Effect of μ

The parameter $\mu$ controls the character of the oscillation:

| μ range | Oscillation type | HRV analogy |
|---------|-----------------|-------------|
| 0.1 – 1.0 | Near-sinusoidal, weakly nonlinear | Regular, low-variability rhythm |
| 1.5 – 2.5 | Strong relaxation oscillations | Normal cardiac range |
| > 3.0 | Sharp peaks with slow recovery | Extreme nonlinearity |

### IBI Generation

The simulation scales the oscillation period to the desired `heart_rate` (in BPM),
with $\mu$ controlling the amplitude and shape of beat-to-beat modulation. The mean
IBI is $60000 / \text{heart\_rate}$ ms.

## Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `μ` | 0.1 – 3.0 | 1.0 | Nonlinearity; controls oscillation strength |
| `heart_rate` | 40 – 120 BPM | 70 | Base heart rate in beats per minute |

## Fitting Methods

| Method | Algorithm | Loss function |
|--------|-----------|---------------|
| `:gradient` | LBFGS with box constraints (Optim.jl) | Normalized feature-space distance over `mean`, `sdnn`, `rmssd` |
| `:bayesian` | NUTS MCMC (Turing.jl) | Likelihood: $\text{IBI} \sim \mathcal{N}(\hat{\text{IBI}}, \sigma)$ |

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

println("Fitted μ:          ", round(result.params.μ; digits=3))
println("Fitted heart rate: ", round(result.params.heart_rate; digits=1), " bpm")
println("Converged:         ", result.diagnostics["converged"])

# Generate synthetic
synthetic = simulate(result.model, result.params, length(ibis))
```

### Fit with Bayesian Inference

```julia
using HeartRateLab

vdp = VanDerPol()
ibis = read_txt("data.txt")

result = fit(vdp, ibis; method=:bayesian, chains=4, samples=1000)

println("Posterior mean μ:          ", round(result.params.μ; digits=3))
println("Posterior mean heart rate: ", round(result.params.heart_rate; digits=1), " bpm")
println("R-hat μ:                   ", round(result.diagnostics["rhat_mu"]; digits=3))

# Posterior samples
μ_samples = parameter_series(result, :μ)
```

## API Reference

```@docs
VanDerPol
parameter_space(::VanDerPol)
simulate(::VanDerPol, ::NamedTuple, ::Int)
fit(::VanDerPol, ::Vector{Float64})
```
