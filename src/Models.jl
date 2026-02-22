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
using Distributions
using DifferentialEquations
using Turing
using Optim

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
    VanDerPol <: AbstractHRVModel

Van der Pol oscillator model for HRV simulation.
Simple mechanistic model for cardiac oscillations.
"""
struct VanDerPol <: AbstractHRVModel end

"""
    simulate(model::VanDerPol, params::NamedTuple, n_beats::Int) -> Vector{Float64}

Simulate IBI time series using Van der Pol oscillator.

# Parameters
- `μ`: Non-linearity parameter (amplitude of oscillation)
- `heart_rate`: Base heart rate in BPM

# Returns
Vector of inter-beat intervals in milliseconds
"""
function simulate(model::VanDerPol, params::NamedTuple, n_beats::Int)::Vector{Float64}
    # Extract parameters with defaults
    μ = get(params, :μ, 0.5)  # Non-linearity
    hr = get(params, :heart_rate, 70)  # Heart rate in BPM

    # Mean IBI in milliseconds
    mean_ibi = 60000 / hr

    # Generate oscillatory modulation
    time = range(0, 4π, length=n_beats)

    # Van der Pol oscillation: x'' + μ(x² - 1)x' + x = 0
    # Use simple harmonic approximation with modulation
    modulation = 1.0 .+ 0.3 .* μ .* sin.(time) .+ 0.1 .* μ .* cos.(2 .* time)

    # Generate IBI with physiological constraints
    ibi = mean_ibi .* modulation

    # Add small random noise
    noise = randn(n_beats) .* (0.01 * mean_ibi)
    ibi = ibi .+ noise

    # Ensure physiological bounds (300-2000 ms typical)
    ibi = max.(ibi, 300)
    ibi = min.(ibi, 2000)

    return ibi
end

"""
    parameter_space(model::VanDerPol) -> NamedTuple

Return the parameter space for Van der Pol model with priors for Bayesian fitting.

# Returns
NamedTuple with keys: `μ`, `heart_rate`, `σ_noise`
Each parameter has: `lower`, `upper`, `prior` (TruncatedNormal or Exponential)
"""
function parameter_space(model::VanDerPol)
    return (
        μ = (
            lower = 0.1,
            upper = 3.0,
            prior = TruncatedNormal(1.0, 0.5, 0.1, 3.0)
        ),
        heart_rate = (
            lower = 40.0,
            upper = 120.0,
            prior = TruncatedNormal(70.0, 15.0, 40.0, 120.0)
        ),
        σ_noise = (
            lower = 1.0,
            upper = 50.0,
            prior = Exponential(10.0)
        )
    )
end

"""
    fit(model::VanDerPol, data::Vector{Float64}; method=:bayesian, kwargs...) -> ModelFitResult

Fit Van der Pol model to IBI data using Bayesian or gradient-based optimization.

# Arguments
- `model::VanDerPol`: Van der Pol model instance
- `data::Vector{Float64}`: IBI time series in milliseconds
- `method::Symbol`: `:bayesian` (NUTS MCMC) or `:gradient` (LBFGS)
- `chains::Int`: Number of MCMC chains (default: 4, for Bayesian only)
- `samples::Int`: Samples per chain (default: 1000, for Bayesian only)

# Returns
`ModelFitResult` with posterior samples, MAP estimates, and diagnostics
"""
function fit(model::VanDerPol, data::Vector{Float64};
             method::Symbol=:bayesian,
             chains::Int=4,
             samples::Int=1000,
             kwargs...)

    if method == :bayesian
        # Define Turing model for Bayesian inference
        @model function vanderpol_model(ibi_data)
            n_beats = length(ibi_data)

            # Priors
            μ ~ TruncatedNormal(1.0, 0.5, 0.1, 3.0)
            heart_rate ~ TruncatedNormal(70.0, 15.0, 40.0, 120.0)
            σ_noise ~ Exponential(10.0)

            # Simulate model with these parameters
            params = (μ=μ, heart_rate=heart_rate)
            predicted_ibi = simulate(model, params, n_beats)

            # Likelihood: observed IBIs ~ predicted IBIs with Gaussian noise
            ibi_data ~ MvNormal(predicted_ibi, σ_noise)
        end

        # Fit using NUTS sampler with threading
        turing_model = vanderpol_model(data)
        chain = sample(turing_model, NUTS(0.65), MCMCThreads(),
                      samples, chains, progress=true)

        # Extract MAP estimates (posterior mean)
        params_map = (
            μ = mean(chain[:μ]),
            heart_rate = mean(chain[:heart_rate])
        )

        # Extract diagnostics
        diagnostics = Dict(
            "method" => "NUTS (Turing.jl)",
            "chains" => chains,
            "samples_per_chain" => samples,
            "total_samples" => samples * chains,
            "rhat_mu" => rhat(chain[:μ])[1],
            "rhat_heart_rate" => rhat(chain[:heart_rate])[1],
            "rhat_sigma_noise" => rhat(chain[:σ_noise])[1]
        )

        # Extract posterior samples as dict
        posterior = Dict(
            "μ" => vec(chain[:μ]),
            "heart_rate" => vec(chain[:heart_rate]),
            "σ_noise" => vec(chain[:σ_noise])
        )

        return ModelFitResult(
            model,
            :bayesian,
            params_map,
            posterior,
            diagnostics,
            data
        )

    elseif method == :gradient
        error("Gradient fitting not yet implemented for VanDerPol. Use method=:bayesian")

    else
        error("Unknown fitting method: $method. Use :bayesian or :gradient")
    end
end

end  # Models
