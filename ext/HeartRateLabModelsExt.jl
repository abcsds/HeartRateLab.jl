"""
    HeartRateLabModelsExt

Extension providing ODE-based and evolutionary model implementations for HRV analysis.

This extension is loaded automatically when any of its dependencies are imported:
- `DifferentialEquations.jl`: ODE solvers (Lorenz, Van der Pol, LIF)
- `Turing.jl`: Bayesian parameter inference
- `Optim.jl`: Gradient-based optimization
- `BlackBoxOptim.jl`: Evolutionary algorithms

# Models Provided (implemented in Phase 3)

## Mechanistic ODE Models
- **LIF** (Leaky Integrate-and-Fire): Stochastic model with threshold-crossing dynamics
- **Van der Pol**: Deterministic oscillator with non-linear damping
- **Lorenz**: Chaotic attractor, IBI extracted from inter-crossing intervals

## Fitting Methods
- `:bayesian` → Turing.jl (MCMC over parameter space)
- `:gradient` → Optim.jl (minimize feature-space distance)
- `:evolutionary` → BlackBoxOptim.jl (non-differentiable models)

## Spectral Models
- **DMD** (Dynamic Mode Decomposition): Fit = decompose, Simulate = reconstruct

All models conform to the `AbstractHRVModel` interface defined in the core package.

# Example (when implemented)
```julia
using HeartRateLab
using DifferentialEquations  # This loads the extension

# Simulate synthetic data from LIF model
lif_model = LIF(τ=50, I_base=0.5, threshold=1.0, noise_amp=0.1)
synthetic_ibis = simulate(lif_model, params, n_beats=1000)

# Fit model to real data using Bayesian inference
real_data = read_txt("subject_001.txt")
result = fit(lif_model, real_data; method=:bayesian, chains=4, samples=1000)
```
"""
module HeartRateLabModelsExt

# This extension is loaded when DifferentialEquations, Turing, Optim, or BlackBoxOptim
# are imported alongside HeartRateLab

# Import the parent module
import HeartRateLab
using HeartRateLab.Models

# Conditional imports based on Julia version (for extensions compatibility)
if !isdefined(Base, :get_extension)
    # Julia < 1.9 (if supporting older versions)
    # This would use Requires.jl instead
    error("Package extensions require Julia >= 1.9")
end

# These will be imported when the extension is loaded
using DifferentialEquations
using Turing
using Optim
using BlackBoxOptim
using Random
using Statistics
using LinearAlgebra

"""
    LIF <: AbstractHRVModel

Leaky Integrate-and-Fire (LIF) model for HRV generation.

A stochastic spiking neuron model that generates inter-beat-intervals (IBIs) through
threshold-crossing dynamics of membrane potential. When the potential crosses a threshold,
a spike (heartbeat) is generated and the potential resets.

# Fields
- `τ::Float64`: Membrane time constant (milliseconds)
- `I_base::Float64`: Baseline input current
- `threshold::Float64`: Spike threshold voltage
- `noise_amp::Float64`: Amplitude of stochastic noise

# Dynamics
The membrane potential evolves as:
```
dV/dt = (V_rest - V + I_base) / τ + noise
```
where V_rest = 0, I_base ∈ (0.1, 2.0) controls firing rate, and noise is Gaussian.

# References
Büzás, A., Horváth, T., & Dér, A. (2022). A Novel Approach in Heart-Rate-Variability
Analysis Based on Modified Poincaré Plots. IEEE Access, 10, 36606–36615.
"""
struct LIF <: AbstractHRVModel
    τ::Float64  # Time constant (ms)
    I_base::Float64  # Baseline input current
    threshold::Float64  # Spike threshold
    noise_amp::Float64  # Noise amplitude
end

"""
    LIF(; τ=50.0, I_base=0.5, threshold=1.0, noise_amp=0.1)

Create a default LIF model with specified parameters.
"""
function LIF(; τ=50.0, I_base=0.5, threshold=1.0, noise_amp=0.1)
    return LIF(τ, I_base, threshold, noise_amp)
