# LIF Cardiac Pacemaker Model Refactoring

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor LIF model to be a physiologically accurate cardiac pacemaker neuron using DifferentialEquations.jl with callbacks, simplifying fitting to only optimize input current I.

**Architecture:** Replace manual Euler integration with DiffEq ODE solver and callback-based spike detection. Use fixed physiological parameters (τ=200ms, V_rest=-65mV, V_threshold=-60mV, R=10Ω) and only fit the input current I to match observed IBI patterns. Add slope field visualization to demonstrate model dynamics.

**Tech Stack:** DifferentialEquations.jl (callbacks), Turing.jl (Bayesian fitting), Optim.jl (gradient fitting), Makie.jl (slope field visualization), Quarto (notebook rendering)

---

## Task 1: Update LIF Model Structure with Physiological Parameters

**Files:**
- Modify: `src/Models/LIF.jl:1-20`

**Context:** Current LIF model uses arbitrary units and variable parameters. Need to update to fixed physiological parameters for cardiac pacemaker.

**Step 1: Write failing test for new LIF structure**

```bash
# Open test file
```

Add to `test/test_models.jl` after line 255:

```julia
@testset "LIF Cardiac Pacemaker Model - New Structure" begin
    # Test 1: Create LIF with physiological defaults
    lif = HeartRateLab.Models.LIF()

    @test lif.τ ≈ 200.0  # Cardiac pacemaker time constant
    @test lif.V_rest ≈ -65.0  # Resting potential in mV
    @test lif.V_threshold ≈ -60.0  # Spike threshold in mV
    @test lif.R ≈ 10.0  # Membrane resistance in MΩ
    @test lif.V_reset ≈ -65.0  # Reset voltage equals resting

    # Test 2: Create LIF with custom I value
    lif_custom = HeartRateLab.Models.LIF(I=1.52)
    @test lif_custom.I ≈ 1.52
end
```

**Step 2: Run test to verify it fails**

Run: `nix run .#test`
Expected: FAIL with "field I not found" or similar

**Step 3: Update LIF struct definition**

In `src/Models/LIF.jl`, replace lines 1-20 with:

```julia
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
    τ::Float64          # Membrane time constant (ms)
    V_rest::Float64     # Resting potential (mV)
    V_reset::Float64    # Reset potential (mV)
    V_threshold::Float64  # Spike threshold (mV)
    R::Float64          # Membrane resistance (MΩ)
    I::Float64          # Input current (fitted parameter)
end

# Constructor with physiological defaults, only I is variable
LIF(; I=1.52) = LIF(200.0, -65.0, -65.0, -60.0, 10.0, I)
```

**Step 4: Run test to verify structure passes**

Run: `nix run .#test`
Expected: Test 1 and 2 pass

**Step 5: Commit**

```bash
git add src/Models/LIF.jl test/test_models.jl
git commit -m "feat(LIF): Update model structure to cardiac pacemaker with physiological parameters

- Fixed physiological params: τ=200ms, V_rest=-65mV, V_threshold=-60mV, R=10MΩ
- Single fitted parameter: I (input current)
- Added comprehensive tests for new structure

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Update parameter_space() for Single Parameter

**Files:**
- Modify: `src/Models/LIF.jl:22-55`

**Step 1: Write failing test for new parameter space**

Add to test file after previous test:

```julia
@testset "LIF Parameter Space - I Only" begin
    lif = HeartRateLab.Models.LIF()
    ps = HeartRateLab.Models.parameter_space(lif)

    # Only I parameter should be in parameter space
    @test haskey(ps, :I)
    @test !haskey(ps, :τ)  # Fixed, not fitted
    @test !haskey(ps, :threshold)  # Fixed, not fitted
    @test !haskey(ps, :noise_amp)  # No noise in deterministic model

    # I should have reasonable bounds for cardiac pacemaker
    @test ps.I.lower ≈ 1.48
    @test ps.I.upper ≈ 1.56
    @test ps.I.prior !== nothing
end
```

**Step 2: Run test to verify it fails**

Run: `nix run .#test`
Expected: FAIL - multiple parameters still returned

**Step 3: Replace parameter_space() function**

In `src/Models/LIF.jl`, replace lines 22-55 with:

```julia
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
```

**Step 4: Run test to verify it passes**

Run: `nix run .#test`
Expected: Parameter space test passes

**Step 5: Commit**

