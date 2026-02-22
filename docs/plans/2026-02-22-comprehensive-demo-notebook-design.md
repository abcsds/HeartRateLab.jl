# Comprehensive HeartRateLab Demo Notebook Design

**Date:** 2026-02-22
**Status:** Design Complete, Implementation Blocked (Missing Library Features)
**Author:** Claude (Design Session)

## Executive Summary

This document specifies a comprehensive Quarto notebook demonstrating HeartRateLab.jl functionality from basic HRV theory through mechanistic modeling. **Development is blocked** pending implementation of critical library features (model fitting via Turing.jl).

### Current State
- ✅ Design complete and validated
- ✅ Library usage patterns defined
- ✅ Test anti-patterns documented in AGENTS.md
- ❌ **Cannot implement**: `fit()` method not yet available
- ❌ **Cannot implement**: Only VanDerPol has basic `simulate()`, no other models

### Blockers
1. **Missing fit() implementation** - Documented but not built (Turing.jl integration)
2. **Missing models** - DMD, Lorenz, LIF have sham tests but no implementations
3. **Missing parameter_space()** - Documented in interface but not implemented

---

## Notebook Structure

### Part 1: HRV Measurement Theory

**Objective:** Introduce HRV fundamentals and establish physiological context

**Content:**
- What is HRV? (Beat-to-beat variability in cardiac rhythm)
- Measurement techniques:
  - ECG: R-peak detection → RR intervals
  - PPG: Pulse detection → pulse-pulse intervals
  - Direct RR tachogram
- Inter-beat interval (IBI) series definition
- HRV analysis domains (matching Features.jl structure):
  - **Time domain**: mean, SDNN, RMSSD, pNN50, CVSD
  - **Frequency domain**: VLF, LF, HF, LF/HF ratio, Total Power
  - **Nonlinear**: SD1/SD2 (Poincaré), DFA, Sample Entropy, Hurst exponent
  - **Geometric**: Triangular index, TINN

**Implementation:**
```julia
using HeartRateLab
using CairoMakie, DataFrames, Statistics, Random

# Load test data
data_path = "../test/testdata/example.txt"
ibi_data = read_txt(data_path)

println("✓ Loaded $(length(ibi_data)) IBI samples")
println("  Duration: $(round(sum(ibi_data)/60_000; digits=1)) minutes")
println("  Range: $(round(minimum(ibi_data)))-$(round(maximum(ibi_data))) ms")
```

**Outputs:**
- Explanatory markdown with physiological background
- Loaded IBI data with summary statistics
- References to Task Force (1996) HRV standards

---

### Part 2: Data & Feature Engineering

**Objective:** Visualize IBI characteristics and extract HRV features using library functions

#### 2.1: Visualizing IBI Series (4-Panel Figure)

**Implementation:**
```julia
using CairoMakie

fig = Figure(size=(1200, 900))

# Panel 1: Time series
ax1 = Axis(fig[1, 1], xlabel="Beat #", ylabel="IBI (ms)",
           title="Inter-Beat Interval Time Series")
lines!(ax1, 1:length(ibi_data), ibi_data, color=:steelblue, linewidth=1.5)

# Panel 2: Histogram
ax2 = Axis(fig[1, 2], xlabel="IBI (ms)", ylabel="Count",
           title="IBI Distribution")
hist!(ax2, ibi_data, bins=30, color=(:coral, 0.7))

# Panel 3: Power Spectral Density
ax3 = Axis(fig[2, 1], xlabel="Frequency (Hz)", ylabel="Power (ms²/Hz)",
           title="Frequency Domain (PSD)")
pgram = Frequency.welch(ibi_data; method=:quadratic)  # ✅ Library function
lines!(ax3, pgram.freq, pgram.power, color=:darkgreen, linewidth=1.5)

# Shade frequency bands
vspan!(ax3, 0.04, 0.15, color=(:yellow, 0.2), label="LF")
vspan!(ax3, 0.15, 0.4, color=(:blue, 0.2), label="HF")

# Panel 4: Poincaré plot
ax4 = Axis(fig[2, 2], xlabel="IBIₙ (ms)", ylabel="IBIₙ₊₁ (ms)",
           title="Poincaré Plot", aspect=DataAspect())
scatter!(ax4, ibi_data[1:end-1], ibi_data[2:end],
         markersize=4, color=(:purple, 0.5))
lines!(ax4, [minimum(ibi_data), maximum(ibi_data)],
            [minimum(ibi_data), maximum(ibi_data)],
            color=:gray, linestyle=:dash)

display(fig)
```