end

"""
    simulate(model::LIF, params::NamedTuple, n_beats::Int) -> Vector{Float64}

Simulate inter-beat-intervals from an LIF model.

# Arguments
- `model::LIF`: Model instance (used for default parameters)
- `params::NamedTuple`: Parameters (τ, I_base, threshold, noise_amp)
- `n_beats::Int`: Number of beats to simulate

# Returns
- `Vector{Float64}`: Inter-beat-intervals in milliseconds

# Algorithm
1. Simulate stochastic differential equation: dV/dt = (V_rest - V + I) / τ + noise
2. Detect threshold crossings (spike times)
3. Convert spike times to inter-spike intervals (IBIs)
4. Return vector of IBIs
"""
function simulate(model::LIF, params::NamedTuple, n_beats::Int)::Vector{Float64}
    τ = params.τ
    I_base = params.I_base
    threshold = params.threshold
    noise_amp = params.noise_amp

    # Generate spikes by threshold crossings
    V_rest = 0.0
    V = V_rest
    spike_times = Float64[]
    t = 0.0
    dt = 1.0  # Integration step in ms

    # Simulate until we get enough spikes
    max_time = 10_000_000  # 10 million ms = ~10,000 seconds max

    while length(spike_times) < n_beats && t < max_time
        # Stochastic Euler step
        dV = (V_rest - V + I_base) / τ * dt
        dV += noise_amp * sqrt(dt) * randn()
        V += dV
        t += dt

        # Check for threshold crossing
        if V >= threshold
            push!(spike_times, t)
            V = V_rest  # Reset
        end
    end

    # Convert spike times to IBIs
    if length(spike_times) < 2
        # Not enough spikes, return default
        return fill(1000.0, n_beats)
    end

    ibis = diff(spike_times)

    # Return first n_beats IBIs
    return ibis[1:min(n_beats, length(ibis))]
end

"""
    parameter_space(model::LIF) -> NamedTuple

Define the parameter space for Bayesian inference on LIF.

Returns a NamedTuple with (lower, upper, prior) for each parameter.
"""
function parameter_space(model::LIF)
    return (
        τ = (lower=1.0, upper=100.0, prior=LogNormal(log(50), 0.5)),
        I_base = (lower=0.1, upper=2.0, prior=Normal(0.8, 0.3)),
        threshold = (lower=0.1, upper=3.0, prior=Normal(1.0, 0.3)),
        noise_amp = (lower=0.01, upper=1.0, prior=LogNormal(log(0.1), 0.5))
    )
end

"""
    compute_summary_stats(ibis::Vector{Float64}) -> Vector{Float64}

Compute normalized summary statistics from IBI series for feature-space comparison.
"""
function compute_summary_stats(ibis::Vector{Float64})
    if length(ibis) < 2
        return zeros(6)
    end

    mean_ibi = mean(ibis)
    std_ibi = std(ibis)

    # Compute pnn50
    diffs = diff(ibis)
    pnn50 = count(x -> abs(x) > 50, diffs) / length(diffs)

    # Compute Poincaré SD1, SD2
    dx = diffs ./ sqrt(2)
    dy = (ibis[1:end-1] .+ ibis[2:end]) ./ (2 * sqrt(2))
    sd1 = std(dx)
    sd2 = std(dy)

    return [mean_ibi, std_ibi, pnn50, sd1, sd2, (sd2 / (sd1 + 1e-8))]
end