```bash
git add src/Models/LIF.jl test/test_models.jl
git commit -m "feat(LIF): Simplify parameter_space to only I

- Only input current I is fitted (1.48-1.56 range)
- All other parameters are physiologically fixed
- Prior centered at 1.52 for normal resting heart rate

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Implement simulate() using DifferentialEquations.jl with Callbacks

**Files:**
- Modify: `src/Models/LIF.jl:57-125`

**Context:** Replace manual Euler integration with DiffEq ODE solver. Use callback to detect spike and record IBI.

**Step 1: Write failing test for DiffEq-based simulation**

Add to test file:

```julia
@testset "LIF Simulation - DiffEq with Callbacks" begin
    lif = HeartRateLab.Models.LIF(I=1.52)

    # Test 1: Simulate produces correct number of IBIs
    ibis = HeartRateLab.Models.simulate(lif, (I=1.52,), 50)
    @test length(ibis) == 50

    # Test 2: IBIs are in physiological range (800-1000 ms for I=1.52)
    @test all(ibis .> 0)
    @test all(700 .< ibis .< 1100)  # Allow 10% tolerance
    @test 800 < mean(ibis) < 1000

    # Test 3: Lower I produces longer IBIs (slower heart rate)
    ibis_low = HeartRateLab.Models.simulate(lif, (I=1.50,), 50)
    @test mean(ibis_low) > mean(ibis)

    # Test 4: Higher I produces shorter IBIs (faster heart rate)
    ibis_high = HeartRateLab.Models.simulate(lif, (I=1.54,), 50)
    @test mean(ibis_high) < mean(ibis)

    # Test 5: No randomness - deterministic for same params
    ibis_repeat = HeartRateLab.Models.simulate(lif, (I=1.52,), 50)
    @test ibis ≈ ibis_repeat
end
```

**Step 2: Run test to verify it fails**

Run: `nix run .#test`
Expected: FAIL - simulate not yet implemented with DiffEq

**Step 3: Implement simulate() with DifferentialEquations.jl**

Replace lines 57-125 in `src/Models/LIF.jl` with:

```julia
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
    # Estimate: at I=1.52, IBI ≈ 90ms model time, so need ~90*n_beats*1.5 for safety
    tspan = (0.0, 150.0 * n_beats)

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
```

**Step 4: Run test to verify it passes**

Run: `nix run .#test`
Expected: All simulation tests pass

**Step 5: Commit**

```bash
git add src/Models/LIF.jl test/test_models.jl
git commit -m "feat(LIF): Implement DiffEq-based simulate with callbacks

- Replace manual Euler integration with ODE solver (Tsit5)
- Use ContinuousCallback for accurate spike detection
- Convert model time to physiological time (×10 scaling)
- Deterministic simulation for reproducibility
- Comprehensive tests for IBI ranges and I sensitivity

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Update fit() Bayesian Method for Single Parameter

**Files:**
- Modify: `src/Models/LIF.jl:127-203`

**Step 1: Write failing test for simplified Bayesian fitting**

Add to test file:

```julia
@testset "LIF Fit - Bayesian I Only" begin
    # Generate synthetic data with known I
    lif_true = HeartRateLab.Models.LIF(I=1.52)
    synthetic_data = HeartRateLab.Models.simulate(lif_true, (I=1.52,), 100)

    # Fit model to recover I
    fitted = HeartRateLab.Models.fit(lif_true, synthetic_data;
                                     method=:bayesian, chains=2, samples=50)

    # Test 1: Fitting completed
    @test fitted isa HeartRateLab.Models.ModelFitResult
    @test fitted.method == :bayesian

    # Test 2: Recovered I close to true value
    @test 1.50 < fitted.params.I < 1.54
    @test abs(fitted.params.I - 1.52) < 0.05

    # Test 3: Posterior exists and has correct structure
    @test fitted.posterior !== nothing
    @test haskey(fitted.posterior, "I")
    @test length(fitted.posterior["I"]) == 50 * 2  # samples * chains

    # Test 4: Diagnostics include R-hat
    @test haskey(fitted.diagnostics, "rhat_I")
    @test fitted.diagnostics["rhat_I"] < 1.1  # Good convergence
end
```

**Step 2: Run test to verify it fails**

Run: `nix run .#test`
Expected: FAIL - still fitting multiple parameters

**Step 3: Replace Bayesian fit() implementation**

In `src/Models/LIF.jl`, replace lines 132-203 (Bayesian section only) with:

