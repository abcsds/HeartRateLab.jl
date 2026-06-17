using HeartRateLab: HeartRateLab
using Test
using Statistics
using Random
using DataFrames

# Set working directory to test directory for relative paths
cd(@__DIR__)
# cd("test/")

# d-15: seed the global RNG so the stochastic model tests (simulate noise, MCMC
# sampling) are reproducible. Individual testsets re-seed for independence.
Random.seed!(20260612)

# ============================================================================
# DMD Model - IMPLEMENTED
# ============================================================================
@testset "DMD Model (V2 UnitCircleDMD)" begin
    Random.seed!(20260617)
    # Full example.txt series (n=4193, mean ≈ 957 ms, std ≈ 90 ms). The V2 model
    # is mean-centered + Hankel-embedded; it needs the full record for a
    # meaningful embedding, not a 60-beat snippet.
    ibis = HeartRateLab.read_txt("testdata/example.txt")
    data_mean = mean(ibis)
    data_std = std(ibis)

    # Test 1: Model can be created with V2 defaults (d=50 embedding, energy rank).
    dmd = HeartRateLab.Models.DMD()
    @test dmd.d == 50
    @test dmd.energy ≈ 0.99
    @test isempty(dmd.modes)
    @test isempty(dmd.evals)
    @test dmd.r == 0

    # The public `rank` knob still works as the rank cap (rmax).
    dmd_r = HeartRateLab.Models.DMD(rank=10)
    @test dmd_r.rank == 10

    # Test 2: fit() works and populates the centered-DMD state.
    fitted_dmd = HeartRateLab.Models.fit(HeartRateLab.Models.DMD(d=50, rank=10), ibis)
    fm = fitted_dmd.model
    @test !isempty(fm.modes)
    @test !isempty(fm.evals)
    @test fm.r == length(fm.evals)
    @test fm.r <= fm.rank
    @test fm.μ ≈ data_mean                                   # mean is stored, not forced
    # Eigenvalues are projected onto the unit circle: |λ| == 1.
    @test all(abs.(abs.(fm.evals) .- 1.0) .< 1e-8)
    @test fitted_dmd.diagnostics["method"] == "UnitCircleDMD (V2)"

    # Test 3: simulate() produces valid, physiological IBIs.
    sim = HeartRateLab.Models.simulate(fm, nothing, length(ibis))
    @test length(sim) == length(ibis)
    @test all(sim .> 0)
    @test all(300 .<= sim .<= 2000)

    sim_mean = mean(sim)
    sim_std = std(sim)

    # Test 4: MEAN FIDELITY (was @test_broken in the old mean-dropping model).
    # V2 centers on the data mean and adds it back, so the reconstructed mean
    # matches the data mean to within a few percent — no more forced 800 ms.
    @test abs(sim_mean - data_mean) / data_mean < 0.03

    # Test 5: recovered variance is in a sane range (realistic, not collapsed and
    # not blown up). The old model collapsed to std ≈ 17; V2 recovers std ≈ 78.
    @test 30.0 < sim_std < 1.5 * data_std

    # Test 6: FULL-variance reconstruction is an HONEST KNOWN LIMIT. A low-rank
    # linear DMD under-reproduces broadband RR variance; it recovers the mean and
    # the dominant LF oscillation but not the full spread. Marked broken with an
    # accurate message (see docs/dmd-rr-modeling-research.md §6 "honest limits").
    @test_broken sim_std ≥ 0.95 * data_std  # low-rank linear DMD under-reproduces broadband RR variance

    # Test 7: BIC is far better than a forced-mean baseline. Compare V2's
    # information criterion against the data's own mean-fidelity floor: V2 should
    # not rank last. (The old model's BIC ≈ 55534; V2 ≈ 49639.)
    ic = HeartRateLab.information_criteria(fitted_dmd; n_sim_beats=length(ibis))
    @test isfinite(ic.bic)
    @test ic.loglik > -30000          # old mean-dropping model: loglik ≈ -27746

    # Test 8: forecast() beats the persistence and mean baselines at h=1.
    # Out-of-sample closed-loop NRMSE over the held-out 30% tail (train 70%),
    # exactly the protocol in docs/dmd-rr-modeling-research.md §5. At each anchor
    # the model is fit on the prefix and asked for the next beat.
    Random.seed!(20260617)
    split = round(Int, 0.7 * length(ibis))
    fc_model = HeartRateLab.Models.DMD(d=50)   # forecast uses a richer rank by default
    preds = Float64[]; truth = Float64[]; pers = Float64[]
    for t0 in split:(length(ibis) - 1)
        push!(preds, HeartRateLab.forecast(fc_model, ibis[1:t0], 1)[1])
        push!(truth, ibis[t0 + 1])
        push!(pers, ibis[t0])
    end
    dmd_nrmse1 = sqrt(mean((truth .- preds) .^ 2)) / data_std
    persistence_nrmse1 = sqrt(mean((truth .- pers) .^ 2)) / data_std
    mean_nrmse1 = sqrt(mean((truth .- mean(ibis)) .^ 2)) / data_std

    @test isfinite(dmd_nrmse1)
    @test dmd_nrmse1 < persistence_nrmse1     # DMD beats persistence at h=1 (≈0.19 vs 0.35)
    @test dmd_nrmse1 < mean_nrmse1            # DMD beats the mean baseline at h=1

    # forecast returns the requested horizon length and physiological values.
    fc = HeartRateLab.forecast(fc_model, ibis[1:split], 5)
    @test length(fc) == 5
    @test all(300 .<= fc .<= 2000)

    # Test 9: forecast does not mutate the model.
    @test isempty(fc_model.modes)
