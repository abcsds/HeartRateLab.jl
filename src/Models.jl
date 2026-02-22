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
function simulate(model::VanDerPol, params::NamedTuple, n_beats::Int)
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
            prior = Distributions.truncated(Distributions.Normal(1.0, 0.5), 0.1, 3.0)
        ),
        heart_rate = (
            lower = 40.0,
            upper = 120.0,
            prior = Distributions.truncated(Distributions.Normal(70.0, 15.0), 40.0, 120.0)
        ),
        σ_noise = (
            lower = 1.0,
            upper = 50.0,
            prior = Distributions.Exponential(10.0)
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

            # Priors using truncated() function
            μ ~ Distributions.truncated(Distributions.Normal(1.0, 0.5), 0.1, 3.0)
            heart_rate ~ Distributions.truncated(Distributions.Normal(70.0, 15.0), 40.0, 120.0)
            σ_noise ~ Distributions.Exponential(10.0)

            # Simulate model with these parameters
            params = (μ=μ, heart_rate=heart_rate)
            predicted_ibi = simulate(model, params, n_beats)

            # Likelihood: observed IBIs ~ predicted IBIs with Gaussian noise
            ibi_data ~ Distributions.MvNormal(predicted_ibi, σ_noise)
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
            "total_samples" => samples * chains
        )
        # TODO: Add rhat diagnostics from MCMCDiagnosticTools when needed

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
        # Gradient-based optimization using feature-space distance minimization
        # Extract core features for fitting
        real_features = extract_feature_set(data)
        feature_names = ["mean", "sdnn", "rmssd"]

        # Define loss function: MSE of key HRV features
        function loss(params_vec)
            μ, heart_rate = params_vec

            # Simulate with current parameters
            params = (μ=μ, heart_rate=heart_rate)
            synthetic = simulate(model, params, length(data))

            # Extract features from synthetic
            synth_features = extract_feature_set(synthetic)

            # Compute normalized feature-space distance
            distance = 0.0
            for feat in feature_names
                real_val = real_features[!, feat][1]
                synth_val = synth_features[!, feat][1]
                # Avoid division by zero
                if real_val > 0
                    distance += ((real_val - synth_val) / real_val)^2
                else
                    distance += (real_val - synth_val)^2
                end
            end

            return distance
        end

        # Parameter bounds and initial guess
        x0 = [1.0, 70.0]  # Initial: μ=1.0, heart_rate=70 BPM
        lower = [0.1, 40.0]
        upper = [3.0, 120.0]

        # Optimize using LBFGS with box constraints
        result = optimize(loss, lower, upper, x0, Fminbox(LBFGS()))

        # Extract fitted parameters
        fitted_params = (
            μ = result.minimizer[1],
            heart_rate = result.minimizer[2]
        )

        # Create diagnostics
        diagnostics = Dict(
            "method" => "LBFGS",
            "converged" => Optim.converged(result),
            "iterations" => result.iterations,
            "loss_final" => result.minimum
        )

        return ModelFitResult(
            model,
            :gradient,
            fitted_params,
            nothing,  # No posterior for gradient-based fitting
            diagnostics,
            data
        )

    else
        error("Unknown fitting method: $method. Use :bayesian or :gradient")
    end
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

# ============================================================================
# Lorenz Oscillator Model for HRV Simulation
# ============================================================================

"""
    Lorenz <: AbstractHRVModel

Lorenz chaotic oscillator model for HRV simulation.
Generates complex, nonlinear cardiac dynamics through threshold crossings.

# Parameters
- `σ`: Prandtl number (typically ~10)
- `ρ`: Rayleigh number (controls chaos, typically ~28)
- `β`: Aspect ratio (typically 8/3)
- `threshold`: z-value threshold for IBI detection
"""
struct Lorenz <: AbstractHRVModel
    σ::Float64
    ρ::Float64
    β::Float64
    threshold::Float64
end

Lorenz(; σ=10.0, ρ=28.0, β=8/3, threshold=10.0) = Lorenz(σ, ρ, β, threshold)

