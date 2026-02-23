# Complete Model Fitting & Visualization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement fit() method, parameter_space() method, complete all 4 models (VanDerPol, Lorenz, LIF, DMD), and implement all 9 visualization functions to create a production-complete HRV modeling library.

**Architecture:**
- Unified fit() interface using Turing.jl (Bayesian) and Optim.jl (gradient) backends
- parameter_space() defines priors for each model
- All models inherit from AbstractHRVModel with simulate() and fit() methods
- Visualization functions build on CairoMakie with consistent styling

**Tech Stack:**
- Turing.jl (MCMC/Bayesian inference)
- DifferentialEquations.jl (ODE solving for VanDerPol, Lorenz, LIF)
- Optim.jl (gradient-based optimization)
- CairoMakie (visualization backend)
- MCMCChains.jl (posterior diagnostics)

---

## Phase 1: Foundation - fit() and parameter_space() Methods

### Task 1.1: Implement parameter_space() for VanDerPol

**Files:**
- Modify: `src/Models.jl:84-200` (VanDerPol struct and methods)
- Test: `test/test_models.jl:72-170` (VanDerPol tests)

**Step 1: Read existing VanDerPol struct**

Run: `grep -A 30 "struct VanDerPol" src/Models.jl`

Expected output shows the struct definition around line 84.

**Step 2: Write test for parameter_space()**

Edit `test/test_models.jl` to add test after line 76:

```julia
@testset "VanDerPol parameter_space" begin
    vdp = VanDerPol()
    ps = parameter_space(vdp)

    # Check all parameters exist
    @test haskey(ps, :μ)
    @test haskey(ps, :heart_rate)
    @test haskey(ps, :σ_noise)

    # Check bounds structure
    @test haskey(ps.μ, :lower)
    @test haskey(ps.μ, :upper)
    @test ps.μ.lower < ps.μ.upper
end
```

**Step 3: Run test to verify it fails**

Run: `nix run .#test -- test/test_models.jl 2>&1 | grep -A 5 "VanDerPol parameter_space"`

Expected: FAIL with "parameter_space is not defined"

**Step 4: Implement parameter_space() for VanDerPol**

Add to `src/Models.jl` after VanDerPol struct (around line 95):

```julia
function parameter_space(model::VanDerPol)
    return (
        μ = (lower=0.1, upper=3.0),
        heart_rate = (lower=40.0, upper=120.0),
        σ_noise = (lower=1.0, upper=50.0)
    )
end
```

**Step 5: Run test to verify it passes**

Run: `nix run .#test -- test/test_models.jl 2>&1 | grep -A 2 "VanDerPol parameter_space"`

Expected: PASS

**Step 6: Commit**

```bash
git add src/Models.jl test/test_models.jl
git commit -m "feat: implement parameter_space() for VanDerPol model"
```

---

### Task 1.2: Implement fit(::VanDerPol; method=:gradient)

**Files:**
- Modify: `src/Models.jl:200-300` (fit implementation)
- Test: `test/test_models.jl:119-140` (gradient fit tests)

**Step 1: Write test for gradient fitting**

Add to `test/test_models.jl` after parameter_space test:

```julia
@testset "VanDerPol gradient fitting" begin
    vdp = VanDerPol()
    data = read_txt("test/testdata/example.txt")[1:100]  # Use first 100 IBIs

    # Fit using gradient method
    result = fit(vdp, data; method=:gradient)

    # Check result structure
    @test result.model isa VanDerPol
    @test result.method == :gradient
    @test haskey(result.params, :μ)
    @test haskey(result.params, :heart_rate)
    @test result.posterior === nothing  # No posterior for gradient

    # Check parameters are reasonable
    @test 0.1 <= result.params.μ <= 3.0
    @test 40.0 <= result.params.heart_rate <= 120.0

    # Check diagnostics
    @test haskey(result.diagnostics, "converged")
    @test haskey(result.diagnostics, "iterations")
end
```

**Step 2: Run test to verify it fails**

Run: `nix run .#test -- test/test_models.jl 2>&1 | grep "VanDerPol gradient fitting" -A 5`

Expected: FAIL

**Step 3: Implement fit() for gradient method**

Add to `src/Models.jl` after parameter_space (around line 200):