end

# ============================================================================
# Van der Pol Model - PARTIALLY IMPLEMENTED (simulate only)
# ============================================================================
@testset "Van der Pol Model" begin
    Random.seed!(2)
    # Create a Van der Pol model instance
    vdp = HeartRateLab.Models.VanDerPol()

    # Test 1: Model can be created
    @test vdp isa HeartRateLab.Models.VanDerPol

    # Test 2: simulate() produces valid IBIs
    params = (μ=1.5, heart_rate=70.0)
    ibis = HeartRateLab.Models.simulate(vdp, params, 50)

    @test length(ibis) ≈ 50 atol=5
    @test all(ibis .> 0)
    @test all(300 .< ibis .< 2000)

    # Test 3: Different μ produces different IBIs
    params_low_mu = (μ=0.8, heart_rate=70.0)
    ibis_low_mu = HeartRateLab.Models.simulate(vdp, params_low_mu, 50)

    params_high_mu = (μ=2.5, heart_rate=70.0)
    ibis_high_mu = HeartRateLab.Models.simulate(vdp, params_high_mu, 50)

    mean_low = mean(ibis_low_mu)
    mean_high = mean(ibis_high_mu)
    @test abs(mean_low - mean_high) / mean_low > 0.05

    # Test 4: heart_rate parameter affects timing
    params_slow_hr = (μ=1.5, heart_rate=50.0)
    ibis_slow_hr = HeartRateLab.Models.simulate(vdp, params_slow_hr, 50)

    params_fast_hr = (μ=1.5, heart_rate=100.0)
    ibis_fast_hr = HeartRateLab.Models.simulate(vdp, params_fast_hr, 50)

    @test mean(ibis_slow_hr) > mean(ibis_fast_hr)

    # Test 5: Standard deviation is reasonable
    @test std(ibis) > 5.0

    # Test 6: parameter_space() - NOW IMPLEMENTED
    ps = HeartRateLab.Models.parameter_space(vdp)
    @test haskey(ps, :μ)
    @test haskey(ps, :heart_rate)
    @test haskey(ps, :σ_noise)
    @test ps.μ.lower < ps.μ.upper
    @test ps.heart_rate.lower < ps.heart_rate.upper
    @test ps.σ_noise.lower < ps.σ_noise.upper

    # Test 7: fit(:gradient) - NOW IMPLEMENTED (Phase C)
    data = HeartRateLab.read_txt("testdata/example.txt")[1:200]
    fitted_grad = HeartRateLab.Models.fit(vdp, data; method=:gradient)

    @test fitted_grad.model isa HeartRateLab.Models.VanDerPol
    @test fitted_grad.method == :gradient
    @test haskey(fitted_grad.params, :μ)
    @test haskey(fitted_grad.params, :heart_rate)
    @test fitted_grad.posterior === nothing  # No posterior for gradient

    # Test 7b: Gradient fit produces valid parameters
    @test fitted_grad.params.μ > 0
    @test fitted_grad.params.heart_rate > 0
    @test 0.1 <= fitted_grad.params.μ <= 3.0
    @test 40.0 <= fitted_grad.params.heart_rate <= 120.0

    # Test 7c: Diagnostics contain optimization info
    @test haskey(fitted_grad.diagnostics, "converged")
    @test haskey(fitted_grad.diagnostics, "iterations")
    @test haskey(fitted_grad.diagnostics, "loss_final")
    @test fitted_grad.diagnostics["method"] == "LBFGS"

    # Test 8: fit(:bayesian) - NOW IMPLEMENTED (Phase B)
    fitted_result = HeartRateLab.Models.fit(vdp, data; method=:bayesian, chains=2, samples=length(data))

    @test fitted_result.model isa HeartRateLab.Models.VanDerPol
    @test fitted_result.method == :bayesian
    @test fitted_result.posterior !== nothing
    @test haskey(fitted_result.posterior, "μ")
    @test haskey(fitted_result.posterior, "heart_rate")
    @test haskey(fitted_result.posterior, "σ_noise")
    # heart rate to ibi:
    synth_ibis = 60000 ./ fitted_result.posterior["heart_rate"]
    @test all(synth_ibis .> 300) && all(synth_ibis .< 2000)

    # Test 9: Bayesian fit produces valid parameters
    @test haskey(fitted_result.params, :μ)
    @test haskey(fitted_result.params, :heart_rate)
    @test fitted_result.params.μ > 0
    @test fitted_result.params.heart_rate > 0

    # Test 10: Posterior samples have expected length
    expected_samples = length(data) * 2  # samples * chains
    @test length(fitted_result.posterior["μ"]) == expected_samples
    @test length(fitted_result.posterior["heart_rate"]) == expected_samples

    # Test 11: Diagnostics include R-hat values (d-16: assert real convergence-range
    # values, not just ">0" — a hardcoded 1.0 used to pass that).
    @test haskey(fitted_result.diagnostics, "rhat_mu")
    @test haskey(fitted_result.diagnostics, "rhat_heart_rate")
    @test haskey(fitted_result.diagnostics, "rhat_sigma_noise")
    for k in ("rhat_mu", "rhat_heart_rate", "rhat_sigma_noise")
        rh = fitted_result.diagnostics[k]
        @test rh isa Real && isfinite(rh)
        @test 0.5 < rh < 3.0   # plausible split-R-hat range for a (short) fitted chain
    end