"""
    parameter_space(model::Lorenz) -> NamedTuple

Return the parameter space for Lorenz model with priors for Bayesian fitting.
"""
function parameter_space(model::Lorenz)
    return (
        σ = (
            lower = 5.0,
            upper = 15.0,
            prior = TruncatedNormal(10.0, 2.0, 5.0, 15.0)
        ),
        ρ = (
            lower = 20.0,
            upper = 35.0,
            prior = TruncatedNormal(28.0, 3.0, 20.0, 35.0)
        ),
        β = (
            lower = 1.0,
            upper = 4.0,
            prior = TruncatedNormal(8/3, 0.5, 1.0, 4.0)
        ),
        threshold = (
            lower = 5.0,
            upper = 15.0,
            prior = TruncatedNormal(10.0, 2.0, 5.0, 15.0)
        ),
        σ_noise = (
            lower = 1.0,
            upper = 50.0,
            prior = Exponential(10.0)
        )
    )
end

"""
    simulate(model::Lorenz, params::NamedTuple, n_beats::Int) -> Vector{Float64}

Simulate IBI time series using Lorenz chaotic oscillator with threshold crossings.

# Parameters
- `σ`, `ρ`, `β`: Lorenz ODE parameters
- `threshold`: z-value threshold for detecting heartbeats

# Returns
Vector of inter-beat intervals in milliseconds
"""
function simulate(model::Lorenz, params::NamedTuple, n_beats::Int)::Vector{Float64}
    if !hasDiffEq
        error("Lorenz model requires DifferentialEquations.jl. Install with: Pkg.add(\"DifferentialEquations\")")
    end

    # Extract parameters
    σ = get(params, :σ, model.σ)
    ρ = get(params, :ρ, model.ρ)
    β = get(params, :β, model.β)
    threshold = get(params, :threshold, model.threshold)

    # Lorenz ODE system: dx/dt = σ(y-x), dy/dt = x(ρ-z)-y, dz/dt = xy - βz
    function lorenz!(du, u, p, t)
        σ, ρ, β = p
        du[1] = σ * (u[2] - u[1])
        du[2] = u[1] * (ρ - u[3]) - u[2]
        du[3] = u[1] * u[2] - β * u[3]
    end

    # Initial conditions
    u0 = [1.0, 1.0, 1.0]

    # Time span - solve for long enough to get enough beats
    # Empirically, about 200-300 time units gives ~50-100 beats
    tspan = (0.0, n_beats * 4.0)

    # Problem setup
    p = [σ, ρ, β]
    prob = ODEProblem(lorenz!, u0, tspan, p)

    # Solve with fine time resolution for accurate threshold detection
    sol = solve(prob, Tsit5(), saveat=0.01, dense=true)

    # Extract IBIs from z-coordinate threshold crossings
    z = sol[3, :]
    crossing_times = Float64[]

    # Find upward threshold crossings
    for i in 2:length(z)
        if z[i-1] < threshold && z[i] >= threshold
            push!(crossing_times, sol.t[i])
        end
    end

    # Compute IBIs (time intervals between crossings) in milliseconds
    if length(crossing_times) < 2
        error("Lorenz simulation: insufficient threshold crossings ($(length(crossing_times))). Try adjusting threshold parameter.")
    end

    ibis = diff(crossing_times) .* 1000  # Convert to ms

    # Ensure physiological bounds (300-2000 ms)
    ibis = max.(ibis, 300.0)
    ibis = min.(ibis, 2000.0)

    # Return requested number of IBIs
    if length(ibis) >= n_beats
        return ibis[1:n_beats]
    else
        error("Lorenz simulation: got $(length(ibis)) IBIs but needed $n_beats. Try increasing simulation time.")
    end
end