```julia
function fit(model::VanDerPol, data::Vector{Float64};
             method::Symbol=:gradient, kwargs...)
    if method == :gradient
        # Loss function: minimize distance in feature space
        function loss(params_vec)
            μ, heart_rate = params_vec
            params = (μ=μ, heart_rate=heart_rate)

            # Simulate with current parameters
            synthetic = simulate(model, params, length(data))

            # Extract key features from real and synthetic
            real_mean = mean(data)
            synth_mean = mean(synthetic)
            real_std = std(data)
            synth_std = std(synthetic)

            # Feature-space loss (normalized)
            loss_val = ((real_mean - synth_mean) / real_mean)^2 +
                       ((real_std - synth_std) / real_std)^2

            return loss_val
        end

        # Initial guess
        x0 = [1.5, 70.0]

        # Bounds
        lower = [0.1, 40.0]
        upper = [3.0, 120.0]

        # Optimize using Fminbox(LBFGS)
        result = optimize(loss, lower, upper, x0, Fminbox(LBFGS()))

        # Extract fitted parameters
        fitted_params = (
            μ = result.minimizer[1],
            heart_rate = result.minimizer[2]
        )

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
            nothing,
            diagnostics,
            data
        )
    else
        error("Unknown fitting method: $method")
    end
end
```

**Step 4: Run test**

Run: `nix run .#test -- test/test_models.jl 2>&1 | grep "VanDerPol gradient" -A 5`

Expected: PASS

**Step 5: Commit**

```bash
git add src/Models.jl test/test_models.jl
git commit -m "feat: implement fit(:gradient) for VanDerPol"
```

---

### Task 1.3: Implement fit(::VanDerPol; method=:bayesian) with Turing.jl

**Files:**
- Modify: `src/Models.jl:250-350` (Bayesian fit)
- Test: `test/test_models.jl:141-175` (Bayesian fit tests)

**Step 1: Add Turing.jl dependencies**

Run: `nix run .# -- julia -e 'Pkg.add("Turing"); Pkg.add("MCMCChains")'`

This updates Project.toml via Docker.

**Step 2: Write Bayesian fitting test**

Add to `test/test_models.jl`:

```julia
@testset "VanDerPol Bayesian fitting" begin
    vdp = VanDerPol()
    data = read_txt("test/testdata/example.txt")[1:50]  # Shorter for fast test

    # Fit using Bayesian method
    result = fit(vdp, data; method=:bayesian, chains=2, samples=100)

    # Check structure
    @test result.model isa VanDerPol
    @test result.method == :bayesian
    @test result.posterior !== nothing

    # Check posterior samples exist
    @test haskey(result.posterior, "μ")
    @test haskey(result.posterior, "heart_rate")
    @test length(result.posterior["μ"]) == 200  # samples * chains

    # Check parameters are reasonable
    @test 0.1 <= result.params.μ <= 3.0
    @test 40.0 <= result.params.heart_rate <= 120.0
end
```

**Step 3: Run test to verify it fails**

Run: `nix run .#test 2>&1 | grep "VanDerPol Bayesian" -A 3`

Expected: FAIL

**Step 4: Implement Bayesian fit**

Add to `src/Models.jl` in fit() function, after gradient section:

```julia
    elseif method == :bayesian
        # Define Turing model
        @model function vanderpol_model(ibi_data)
            # Priors
            μ ~ Truncated(Normal(1.5, 0.5), 0.1, 3.0)
            heart_rate ~ Truncated(Normal(70.0, 15.0), 40.0, 120.0)
            σ_noise ~ Exponential(10.0)

            # Simulate with these parameters
            params = (μ=μ, heart_rate=heart_rate)
            predicted_ibi = simulate(model, params, length(ibi_data))

            # Likelihood
            ibi_data ~ MvNormal(predicted_ibi, σ_noise)
        end

        # Sample posterior
        turing_model = vanderpol_model(data)
        chain = sample(turing_model, NUTS(0.65), MCMCThreads(),
                      get(kwargs, :samples, 1000),
                      get(kwargs, :chains, 4);
                      progress=true)

        # Extract MAP estimates
        params_map = (
            μ = mean(chain[:μ]),
            heart_rate = mean(chain[:heart_rate])
        )

        # Extract diagnostics
        diagnostics = Dict(
            "method" => "NUTS (Turing.jl)",
            "chains" => get(kwargs, :chains, 4),
            "samples" => get(kwargs, :samples, 1000),
            "rhat_mu" => rhat(chain[:μ])[1],
            "rhat_heart_rate" => rhat(chain[:heart_rate])[1]
        )

        # Convert chain to posterior dict
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
```

**Step 5: Run test**

Run: `nix run .#test -- test/test_models.jl 2>&1 | grep "VanDerPol Bayesian" -A 3`