"""
    fit(model::LIF, data::Vector{Float64}; method=:gradient, kwargs...) -> ModelFitResult

Fit an LIF model to real HRV data using gradient-based optimization.

# Arguments
- `model::LIF`: Model instance
- `data::Vector{Float64}`: Real IBI data (milliseconds)
- `method=:gradient`: Optimization method
- `optimizer=:LBFGS`: Optim optimizer
- `max_iter=1000`: Maximum iterations
- `abstol=1e-6`: Absolute tolerance
- `rng=Random.default_rng()`: Random number generator

# Returns
- `ModelFitResult`: Fitted model with parameters and diagnostics
"""
function fit(model::LIF, data::Vector{Float64};
             method::Symbol=:gradient,
             optimizer::Symbol=:LBFGS,
             max_iter::Int=1000,
             abstol::Float64=1e-6,
             rng=Random.default_rng())

    if method != :gradient
        error("LIF only supports :gradient fitting in this version")
    end

    # Get parameter space
    ps = parameter_space(model)

    # Extract bounds
    bounds = (
        τ = (ps.τ.lower, ps.τ.upper),
        I_base = (ps.I_base.lower, ps.I_base.upper),
        threshold = (ps.threshold.lower, ps.threshold.upper),
        noise_amp = (ps.noise_amp.lower, ps.noise_amp.upper)
    )

    # Compute target statistics from real data
    target_stats = compute_summary_stats(data)

    # Create loss function (L2 distance in feature space)
    function loss(params_vec)
        # Unpack parameters
        τ, I_base, threshold, noise_amp = params_vec

        # Check bounds
        if τ < bounds.τ[1] || τ > bounds.τ[2] ||
           I_base < bounds.I_base[1] || I_base > bounds.I_base[2] ||
           threshold < bounds.threshold[1] || threshold > bounds.threshold[2] ||
           noise_amp < bounds.noise_amp[1] || noise_amp > bounds.noise_amp[2]
            return 1e10
        end

        try
            # Simulate from parameters
            params = (τ=τ, I_base=I_base, threshold=threshold, noise_amp=noise_amp)
            synthetic = simulate(model, params, length(data))

            # Compute statistics
            synth_stats = compute_summary_stats(synthetic)

            # L2 distance (normalized)
            loss_val = sum((target_stats .- synth_stats).^2)
            return loss_val
        catch
            return 1e10
        end
    end

    # Initialize from prior mean
    x0 = [
        (ps.τ.lower + ps.τ.upper) / 2,
        (ps.I_base.lower + ps.I_base.upper) / 2,
        (ps.threshold.lower + ps.threshold.upper) / 2,
        (ps.noise_amp.lower + ps.noise_amp.upper) / 2
    ]

    # Optimize
    opt_result = Optim.optimize(
        loss, x0,
        Optim.LBFGS(),
        Optim.Options(
            iterations=max_iter,
            f_abstol=abstol,
            show_trace=false
        )
    )

    # Extract best parameters
    best_params = (
        τ = opt_result.minimizer[1],
        I_base = opt_result.minimizer[2],
        threshold = opt_result.minimizer[3],
        noise_amp = opt_result.minimizer[4]
    )

    # Create diagnostics
    diagnostics = Dict(
        "converged" => Optim.converged(opt_result),
        "iterations" => opt_result.iterations,
        "loss_final" => Optim.minimum(opt_result),
        "method" => "LBFGS"
    )

    return ModelFitResult(
        model,
        method,
        best_params,
        nothing,  # No posterior for gradient fitting
        diagnostics,
        data
    )
end

"""
    VanDerPol <: AbstractHRVModel

Van der Pol oscillator model for HRV generation.

A deterministic non-linear oscillator that self-sustains oscillations with controllable
damping behavior. Inter-beat-intervals (IBIs) are extracted as the time between peaks
(local maxima) of the V coordinate.

# Fields
- `μ::Float64`: Non-linearity parameter (controls damping strength)
- `heart_rate::Float64`: Target heart rate in BPM (scales integration time)

# Dynamics
The two-dimensional Van der Pol system:
```
dV/dt = W
dW/dt = μ(1 - V²)W - V
```

The parameter μ controls the oscillation behavior:
- Small μ ≈ 0.1-0.5: Nearly sinusoidal, weakly non-linear
- Moderate μ ≈ 1-3: Strong relaxation oscillations (cardiac range)
- Large μ > 5: Sharp peaks with slow return (extreme non-linearity)

# References
Lopez-Chamorro et al. (2018). Cardiac Pulse Modeling Using Modified van der Pol Oscillator.
Bioinformatics and Biomedical Engineering.
"""
struct VanDerPol <: AbstractHRVModel
    μ::Float64  # Non-linearity parameter
    heart_rate::Float64  # Target heart rate (BPM)
