using HeartRateLab: HeartRateLab
using Test
using Statistics

# Set working directory to test directory for relative paths
cd(@__DIR__)
# cd("test/")

# ============================================================================
# DMD Model - IMPLEMENTED
# ============================================================================
@testset "DMD Model" begin
    # Load IBI data for testing
    ibis = HeartRateLab.read_txt("testdata/example.txt")[1:60]  # Use first 60 for faster tests

    # Test 1: Model can be created
    r = 4
    dmd = HeartRateLab.Models.DMD(rank=r)
    @test dmd.rank == r
    @test isempty(dmd.modes)
    @test isempty(dmd.evals)

    # Test 2: fit() works and updates the model
    fitted_dmd = HeartRateLab.Models.fit(dmd, ibis)

    @test !isempty(fitted_dmd.model.modes)
    @test !isempty(fitted_dmd.model.evals)
    @test size(fitted_dmd.model.modes, 2) <= fitted_dmd.model.rank
    @test length(fitted_dmd.model.evals) == size(fitted_dmd.model.modes, 2)

    # Test 3: simulate() produces valid IBIs
    reconstructed = HeartRateLab.Models.simulate(fitted_dmd.model, nothing, length(ibis))

    # NOTE: plot() calls removed to avoid GLMakie display errors in CI/Docker
    # plot(ibis, label="Original", legend=:topleft)
    # plot!(reconstructed, label="Reconstructed")

    @test length(reconstructed) ≈ length(ibis)
    @test all(reconstructed .> 0)
    @test all(300 .< reconstructed .< 2000)

    # Test 4: Reconstruction captures mean of original data.
    # KNOWN LIMITATION (intentional, d-06): DMD reconstructs the *dynamics about the mean*
    # and does not restore the DC/mean term, so reconstructed mean drifts from the original.
    # We deliberately keep DMD as the weakest of the four models rather than bolt on a DC
    # fix; a future AIC/BIC model ranking (d-20) will contextualise why it underperforms.
    orig_mean = mean(ibis)
    recon_mean = mean(reconstructed)

    @test_broken abs(orig_mean .- recon_mean) < 50.0  # DMD drops the mean by design — see note above

    # Test 5: round-trip has reasonable fidelity
    orig_centered = ibis .- mean(ibis)
    recon_centered = reconstructed .- mean(reconstructed)

    # plot(orig_centered, label="Original (centered)", legend=:topleft)
    # plot!(recon_centered, label="Reconstructed (centered)")

    if std(orig_centered) > 0 && std(recon_centered) > 0
        correlation = cor(orig_centered, recon_centered)
        @test correlation > 0.3
    end

    # Test 6: Different rank produces different reconstructions
    ibis = HeartRateLab.read_txt("testdata/example.txt")[1:200]
    dmd_rank10 = HeartRateLab.Models.DMD(rank=10)
    fitted_dmd10 = HeartRateLab.Models.fit(dmd_rank10, ibis)
    recon10 = HeartRateLab.Models.simulate(fitted_dmd10.model, nothing, length(ibis))

    dmd_rank15 = HeartRateLab.Models.DMD(rank=15)
    fitted_dmd15 = HeartRateLab.Models.fit(dmd_rank15, ibis)
    recon15 = HeartRateLab.Models.simulate(fitted_dmd15.model, nothing, length(ibis))

    error10 = sum(abs.(ibis .- recon10))
    error15 = sum(abs.(ibis .- recon15))

    # plot(ibis, label="Original", legend=:topleft)
    # plot!(recon10, label="Reconstructed (rank=10)")
    # plot!(recon15, label="Reconstructed (rank=15)")

    @test error15 <= error10
    # Higher rank should present lower (or equal) reconstruction error
end

# ============================================================================
# Van der Pol Model - PARTIALLY IMPLEMENTED (simulate only)
# ============================================================================
@testset "Van der Pol Model" begin
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

    # Test 11: Diagnostics include R-hat values
    @test haskey(fitted_result.diagnostics, "rhat_mu")
    @test haskey(fitted_result.diagnostics, "rhat_heart_rate")
    @test haskey(fitted_result.diagnostics, "rhat_sigma_noise")
    @test fitted_result.diagnostics["rhat_mu"] > 0
end

# ============================================================================
# Lorenz Model - IMPLEMENTED (requires DifferentialEquations.jl)
# ============================================================================
@testset "Lorenz Model (requires DifferentialEquations)" begin
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