Expected: PASS (or timeout - if timeout, increase sample size is OK for first pass)

**Step 6: Commit**

```bash
git add src/Models.jl test/test_models.jl
git commit -m "feat: implement fit(:bayesian) for VanDerPol with Turing.jl"
```

---

## Phase 2: Complete Remaining Models

### Task 2.1: Implement Lorenz Model (structure, parameter_space, simulate)

**Files:**
- Modify: `src/Models.jl:350-500` (add Lorenz struct and methods)
- Test: `test/test_models.jl:175-240` (Lorenz tests)

**Step 1: Define Lorenz struct**

Add to `src/Models.jl` after VanDerPol section:

```julia
struct Lorenz <: AbstractHRVModel
    σ::Float64
    ρ::Float64
    β::Float64
    threshold::Float64
end

Lorenz(; σ=10.0, ρ=28.0, β=8/3, threshold=10.0) = Lorenz(σ, ρ, β, threshold)
```

**Step 2: Implement parameter_space(::Lorenz)**

```julia
function parameter_space(model::Lorenz)
    return (
        σ = (lower=5.0, upper=15.0),
        ρ = (lower=20.0, upper=35.0),
        β = (lower=1.0, upper=4.0),
        threshold = (lower=5.0, upper=15.0),
        σ_noise = (lower=1.0, upper=50.0)
    )
end
```

**Step 3: Implement simulate(::Lorenz)**

```julia
function simulate(model::Lorenz, params::NamedTuple, n_beats::Int)::Vector{Float64}
    σ = get(params, :σ, model.σ)
    ρ = get(params, :ρ, model.ρ)
    β = get(params, :β, model.β)
    threshold = get(params, :threshold, model.threshold)

    # Lorenz ODE system
    function lorenz!(du, u, p, t)
        σ, ρ, β = p
        du[1] = σ * (u[2] - u[1])
        du[2] = u[1] * (ρ - u[3]) - u[2]
        du[3] = u[1] * u[2] - β * u[3]
    end

    # Solve ODE (oversample to get enough threshold crossings)
    u0 = [1.0, 1.0, 1.0]
    tspan = (0.0, max(n_beats * 50.0, 5000.0))
    prob = ODEProblem(lorenz!, u0, tspan, [σ, ρ, β])
    sol = solve(prob, Tsit5(), saveat=0.1)

    # Extract IBIs from z-threshold crossings
    z = sol[3, :]
    crossing_times = Float64[]

    for i in 2:length(z)
        if z[i-1] < threshold && z[i] >= threshold
            push!(crossing_times, sol.t[i])
        end
    end

    # Convert to IBIs in milliseconds
    if length(crossing_times) > 1
        ibis = diff(crossing_times) .* 1000

        # Clip to physiological range
        ibis = max.(ibis, 300.0)
        ibis = min.(ibis, 2000.0)

        if length(ibis) >= n_beats
            return ibis[1:n_beats]
        end
    end

    # Fallback: generate synthetic IBIs if simulation fails
    error("Lorenz simulation failed to generate enough beats. Adjust threshold or parameters.")
end
```

**Step 4: Write and run tests**

Add tests to `test/test_models.jl`:

```julia
@testset "Lorenz Model" begin
    lorenz = Lorenz()

    # Test structure
    @test lorenz.σ ≈ 10.0
    @test lorenz.ρ ≈ 28.0

    # Test parameter_space
    ps = parameter_space(lorenz)
    @test haskey(ps, :σ)
    @test haskey(ps, :ρ)

    # Test simulate
    params = (σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
    ibis = simulate(lorenz, params, 40)
    @test length(ibis) ≈ 40 atol=5
    @test all(300 .< ibis .< 2000)
end
```

Run: `nix run .#test -- test/test_models.jl 2>&1 | grep "Lorenz" -A 5`

Expected: PASS

**Step 5: Commit**

```bash
git add src/Models.jl test/test_models.jl
git commit -m "feat: implement Lorenz model (structure, parameter_space, simulate)"
```

---

### Task 2.2: Implement Lorenz fit(:bayesian)

**Files:**
- Modify: `src/Models.jl:480-550` (add fit for Lorenz)
- Test: `test/test_models.jl:220-250` (Bayesian fit test)

**Step 1: Write test**

```julia
@testset "Lorenz Bayesian fitting" begin
    lorenz = Lorenz()
    synthetic_data = simulate(lorenz, (σ=10.0, ρ=28.0, β=8/3, threshold=10.0), 100)

    result = fit(lorenz, synthetic_data; method=:bayesian, chains=2, samples=50)

    @test result.model isa Lorenz
    @test result.method == :bayesian
    @test result.posterior !== nothing
    @test 5.0 <= result.params.σ <= 15.0
end
```