end

"""
    VanDerPol(; μ=1.5, heart_rate=70.0)

Create a default Van der Pol model with specified parameters.
"""
function VanDerPol(; μ=1.5, heart_rate=70.0)
    return VanDerPol(μ, heart_rate)
end

"""
    simulate(model::VanDerPol, params::NamedTuple, n_beats::Int) -> Vector{Float64}

Simulate inter-beat-intervals from a Van der Pol model.

# Arguments
- `model::VanDerPol`: Model instance (used for default parameters)
- `params::NamedTuple`: Parameters (μ, heart_rate)
- `n_beats::Int`: Number of beats to simulate

# Returns
- `Vector{Float64}`: Inter-beat-intervals in milliseconds

# Algorithm
1. Solve the Van der Pol ODE system for sufficient time to capture n_beats
2. Detect peaks in V (local maxima)
3. Convert peak-to-peak times to inter-beat-intervals
4. Scale output to target heart rate
"""
function simulate(model::VanDerPol, params::NamedTuple, n_beats::Int)::Vector{Float64}
    μ = params.μ
    heart_rate = params.heart_rate

    # Define the Van der Pol ODE system
    function vdp_dynamics!(du, u, p, t)
        V, W = u
        du[1] = W
        du[2] = p * (1 - V^2) * W - V
    end

    # Initial conditions (near fixed point)
    u0 = [1.0, 0.0]

    # Estimate integration time needed for n_beats
    # At heart_rate BPM, one beat takes 60_000 / heart_rate milliseconds
    # For Van der Pol, oscillation period varies with μ, but roughly scales as 1/μ for large μ
    # Use a generous estimate to ensure we capture enough peaks
    period_estimate = 60_000 / heart_rate  # milliseconds per beat
    t_span = (0.0, n_beats * period_estimate * 1.2)  # Add 20% buffer

    # Solve ODE with dense output for accurate peak detection
    prob = ODEProblem(vdp_dynamics!, u0, t_span, μ)
    sol = solve(prob, Rodas4(), dense=true, abstol=1e-8, reltol=1e-8)

    # Sample solution at fine resolution for peak detection
    t_samples = range(t_span[1], t_span[2], length=10000)
    V_samples = [sol(t, idxs=1) for t in t_samples]

    # Detect peaks in V (local maxima)
    peaks_idx = Int[]
    for i in 2:length(V_samples)-1
        if V_samples[i] > V_samples[i-1] && V_samples[i] > V_samples[i+1]
            push!(peaks_idx, i)
        end
    end

    # Convert indices to times
    peak_times = t_samples[peaks_idx]

    # Need at least 2 peaks to compute IBIs
    if length(peak_times) < 2
        # Fall back to default IBIs if peak detection failed
        return fill(period_estimate, n_beats)
    end

    # Compute inter-beat-intervals (peak-to-peak times)
    ibis = diff(peak_times)

    # Return first n_beats IBIs
    return ibis[1:min(n_beats, length(ibis))]
end

"""
    parameter_space(model::VanDerPol) -> NamedTuple

Define the parameter space for Van der Pol model fitting.

Returns a NamedTuple with (lower, upper, prior) for each parameter.
"""
function parameter_space(model::VanDerPol)
    return (
        μ = (lower=0.5, upper=3.0, prior=Normal(1.5, 0.5)),
        heart_rate = (lower=40.0, upper=150.0, prior=Normal(70.0, 20.0))
    )
end