#### 2.2: Feature Selection

**Strategy:** Exclude ULF (requires >24hr data), select representative features across domains

```julia
# Get all available features from registry
all_features = collect(keys(Features.feature_registry))
println("Total available features: $(length(all_features))")

# Exclude ULF-related features (data < 24hr)
excluded = ["ulf", "ulf_peak", "ulf_power"]
selected_features = filter(f -> !any(occursin.(excluded, lowercase(f))), all_features)

# Select diverse subset across domains
feature_subset = [
    # Time domain
    "mean", "sdnn", "rmssd", "pnn50", "cvsd",
    # Frequency domain
    "vlf_power", "lf_power", "hf_power", "lf_hf_ratio", "total_power",
    # Nonlinear
    "sd1", "sd2", "sd1_sd2_ratio", "dfa_alpha1", "sample_entropy",
    # Geometric
    "triangular_index"
]

println("\nSelected $(length(feature_subset)) features for analysis")
```

#### 2.3: Feature Extraction with Timing

**Implementation:**
```julia
# ✅ Library function: extract_feature_set()
println("\nExtracting features...")
@time feature_df = extract_feature_set(ibi_data)

# Display selected features
println("\nExtracted Features:")
display(feature_df[!, feature_subset])
```

**Outputs:**
- 4-panel Makie figure (time series, histogram, PSD, Poincaré)
- Feature selection explanation
- DataFrame with execution timing

---

### Part 3: Windowed Analysis

**Objective:** Demonstrate temporal HRV dynamics using sliding windows with z-score normalization

**Configuration:**
- Window size: 60 beats
- Step size: 1 beat (no skipping, as specified)
- Normalization: **Gaussian (z-scores)** for statistical testing, not min-max

**Implementation:**
```julia
window_size = 60
step_size = 1  # ✅ Step 1 beat at a time

println("Windowed Analysis:")
println("  Window: $window_size beats")
println("  Step: $step_size beats")

# ✅ Library function: windowed_feature_set()
@time windowed_features = windowed_feature_set(
    ibi_data,
    window_size=window_size,
    step_size=step_size
)

println("✓ Extracted features from $(nrow(windowed_features)) windows")

# Visualize with z-normalization
viz_features = ["mean", "rmssd", "pnn50", "sd1", "lf_hf_ratio", "sample_entropy"]

fig = Figure(size=(1400, 1000))

for (idx, feat) in enumerate(viz_features)
    row = ((idx-1) ÷ 3) + 1
    col = ((idx-1) % 3) + 1

    # ✅ Z-SCORE normalization (not min-max)
    values = windowed_features[!, feat]
    z_values = (values .- mean(values)) ./ std(values)

    ax = Axis(fig[row, col], xlabel="z-score", ylabel="Density",
              title="$feat (z-normalized)")

    violin!(ax, ones(length(z_values)), z_values,
            color=(:steelblue, 0.5), show_median=true)
    boxplot!(ax, ones(length(z_values)), z_values,
             width=0.3, color=(:coral, 0.7))

    # Reference lines for statistical thresholds
    hlines!(ax, [0], color=:gray, linestyle=:dash, label="μ")
    hlines!(ax, [-2, 2], color=:red, linestyle=:dot, linewidth=1, label="±2σ")
end

display(fig)

# Time evolution plot (z-normalized)
fig2 = Figure(size=(1400, 600))
ax = Axis(fig2[1, 1], xlabel="Window index", ylabel="z-score",
          title="Temporal Evolution of HRV Features")

for feat in viz_features
    values = windowed_features[!, feat]
    z_values = (values .- mean(values)) ./ std(values)
    lines!(ax, 1:nrow(windowed_features), z_values, label=feat, linewidth=2)
end

hlines!(ax, [0], color=:black, linestyle=:dash)
hlines!(ax, [-2, 2], color=:red, linestyle=:dot, linewidth=1)
axislegend(ax, position=:rt)

display(fig2)
```

**Outputs:**
- Windowed feature DataFrame
- Violin/box plots with z-score normalization
- Time evolution showing feature dynamics across recording

---

### Part 4: Mechanistic Modeling Theory

**Objective:** Show library's model architecture and current implementation status

#### 4.1: Model Interface