**Step 2: Implement fit() method for Lorenz**

Add to fit() function in `src/Models.jl`:

```julia
elseif model isa Lorenz
    if method == :bayesian
        @model function lorenz_model(ibi_data)
            σ ~ Truncated(Normal(10.0, 2.0), 5.0, 15.0)
            ρ ~ Truncated(Normal(28.0, 3.0), 20.0, 35.0)
            β ~ Truncated(Normal(8/3, 0.5), 1.0, 4.0)
            threshold ~ Truncated(Normal(10.0, 2.0), 5.0, 15.0)
            σ_noise ~ Exponential(10.0)

            params = (σ=σ, ρ=ρ, β=β, threshold=threshold)
            predicted_ibi = simulate(model, params, length(ibi_data))

            ibi_data ~ MvNormal(predicted_ibi, σ_noise)
        end

        turing_model = lorenz_model(data)
        chain = sample(turing_model, NUTS(0.65), MCMCThreads(),
                      get(kwargs, :samples, 1000),
                      get(kwargs, :chains, 4))

        # ... extract params, diagnostics, posterior (similar to VanDerPol)

        return ModelFitResult(model, :bayesian, params_map, posterior, diagnostics, data)
    else
        error("Lorenz only supports :bayesian fitting")
    end
```

**Step 3: Test and commit**

Run: `nix run .#test -- test/test_models.jl 2>&1 | grep "Lorenz Bayesian" -A 3`

```bash
git add src/Models.jl test/test_models.jl
git commit -m "feat: implement fit(:bayesian) for Lorenz"
```

---

### Task 2.3: Implement LIF Model (structure, parameter_space, simulate)

**Files:**
- Modify: `src/Models.jl:550-700` (add LIF)
- Test: `test/test_models.jl:250-320` (LIF tests)

**Similar pattern to Lorenz:**
1. Define struct
2. Implement parameter_space()
3. Implement simulate() with Euler-Maruyama integration
4. Write tests
5. Implement fit(:bayesian) and fit(:gradient)

*Full implementation follows same pattern as Tasks 2.1-2.2*

---

### Task 2.4: Implement DMD Model (structure, fit, simulate)

**Files:**
- Modify: `src/Models.jl:700-850` (add DMD)
- Test: `test/test_models.jl:320-380` (DMD tests)

**Step 1: Define DMD struct**

```julia
mutable struct DMD <: AbstractHRVModel
    rank::Int
    modes::Matrix{ComplexF64}
    evals::Vector{ComplexF64}
    b::Vector{ComplexF64}
end

DMD(; rank::Int=5) = DMD(rank, Matrix{ComplexF64}(undef, 0, 0), ComplexF64[], ComplexF64[])
```

**Step 2: Implement fit(::DMD)**

```julia
function fit(model::DMD, data::Vector{Float64}; kwargs...)
    n = length(data)
    r = min(model.rank, n-1)

    # Create Hankel matrix
    X = zeros(r, n-r)
    for i in 1:r
        X[i, :] = data[i:i+n-r-1]
    end

    X1 = X[:, 1:end-1]
    X2 = X[:, 2:end]

    # SVD
    U, Σ, V = svd(X1)
    U_r = U[:, 1:r]
    Σ_r = Diagonal(Σ[1:r])
    V_r = V[:, 1:r]

    # DMD matrix and eigendecomposition
    A_tilde = U_r' * X2 * V_r / Σ_r
    evals, W = eigen(A_tilde)

    # Dynamic modes
    modes = X2 * V_r / Σ_r * W
    b = modes \ data[1:r]

    # Create fitted model
    fitted_model = DMD(r, modes, evals, b)

    return ModelFitResult(fitted_model, :spectral, NamedTuple(), nothing, Dict("method" => "SVD"), data)
end
```

**Step 3: Implement simulate(::DMD)**

```julia
function simulate(model::DMD, params::Union{NamedTuple,Nothing}, n_beats::Int)::Vector{Float64}
    if isempty(model.modes)
        error("DMD must be fitted first")
    end

    reconstructed = zeros(n_beats)
    for i in 1:n_beats
        for (j, λ) in enumerate(model.evals)
            reconstructed[i] += real(model.modes[:, j]' * (λ^i) * model.b[j])
        end
    end

    # Clip to physiological range
    reconstructed = max.(reconstructed, 300.0)
    reconstructed = min.(reconstructed, 2000.0)

    return reconstructed
end
```

