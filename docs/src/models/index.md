```@meta
CurrentModule = HeartRateLab
```

# Heart Rate Variability Models

HeartRateLab provides four models for synthesizing and analyzing inter-beat interval (IBI)
time series. Two are mechanistic (grounded in physiology or physics), one is chaotic
(deterministic but sensitive to initial conditions), and one is purely data-driven.

| Model | Type | Fit Methods |
|-------|------|-------------|
| [LIF](@ref lif-page) | Mechanistic ODE — cardiac pacemaker | `:analytical`, `:gradient`, `:bayesian` |
| [Van der Pol](@ref vdp-page) | Mechanistic ODE — nonlinear oscillator | `:gradient`, `:bayesian` |
| [Lorenz](@ref lorenz-page) | Chaotic ODE — butterfly attractor | `:bayesian` |
| [DMD](@ref dmd-page) | Data-driven — spectral decomposition | SVD (no fitting methods) |

## Shared Interface

All models implement a common interface via [`AbstractHRVModel`](@ref):

```julia
# Create a model
model = LIF()           # or VanDerPol(), Lorenz(), DMD(rank=5)

# Fit to IBI data (milliseconds)
result = fit(model, ibis; method=:gradient)

# Generate synthetic IBIs
synthetic = simulate(result.model, result.params, 500)
```

See [Framework](@ref framework-page) for the full interface specification, including
how `ModelFitResult` stores fitted parameters, posteriors, and diagnostics.

## API Reference

```@docs
AbstractHRVModel
ModelFitResult
```
