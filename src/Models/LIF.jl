"""
    LIF <: AbstractHRVModel

Leaky Integrate-and-Fire cardiac pacemaker model for HRV simulation.
Models the heart's sinoatrial node as a large-τ pacemaker neuron.

# Physiological Parameters (Fixed)
- `τ`: Membrane time constant = 200 ms (cardiac pacemaker)
- `V_rest`: Resting potential = -65 mV
- `V_reset`: Reset potential = -65 mV (equals resting)
- `V_threshold`: Spike threshold = -60 mV
- `R`: Membrane resistance = 10 MΩ

# Fitted Parameter
- `I`: Input current (dimensionless, typical 1.51-1.53 for 800-1000ms IBIs)

# Model Equation
τ dV/dt = -(V - V_rest) + R*I

When V crosses V_threshold, a spike occurs and V resets to V_reset.
IBI = time between spikes × 10 (converts 80-100ms model time to 800-1000ms physiological time)
"""
struct LIF <: AbstractHRVModel
    τ::Float64          # Membrane time constant (ms) = 200 (fixed)
    V_rest::Float64     # Resting potential (mV) = -65 (fixed)
    V_reset::Float64    # Reset potential (mV) = -65 (fixed)
    V_threshold::Float64  # Spike threshold (mV) = -60 (fixed)
    R::Float64          # Membrane resistance (MΩ) = 10 (fixed)
    I::Float64          # Input current (fitted parameter, typically 1.51-1.53)
end

LIF(; I=1.52) = LIF(200.0, -65.0, -65.0, -60.0, 10.0, I)

"""
    parameter_space(model::LIF) -> NamedTuple

Return the parameter space for LIF model (only I is fitted).

# Returns
NamedTuple with single key `I` (input current)
- lower = 1.48: Below this, heart rate too slow
- upper = 1.56: Above this, heart rate too fast
- prior: TruncatedNormal centered at 1.52 (normal resting heart rate)
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
  τ dV/dt = -(V - V_rest) + R*I

When V crosses V_threshold (upward), spike occurs and V resets to V_reset.

# Returns
Vector of inter-beat intervals in milliseconds (physiological time)
Model time multiplied by 10 to convert 80-100ms → 800-1000ms
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

    # Time span: simulate long enough to get n_beats IBIs
    # Maximum IBI ~3000ms -> 300ms in model time.
    tspan = (0.0, 300.0 * n_beats)

    # Define and solve ODE problem
    prob = ODEProblem(lif_dynamics!, u0, tspan, p)
    sol = solve(prob, Tsit5(), callback=cb, dtmax=0.1)

    # Compute IBIs from spike times
    if length(spike_times) < 2
        error("LIF simulation: insufficient spikes ($(length(spike_times))). " *
              "I=$I may be too low to trigger spikes.")
    end

    # Calculate inter-beat intervals
    ibis_model_time = diff(spike_times)

    # Convert from model time to physiological time (×10)
    # Model: 80-100ms → Physiological: 800-1000ms
    ibis_physiological = ibis_model_time .* 10.0

    # Return exactly n_beats IBIs
    if length(ibis_physiological) >= n_beats
        return ibis_physiological[1:n_beats]
    else
        error("LIF simulation: only generated $(length(ibis_physiological))/$n_beats IBIs")
    end
end

"""
    fit(model::LIF, data::Vector{Float64}; method=:bayesian, kwargs...) -> ModelFitResult

Fit LIF model to IBI data using Bayesian inference or gradient-based optimization.

Only the I parameter is fitted; physiological parameters (τ, V_rest, R, V_threshold) are fixed.
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
        # Gradient-based optimization using feature-space distance minimization
        real_features = extract_feature_set(data)
        feature_names = ["mean", "sdnn", "rmssd"]

        # Validate that initial parameters can simulate
        initial_params = (I=model.I,)
        try
            test_sim = simulate(model, initial_params, min(100, length(data)))
            @info "LIF gradient fit: Initial simulation successful ($(length(test_sim)) IBIs)"
        catch e
            error("LIF gradient fit: Initial simulation failed with default parameters. " *
                  "Data may be too short or model parameters incompatible. Error: $e")
        end

        # Define loss function: MSE of key HRV features
        sim_failures = Ref(0)  # Track simulation failures
        function loss(params_vec)
            I_val = params_vec[1]

            # Simulate with current I parameter
            params = (I=I_val,)
            try
                synthetic = simulate(model, params, length(data))
                synth_features = extract_feature_set(synthetic)

                # Compute normalized feature-space distance
                distance = 0.0
                for feat in feature_names
                    real_val = real_features[!, feat][1]
                    synth_val = synth_features[!, feat][1]
                    if real_val > 0
                        distance += ((real_val - synth_val) / real_val)^2
                    else
                        distance += (real_val - synth_val)^2
                    end
                end
                return distance
            catch e
                sim_failures[] += 1
                return 1e10  # Large penalty for failed simulations
            end
        end

        # Get bounds from parameter space
        ps = parameter_space(model)
        lower = [ps.I.lower]
        upper = [ps.I.upper]
        initial_x = [model.I]

        result = optimize(loss, lower, upper, initial_x, Fminbox(LBFGS()),
                         Optim.Options(iterations=500, g_tol=1e-6, f_tol=1e-8))

        # Check if optimization was successful
        if result.iterations <= 1 && result.minimum >= 1e9
            @warn "LIF gradient fit: Optimization failed - simulation errors likely. " *
                  "Sim failures: $(sim_failures[]). Returning initial parameters."
        end

        # Extract optimized parameters
        params_map = (
            I = result.minimizer[1],
        )

        # Extract diagnostics
        diagnostics = Dict(
            "method" => "LBFGS",
            "converged" => Optim.converged(result),
            "iterations" => result.iterations,
            "loss_final" => result.minimum,
            "simulation_failures" => sim_failures[],
            "optimization_successful" => result.minimum < 1e9
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