**Show library documentation:**
```julia
println("HeartRateLab Model Interface (from src/Models.jl):")
println("=" ^ 70)

"""
    abstract type AbstractHRVModel end

All models must implement:
- simulate(model::AbstractHRVModel, params::NamedTuple, n_beats::Int)::Vector{Float64}

Optional methods (documented but NOT YET IMPLEMENTED):
- fit(model::AbstractHRVModel, data::Vector{Float64}; method::Symbol, kwargs...)
- parameter_space(model::AbstractHRVModel)

Fitting methods (PLANNED):
- :bayesian  - MCMC via Turing.jl (posterior distributions)
- :gradient  - Optim.jl (feature-space optimization)
- :evolutionary - BlackBoxOptim.jl (genetic algorithms)
"""
```

#### 4.2: VanDerPol (Currently Implemented)

**Show actual library code:**
```julia
println("\nVan der Pol Oscillator - CURRENTLY IMPLEMENTED")
println("=" ^ 70)

"""
From src/Models.jl (lines 84-125):

    struct VanDerPol <: AbstractHRVModel end

    function simulate(model::VanDerPol, params::NamedTuple, n_beats::Int)::Vector{Float64}
        μ = get(params, :μ, 0.5)
        hr = get(params, :heart_rate, 70)
        mean_ibi = 60000 / hr
        time = range(0, 4π, length=n_beats)

        # Van der Pol: ẍ - μ(1-x²)ẋ + x = 0
        modulation = 1.0 .+ 0.3 .* μ .* sin.(time) .+ 0.1 .* μ .* cos.(2 .* time)
        ibi = mean_ibi .* modulation
        noise = randn(n_beats) .* (0.01 * mean_ibi)
        ibi = ibi .+ noise

        # Physiological bounds
        ibi = max.(ibi, 300)
        ibi = min.(ibi, 2000)

        return ibi
    end

Equation: ẍ - μ(1 - x²)ẋ + x = 0

Parameters:
- μ: nonlinearity parameter (controls oscillation amplitude)
- heart_rate: base heart rate in BPM
"""

# ✅ Demonstrate library usage
using HeartRateLab.Models: VanDerPol, simulate

vdp = VanDerPol()
params = (μ=1.2, heart_rate=70.0)
synthetic_ibi = simulate(vdp, params, 100)

println("\n✓ Generated $(length(synthetic_ibi)) synthetic IBIs")
println("  Mean: $(round(mean(synthetic_ibi); digits=1)) ms")
println("  Std: $(round(std(synthetic_ibi); digits=1)) ms")
```

**Phase portrait visualization (for education, not required by end-users):**
```julia
# ODE solution for phase portrait visualization
# Users don't need to do this - library handles simulation internally

using DifferentialEquations

function vdp_ode!(du, u, p, t)
    μ = p[1]
    du[1] = u[2]
    du[2] = μ * (1 - u[1]^2) * u[2] - u[1]
end

fig = Figure(size=(800, 600))
ax = Axis(fig[1, 1], xlabel="x", ylabel="ẋ",
          title="Van der Pol Phase Portrait (μ=$(params.μ))")

# Multiple trajectories converging to limit cycle
for (x0, y0) in [(0.5, 0.0), (2.0, 1.0), (-1.5, -1.0)]
    prob = ODEProblem(vdp_ode!, [x0, y0], (0.0, 50.0), [params.μ])
    sol = solve(prob, Tsit5())
    lines!(ax, sol[1, :], sol[2, :], color=(:steelblue, 0.6), linewidth=1.5)
end

# Highlight limit cycle
prob_lc = ODEProblem(vdp_ode!, [2.0, 0.0], (0.0, 100.0), [params.μ])
sol_lc = solve(prob_lc, Tsit5())
lines!(ax, sol_lc[1, end-300:end], sol_lc[2, end-300:end],
       color=:coral, linewidth=3, label="Limit cycle")

axislegend(ax, position=:rt)
display(fig)
```

#### 4.3: Planned Models (Not Implemented)

```julia
println("\n" * "=" ^ 70)
println("MODELS PLANNED - NOT YET IMPLEMENTED")
println("(Test specifications exist in test/test_models.jl)")
println("=" ^ 70)

"""
1. **DMD (Dynamic Mode Decomposition)** - Data-driven

   Expected API:
   dmd = HeartRateLab.Models.DMD(rank=5)
   fitted_dmd = fit(dmd, ibi_data)
   reconstructed = simulate(fitted_dmd, nothing, n_beats)

   Equation: X_{k+1} = A X_k
   - Learns linear approximation via SVD
   - Extracts dominant modes of variability

2. **Lorenz System** - Chaotic dynamics

   Expected API:
   lorenz = HeartRateLab.Models.Lorenz(σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
   ibis = simulate(lorenz, params, n_beats=40)

   Equations:
   ẋ = σ(y - x)
   ẏ = x(ρ - z) - y
   ż = xy - βz

   - Models arrhythmias and chaotic heart dynamics
   - IBI = time between z-threshold crossings

3. **LIF (Leaky Integrate-and-Fire)** - Pacemaker neuron

   Expected API:
   lif = HeartRateLab.Models.LIF(τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
   ibis = simulate(lif, params, n_beats=50)

   Equation: τ dV/dt = -V + I_base + σξ(t)
   Fire when V ≥ threshold

   - I_base represents autonomic balance (vagal/sympathetic)
   - Models SA node pacemaker dynamics
"""
```

