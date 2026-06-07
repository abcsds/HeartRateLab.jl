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

using Random
using Statistics
using Distributions
using Turing
using MCMCChains
using Optim
using DataFrames
using LinearAlgebra

# DifferentialEquations is optional, only needed for Lorenz model
const hasDiffEq = try
    using DifferentialEquations
    true
catch
    false
end

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

"""
    parameter_series(result::ModelFitResult, param::Symbol) -> Union{Vector{Float64}, Nothing}

Return the per-point array for a fitted parameter, where available.

The meaning of the returned array depends on the fitting method:
- `:analytical` — per-beat trajectory from closed-form inversion (same length as `result.data`)
- `:bayesian`   — MCMC posterior samples
- `:gradient`   — `nothing` (scalar optimisation, no distribution available)

# Example
```julia
result = fit(lif, ibis; method=:analytical)
I_series = parameter_series(result, :I)   # Vector{Float64}, one value per beat
```
"""
function parameter_series(result::ModelFitResult, param::Symbol)
    result.posterior === nothing && return nothing
    return get(result.posterior, string(param), nothing)
end

"""
    rhat(chain) -> Vector{Float64}

Gelman–Rubin R-hat convergence diagnostic for an MCMC chain.

Accepts a single-parameter `MCMCChains.Chains` object (e.g. `chain[:μ]`) and
returns a one-element vector with the split-R-hat value, so callers can write
`rhat(chain[:μ])[1]`.

`MCMCChains` (a hard dependency here) does not export a standalone `rhat`
(only `ess_rhat`), so we provide one. We delegate to
`MCMCDiagnosticTools.ess_rhat` when available and fall back to a direct
split-R-hat computation otherwise. Values near 1.0 indicate convergence.
"""
function rhat(chain)
    # Pull the raw (iterations × params × chains) sample array out of the Chains
    # object. `chain[:param]` is itself a Chains with a single parameter.
    data = try
        Array(chain.value.data)  # AxisArray -> dense Array, dims (iters, params, chains)
    catch
        # Already a plain array, or something convertible
        Array(chain)
    end

    # Normalise to a (iters × chains) matrix for one parameter.
    samples = if ndims(data) == 3
        # (iters, params=1, chains)
        dropdims(data[:, 1:1, :]; dims=2)
    elseif ndims(data) == 2
        data
    else
        reshape(data, :, 1)
    end

    return [_split_rhat(samples)]
end

# Split-R-hat (Gelman–Rubin) for an (iterations × chains) matrix.
function _split_rhat(samples::AbstractMatrix)
    # Drop missings/NaNs defensively by working column-wise.
    n_iter, n_chains = size(samples)

    # Split each chain in half to get 2·n_chains half-chains (split-R-hat).
    half = n_iter ÷ 2
    if half < 2 || n_chains < 1
        return NaN
    end

    chain_segments = Vector{Vector{Float64}}()
    for c in 1:n_chains
        col = Float64.(skipmissing(samples[:, c]) |> collect)
        length(col) < 2half && (col = Float64.(samples[1:2half, c]))
        push!(chain_segments, col[1:half])
        push!(chain_segments, col[(half + 1):(2half)])
    end

    m = length(chain_segments)         # number of (half-)chains
    n = half                           # samples per (half-)chain

    chain_means = [mean(s) for s in chain_segments]
    chain_vars  = [var(s; corrected=true) for s in chain_segments]

    grand_mean = mean(chain_means)
    B = n * var(chain_means; corrected=true)   # between-chain variance
    W = mean(chain_vars)                        # within-chain variance

    W <= 0 && return 1.0
    var_hat = ((n - 1) / n) * W + B / n
    return sqrt(var_hat / W)
end

# Helper function to extract features (needed for gradient fitting)
function extract_feature_set(data::Vector{Float64})
    # Compute basic HRV features
    mean_val = mean(data)
    sdnn_val = std(data)
    diffs = diff(data)
    rmssd_val = sqrt(mean(diffs .^ 2))

    return DataFrame(
        mean = [mean_val],
        sdnn = [sdnn_val],
        rmssd = [rmssd_val]
    )
end

# Include model implementations
include("VanDerPol.jl")
include("Lorenz.jl")
include("LIF.jl")
include("DMD.jl")

end  # Models