"""
    fit(model::Lorenz, data::Vector{Float64}; method=:bayesian, kwargs...) -> ModelFitResult

Fit Lorenz model to IBI data using Bayesian inference.
Note: Lorenz is a chaotic system, so only Bayesian fitting is supported.
"""
function fit(model::Lorenz, data::Vector{Float64};
             method::Symbol=:bayesian,
             chains::Int=4,
             samples::Int=1000,
             kwargs...)

    if method == :bayesian
        # Define Turing model for Bayesian inference
        @model function lorenz_model(ibi_data)
            n_beats = length(ibi_data)

            # Priors
            σ ~ TruncatedNormal(10.0, 2.0, 5.0, 15.0)
            ρ ~ TruncatedNormal(28.0, 3.0, 20.0, 35.0)
            β ~ TruncatedNormal(8/3, 0.5, 1.0, 4.0)
            threshold ~ TruncatedNormal(10.0, 2.0, 5.0, 15.0)
            σ_noise ~ Exponential(10.0)

            # Simulate model with these parameters
            params = (σ=σ, ρ=ρ, β=β, threshold=threshold)
            try
                predicted_ibi = simulate(model, params, n_beats)
                # Likelihood: observed IBIs ~ predicted IBIs with Gaussian noise
                ibi_data ~ MvNormal(predicted_ibi, σ_noise)
            catch
                # If simulation fails, assign very low likelihood
                Turing.@addlogprob! -Inf
            end
        end

        # Fit using NUTS sampler
        turing_model = lorenz_model(data)
        chain = sample(turing_model, NUTS(0.65), MCMCThreads(),
                      samples, chains, progress=true)

        # Extract MAP estimates
        params_map = (
            σ = mean(chain[:σ]),
            ρ = mean(chain[:ρ]),
            β = mean(chain[:β]),
            threshold = mean(chain[:threshold])
        )

        # Extract diagnostics
        diagnostics = Dict(
            "method" => "NUTS (Turing.jl)",
            "chains" => chains,
            "samples_per_chain" => samples,
            "total_samples" => samples * chains,
            "rhat_sigma" => rhat(chain[:σ])[1],
            "rhat_rho" => rhat(chain[:ρ])[1],
            "rhat_beta" => rhat(chain[:β])[1],
            "rhat_threshold" => rhat(chain[:threshold])[1],
            "rhat_sigma_noise" => rhat(chain[:σ_noise])[1]
        )

        # Extract posterior samples
        posterior = Dict(
            "σ" => vec(chain[:σ]),
            "ρ" => vec(chain[:ρ]),
            "β" => vec(chain[:β]),
            "threshold" => vec(chain[:threshold]),
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

    else
        error("Lorenz only supports :bayesian fitting (chaotic system, non-differentiable)")
    end
end

# ============================================================================
# Leaky Integrate-and-Fire (LIF) Neural Model
# ============================================================================

"""
    LIF <: AbstractHRVModel

Leaky Integrate-and-Fire stochastic neural model for HRV simulation.
Generates spike-based cardiac dynamics through threshold crossings.

# Parameters
- `τ`: Membrane time constant (typically ~50 ms)
- `I_base`: Base input current (typically ~0.8)
- `threshold`: Spike threshold (typically ~1.0)
- `noise_amp`: Noise amplitude (typically ~0.15)
"""
struct LIF <: AbstractHRVModel
    τ::Float64
    I_base::Float64
    threshold::Float64
    noise_amp::Float64
end

LIF(; τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15) = LIF(τ, I_base, threshold, noise_amp)

"""
    parameter_space(model::LIF) -> NamedTuple

Return the parameter space for LIF model with priors for Bayesian fitting.
"""
function parameter_space(model::LIF)
    return (
        τ = (
            lower = 10.0,
            upper = 100.0,
            prior = TruncatedNormal(50.0, 15.0, 10.0, 100.0)
        ),
        I_base = (
            lower = 0.5,
            upper = 1.5,
            prior = TruncatedNormal(0.8, 0.2, 0.5, 1.5)
        ),
        threshold = (
            lower = 0.5,
            upper = 1.5,
            prior = TruncatedNormal(1.0, 0.2, 0.5, 1.5)
        ),
        noise_amp = (
            lower = 0.05,
            upper = 0.5,
            prior = TruncatedNormal(0.15, 0.1, 0.05, 0.5)
        ),
        σ_noise = (
            lower = 1.0,
            upper = 50.0,
            prior = Exponential(10.0)
        )
    )
end

"""
    simulate(model::LIF, params::NamedTuple, n_beats::Int) -> Vector{Float64}

Simulate IBI time series using LIF stochastic neural model with threshold crossings.

# Parameters
- `τ`: Membrane time constant (ms)
- `I_base`: Base input current
- `threshold`: Spike threshold voltage
- `noise_amp`: Noise amplitude in dynamics

# Returns
Vector of inter-beat intervals in milliseconds
"""
function simulate(model::LIF, params::NamedTuple, n_beats::Int)::Vector{Float64}
    if !hasDiffEq
        error("LIF model requires DifferentialEquations.jl. Install with: Pkg.add(\"DifferentialEquations\")")
    end

    # Extract parameters
    τ = get(params, :τ, model.τ)
    I_base = get(params, :I_base, model.I_base)
    threshold = get(params, :threshold, model.threshold)
    noise_amp = get(params, :noise_amp, model.noise_amp)

    # LIF ODE: τ dV/dt = -V + I_base + noise
    function lif!(du, u, p, t)
        τ_param, I_base_param, noise_amp_param = p
        V = u[1]
        du[1] = (-V + I_base_param) / τ_param + noise_amp_param * randn()
    end

    # Simulate until we get n_beats
    ibis = Float64[]
    u0 = [0.0]  # Start below threshold
    t = 0.0
    dt = 0.1   # Time step in ms
    last_spike_time = -Inf

    max_iterations = n_beats * 100  # Safety limit

    for iteration = 1:max_iterations
        # Solve for short interval (100ms)
        tspan = (t, t + 100.0)
        prob = ODEProblem(lif!, u0, tspan, [τ, I_base, noise_amp])

        try
            sol = solve(prob, Tsit5(), saveat=dt, verbose=false)

            # Check for threshold crossings
            for i in 2:length(sol.t)
                if sol[1, i] >= threshold && sol[1, i-1] < threshold
                    spike_time = sol.t[i]
                    if last_spike_time > -Inf
                        ibi = spike_time - last_spike_time
                        if 300 < ibi < 2000  # Physiological bounds
                            push!(ibis, ibi)
                        end
                    end
                    last_spike_time = spike_time
                    u0 = [0.0]  # Reset voltage after spike
                    break
                end
            end

            t += 100.0
            u0 = [sol[1, end]]

            if length(ibis) >= n_beats
                return ibis[1:n_beats]
            end
        catch
            # If ODE solve fails, stop
            break
        end
    end

    if length(ibis) < n_beats
        error("LIF simulation: got $(length(ibis)) IBIs but needed $n_beats. Try adjusting parameters.")
    end

    return ibis[1:n_beats]
end

"""
    fit(model::LIF, data::Vector{Float64}; method=:bayesian, kwargs...) -> ModelFitResult

Fit LIF model to IBI data using Bayesian inference or gradient-based optimization.
"""
function fit(model::LIF, data::Vector{Float64};
             method::Symbol=:bayesian,
             chains::Int=4,
             samples::Int=1000,
             kwargs...)

    if method == :bayesian
        # Define Turing model for Bayesian inference
        @model function lif_model(ibi_data)
            n_beats = length(ibi_data)

            # Priors
            τ ~ TruncatedNormal(50.0, 15.0, 10.0, 100.0)
            I_base ~ TruncatedNormal(0.8, 0.2, 0.5, 1.5)
            threshold ~ TruncatedNormal(1.0, 0.2, 0.5, 1.5)
            noise_amp ~ TruncatedNormal(0.15, 0.1, 0.05, 0.5)
            σ_noise ~ Exponential(10.0)

            # Simulate model with these parameters
            params = (τ=τ, I_base=I_base, threshold=threshold, noise_amp=noise_amp)
            try
                predicted_ibi = simulate(model, params, n_beats)
                # Likelihood: observed IBIs ~ predicted IBIs with Gaussian noise
                ibi_data ~ MvNormal(predicted_ibi, σ_noise)
            catch
                # If simulation fails, assign very low likelihood
                Turing.@addlogprob! -Inf
            end
        end

        # Fit using NUTS sampler
        turing_model = lif_model(data)
        chain = sample(turing_model, NUTS(0.65), MCMCThreads(),
                      samples, chains, progress=true)

        # Extract MAP estimates
        params_map = (
            τ = mean(chain[:τ]),
            I_base = mean(chain[:I_base]),
            threshold = mean(chain[:threshold]),
            noise_amp = mean(chain[:noise_amp])
        )

        # Extract diagnostics
        diagnostics = Dict(
            "method" => "NUTS (Turing.jl)",
            "chains" => chains,
            "samples_per_chain" => samples,
            "total_samples" => samples * chains,
            "rhat_tau" => rhat(chain[:τ])[1],
            "rhat_I_base" => rhat(chain[:I_base])[1],
            "rhat_threshold" => rhat(chain[:threshold])[1],
            "rhat_noise_amp" => rhat(chain[:noise_amp])[1],
            "rhat_sigma_noise" => rhat(chain[:σ_noise])[1]
        )

        # Extract posterior samples
        posterior = Dict(
            "τ" => vec(chain[:τ]),
            "I_base" => vec(chain[:I_base]),
            "threshold" => vec(chain[:threshold]),
            "noise_amp" => vec(chain[:noise_amp]),
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
        # Gradient-based optimization using feature-space distance minimization
        real_features = extract_feature_set(data)

        # Define loss function: MSE of key HRV features
        function loss(params_vec)
            τ, I_base, threshold, noise_amp = params_vec

            # Simulate with current parameters
            params = (τ=τ, I_base=I_base, threshold=threshold, noise_amp=noise_amp)
            try
                synthetic = simulate(model, params, length(data))
                synth_features = extract_feature_set(synthetic)

                # Compute normalized feature-space distance
                diff = (real_features .- synth_features) ./ (abs.(real_features) .+ 1e-6)
                return sum(diff .^ 2)
            catch
                return 1e10  # Large penalty for failed simulations
            end
        end

        # Optimize using Fminbox(LBFGS())
        lower = [10.0, 0.5, 0.5, 0.05]
        upper = [100.0, 1.5, 1.5, 0.5]
        initial_x = [50.0, 0.8, 1.0, 0.15]

        result = optimize(loss, lower, upper, initial_x, Fminbox(LBFGS()),
                         Optim.Options(iterations=500))

        # Extract optimized parameters
        params_opt = result.minimizer
        params_map = (
            τ = params_opt[1],
            I_base = params_opt[2],
            threshold = params_opt[3],
            noise_amp = params_opt[4]
        )

        # Extract diagnostics
        diagnostics = Dict(
            "method" => "LBFGS",
            "converged" => Optim.converged(result),
            "iterations" => result.iterations,
            "loss_final" => result.minimum
        )

        return ModelFitResult(
            model,
            :gradient,
            params_map,
            nothing,
            diagnostics,
            data
        )

    else
        error("LIF supports :bayesian and :gradient fitting methods")
    end
end

# ============================================================================
# Dynamic Mode Decomposition (DMD) Model
# ============================================================================

"""
    DMD <: AbstractHRVModel

Dynamic Mode Decomposition model for spectral IBI analysis.
Decomposes time series into dynamic modes and eigenvalues for reconstruction.

# Parameters
- `rank`: Number of modes to retain
- `modes`: Dynamic modes (matrix, empty until fitted)
- `evals`: Eigenvalues of modes (vector, empty until fitted)
- `b`: Mode amplitudes (vector, empty until fitted)
"""
mutable struct DMD <: AbstractHRVModel
    rank::Int
    modes::Matrix{ComplexF64}
    evals::Vector{ComplexF64}
    b::Vector{ComplexF64}
end

DMD(; rank::Int=5) = DMD(rank, Matrix{ComplexF64}(undef, 0, 0), ComplexF64[], ComplexF64[])

"""
    fit(model::DMD, data::Vector{Float64}; kwargs...) -> ModelFitResult

Fit DMD model to IBI data using SVD-based decomposition.
Returns a new DMD model instance with fitted modes and eigenvalues.

# Arguments
- `model::DMD`: DMD model instance with desired rank
- `data::Vector{Float64}`: IBI time series in milliseconds

# Returns
`ModelFitResult` with fitted DMD model containing modes and eigenvalues
"""
function fit(model::DMD, data::Vector{Float64}; kwargs...)
    n = length(data)
    r = min(model.rank, n - 1)  # Rank cannot exceed n-1

    # Construct Hankel matrix (embedding)
    # Each row is a delay-embedded view of the signal
    m = div(n, 2)  # Use half the length for embedding dimension
    X = zeros(m, n - m)

    for i in 1:m
        X[i, :] = data[i:i+n-m-1]
    end

    if size(X, 2) < 2
        error("DMD: data too short for decomposition. Need at least rank+2 points.")
    end

    # Split into X1 and X2 (shifted version)
    X1 = X[:, 1:end-1]
    X2 = X[:, 2:end]

    # SVD of X1
    U, Σ, V = svd(X1)

    # Truncate to rank
    U_r = U[:, 1:r]
    Σ_r = Diagonal(Σ[1:r])
    V_r = V[:, 1:r]

    # DMD matrix in reduced space
    A_tilde = U_r' * X2 * V_r * inv(Σ_r)

    # Eigendecomposition of A_tilde
    eigen_result = eigen(A_tilde)
    evals = eigen_result.values
    W = eigen_result.vectors

    # Dynamic modes: Φ = X2 * V_r * Σ_r^{-1} * W
    modes = X2 * V_r * inv(Σ_r) * W

    # Compute mode amplitudes b via least squares
    # We want: data ≈ Φ * b (approximately, for reconstruction)
    b = nothing  # Initialize b to ensure it's defined in function scope
    try
        b = modes \ data[1:size(modes, 1)]
    catch
        # If direct solve fails, use pinv
        b = pinv(modes) * data[1:size(modes, 1)]
    end
    # Create fitted model
    fitted_model = DMD(r, modes, evals, b)

    # Diagnostics
    reconstruction_error = norm(X1 - U_r * Σ_r * V_r')

    diagnostics = Dict(
        "method" => "SVD (DMD)",
        "rank" => r,
        "embedding_dimension" => m,
        "reconstruction_error" => reconstruction_error,
        "condition_number" => cond(A_tilde)
    )

    return ModelFitResult(
        fitted_model,
        :gradient,  # DMD is deterministic (like gradient-based)
        NamedTuple(),  # No continuous parameters to optimize
        nothing,  # No posterior samples
        diagnostics,
        data
    )
end

"""
    simulate(model::DMD, params::Union{NamedTuple,Nothing}, n_beats::Int) -> Vector{Float64}

Reconstruct IBI time series using fitted DMD model.

# Arguments
- `model::DMD`: Fitted DMD model with modes and eigenvalues
- `params`: Ignored (DMD is data-driven)
- `n_beats`: Number of IBIs to generate

# Returns
Vector of inter-beat intervals in milliseconds
"""
function simulate(model::DMD, params::Union{NamedTuple,Nothing}, n_beats::Int)::Vector{Float64}
    if isempty(model.modes)
        error("DMD model must be fitted before simulation. Call fit() first.")
    end

    # Standard DMD reconstruction: x(t) ≈ Σ_j φ_j * λ_j^(t-1) * b_j
    # where φ_j is j-th mode (column of modes matrix), λ_j is eigenvalue, b_j is amplitude

    m = size(model.modes, 1)  # Spatial dimension (embedding dimension)
    r = size(model.modes, 2)  # Number of modes
    reconstructed = zeros(n_beats)

    # For each time step, compute the reconstruction
    for t in 1:n_beats
        # Sum contribution from each dynamic mode
        for j in 1:r
            # Mode amplitude evolves as λ_j^(t-1)
            λ_power = model.evals[j]^(t-1)

            # Average the mode contribution across spatial dimension
            mode_j = model.modes[:, j]
            spatial_avg = mean(abs.(mode_j))

            # Weighted contribution
            contribution = real(spatial_avg * λ_power * model.b[j])
            reconstructed[t] += contribution
        end
    end

    # Normalize to physiological range
    # First, shift to have similar mean as original signal
    μ = mean(reconstructed)
    if μ > 0 && !isnan(μ)
        # Scale to typical IBI mean (800ms for ~75 BPM)
        reconstructed = reconstructed * (800 / abs(μ))
    else
        reconstructed = fill(800.0, n_beats)
    end

    # Enforce physiological bounds (300-2000 ms)
    reconstructed = max.(reconstructed, 300.0)
    reconstructed = min.(reconstructed, 2000.0)

    return reconstructed
end

end  # Models