**Outputs:**
- Library model interface documentation
- VanDerPol source code + usage + phase portrait
- Planned models with expected APIs from test specifications

---

### Part 5: Model Fitting & Validation (BLOCKED)

**Status:** ⚠️ **CANNOT IMPLEMENT - fit() method does not exist**

**Critical Missing Feature:**
The library documents a `fit()` method using Turing.jl for Bayesian parameter estimation, but **no implementation exists** in `src/Models.jl`.

**Planned Interface (Aspirational):**
```julia
# DOES NOT WORK - fit() not implemented
fit_result = fit(vdp, ibi_data; method=:bayesian, chains=4, samples=1000)

# Would return ModelFitResult with:
# - params: NamedTuple (MAP estimates)
# - posterior: Turing.Chain (full posterior distributions)
# - diagnostics: Dict (R-hat, ESS, convergence)
```

**Expected Turing.jl Implementation:**
```julia
using Turing, DifferentialEquations

@model function fit_vanderpol(ibi_data)
    # Priors
    μ ~ TruncatedNormal(1.0, 0.5, 0.1, 3.0)
    heart_rate ~ TruncatedNormal(70.0, 15.0, 40.0, 120.0)
    σ_noise ~ Exponential(10.0)

    # Simulate model
    params = (μ=μ, heart_rate=heart_rate)
    predicted_ibi = simulate(VanDerPol(), params, length(ibi_data))

    # Likelihood
    ibi_data ~ MvNormal(predicted_ibi, σ_noise)
end

# Sample posterior
chain = sample(fit_vanderpol(ibi_data), NUTS(0.65), MCMCThreads(),
               1000, 4, progress=true)
```

**Workaround (for demonstration purposes only):**
```julia
# Empirical parameter estimation (manual fitting)
mean_ibi = mean(ibi_data)
std_ibi = std(ibi_data)
cv_ibi = std_ibi / mean_ibi

empirical_params = (
    μ = cv_ibi * 3.0,  # Heuristic scaling
    heart_rate = 60000 / mean_ibi
)

println("⚠️  Using empirical estimates (NOT Bayesian fitted):")
println("  μ = $(round(empirical_params.μ; digits=3))")
println("  HR = $(round(empirical_params.heart_rate; digits=1)) BPM")

# ✅ Library usage: Generate ensemble
ensemble = simulate_ensemble(vdp, empirical_params, length(ibi_data); n_sim=100)

# ✅ Library usage: Extract features
ensemble_features = extract_ensemble_features(ensemble)
real_features = extract_feature_set(ibi_data)

# ✅ Library usage: Statistical validation
real_df = DataFrame([real_features])
ks_results = eval_distributional(real_df, ensemble_features; test=:ks)

matching = sum(ks_results.p_value .>= 0.05)
total = nrow(ks_results)

println("\n✓ KS test: $matching / $total features match real data")
println("⚠️  Match quality limited by empirical (non-fitted) parameters")
```

**Visualization:**
```julia
# Compare real vs ensemble features (z-normalized)
viz_features = ["mean", "rmssd", "sd1", "lf_hf_ratio"]

fig = Figure(size=(1400, 800))

for (idx, feat) in enumerate(viz_features)
    row = ((idx-1) ÷ 2) + 1
    col = ((idx-1) % 2) + 1

    ax = Axis(fig[row, col], xlabel="z-score", ylabel="Density",
              title="$feat (Ensemble vs Real)")

    # Ensemble distribution (z-normalized)
    ensemble_vals = ensemble_features[!, feat]
    μ_ens = mean(ensemble_vals)
    σ_ens = std(ensemble_vals)
    z_ensemble = (ensemble_vals .- μ_ens) ./ σ_ens

    violin!(ax, fill(1, length(z_ensemble)), z_ensemble,
            color=(:steelblue, 0.5), label="Ensemble", width=0.8)

    # Real data point (z-normalized)
    real_val = real_features[!, feat][1]
    real_z = (real_val - μ_ens) / σ_ens

    scatter!(ax, [1.5], [real_z], markersize=25,
             color=:red, marker=:star5, label="Real data")

    # Statistical thresholds
    hlines!(ax, [0], color=:gray, linestyle=:dash, label="μ")
    hlines!(ax, [-2, 2], color=:red, linestyle=:dot, linewidth=1, label="±2σ")

    # KS test result
    p_val = ks_results[ks_results.feature .== feat, :p_value][1]
    pass = p_val >= 0.05 ? "✓" : "✗"
    text!(ax, 1.2, 3.0, text="KS p=$pass$(round(p_val; digits=3))", fontsize=12)

    axislegend(ax, position=:rt)
end

display(fig)
```