```julia
    if method == :bayesian
        # Define Turing model for Bayesian inference (only I is fitted)
        @model function lif_model(ibi_data)
            n_beats = length(ibi_data)

            # Prior for I (input current) - only parameter to fit
            I ~ Distributions.truncated(Distributions.Normal(1.52, 0.02), 1.48, 1.56)

            # Observation noise
            σ_noise ~ Distributions.Exponential(10.0)

            # Simulate model with current I
            params = (I=I,)
            try
                predicted_ibi = simulate(model, params, n_beats)
                # Likelihood: observed IBIs ~ predicted IBIs with Gaussian noise
                ibi_data ~ MvNormal(predicted_ibi, σ_noise)
            catch
                # If simulation fails (I too low/high), assign very low likelihood
                Turing.@addlogprob! -Inf
            end
        end

        # Fit using NUTS sampler with threading
        turing_model = lif_model(data)
        chain = sample(turing_model, NUTS(0.65), MCMCThreads(),
                      samples, chains, progress=true)

        # Extract MAP estimate (posterior mean)
        params_map = (I = mean(chain[:I]),)

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
```

**Step 4: Run test to verify it passes**

Run: `nix run .#test`
Expected: Bayesian fitting test passes

**Step 5: Commit**

```bash
git add src/Models/LIF.jl test/test_models.jl
git commit -m "feat(LIF): Simplify Bayesian fitting to only fit I

- Single parameter inference (input current I)
- Tight prior around physiological range (1.48-1.56)
- Test verifies I recovery within 5% of true value
- Reduced computational cost vs multi-parameter fit

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Update fit() Gradient Method for Single Parameter

**Files:**
- Modify: `src/Models/LIF.jl:205-290`

**Step 1: Write failing test for gradient fitting**

Add to test file:

```julia
@testset "LIF Fit - Gradient I Only" begin
    lif_true = HeartRateLab.Models.LIF(I=1.52)
    synthetic_data = HeartRateLab.Models.simulate(lif_true, (I=1.52,), 100)

    # Gradient-based fit
    fitted = HeartRateLab.Models.fit(lif_true, synthetic_data; method=:gradient)

    # Test 1: Fitting completed
    @test fitted.method == :gradient
    @test fitted.params.I isa Float64

    # Test 2: Recovered I close to true value
    @test 1.50 < fitted.params.I < 1.54
    @test abs(fitted.params.I - 1.52) < 0.05

    # Test 3: Convergence diagnostics
    @test fitted.diagnostics["converged"] == true
    @test fitted.diagnostics["loss_final"] < 0.01
end
```

**Step 2: Run test to verify it fails**

Run: `nix run .#test`
Expected: FAIL - still fitting 4 parameters

**Step 3: Replace gradient fit() implementation**

In `src/Models/LIF.jl`, replace lines 205-290 (gradient section) with:

```julia
    elseif method == :gradient
        # Gradient-based optimization (only I is fitted)
        real_features = extract_feature_set(data)
        feature_names = ["mean", "sdnn", "rmssd"]

        # Define loss function: MSE of key HRV features
        function loss(I_scalar)
            # I is single scalar value
            params = (I=I_scalar,)
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
                return 1e10  # Large penalty for failed simulations
            end
        end

        # Optimize using Brent's method (1D optimization)
        result = optimize(loss, 1.48, 1.56, Brent())

        # Extract optimized parameter
        params_map = (I = result.minimizer,)

        # Extract diagnostics
        diagnostics = Dict(
            "method" => "Brent (1D optimization)",
            "converged" => Optim.converged(result),
            "iterations" => result.iterations,
            "loss_final" => result.minimum
        )

        return ModelFitResult(
            model,
            :gradient,
            params_map,
            nothing,  # No posterior for gradient fitting
            diagnostics,
            data
        )

    else
        error("LIF supports :bayesian and :gradient fitting methods")
    end
end
```

**Step 4: Run test to verify it passes**

Run: `nix run .#test`
Expected: Gradient fitting test passes

**Step 5: Commit**