"""
    Lorenz <: AbstractHRVModel

Lorenz chaotic attractor model for HRV generation.

A 3D non-linear dynamical system exhibiting chaotic behavior with sensitive dependence
on initial conditions. Inter-beat-intervals (IBIs) are extracted as the time between
threshold crossings on the Z coordinate.

# Fields
- `σ::Float64`: Rayleigh parameter (controls flow structure)
- `ρ::Float64`: Rayleigh convection parameter (controls chaos level)
- `β::Float64`: Dissipation parameter
- `threshold::Float64`: Detection threshold for Z-axis crossings

# Dynamics
The three-dimensional Lorenz system:
```
dX/dt = σ(Y - X)
dY/dt = X(ρ - Z) - Y
dZ/dt = XY - βZ
```

Standard parameters: σ≈10, ρ≈28, β≈8/3 (exhibits chaotic behavior with positive Lyapunov exponent)

The system generates self-similar patterns and demonstrates the butterfly effect:
tiny changes in initial conditions lead to drastically different trajectories.

# References
Esperer et al. (2008). Cardiac Arrhythmias Imprint Specific Signatures on Lorenz Plots.
Annals of Noninvasive Electrocardiology, 13(1), 44-60.
"""
struct Lorenz <: AbstractHRVModel
    σ::Float64  # Rayleigh parameter
    ρ::Float64  # Convection parameter
    β::Float64  # Dissipation parameter
    threshold::Float64  # Z-crossing detection threshold
end

