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
            prior = Distributions.truncated(Distributions.Normal(50.0, 15.0), 10.0, 100.0)
        ),
        I_base = (
            lower = 0.5,
            upper = 1.5,
            prior = Distributions.truncated(Distributions.Normal(0.8, 0.2), 0.5, 1.5)
        ),
        threshold = (
            lower = 0.5,
            upper = 1.5,
            prior = Distributions.truncated(Distributions.Normal(1.0, 0.2), 0.5, 1.5)
        ),
        noise_amp = (
            lower = 0.05,
            upper = 0.5,
            prior = Distributions.truncated(Distributions.Normal(0.15, 0.1), 0.05, 0.5)
        ),
        σ_noise = (
            lower = 1.0,
            upper = 50.0,
            prior = Distributions.Exponential(10.0)
        )
    )
end

"""
    simulate(model::LIF, params::NamedTuple, n_beats::Int) -> Vector{Float64}

Simulate IBI time series using LIF stochastic neural model with threshold crossings.

# Parameters
- `τ`: Membrane time constant (ms) - controls membrane integration speed
- `I_base`: Base input current (dimensionless, typical ~0.8)
- `threshold`: Spike threshold voltage (dimensionless, typical ~1.0)
- `noise_amp`: Noise amplitude in dynamics (dimensionless, typical ~0.15)

# Model
The Leaky Integrate-and-Fire neuron model:
  τ dV/dt = -V + I_base + noise_amp * ξ(t)

When V crosses threshold, a spike occurs and V resets to 0.

# Returns
Vector of inter-beat intervals in milliseconds (time between spike events)
"""
function simulate(model::LIF, params::NamedTuple, n_beats::Int, dt::Float64=0.1, T_max::Float64=nothing)::Vector{Float64}
    # Extract parameters
    τ = get(params, :τ, model.τ)              # time constant in ms
    I_base = get(params, :I_base, model.I_base)  # base input current
    threshold = get(params, :threshold, model.threshold)  # spike threshold
    noise_amp = get(params, :noise_amp, model.noise_amp)  # noise amplitude

    # State variables
    V = 0.0  # Membrane voltage (start below threshold)
    t = 0.0  # Current time in ms
    last_spike_time = -Inf  # Time of last spike
    ibis = Float64[]  # Inter-beat intervals

    # Simulate until we have enough IBIs
    while length(ibis) < n_beats && (T_max === nothing || t < T_max)
        # Stochastic Euler step for LIF ODE
        # dV = (-V + I_base) * dt/τ + noise_amp * sqrt(dt) * randn()
        dV = (-V + I_base) / τ * dt + noise_amp * sqrt(dt) * randn()
        V_new = V + dV

        # Check for threshold crossing
        if V < threshold && V_new >= threshold
            # Spike occurred
            spike_time = t + dt * (threshold - V) / (V_new - V)  # Interpolate exact crossing time

            if last_spike_time > -Inf
                ibi = spike_time - last_spike_time  # Time between spikes in ms
                # Only include physiologically valid IBIs
                if 300.0 < ibi < 2000.0
                    push!(ibis, ibi)
                end
            end

            last_spike_time = spike_time
            V_new = 0.0  # Reset voltage after spike
        end

        V = V_new
        t += dt
    end

    # Check if we got enough IBIs
    if length(ibis) < n_beats
        error("LIF simulation failed: only generated $(length(ibis))/$n_beats IBIs. " *
              "Try increasing τ or I_base, or reducing noise_amp.")
    end

    return ibis[1:n_beats]
end

"""
    fit(model::LIF, data::Vector{Float64}; method=:bayesian, kwargs...) -> ModelFitResult

Fit LIF model to IBI data using Bayesian inference or gradient-based optimization.
"""
function fit(model::LIF, data::Vector{Float64};
             method::Symbol=:bayesian,
             chains::Int=4, # TODO: nprocs()
             samples::Int=1000,
             kwargs...)

    if method == :bayesian
        # Define Turing model for Bayesian inference
        @model function lif_model(ibi_data)
            n_beats = length(ibi_data)

            # Priors # TODO: take from parameter_space() function
            τ ~ Distributions.truncated(Distributions.Normal(50.0, 15.0), 10.0, 100.0)
            I_base ~ Distributions.truncated(Distributions.Normal(0.8, 0.2), 0.5, 1.5)
            threshold ~ Distributions.truncated(Distributions.Normal(1.0, 0.2), 0.5, 1.5)
            noise_amp ~ Distributions.truncated(Distributions.Normal(0.15, 0.1), 0.05, 0.5)
            σ_noise ~ Distributions.Exponential(10.0)
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
        feature_names = ["mean", "sdnn", "rmssd"]

        # Validate that initial parameters can simulate
        initial_params = (τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
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
            τ, I_base, threshold, noise_amp = params_vec

            # Simulate with current parameters
            params = (τ=τ, I_base=I_base, threshold=threshold, noise_amp=noise_amp)
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

        # Optimize using Fminbox(LBFGS()) with relaxed convergence
        lower = [10.0, 0.5, 0.5, 0.05]
        upper = [100.0, 1.5, 1.5, 0.5]
        initial_x = [50.0, 0.8, 1.0, 0.15]

        result = optimize(loss, lower, upper, initial_x, Fminbox(LBFGS()),
                         Optim.Options(iterations=500, g_tol=1e-6, f_tol=1e-8))

        # Check if optimization was successful
        if result.iterations <= 1 && result.minimum >= 1e9
            @warn "LIF gradient fit: Optimization failed - simulation errors likely. " *
                  "Sim failures: $(sim_failures[]). Returning initial parameters."
        end

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
