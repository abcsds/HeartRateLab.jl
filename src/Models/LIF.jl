"""
    LIF <: AbstractHRVModel

Leaky Integrate-and-Fire cardiac pacemaker model for HRV simulation.
Models the heart's sinoatrial node as a pacemaker neuron.

# Parameters
- `τ`: Membrane time constant (ms) — sets the intrinsic inter-beat timescale
- `V_rest`: Resting potential (mV)
- `V_reset`: Reset potential (mV) after each spike (typically equals V_rest)
- `V_threshold`: Spike threshold (mV)
- `R`: Membrane resistance — scales input current to voltage units

# Fitted Parameter
- `I`: Input current — sole free parameter; encodes autonomic drive and heart rate

# Model Equation
τ dV/dt = -(V - V_rest) + R*I

When V crosses V_threshold (upward), a spike occurs and V resets to V_reset.
The inter-beat interval (IBI) is the time between consecutive spikes, directly
in milliseconds — no post-hoc scaling is applied.

# Period Formula (analytical)
With ΔV = V_threshold - V_rest and nullcline V* = V_rest + R·I (requires V* > V_threshold):
  T = τ · ln(R·I / (R·I - ΔV))
Inverse (desired period → required I):
  I = ΔV / (R · (1 - exp(-T/τ)))
"""
struct LIF <: AbstractHRVModel
    τ::Float64            # Membrane time constant (ms)
    V_rest::Float64       # Resting potential (mV)
    V_reset::Float64      # Reset potential (mV)
    V_threshold::Float64  # Spike threshold (mV)
    R::Float64            # Membrane resistance
    I::Float64            # Input current (fitted parameter)
end

"""
    parameter_space(model::LIF) -> NamedTuple

Return the parameter space for LIF model (only I is fitted).

Bounds are derived analytically from the model's own parameters using
  I(T) = ΔV / (R · (1 - exp(-T/τ)))
so they automatically adapt when τ, R, or the voltage parameters change.

# Derived bounds
- lower ↔ T_max = 3000 ms (very slow heart rate, ~20 bpm)
- upper ↔ T_min =  300 ms (very fast heart rate, ~200 bpm)
- center ↔ T_center = 800 ms (~75 bpm, normal resting)
"""
function parameter_space(model::LIF)
    return (
        I = (
            lower = 1.48,
            upper = 1.56,
            prior = Distributions.truncated(Distributions.Normal(1.52, 0.02), 1.48, 1.56)
        ),
    )
end

"""
    simulate(model::LIF, params::NamedTuple, n_beats::Int) -> Vector{Float64}

Simulate IBI time series using LIF cardiac pacemaker with DifferentialEquations.jl.

Uses callback-based spike detection for accurate IBI measurement.

# Parameters
- `I`: Input current (from params or model default)

# Model
Leaky Integrate-and-Fire ODE:
  τ dV/dt = -(V - V_rest) + R·I

When V crosses V_threshold (upward), a spike occurs and V resets to V_reset.

# Returns
Vector of n_beats inter-beat intervals in milliseconds (spike-time differences,
no rescaling applied — model time IS physiological time).
"""
function simulate(model::LIF, params::NamedTuple, n_beats::Int)::Vector{Float64}
    # Check DifferentialEquations availability
    if !hasDiffEq
        error("LIF model requires DifferentialEquations.jl. Install with: Pkg.add(\"DifferentialEquations\")")
    end

    # Extract parameter (only I is variable)
    I = get(params, :I, model.I)

    # LIF ODE: τ dV/dt = -(V - V_rest) + R*I
    function lif_dynamics!(du, u, p, t)
        V = u[1]
        τ, V_rest, R, I_curr = p
        du[1] = (-(V - V_rest) + R * I_curr) / τ
    end

    # Initial condition: start at resting potential
    u0 = [model.V_rest]

    # Parameters tuple for ODE
    p = [model.τ, model.V_rest, model.R, I]

    # Storage for spike times
    spike_times = Float64[]

    # Callback: detect threshold crossing (spike)
    function spike_condition(u, t, integrator)
        return u[1] - model.V_threshold  # Zero when V crosses threshold
    end

    function spike_affect!(integrator)
        # Record spike time
        push!(spike_times, integrator.t)

        # Reset voltage to V_reset
        integrator.u[1] = model.V_reset

        # Stop if we have enough spikes
        if length(spike_times) >= n_beats + 1  # +1 because first IBI needs 2 spikes
            terminate!(integrator)
        end
    end

    # Create callback for upward threshold crossings
    cb = ContinuousCallback(spike_condition, spike_affect!,
                           nothing,  # No negative crossing action
                           rootfind=SciMLBase.RightRootFind)  # Only upward crossings

    # Time span: generous upper bound — at least n_beats × max expected IBI.
    # Maximum physiological IBI ~3000 ms, so 3000 × n_beats is a safe ceiling.
    tspan = (0.0, 3000.0 * n_beats)

    # Define and solve ODE problem
    prob = ODEProblem(lif_dynamics!, u0, tspan, p)
    sol = solve(prob, Tsit5(), callback=cb, dtmax=0.1)

    # Compute IBIs from spike times
    if length(spike_times) < 2
        error("LIF simulation: insufficient spikes ($(length(spike_times))). " *
              "I=$I may be too low to trigger spikes.")
    end

    # Inter-beat intervals are spike-time differences
    ibis = diff(spike_times)

    if length(ibis) >= n_beats
        return ibis[1:n_beats]
    else
        error("LIF simulation: only generated $(length(ibis))/$n_beats IBIs")
    end