**Outputs (with limitations):**
- Synthetic ensemble (100 realizations)
- Feature comparison with statistical validation
- ⚠️ **Limited accuracy** due to empirical (non-fitted) parameters

---

### Part 6: Animated Visualization (BLOCKED)

**Status:** ⚠️ **Limited by missing fit() - uses empirical parameters**

**Objective:** Animate Van der Pol phase space with signal generation and IBI extraction

**Implementation:**
```julia
println("=" ^ 70)
println("Part 6: Animated Visualization")
println("⚠️  Using empirical params (fit() not implemented)")
println("=" ^ 70)

using CairoMakie, DifferentialEquations

# Setup
vdp = VanDerPol()
params = empirical_params  # From Part 5

println("Animation parameters:")
println("  μ = $(round(params.μ; digits=3)) (empirical)")
println("  HR = $(round(params.heart_rate; digits=1)) BPM")

# Solve Van der Pol ODE
function vdp_ode!(du, u, p, t)
    μ, ω = p
    du[1] = u[2]
    du[2] = μ * (1 - u[1]^2) * u[2] - ω^2 * u[1]
end

ω = 2π * params.heart_rate / 60
u0 = [1.0, 0.0]
tspan = (0.0, 20.0)
prob = ODEProblem(vdp_ode!, u0, tspan, [params.μ, ω])
sol = solve(prob, Tsit5(), saveat=0.05)

# Extract IBIs via peak detection
x_trajectory = sol[1, :]
t_trajectory = sol.t

peak_indices = Int[]
for i in 2:length(x_trajectory)-1
    if x_trajectory[i] > x_trajectory[i-1] && x_trajectory[i] > x_trajectory[i+1]
        if x_trajectory[i] > 0.5
            push!(peak_indices, i)
        end
    end
end

ibi_from_trajectory = [
    (t_trajectory[peak_indices[i]] - t_trajectory[peak_indices[i-1]]) * 1000
    for i in 2:length(peak_indices)
]

println("✓ Generated trajectory: $(length(peak_indices)) beats")

# Create animated figure
fig = Figure(size=(1600, 800))

# Left: Phase space
ax_phase = Axis(fig[1:2, 1], xlabel="x", ylabel="ẋ",
                title="Van der Pol Phase Space")

scatter!(ax_phase, ibi_data[1:end-1], ibi_data[2:end],
         markersize=3, color=(:gray, 0.3), label="Real data")

trajectory_x = Observable(Float64[])
trajectory_y = Observable(Float64[])
lines!(ax_phase, trajectory_x, trajectory_y,
       color=:coral, linewidth=3, label="VdP trajectory")

current_x = Observable(u0[1])
current_y = Observable(u0[2])
scatter!(ax_phase, current_x, current_y,
         markersize=20, color=:red)

axislegend(ax_phase, position=:rb)

# Right top: Signal
ax_signal = Axis(fig[1, 2], xlabel="Time (s)", ylabel="x(t)",
                 title="Generated Signal")

signal_t = Observable(Float64[])
signal_x = Observable(Float64[])
lines!(ax_signal, signal_t, signal_x, color=:steelblue, linewidth=2)

beat_t = Observable(Float64[])
beat_x = Observable(Float64[])
scatter!(ax_signal, beat_t, beat_x,
         markersize=12, color=:red, marker=:star5)

# Right bottom: IBIs
ax_ibi = Axis(fig[2, 2], xlabel="Beat #", ylabel="IBI (ms)",
              title="Inter-Beat Intervals")

ibi_beats = Observable(Int[])
ibi_values = Observable(Float64[])
lines!(ax_ibi, ibi_beats, ibi_values,
       color=:darkgreen, linewidth=2, marker=:circle)

hlines!(ax_ibi, [60000/params.heart_rate],
        color=:gray, linestyle=:dash)

# Record animation
n_frames = min(200, length(sol.t))
frame_skip = max(1, length(sol.t) ÷ n_frames)

record(fig, "vanderpol_animation.gif", 1:frame_skip:length(sol.t); framerate=20) do frame_idx
    trajectory_x[] = sol[1, 1:frame_idx]
    trajectory_y[] = sol[2, 1:frame_idx]
    current_x[] = sol[1, frame_idx]
    current_y[] = sol[2, frame_idx]

    signal_t[] = t_trajectory[1:frame_idx]
    signal_x[] = x_trajectory[1:frame_idx]

    current_peaks = filter(p -> p <= frame_idx, peak_indices)
    beat_t[] = t_trajectory[current_peaks]
    beat_x[] = x_trajectory[current_peaks]

    if length(current_peaks) >= 2
        current_ibis = [
            (t_trajectory[current_peaks[i]] - t_trajectory[current_peaks[i-1]]) * 1000
            for i in 2:length(current_peaks)
        ]
        ibi_beats[] = 1:length(current_ibis)
        ibi_values[] = current_ibis
    end

    autolimits!(ax_signal)
    autolimits!(ax_ibi)
end

println("✓ Animation saved: vanderpol_animation.gif")
```