"""
    Lorenz(; σ=10.0, ρ=28.0, β=8/3, threshold=10.0)

Create a default Lorenz model with specified parameters.

Default parameters exhibit chaotic behavior and are commonly used in cardiac modeling.
"""
function Lorenz(; σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
    return Lorenz(σ, ρ, β, threshold)
end

"""
    simulate(model::Lorenz, params::NamedTuple, n_beats::Int) -> Vector{Float64}

Simulate inter-beat-intervals from a Lorenz model.

# Arguments
- `model::Lorenz`: Model instance (used for default parameters)
- `params::NamedTuple`: Parameters (σ, ρ, β, threshold)
- `n_beats::Int`: Number of beats to simulate

# Returns
- `Vector{Float64}`: Inter-beat-intervals in milliseconds

# Algorithm
1. Solve the 3D Lorenz ODE system for sufficient time
2. Detect threshold crossings on Z coordinate
3. Convert crossing times to inter-beat-intervals
4. Scale output to milliseconds and physiological range
"""
function simulate(model::Lorenz, params::NamedTuple, n_beats::Int)::Vector{Float64}
    σ = params.σ
    ρ = params.ρ
    β = params.β
    threshold = params.threshold

    # Define the Lorenz ODE system
    function lorenz_dynamics!(du, u, p, t)
        X, Y, Z = u
        s, r, b = p
        du[1] = s * (Y - X)
        du[2] = X * (r - Z) - Y
        du[3] = X * Y - b * Z
    end

    # Initial conditions (near origin, on attractor)
    u0 = [1.0, 1.0, 1.0]

    # Time span - estimate based on expected crossings
    # Lorenz at ρ=28 produces oscillations with period ~1.0-1.5 in natural units
    # For n_beats crossings, use generous time window
    t_span = (0.0, n_beats * 5.0)  # Each beat roughly every 5 time units

    # Solve ODE with dense output
    prob = ODEProblem(lorenz_dynamics!, u0, t_span, (σ, ρ, β))
    sol = solve(prob, Rodas4(), dense=true, abstol=1e-8, reltol=1e-8)

    # Sample solution at fine resolution for crossing detection
    t_samples = range(t_span[1], t_span[2], length=15000)
    Z_samples = [sol(t, idxs=3) for t in t_samples]

    # Detect threshold crossings (upward crossings of Z through threshold)
    crossing_times = Float64[]
    for i in 2:length(Z_samples)
        if Z_samples[i-1] < threshold && Z_samples[i] >= threshold
            # Found an upward crossing, interpolate for better precision
            t1, t2 = t_samples[i-1], t_samples[i]
            z1, z2 = Z_samples[i-1], Z_samples[i]

            # Linear interpolation to find crossing time
            t_cross = t1 + (threshold - z1) / (z2 - z1) * (t2 - t1)
            push!(crossing_times, t_cross)
        end
    end

    # Need at least 2 crossings to compute IBIs
    if length(crossing_times) < 2
        # Fall back to default IBIs if crossing detection failed
        return fill(800.0, n_beats)  # Default 75 BPM = 800 ms per beat
    end

    # Compute inter-beat-intervals (crossing-to-crossing times)
    ibis_raw = diff(crossing_times)

    # Scale to milliseconds (Lorenz natural time units → milliseconds)
    # Typical Lorenz oscillation period in natural units is ~1.0-1.5
    # Map to ~800 ms (75 BPM) for cardiac range
    scaling_factor = 600.0  # milliseconds per natural time unit
    ibis = ibis_raw .* scaling_factor

    # Clamp to physiological range to handle edge cases
    ibis = max.(min.(ibis, 2000.0), 300.0)

    # Return first n_beats IBIs
    return ibis[1:min(n_beats, length(ibis))]
end

"""
    parameter_space(model::Lorenz) -> NamedTuple

Define the parameter space for Lorenz model fitting.

Returns a NamedTuple with (lower, upper, prior) for each parameter.
"""
function parameter_space(model::Lorenz)
    return (
        σ = (lower=5.0, upper=15.0, prior=Normal(10.0, 2.0)),
        ρ = (lower=20.0, upper=40.0, prior=Normal(28.0, 5.0)),
        β = (lower=1.0, upper=3.0, prior=Normal(8/3, 0.5)),
        threshold = (lower=0.0, upper=50.0, prior=Normal(10.0, 5.0))
    )
end

"""
    DMD <: AbstractHRVModel

Dynamic Mode Decomposition model for data-driven HRV synthesis.

Unlike mechanistic models (LIF, Van der Pol, Lorenz), DMD is a purely data-driven approach
that learns the dynamics of a time series through eigenmode decomposition. It decomposes
the IBI series into spatial modes and temporal dynamics (eigenvalues), enabling reconstruction
and forecasting.

# Fields
- `modes::Vector{ComplexF64}`: DMD spatial modes (eigenmodes of dynamics matrix)
- `evals::Vector{ComplexF64}`: Eigenvalues controlling temporal evolution
- `rank::Int`: Truncation rank for low-rank approximation

An unfitted DMD model has empty modes and evals; fitting populates them.

# Algorithm (SVD-based DMD)
1. Construct data matrix: X = [x₁, x₂, ..., x_{n-1}] and Y = [x₂, x₃, ..., x_n]
2. Compute SVD: X ≈ UΣVᵀ (truncated to rank r)
3. Compute A ≈ YVΣ⁻¹Uᵀ (reduced dynamics matrix)
4. Compute eigendecomposition: A = WΛW⁻¹
5. Extract modes and eigenvalues from Λ and W

# References
Schmid, P. J. (2010). Dynamic mode decomposition of numerical and experimental data.
Journal of Fluid Mechanics, 656, 5-28.
"""
struct DMD <: AbstractHRVModel
    modes::Vector{ComplexF64}  # Spatial modes (columns of W)
    evals::Vector{ComplexF64}  # Eigenvalues (diagonal of Λ)
    rank::Int  # Truncation rank for SVD
end

"""
    DMD(; rank=5)

Create an unfitted DMD model with specified truncation rank.

The rank parameter controls the dimensionality of the learned subspace.
Higher rank captures more detail but risks overfitting.
"""
function DMD(; rank=5)
    return DMD(ComplexF64[], ComplexF64[], rank)
end

"""
    fit(model::DMD, data::Vector{Float64}) -> DMD

Fit a DMD model to IBI time series data.

# Arguments
- `model::DMD`: DMD model instance (rank is used)
- `data::Vector{Float64}`: IBI time series data

# Returns
- `DMD`: Fitted model with populated modes and eigenvalues

# Algorithm
1. Center data to zero mean
2. Construct Hankel-like data matrices (X, Y)
3. Perform SVD of X truncated to specified rank
4. Compute reduced dynamics matrix A
5. Compute eigendecomposition to extract modes and eigenvalues
"""
function fit(model::DMD, data::Vector{Float64})::DMD
    using LinearAlgebra

    # Need at least rank+1 data points
    if length(data) < model.rank + 1
        @warn "DMD: data length ($(length(data))) < rank+1 ($(model.rank+1)), returning unfitted model"
        return model
    end

    # Center data
    data_centered = data .- mean(data)

    # Construct data matrices X and Y
    # X: [x₁, x₂, ..., x_{n-1}]
    # Y: [x₂, x₃, ..., x_n]
    n = length(data_centered) - 1
    X = data_centered[1:n]'  # 1×n
    Y = data_centered[2:n+1]'  # 1×n

    # Perform SVD of X
    U, Σ, V = svd(X)

    # Truncate to specified rank
    r = min(model.rank, length(Σ))
    U_r = U[:, 1:r]
    Σ_r = Σ[1:r]
    V_r = V[:, 1:r]

    # Compute reduced dynamics matrix: A = Y * V_r * Σ_r^{-1} * U_r'
    # For 1D case, this simplifies to a scalar
    A = Y * V_r * Diagonal(1.0 ./ Σ_r) * U_r'

    # Compute eigendecomposition of A
    try
        eigvals_A, eigvecs_A = eigen(A)

        # Extract modes and eigenvalues
        modes = vec(eigvecs_A)  # Convert to vector
        evals = eigvals_A

        return DMD(modes, evals, r)
    catch
        # If eigendecomposition fails, return unfitted model
        @warn "DMD: eigendecomposition failed, returning unfitted model"
        return model
    end
end

"""
    simulate(model::DMD, params::Nothing, n_beats::Int) -> Vector{Float64}

Reconstruct or forecast IBIs using fitted DMD modes.

# Arguments
- `model::DMD`: Fitted DMD model
- `params::Nothing`: DMD has no parameters (data-driven)
- `n_beats::Int`: Number of beats to reconstruct

# Returns
- `Vector{Float64}`: Reconstructed/forecasted IBI series

# Algorithm
1. Initialize with random projection onto mode space
2. Iterate: x_{n+1} = Σᵢ λᵢ wᵢ (x_n · wᵢ)
3. Extract real part and scale to physiological range
"""
function simulate(model::DMD, params::Nothing, n_beats::Int)::Vector{Float64}
    using LinearAlgebra

    # Check if model is fitted
    if isempty(model.modes) || isempty(model.evals)
        @warn "DMD: model not fitted, returning default IBIs"
        return fill(800.0, n_beats)
    end

    # Initialize condition: random projection onto mode space
    r = length(model.modes)
    coeffs = randn(ComplexF64, r)

    # Normalize initial condition
    coeffs ./= norm(coeffs)

    # Reconstruct/forecast
    reconstructed = Float64[]

    for step in 1:n_beats
        # Compute current state: x = Σᵢ aᵢ * wᵢ * λᵢ^step
        x = sum(coeffs[i] * model.modes[i] * (model.evals[i]^step) for i in 1:r)

        # Extract real part and scale
        x_real = real(x)

        # Scale to physiological range
        # Map [-∞, ∞] to [300, 2000] ms
        x_scaled = 800.0 + x_real * 100.0  # Rough scaling

        # Clamp to physiological range
        x_clipped = max(300.0, min(2000.0, x_scaled))

        push!(reconstructed, x_clipped)
    end

    return reconstructed
end

# TODO: Phase 3 - Model implementations will be added here:
# - fit() implementations for LIF, Van der Pol, Lorenz
# - Bayesian inference wrappers

"""
    __init__()

Initialize the models extension. Called automatically when required dependencies are loaded.
"""
function __init__()
    # This function is called automatically when the extension is loaded
    # Can be used for setup, precompilation hints, etc.
end

end  # HeartRateLabModelsExt
