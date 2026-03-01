```@meta
CurrentModule = HeartRateLab
```

# [Model Framework](@id framework-page)

All HRV models in HeartRateLab inherit from `AbstractHRVModel` and share a unified API
for simulation, parameter fitting, and evaluation.

## AbstractHRVModel Interface

Every model must implement `simulate`. The `fit` and `parameter_space` methods are
optional — only models that support parameter inference implement them.

```julia
# Required for all models
simulate(model::AbstractHRVModel, params::NamedTuple, n_beats::Int) -> Vector{Float64}

# Optional — models that support fitting
fit(model::AbstractHRVModel, data::Vector{Float64}; method::Symbol, kwargs...) -> ModelFitResult
parameter_space(model::AbstractHRVModel) -> NamedTuple
```

`simulate` always returns a `Vector{Float64}` of IBI values in **milliseconds**.
`params` is a `NamedTuple` of parameter values passed to the simulator;
each model defines which keys it reads.

## ModelFitResult

`fit` returns a `ModelFitResult` containing:

| Field | Type | Description |
|-------|------|-------------|
| `model` | `AbstractHRVModel` | The model that was fitted |
| `method` | `Symbol` | Fitting method: `:analytical`, `:gradient`, or `:bayesian` |
| `params` | `NamedTuple` | Point estimates (MAP for Bayesian, minimizer for gradient, mean for analytical) |
| `posterior` | `Dict` or `nothing` | Posterior samples (Bayesian) or per-beat series (analytical); `nothing` for gradient |
| `diagnostics` | `Dict{String,Any}` | Convergence info, iterations, loss, R-hat values, etc. |
| `data` | `Vector{Float64}` | Original IBI data used for fitting (milliseconds) |

```@doctest
julia> using HeartRateLab

julia> vdp = VanDerPol()
VanDerPol()

julia> typeof(vdp) <: AbstractHRVModel
true
```

## Fitting Methods

### `:analytical`

Available on `LIF` only. Inverts the closed-form period formula for each measured IBI
individually, yielding a per-beat current $I$ series. Instantaneous — no simulation or
optimization is needed.

```julia
result = fit(LIF(), ibis; method=:analytical)
result.params.I          # mean I across all beats
result.posterior["I"]    # Vector{Float64} of per-beat I values (same length as ibis)
result.diagnostics["I_std"]  # standard deviation of per-beat I
```

### `:gradient`

Minimizes a distance function (RMSE or feature-space distance) using gradient-free or
gradient-based optimization via Optim.jl. Returns a scalar point estimate per parameter.

```julia
result = fit(VanDerPol(), ibis; method=:gradient)
result.params.μ                   # fitted μ
result.diagnostics["converged"]   # Bool
result.diagnostics["iterations"]  # Int
result.diagnostics["loss_final"]  # Float64
result.posterior                  # nothing
```

### `:bayesian`

NUTS MCMC sampler via Turing.jl. Samples the full posterior distribution over parameters.
Requires more computation but provides uncertainty estimates.

```julia
result = fit(LIF(), ibis; method=:bayesian, chains=4, samples=1000)
result.params.I               # posterior mean of I
result.posterior["I"]         # Vector of 4000 MCMC samples
result.diagnostics["rhat_I"]  # R-hat convergence statistic (target: < 1.1)
```

## Accessing Posterior Samples

Use `parameter_series` to retrieve per-beat series or posterior samples from a fit result:

```julia
# Analytical fit: per-beat I series
result = fit(LIF(), ibis; method=:analytical)
I_series = parameter_series(result, :I)   # Vector{Float64}, one value per beat

# Bayesian fit: MCMC posterior samples
result_bayes = fit(LIF(), ibis; method=:bayesian)
I_samples = parameter_series(result_bayes, :I)  # Vector{Float64}, MCMC samples

# Gradient fit: returns nothing (no distribution)
result_grad = fit(LIF(), ibis; method=:gradient)
parameter_series(result_grad, :I)  # nothing
```

## API Reference

```@docs
AbstractHRVModel
ModelFitResult
parameter_series
```