**Summary Dashboard:**
```julia
summary_fig = Figure(size=(1400, 1000))

Label(summary_fig[0, :],
      "HeartRateLab: Van der Pol Model Demonstration",
      fontsize=24, font=:bold)

# Panel 1: Real vs Synthetic comparison
ax1 = Axis(summary_fig[1, 1:2],
           xlabel="Beat #", ylabel="IBI (ms)",
           title="Real Data vs Synthetic (VanDerPol)")

lines!(ax1, 1:length(ibi_data), ibi_data,
       color=:black, linewidth=2, label="Real")
lines!(ax1, 1:length(ibi_from_trajectory), ibi_from_trajectory,
       color=:coral, linewidth=2, linestyle=:dash, label="Synthetic")

axislegend(ax1, position=:rt)

# Panel 2: Poincaré comparison
ax2 = Axis(summary_fig[1, 3],
           xlabel="IBIₙ", ylabel="IBIₙ₊₁",
           title="Poincaré Plot", aspect=DataAspect())

scatter!(ax2, ibi_data[1:end-1], ibi_data[2:end],
         markersize=4, color=(:black, 0.5), label="Real")
scatter!(ax2, ibi_from_trajectory[1:end-1], ibi_from_trajectory[2:end],
         markersize=4, color=(:coral, 0.5), label="Synthetic")

axislegend(ax2, position=:rb)

# Panel 3: Feature comparison
ax3 = Axis(summary_fig[2, 1:2],
           xlabel="Feature", ylabel="Normalized Value",
           title="HRV Features: Real vs Synthetic")

compare_features = ["mean", "sdnn", "rmssd", "pnn50", "sd1", "lf_hf_ratio"]
x_pos = 1:length(compare_features)

real_vals = [real_feats[!, f][1] for f in compare_features]
synth_vals = [synth_feats[!, f][1] for f in compare_features]

real_norm = real_vals ./ maximum(abs.(real_vals))
synth_norm = synth_vals ./ maximum(abs.(synth_vals))

barplot!(ax3, x_pos .- 0.2, real_norm, width=0.4,
         color=:black, label="Real")
barplot!(ax3, x_pos .+ 0.2, synth_norm, width=0.4,
         color=:coral, label="Synthetic")

ax3.xticks = (x_pos, compare_features)
ax3.xticklabelrotation = π/4

axislegend(ax3, position=:rt)

# Panel 4: Model info
ax4 = Axis(summary_fig[2, 3])
hidedecorations!(ax4)
hidespines!(ax4)

info_text = """
Van der Pol Oscillator

Equation: ẍ - μ(1-x²)ẋ + x = 0

Parameters:
• μ = $(params.μ) (empirical)
• HR = $(params.heart_rate) BPM

Statistics:
Real: μ=$(round(mean(ibi_data); digits=1)) ms
Synth: μ=$(round(mean(ibi_from_trajectory); digits=1)) ms

⚠️ Empirical parameters
   (fit() not implemented)
"""

text!(ax4, 0.1, 0.5, text=info_text, fontsize=14, align=(:left, :center))
xlims!(ax4, 0, 1)
ylims!(ax4, 0, 1)

display(summary_fig)
save("vanderpol_summary.png", summary_fig)
```

