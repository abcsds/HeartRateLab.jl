"""
    Models

Core types and interfaces for HRV modeling. This module provides the abstract interface
that all HRV models must implement, enabling a unified API for model simulation, fitting,
and evaluation.

## Model Interface

All HRV models inherit from `AbstractHRVModel` and must implement:

- `simulate(m::AbstractHRVModel, params::NamedTuple, n_beats::Int) -> Vector{Float64}`
  Returns an IBI series in milliseconds

Optional implementations:

- `fit(m::AbstractHRVModel, data::Vector{Float64}; method::Symbol=:bayesian, kwargs...)`
  Fits model parameters to data using specified method

- `parameter_space(m::AbstractHRVModel) -> NamedTuple`
  Returns (param_name = (lower, upper, prior_distribution), ...)
"""
module Models

"""
    AbstractHRVModel

Abstract base type for all HRV models (mechanistic, data-driven, or spectral).

All models must implement at minimum:
- `simulate(model::AbstractHRVModel, params::NamedTuple, n_beats::Int)::Vector{Float64}`

Models may optionally implement:
- `fit(model::AbstractHRVModel, data::Vector{Float64}; method::Symbol, kwargs...)`
- `parameter_space(model::AbstractHRVModel)`
"""
abstract type AbstractHRVModel end

"""
    ModelFitResult

Result of fitting an HRV model to data. Stores both point estimates and uncertainty information.

# Fields
- `model::AbstractHRVModel`: The model type that was fitted
- `method::Symbol`: Fitting method used (`:bayesian`, `:gradient`, or `:evolutionary`)
- `params::NamedTuple`: Point estimate of parameters (MAP/MLE for Bayesian, best individual otherwise)
- `posterior`: Posterior samples for Bayesian fitting (Turing.Chain), nothing otherwise
- `diagnostics::Dict`: Convergence info, iteration count, loss history, etc.
- `data::Vector{Float64}`: Original IBI data used for fitting (in milliseconds)

# Fitting Methods

- `:bayesian`: Markov Chain Monte Carlo via Turing.jl, produces full posterior over parameters
- `:gradient`: Gradient-based optimization via Optim.jl, minimizes feature-space distance
- `:evolutionary`: Evolutionary algorithm via BlackBoxOptim.jl or Evolutionary.jl, non-differentiable models

# Example

```julia
result = fit(LIF(), data; method=:bayesian)
posterior_samples = result.posterior  # Turing.Chain
point_estimate = result.params       # NamedTuple of parameter values
simulated = simulate(result.model, point_estimate, 100)  # Generate synthetic data
```
"""
struct ModelFitResult
    model::AbstractHRVModel
    method::Symbol  # :bayesian, :gradient, or :evolutionary
    params::NamedTuple  # Point estimate (MAP/MLE or best individual)
    posterior  # Turing.Chain for Bayesian, nothing otherwise
    diagnostics::Dict  # convergence status, iterations, loss history, etc.
    data::Vector{Float64}  # Original data used for fitting
end

end  # Models