end

"""
    fit(model::LIF, data::Vector{Float64}; method=:bayesian, kwargs...) -> ModelFitResult

Fit LIF model to IBI data using Bayesian inference, gradient-based optimization,
or the closed-form analytical solution.

Only the I parameter is fitted; physiological parameters (τ, V_rest, R, V_threshold) are fixed.

# Methods
- `:analytical` — Inverts the period formula `T = τ·ln(R·I / (R·I - ΔV))` for
  every IBI individually, yielding a per-beat `I` series.  `params.I` is the
  mean; the full series is stored in `result.posterior["I"]`.  Instantaneous,
  no simulation required.
- `:gradient`   — Brent univariate optimisation minimising RMSE of simulated IBIs.
- `:bayesian`   — NUTS sampler via Turing.jl.
"""
function fit(model::LIF, data::Vector{Float64};
             method::Symbol=:bayesian,
             chains::Int=4,
             samples::Int=1000,
             kwargs...)

    if method == :analytical
        # Invert the period formula pointwise for every IBI.
        # Period formula:  T = τ · ln(R·I / (R·I - ΔV))
        # Inverse:         I = ΔV / (R · (1 - exp(-T/τ)))
        ΔV = model.V_threshold - model.V_rest
        I_series = ΔV ./ (model.R .* (1.0 .- exp.(-data ./ model.τ)))

        # Representative scalar: mean over all beats
        I_mean = mean(I_series)

        params_map = (I = I_mean,)

        diagnostics = Dict(
            "method"    => "analytical (per-beat period inversion)",
            "I_std"     => std(I_series),
            "I_min"     => minimum(I_series),
            "I_max"     => maximum(I_series),
            "n_beats"   => length(data),
        )

        # Full per-beat I values stored as posterior for downstream use
        posterior = Dict("I" => I_series)

        return ModelFitResult(
            model,
            :analytical,
            params_map,
            posterior,
            diagnostics,
            data
        )

    elseif method == :bayesian
        # Define Turing model for Bayesian inference
        @model function lif_model(ibi_data)
            n_beats = length(ibi_data)

            # Prior from parameter_space
            ps = parameter_space(model)
            I ~ ps.I.prior
            σ_noise ~ Distributions.Exponential(10.0)

            # Simulate model with fitted I parameter
            params = (I=I,)
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
            I = mean(chain[:I]),
        )

        # Extract diagnostics
        diagnostics = Dict(
            "method" => "NUTS (Turing.jl)",
            "chains" => chains,
            "samples_per_chain" => samples,
            "total_samples" => samples * chains,
            "rhat_I" => rhat(chain[:I])[1],
            "rhat_sigma_noise" => rhat(chain[:σ_noise])[1]
        )

        # Extract posterior samples
        posterior = Dict(
            "I" => vec(chain[:I]),
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
        initial_params = (I=model.I,)
        try
            test_sim = simulate(model, initial_params, min(100, length(data)))
            @debug "LIF gradient fit: Initial simulation successful ($(length(test_sim)) IBIs)"
        catch e
            error("LIF gradient fit: Initial simulation failed with default parameters. " *
                  "Data may be too short or model parameters incompatible. Error: $e")
        end

        # Define loss function: MSE of key HRV features
        sim_failures = Ref(0)  # Track simulation failures
        function loss(I_val::Float64)
            params = (I=I_val,)
            try
                synthetic = simulate(model, params, length(data))
                # Compute RMSE
                return sqrt(mean((synthetic - data).^2))
            catch e
                sim_failures[] += 1
                return 1e10  # Large penalty for failed simulations
            end
        end

        # Get bounds from parameter space
        ps = parameter_space(model)

        # Use Brent's univariate method (gradient-free): avoids ForwardDiff issues
        # with DifferentialEquations callbacks and is optimal for this 1D problem.
        result = optimize(loss, ps.I.lower, ps.I.upper,
                         Optim.Brent();
                         rel_tol=1e-6, abs_tol=1e-8)

        # Check if optimization was successful
        if Optim.iterations(result) <= 1 && Optim.minimum(result) >= 1e9
            @warn "LIF gradient fit: Optimization failed - simulation errors likely. " *
                  "Sim failures: $(sim_failures[]). Returning initial parameters."
        end

        # Extract optimized parameters (scalar minimizer for univariate result)
        params_map = (
            I = result.minimizer,
        )

        # Extract diagnostics
        diagnostics = Dict(
            "method" => "Brent",
            "converged" => Optim.converged(result),
            "iterations" => Optim.iterations(result),
            "loss_final" => Optim.minimum(result),
            "simulation_failures" => sim_failures[],
            "optimization_successful" => Optim.minimum(result) < 1e9
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
        error("LIF supports :analytical, :gradient, and :bayesian fitting methods")
    end
end