**Outputs:**
- `vanderpol_animation.gif` - Phase space + signal + IBIs
- `vanderpol_summary.png` - 4-panel comparison
- ⚠️ **Limitation noted**: Parameters not fitted, only empirical

---

### Part 7: References

```markdown
## References

### HRV Analysis Foundations

[1] Task Force of the European Society of Cardiology (1996).
    Heart rate variability: standards of measurement, physiological
    interpretation and clinical use. *Circulation*, 93(5): 1043-1065.

[2] Brennan, M., Palaniswami, M., & Kamen, P. (2001).
    Do existing measures of Poincaré plot geometry reflect nonlinear
    features of heart rate variability? *IEEE Trans Biomed Eng*, 48(11).

[3] Peng, C.K., Havlin, S., Stanley, H.E., Goldberger, A.L. (1995).
    Quantification of scaling exponents and crossover phenomena in
    nonstationary heartbeat time series. *Chaos*, 5(1): 82-87.

### Mechanistic Models

[4] van der Pol, B. (1926).
    On relaxation-oscillations. *The London, Edinburgh and Dublin
    Phil. Mag. & J. of Sci.*, 2(11): 978-992.

[5] McSharry, P.E., Clifford, G.D., Tarassenko, L., Smith, L.A. (2003).
    A dynamical model for generating synthetic electrocardiogram signals.
    *IEEE Trans Biomed Eng*, 50(3): 289-294.

[6] Glass, L. (2001).
    Synchronization and rhythmic processes in physiology.
    *Nature*, 410(6825): 277-284.

### Data-Driven Methods

[7] Kutz, J.N., Brunton, S.L., Brunton, B.W., Proctor, J.L. (2016).
    *Dynamic Mode Decomposition: Data-Driven Modeling of Complex Systems*.
    SIAM, Philadelphia.

[8] Brunton, S.L., Proctor, J.L., Kutz, J.N. (2016).
    Discovering governing equations from data by sparse identification
    of nonlinear dynamical systems. *PNAS*, 113(15): 3932-3937.

### Bayesian Inference

[9] Gelman, A., Carlin, J.B., Stern, H.S., Rubin, D.B. (2013).
    *Bayesian Data Analysis* (3rd ed). Chapman and Hall/CRC.

[10] Ge, H., Xu, K., Ghahramani, Z. (2018).
     Turing: A language for flexible probabilistic inference.
     *International Conference on Artificial Intelligence and Statistics*.

### Software

- **HeartRateLab.jl** - https://github.com/abcsds/HeartRateLab.jl
- **Makie.jl** - https://docs.makie.org
- **DifferentialEquations.jl** - https://diffeq.sciml.ai
- **Turing.jl** - https://turing.ml
```

---

## Implementation Requirements

### Dependencies

**Already in Project.toml:**
- CairoMakie (visualization)
- DataFrames (feature storage)
- Statistics (basic stats)
- StatsBase (advanced stats)

**Need to Add:**
- DifferentialEquations.jl (ODE solving for phase portraits)
- Turing.jl (Bayesian inference - when fit() is implemented)
- Optim.jl (gradient-based fitting - when fit() is implemented)

### Library Functions Used

All library functions properly showcased:
- ✅ `read_txt()` - Load IBI data
- ✅ `Frequency.welch()` - Power spectral density
- ✅ `extract_feature_set()` - Feature extraction
- ✅ `windowed_feature_set()` - Windowed analysis
- ✅ `VanDerPol()`, `simulate()` - Model usage
- ✅ `simulate_ensemble()` - Ensemble generation
- ✅ `extract_ensemble_features()` - Ensemble feature extraction
- ✅ `eval_distributional()` - Statistical validation

---

## Blockers and Required Implementation

### CRITICAL: fit() Method (Turing.jl Integration)

**What's Missing:**
```julia
# This function does NOT exist in src/Models.jl
function fit(model::VanDerPol, data::Vector{Float64};
             method::Symbol=:bayesian, kwargs...)
    if method == :bayesian
        # Turing.jl MCMC sampling
        # Sample posterior distributions for μ and heart_rate
        # Return ModelFitResult with chain
    elseif method == :gradient
        # Optim.jl optimization
        # Minimize feature-space distance
        # Return ModelFitResult with point estimate
    else
        error("Unknown method: $method")
    end
end
```