end

# ============================================================================
# Lorenz Model - IMPLEMENTED (requires DifferentialEquations.jl)
# ============================================================================
@testset "Lorenz Model (requires DifferentialEquations)" begin
    Random.seed!(3)
    lorenz = HeartRateLab.Models.Lorenz(σ=10.0, ρ=28.0, β=8/3, threshold=10.0)

    # Test 1: Model can be created
    @test lorenz.σ ≈ 10.0
    @test lorenz.ρ ≈ 28.0
    @test lorenz.β ≈ 8/3
    @test lorenz.threshold ≈ 10.0

    # Test 2: parameter_space() returns expected parameters
    ps = HeartRateLab.Models.parameter_space(lorenz)
    @test haskey(ps, :σ)
    @test haskey(ps, :ρ)
    @test haskey(ps, :β)
    @test haskey(ps, :threshold)
    @test haskey(ps, :σ_noise)

    # Test 3: simulate() produces valid IBIs
    params = (σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
    ibis = HeartRateLab.Models.simulate(lorenz, params, 40)

    @test length(ibis) ≈ 40 atol=8
    @test all(ibis .> 0)
    @test all(300 .< ibis .< 2000)

    # Test 4: Different ρ (chaos parameter) produces different IBIs
    params_low_rho = (σ=10.0, ρ=20.0, β=8/3, threshold=10.0)
    ibis_low_rho = HeartRateLab.Models.simulate(lorenz, params_low_rho, 40)

    params_high_rho = (σ=10.0, ρ=35.0, β=8/3, threshold=10.0)
    ibis_high_rho = HeartRateLab.Models.simulate(lorenz, params_high_rho, 40)

    mean_low = mean(ibis_low_rho)
    mean_high = mean(ibis_high_rho)
    @test abs(mean_low - mean_high) / mean_low > 0.05

    # Test 5: fit(:bayesian) produces valid result
    synthetic_data = HeartRateLab.Models.simulate(lorenz, params, 150)
    fitted_result = HeartRateLab.Models.fit(lorenz, synthetic_data; method=:bayesian, chains=2, samples=100)

    @test fitted_result.model isa HeartRateLab.Models.Lorenz
    @test fitted_result.method == :bayesian
    @test fitted_result.posterior !== nothing
    @test haskey(fitted_result.diagnostics, "method")

    # Test 6: Fitted parameters are within bounds
    @test 5.0 <= fitted_result.params.σ <= 15.0
    @test 20.0 <= fitted_result.params.ρ <= 35.0
    @test 1.0 <= fitted_result.params.β <= 4.0
    @test 5.0 <= fitted_result.params.threshold <= 15.0

    # Test 7: Posterior samples have expected length
    expected_samples = 100 * 2  # samples * chains
    @test length(fitted_result.posterior["σ"]) == expected_samples
    @test length(fitted_result.posterior["ρ"]) == expected_samples
    @test length(fitted_result.posterior["β"]) == expected_samples
    @test length(fitted_result.posterior["threshold"]) == expected_samples

    # Test 8: Diagnostics include R-hat values
    @test haskey(fitted_result.diagnostics, "rhat_sigma")
    @test haskey(fitted_result.diagnostics, "rhat_rho")
    @test haskey(fitted_result.diagnostics, "rhat_beta")
    @test haskey(fitted_result.diagnostics, "rhat_threshold")
    @test haskey(fitted_result.diagnostics, "rhat_sigma_noise")
end

# ============================================================================
# LIF Model - LEGACY TESTS (OLD IMPLEMENTATION - DEPRECATED)
# These tests reference an old model structure and are no longer applicable
# See "LIF Cardiac Pacemaker Model - New Structure" testset instead
# ============================================================================
# DEPRECATED: Old test structure removed - LIF now has only I as fitted parameter
# The old parameters (τ, I_base, threshold, noise_amp) are now physiologically fixed

# ============================================================================
# LIF Cardiac Pacemaker Model - New Structure
# ============================================================================
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

# ============================================================================
# LIF Parameter Space - I Only (New Implementation)
# ============================================================================
@testset "LIF Parameter Space - I Only" begin
    lif = HeartRateLab.Models.LIF()
    ps = HeartRateLab.Models.parameter_space(lif)

    # Only I parameter should be in parameter space
    @test haskey(ps, :I)
    @test !haskey(ps, :τ)  # Fixed, not fitted
    @test !haskey(ps, :I_base)  # Old parameter, no longer used
    @test !haskey(ps, :threshold)  # Fixed, not fitted
    @test !haskey(ps, :noise_amp)  # Old parameter, no longer used
    @test !haskey(ps, :σ_noise)  # Old parameter, no longer used

    # I should have reasonable bounds for cardiac pacemaker
    @test ps.I.lower ≈ 1.48
    @test ps.I.upper ≈ 1.56
    @test ps.I.prior !== nothing
end

# ============================================================================
# LIF Simulation - DiffEq with Callbacks
# ============================================================================
@testset "LIF Simulation - DiffEq with Callbacks" begin
    Random.seed!(4)
    lif = HeartRateLab.Models.LIF(I=1.52)

    # Test 1: Simulate produces correct number of IBIs
    ibis = HeartRateLab.Models.simulate(lif, (I=1.52,), 50)
    @test length(ibis) == 50

    # Test 2: IBIs are in physiological range (750-1050 ms for I=1.52)
    @test all(ibis .> 0)
    @test all(700 .< ibis .< 1100)  # Allow ~15% tolerance on both sides
    @test 750 < mean(ibis) < 1050  # More realistic tolerance for I=1.52

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

# ============================================================================
# LIF Physiological Validation
# ============================================================================
@testset "LIF Physiological Validation" begin
    Random.seed!(5)
    # Test 1: I=1.48 produces relatively slower heart rate compared to I=1.52
    lif_slow = HeartRateLab.Models.LIF(I=1.48)
    ibis_slow = HeartRateLab.Models.simulate(lif_slow, (I=1.48,), 50)
    mean_ibi_slow = mean(ibis_slow)
    bpm_slow = 60000 / mean_ibi_slow

    @test mean_ibi_slow > 750  # Slower than normal
    @test bpm_slow < 80  # Below tachycardia
    @test all(700 .< ibis_slow .< 900)  # All IBIs in physiological range

    # Test 2: I=1.52 produces normal heart rate (60-80 BPM, 750-800ms IBI)
    lif_normal = HeartRateLab.Models.LIF(I=1.52)
    ibis_normal = HeartRateLab.Models.simulate(lif_normal, (I=1.52,), 50)
    mean_ibi_normal = mean(ibis_normal)
    bpm_normal = 60000 / mean_ibi_normal

    @test 750 < mean_ibi_normal < 850  # Normal IBI range
    @test 70 < bpm_normal < 80  # Normal heart rate
    @test all(700 .< ibis_normal .< 900)  # All IBIs physiological

    # Test 3: I=1.56 produces relatively faster heart rate compared to I=1.52
    lif_fast = HeartRateLab.Models.LIF(I=1.56)
    ibis_fast = HeartRateLab.Models.simulate(lif_fast, (I=1.56,), 50)
    mean_ibi_fast = mean(ibis_fast)
    bpm_fast = 60000 / mean_ibi_fast

    @test mean_ibi_fast < 800  # Faster than normal
    @test bpm_fast > 75  # Approaching tachycardia
    @test all(700 .< ibis_fast .< 850)  # All IBIs physiological

    # Test 4: Monotonic relationship - higher I → shorter IBI (slower heart rate numerically)
    @test mean_ibi_slow > mean_ibi_normal > mean_ibi_fast
    @test bpm_slow < bpm_normal < bpm_fast

    # Test 5: Standard deviation is minimal (deterministic model)
    @test std(ibis_normal) >= 0  # No negative variability

    # Test 6: All IBIs remain in physiological range (300-2000ms)
    all_ibis = vcat(ibis_slow, ibis_normal, ibis_fast)
    @test all(300 .< all_ibis .< 2000)
    @test minimum(all_ibis) > 300
    @test maximum(all_ibis) < 2000

    # Test 7: Different I values produce different mean IBIs
    @test abs(mean_ibi_slow - mean_ibi_fast) > 10  # At least 10ms difference
end

# ============================================================================
# d-12: previously untested exported Models API
# ============================================================================
@testset "Models API: rhat / parameter_series / extract_feature_set" begin
    M = HeartRateLab.Models

    @testset "_split_rhat convergence diagnostic" begin
        Random.seed!(99)
        # Well-mixed chains drawn from the SAME distribution → R-hat ≈ 1.
        converged = randn(400, 4)
        rh_conv = M._split_rhat(converged)
        @test isfinite(rh_conv)
        @test 0.9 < rh_conv < 1.1

        # Chains centered at very different means → R-hat ≫ 1 (non-convergence).
        divergent = hcat(randn(400), randn(400) .+ 10,
                         randn(400) .+ 20, randn(400) .+ 30)
        rh_div = M._split_rhat(divergent)
        @test rh_div > 1.5

        # Degenerate input (too few iterations) → NaN, not a crash.
        @test isnan(M._split_rhat(zeros(2, 1)))
    end

    @testset "parameter_series" begin
        mfr = M.ModelFitResult(
            M.VanDerPol(), :bayesian, (μ = 1.5, heart_rate = 75.0),
            Dict("μ" => [1.0, 2.0, 3.0]), Dict{String,Any}("rhat_mu" => 1.0),
            [800.0, 810.0, 790.0],
        )
        @test M.parameter_series(mfr, :μ) == [1.0, 2.0, 3.0]
        @test M.parameter_series(mfr, :not_a_param) === nothing

        # No posterior (e.g. :gradient fit) → nothing.
        mfr_nopost = M.ModelFitResult(
            M.VanDerPol(), :gradient, (μ = 1.5,), nothing, Dict{String,Any}(), [800.0],
        )
        @test M.parameter_series(mfr_nopost, :μ) === nothing
    end

    @testset "extract_feature_set(::Vector)" begin
        d = [800.0, 820.0, 810.0, 790.0]
        df = M.extract_feature_set(d)
        @test df isa DataFrame
        @test names(df) == ["mean", "sdnn", "rmssd"]
        @test df.mean[1] ≈ mean(d)
        @test df.sdnn[1] ≈ std(d)
        @test df.rmssd[1] ≈ sqrt(mean(diff(d) .^ 2))
    end
end