---

## Phase 3: Visualization Functions

### Task 3.1-3.9: Implement 8 Missing Visualization Functions

Each visualization function follows similar pattern:

**Files:**
- Modify: `src/Visualization/Visualization.jl:69-500` (add functions)
- Test: `test/test_visualization.jl` (if exists)

Each function should:
1. Use CairoMakie for consistent rendering
2. Match existing plot_flagship() style
3. Have clear documentation
4. Support common parameters (title, xlabel, ylabel, etc.)

**Functions to implement:**
1. `plot_ibi_series()` - Time series with ±1σ envelope
2. `plot_poincare()` - Poincaré plot with ellipse
3. `plot_spectrum()` - Welch periodogram with HRV bands
4. `plot_comparison()` - Real vs synthetic comparison
5. `plot_model_heatmap()` - Model × feature quality matrix
6. `plot_lorenz_3d()` - 3D attractor plot
7. `plot_radar()` - Feature z-score spider chart
8. `plot_correlations()` - Feature correlation heatmap
9. `plot_feature_violins()` - Distribution comparison (violin plots)

*Each implemented as separate task following write test → implement → test → commit pattern*

---

## Phase 4: Cleanup & Integration

### Task 4.1: Fix src/HeartRateLab.jl imports

**Files:**
- Modify: `src/HeartRateLab.jl:55-66`

**Step 1: Update imports to only include existing functions**

Replace lines 55-56 with:

```julia
import .Visualization: plot_flagship, plot_ibi_series, plot_poincare, plot_spectrum,
                       plot_comparison, plot_model_heatmap, plot_lorenz_3d,
                       plot_radar, plot_correlations, plot_feature_violins
```

And update exports (line 65) similarly.

**Step 2: Verify no import warnings**

Run: `nix run .#build 2>&1 | grep "WARNING.*could not import"`

Expected: No warnings

**Step 3: Commit**

```bash
git add src/HeartRateLab.jl
git commit -m "fix: update imports to match implemented visualization functions"
```

---

### Task 4.2: Delete outdated documentation

**Files:**
- Delete: `docs/FLAGSHIP_VISUALIZATION_GUIDE.md`
- Delete: `docs/VISUALIZATION_TESTING_GUIDE.md`
- Delete: `docs/src/visualization.md`
- Delete: `docs/plans/2026-02-22-comprehensive-demo-notebook-design.md`

**Step 1: Remove files**

```bash
rm docs/FLAGSHIP_VISUALIZATION_GUIDE.md \
   docs/VISUALIZATION_TESTING_GUIDE.md \
   docs/src/visualization.md \
   docs/plans/2026-02-22-comprehensive-demo-notebook-design.md
```

**Step 2: Commit**

```bash
git add -u
git commit -m "docs: remove outdated aspirational documentation"
```

---

### Task 4.3: Run full test suite

**Step 1: Build Docker image**

Run: `nix run .#build`

Expected: Builds successfully

**Step 2: Run tests**

Run: `nix run .#test`

Expected: Tests pass at ≥95% (may have a few probabilistic test failures)

**Step 3: Check specific test groups**

Run: `nix run .#test -- test/test_models.jl 2>&1 | tail -5`

Expected: All model tests pass

---

## Success Criteria

When complete, all of these should be TRUE:

✅ fit() works for all 4 models
✅ parameter_space() works for all 4 models
✅ All models have working simulate() methods
✅ All 9 visualization functions exist and are exported
✅ No import warnings when loading HeartRateLab
✅ Test pass rate ≥95%
✅ Tests pass in Docker (via `nix run .#test`)
✅ Documentation accurate and up-to-date

---

## Estimated Effort

- Phase 1 (fit/parameter_space): 3-4 hours
- Phase 2 (Complete Lorenz, LIF, DMD): 6-8 hours
- Phase 3 (9 visualization functions): 4-5 hours
- Phase 4 (Cleanup): 1 hour

**Total: 14-18 hours (2-3 development sessions)**

---

## Critical Notes

1. **Dependencies**: Ensure DifferentialEquations, Turing, Optim, MCMCChains are in Project.toml
2. **Testing**: Use `nix run .#test` not local Julia (Docker ensures consistency)
3. **Commits**: Create frequent commits (per task) to maintain clean history
4. **Order**: Implement in order given (fit() before models before visualization)
5. **Visualization**: Use CairoMakie consistently across all functions