```bash
git add src/Models/LIF.jl test/test_models.jl
git commit -m "feat(LIF): Simplify gradient fitting to 1D optimization

- Single parameter optimization (input current I)
- Use Brent method for efficient 1D search
- Feature-space distance minimization (mean, sdnn, rmssd)
- Test verifies I recovery and convergence

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Add Comprehensive Physiological Range Tests

**Files:**
- Modify: `test/test_models.jl` (add new testset)

**Step 1: Write comprehensive physiological tests**

Add new testset at end of LIF section in `test/test_models.jl`:

```julia
@testset "LIF Physiological Validation" begin
    # Test 1: I=1.48 produces slow heart rate (< 60 BPM, IBI > 1000ms)
    lif_slow = HeartRateLab.Models.LIF(I=1.48)
    ibis_slow = HeartRateLab.Models.simulate(lif_slow, (I=1.48,), 50)
    mean_ibi_slow = mean(ibis_slow)
    bpm_slow = 60000 / mean_ibi_slow

    @test mean_ibi_slow > 1000  # Slow heart rate
    @test bpm_slow < 60  # Bradycardia range
    @test all(950 .< ibis_slow .< 1500)  # All IBIs physiological

    # Test 2: I=1.52 produces normal heart rate (60-80 BPM, 800-1000ms IBI)
    lif_normal = HeartRateLab.Models.LIF(I=1.52)
    ibis_normal = HeartRateLab.Models.simulate(lif_normal, (I=1.52,), 50)
    mean_ibi_normal = mean(ibis_normal)
    bpm_normal = 60000 / mean_ibi_normal

    @test 800 < mean_ibi_normal < 1000  # Normal IBI
    @test 60 < bpm_normal < 80  # Normal heart rate
    @test all(700 .< ibis_normal .< 1100)  # All IBIs physiological

    # Test 3: I=1.56 produces fast heart rate (> 80 BPM, IBI < 800ms)
    lif_fast = HeartRateLab.Models.LIF(I=1.56)
    ibis_fast = HeartRateLab.Models.simulate(lif_fast, (I=1.56,), 50)
    mean_ibi_fast = mean(ibis_fast)
    bpm_fast = 60000 / mean_ibi_fast

    @test mean_ibi_fast < 800  # Fast heart rate
    @test bpm_fast > 80  # Tachycardia range
    @test all(600 .< ibis_fast .< 850)  # All IBIs physiological

    # Test 4: Monotonic relationship - higher I → shorter IBI
    @test mean_ibi_slow > mean_ibi_normal > mean_ibi_fast
    @test bpm_slow < bpm_normal < bpm_fast

    # Test 5: Standard deviation increases slightly with I
    @test std(ibis_normal) > 0  # Some variability even in deterministic model

    # Test 6: All IBIs remain in physiological range (300-2000ms)
    all_ibis = vcat(ibis_slow, ibis_normal, ibis_fast)
    @test all(300 .< all_ibis .< 2000)
    @test minimum(all_ibis) > 300
    @test maximum(all_ibis) < 2000
end
```

**Step 2: Run tests to verify they pass**

Run: `nix run .#test`
Expected: All 6 physiological validation tests pass

**Step 3: Commit**

```bash
git add test/test_models.jl
git commit -m "test(LIF): Add comprehensive physiological validation tests

- Test slow (I=1.48), normal (I=1.52), fast (I=1.56) heart rates
- Verify BPM ranges: bradycardia (<60), normal (60-80), tachycardia (>80)
- Confirm monotonic I-to-IBI relationship
- Ensure all IBIs in physiological range (300-2000ms)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Add Slope Field Visualization to Notebook

**Files:**
- Modify: `docs/flagship_demo.qmd:146-170`

**Context:** Replace existing LIF phase portrait with slope field visualization using streamplot.

**Step 1: Update LIF model section in notebook**

Replace lines 146-170 in `docs/flagship_demo.qmd` with:

```julia
### The Leaky Integrate-and-Fire (LIF) Model

The LIF model represents the heart's sinoatrial node as a large-τ pacemaker neuron.
Unlike typical neurons (τ~10-20ms), cardiac pacemaker cells have τ=200ms, creating
slower, more stable oscillations suitable for heart rhythm generation.

#### Model Equation

The membrane potential V evolves according to:

$$\\tau \\frac{dV}{dt} = -(V - V_{rest}) + R \\cdot I$$

When V crosses the threshold V_threshold = -60mV, a spike occurs and V resets to
V_reset = -65mV. The time between spikes (multiplied by 10) gives the inter-beat
interval (IBI) in milliseconds.

#### Fixed Physiological Parameters
- τ = 200 ms (membrane time constant)
- V_rest = -65 mV (resting potential)
- V_reset = -65 mV (reset potential)
- V_threshold = -60 mV (spike threshold)
- R = 10 MΩ (membrane resistance)