**Implementation Requirements:**
1. Define Turing `@model` with priors for parameters
2. Implement likelihood function (feature-space or direct IBI matching)
3. Sample posterior using NUTS sampler
4. Extract MAP estimates and diagnostics
5. Return `ModelFitResult` struct

**Impact:**
- Cannot demonstrate Bayesian parameter estimation
- Cannot show posterior distributions
- Cannot properly fit model to real data
- Animation uses empirical (not fitted) parameters

### CRITICAL: parameter_space() Method

**What's Missing:**
```julia
# This function does NOT exist in src/Models.jl
function parameter_space(model::VanDerPol)
    return (
        μ = (lower=0.1, upper=3.0, prior=TruncatedNormal(1.0, 0.5, 0.1, 3.0)),
        heart_rate = (lower=40.0, upper=120.0, prior=TruncatedNormal(70.0, 15.0, 40.0, 120.0))
    )
end
```

**Impact:**
- Cannot define prior distributions
- Cannot validate parameter bounds

### Other Missing Models

**DMD, Lorenz, LIF:**
- Have comprehensive test specifications
- Tests are "sham tests" - wrapped in try/catch that silently skip
- No actual implementations in src/Models.jl

---

## Test Anti-Patterns Discovered

### Sham Tests in test/test_models.jl

**Problem:**
```julia
try
    @testset "DMD Model" begin
        dmd = HeartRateLab.Models.DMD(rank=5)  # DMD doesn't exist!
        @test dmd.rank == 5
    end
catch err
    @warn "Skipping DMD model tests - LinearAlgebra not available" exception=err
end
```

**Why Toxic:**
1. Misleading error message (LinearAlgebra IS available)
2. Tests silently skip instead of failing
3. False sense of test coverage
4. Violates TDD principles (tests should fail until implementation exists)

**Solution:**
Use `@test_broken` or `@test_skip` for unimplemented features:
```julia
@testset "DMD Model (NOT YET IMPLEMENTED)" begin
    @test_broken begin
        dmd = HeartRateLab.Models.DMD(rank=5)
        @test dmd.rank == 5
    end
end
```

**Documented in:** `AGENTS.md` - "Testing Standards and Anti-Patterns"

---

## Development Status Summary

| Component | Status | Notes |
|-----------|--------|-------|
| **Parts 1-3** | ✅ Ready | Uses only implemented features |
| **Part 4 (VanDerPol)** | ✅ Ready | Shows actual library code |
| **Part 4 (Other models)** | ⚠️ Theory only | DMD/Lorenz/LIF not implemented |
| **Part 5 (Fitting)** | ❌ Blocked | `fit()` method doesn't exist |
| **Part 6 (Animation)** | ⚠️ Limited | Uses empirical params, not fitted |
| **References** | ✅ Ready | Complete bibliography |

---

## Recommendations

### For Immediate Implementation

**Priority 1: Parts 1-3**
- Can be implemented immediately
- Showcase core library features (IO, preprocessing, feature extraction, windowing)
- No blockers

**Priority 2: Part 4 (VanDerPol)**
- Show library usage of `simulate()`
- Educational phase portraits (manual ODE for visualization only)
- Clear documentation of what's implemented vs planned

### For Future Work (After fit() Implementation)

**Priority 3: Complete Part 5**
- Implement `fit()` with Turing.jl
- Implement `parameter_space()`
- Show Bayesian parameter estimation with posterior distributions

**Priority 4: Complete Part 6**
- Use fitted parameters (not empirical)
- Show uncertainty in animation (posterior samples)

### For Clean Codebase

**Fix Sham Tests:**
- Replace try/catch blocks with `@test_broken`
- Make tests fail loudly for unimplemented features
- Accurate error messages

---

## Conclusion

This design provides a comprehensive demonstration of HeartRateLab.jl, from basic HRV theory through mechanistic modeling. However, **implementation is blocked** pending critical library features:

1. **`fit()` method with Turing.jl** - Documented but not built
2. **`parameter_space()` method** - Documented but not built
3. **Other models (DMD, Lorenz, LIF)** - Tested but not implemented

The notebook can be **partially implemented** (Parts 1-4) to showcase existing functionality, but the core demonstration of Bayesian model fitting (Part 5-6) requires significant library development first.

**Recommended Next Steps:**
1. Implement Parts 1-3 immediately (no blockers)
2. Implement Part 4 with current VanDerPol
3. Document Parts 5-6 as "Future Work" sections
4. Fix sham tests in test/test_models.jl
5. Build `fit()` and `parameter_space()` methods
6. Return to complete Parts 5-6 once library is ready