#### Fitted Parameter
- I = input current (typically 1.51-1.53 for normal heart rate)

```{julia}
# Create LIF model with normal heart rate parameters
lif = HeartRateLab.Models.LIF(I=1.52)

println("LIF Cardiac Pacemaker Model:")
println("  τ = $(lif.τ) ms")
println("  V_rest = $(lif.V_rest) mV")
println("  V_threshold = $(lif.V_threshold) mV")
println("  R = $(lif.R) MΩ")
println("  I = $(lif.I) (input current)")
```

#### Slope Field Visualization

The slope field shows how the membrane potential changes over time for different
voltages. The red dashed line indicates V_threshold where spikes occur.

```{julia}
using CairoMakie

# Create voltage range around physiological values
V_range = range(-70, -55, length=20)
t_range = range(0, 500, length=20)

# Compute slope field: dV/dt = -(V - V_rest) + R*I) / τ
function dVdt(V, I_val)
    return (-(V - lif.V_rest) + lif.R * I_val) / lif.τ
end

# Create meshgrid
V_grid = [V for V in V_range, t in t_range]
t_grid = [t for V in V_range, t in t_range]

# Compute slopes for different I values
I_values = [1.48, 1.52, 1.56]  # Slow, normal, fast
colors = [:blue, :green, :red]
labels = ["I=1.48 (slow)", "I=1.52 (normal)", "I=1.56 (fast)"]

fig = Figure(size=(900, 600))
ax = Axis(fig[1, 1],
         xlabel="Time (ms)",
         ylabel="Membrane Potential (mV)",
         title="LIF Cardiac Pacemaker Slope Field")

for (idx, I_val) in enumerate(I_values)
    # Compute vector field
    dV_grid = dVdt.(V_grid, I_val)
    dt_grid = ones(size(t_grid))

    # Normalize for streamplot
    magnitude = sqrt.(dt_grid.^2 .+ dV_grid.^2)
    u = dt_grid ./ magnitude
    v = dV_grid ./ magnitude

    # Plot streamplot
    streamplot!(ax, t_range, V_range,
               (t, V) -> Point2f(1.0, dVdt(V, I_val)),
               arrow_size=10, color=colors[idx],
               linewidth=1.5, alpha=0.6)
end

# Add threshold and rest lines
hlines!(ax, [lif.V_threshold], color=:red, linestyle=:dash, linewidth=2, label="Threshold")
hlines!(ax, [lif.V_rest], color=:black, linestyle=:dot, linewidth=2, label="Resting")

# Add legend
axislegend(ax, [labels..., "Threshold", "Resting"], position=:rb)

fig
```

#### Simulate Different Heart Rates

```{julia}
# Simulate IBIs for slow, normal, and fast heart rates
ibis_slow = HeartRateLab.Models.simulate(lif, (I=1.48,), 30)
ibis_normal = HeartRateLab.Models.simulate(lif, (I=1.52,), 30)
ibis_fast = HeartRateLab.Models.simulate(lif, (I=1.56,), 30)

# Calculate heart rates in BPM
bpm_slow = 60000 / mean(ibis_slow)
bpm_normal = 60000 / mean(ibis_normal)
bpm_fast = 60000 / mean(ibis_fast)

println("\nHeart Rate Analysis:")
println("  Slow   (I=1.48): $(round(mean(ibis_slow); digits=1)) ms IBI = $(round(bpm_slow; digits=1)) BPM")
println("  Normal (I=1.52): $(round(mean(ibis_normal); digits=1)) ms IBI = $(round(bpm_normal; digits=1)) BPM")
println("  Fast   (I=1.56): $(round(mean(ibis_fast); digits=1)) ms IBI = $(round(bpm_fast; digits=1)) BPM")
```

```{julia}
# Plot IBI time series comparison
fig2 = Figure(size=(900, 600))
ax2 = Axis(fig2[1, 1],
          xlabel="Beat Number",
          ylabel="IBI (ms)",
          title="LIF Model: IBI Time Series for Different Input Currents")

lines!(ax2, 1:30, ibis_slow, color=:blue, linewidth=2, label="I=1.48 (slow)")
lines!(ax2, 1:30, ibis_normal, color=:green, linewidth=2, label="I=1.52 (normal)")
lines!(ax2, 1:30, ibis_fast, color=:red, linewidth=2, label="I=1.56 (fast)")

hlines!(ax2, [800, 1000], color=:gray, linestyle=:dash, alpha=0.5)

axislegend(ax2, position=:rt)

fig2
```
```

**Step 2: Verify notebook renders**

Run: `nix run .#render`
Expected: Notebook renders without errors, shows slope field and IBI plots

**Step 3: Commit**

```bash
git add docs/flagship_demo.qmd
git commit -m "docs(LIF): Add slope field visualization to flagship demo

- Replace phase portrait with CairoMakie streamplot
- Show slope fields for slow/normal/fast heart rates (I=1.48/1.52/1.56)
- Add IBI time series comparison plot
- Document physiological parameters and model equation
- Verify rendering with nix run .#render

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Update MEMORY.md with LIF Refactoring Notes

**Files:**
- Modify: `memory/MEMORY.md`

**Step 1: Add LIF refactoring section**

Add to end of `memory/MEMORY.md`:

```markdown
## ✅ COMPLETED: LIF Cardiac Pacemaker Refactoring (Feb 24, 2026)

**Goal**: Convert LIF from generic neural model to physiologically accurate cardiac pacemaker

**Key Changes**:
1. **Fixed physiological parameters** (no longer fitted):
   - τ = 200 ms (cardiac pacemaker time constant)
   - V_rest = V_reset = -65 mV (resting/reset potential)
   - V_threshold = -60 mV (spike threshold)
   - R = 10 MΩ (membrane resistance)

2. **Single fitted parameter**: I (input current, range 1.48-1.56)
   - I = 1.48 → slow heart rate (<60 BPM, bradycardia)
   - I = 1.52 → normal heart rate (60-80 BPM)
   - I = 1.56 → fast heart rate (>80 BPM, tachycardia)

3. **Replaced manual Euler with DifferentialEquations.jl**:
   - ODEProblem + Tsit5 solver
   - ContinuousCallback for spike detection
   - 10× time scaling: model 80-100ms → physiological 800-1000ms

4. **Simplified fitting**:
   - Bayesian: NUTS MCMC on single parameter I
   - Gradient: Brent 1D optimization (efficient for single param)

5. **Added visualization**: Slope field in flagship_demo.qmd using CairoMakie streamplot

**Testing**: Comprehensive physiological validation tests verify BPM ranges for different I values

**Documentation**: Updated flagship_demo.qmd with model equation, parameters, and slope field

**Commits**: 8 commits covering structure, parameter_space, simulate, fit, tests, visualization
```

**Step 2: Commit**

```bash
git add memory/MEMORY.md
git commit -m "docs(memory): Document LIF cardiac pacemaker refactoring

- Record physiological parameters and I-to-BPM mapping
- Note DiffEq replacement of manual Euler
- Document simplified single-parameter fitting
- Reference flagship_demo.qmd slope field visualization

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Final Verification and Testing

**Files:**
- All modified files

**Step 1: Run full test suite**

Run: `nix run .#test`
Expected: All tests pass (including new LIF tests)

**Step 2: Render flagship demo notebook**

Run: `nix run .#render`
Expected: Notebook renders successfully with slope field visualization

**Step 3: Verify git status**

Run: `git status`
Expected: No uncommitted changes (all work committed)

**Step 4: Review commit log**

Run: `git log --oneline -10`
Expected: 8-9 commits covering all tasks

**Step 5: Create final summary commit (if needed)**

If any final tweaks needed:

```bash
git add <any-remaining-files>
git commit -m "chore(LIF): Final verification and cleanup

- Verified all tests pass (nix run .#test)
- Confirmed flagship_demo.qmd renders (nix run .#render)
- All physiological validation tests passing
- Slope field visualization displays correctly

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Summary

This plan refactors the LIF model from a generic neural simulator to a physiologically accurate cardiac pacemaker model. Key improvements:

1. **Physiological accuracy**: Fixed parameters match real cardiac pacemaker cells
2. **Simplified inference**: Single parameter (I) instead of 4, making fitting tractable
3. **Robust simulation**: DifferentialEquations.jl with callbacks for accurate spike detection
4. **Clear documentation**: Slope field visualization shows model dynamics
5. **Comprehensive testing**: Validates physiological BPM ranges across I values

**Total commits**: 8-9 focused commits following TDD principles

**Verification**: Tests pass (`nix run .#test`), notebook renders (`nix run .#render`)

**Next steps**: Plan complete - ready for execution with superpowers:executing-plans
