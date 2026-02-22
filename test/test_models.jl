using HeartRateLab: HeartRateLab
using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

# ============================================================================
# DMD Model - IMPLEMENTED
# ============================================================================
@testset "DMD Model" begin
    using LinearAlgebra

    # Create synthetic IBI data from a simple oscillatory pattern
    t = range(0, 10, length=50)
    synthetic_ibis = 800 .+ 100 .* sin.(2π .* t / 10) .+ randn(50) .* 10

    # Test 1: Model can be created
    dmd = HeartRateLab.Models.DMD(rank=5)
    @test dmd.rank == 5
    @test isempty(dmd.modes)
    @test isempty(dmd.evals)

    # Test 2: fit() works and updates the model
    fitted_dmd = HeartRateLab.Models.fit(dmd, synthetic_ibis)

    @test !isempty(fitted_dmd.modes)
    @test !isempty(fitted_dmd.evals)
    @test size(fitted_dmd.modes, 2) <= fitted_dmd.rank
    @test length(fitted_dmd.evals) == size(fitted_dmd.modes, 2)

    # Test 3: simulate() produces valid IBIs
    reconstructed = HeartRateLab.Models.simulate(fitted_dmd, nothing, length(synthetic_ibis))

    @test length(reconstructed) ≈ length(synthetic_ibis)
    @test all(reconstructed .> 0)
    @test all(300 .< reconstructed .< 2000)

    # Test 4: Reconstruction captures mean of original data
    orig_mean = mean(synthetic_ibis)
    recon_mean = mean(reconstructed)

    @test abs(orig_mean - recon_mean) < 50.0

    # Test 5: round-trip has reasonable fidelity
    orig_centered = synthetic_ibis .- mean(synthetic_ibis)
    recon_centered = reconstructed .- mean(reconstructed)

    if std(orig_centered) > 0 && std(recon_centered) > 0
        correlation = cor(orig_centered, recon_centered)
        @test correlation > 0.3
    end

    # Test 6: Different rank produces different reconstructions
    dmd_rank2 = HeartRateLab.Models.DMD(rank=2)
    fitted_dmd2 = HeartRateLab.Models.fit(dmd_rank2, synthetic_ibis)
    recon2 = HeartRateLab.Models.simulate(fitted_dmd2, nothing, length(synthetic_ibis))

    dmd_rank10 = HeartRateLab.Models.DMD(rank=10)
    fitted_dmd10 = HeartRateLab.Models.fit(dmd_rank10, synthetic_ibis)
    recon10 = HeartRateLab.Models.simulate(fitted_dmd10, nothing, length(synthetic_ibis))

    error2 = sum(abs.(synthetic_ibis .- recon2))
    error10 = sum(abs.(synthetic_ibis .- recon10))

    @test error10 <= error2
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
    ibis = HeartRateLab.Models.simulate(vdp, params, n_beats=50)

    @test length(ibis) ≈ 50 atol=5
    @test all(ibis .> 0)
    @test all(300 .< ibis .< 2000)

    # Test 3: Different μ produces different IBIs
    params_low_mu = (μ=0.8, heart_rate=70.0)
    ibis_low_mu = HeartRateLab.Models.simulate(vdp, params_low_mu, n_beats=50)

    params_high_mu = (μ=2.5, heart_rate=70.0)
    ibis_high_mu = HeartRateLab.Models.simulate(vdp, params_high_mu, n_beats=50)

    mean_low = mean(ibis_low_mu)
    mean_high = mean(ibis_high_mu)
    @test abs(mean_low - mean_high) / mean_low > 0.05

    # Test 4: heart_rate parameter affects timing
    params_slow_hr = (μ=1.5, heart_rate=50.0)
    ibis_slow_hr = HeartRateLab.Models.simulate(vdp, params_slow_hr, n_beats=50)

    params_fast_hr = (μ=1.5, heart_rate=100.0)
    ibis_fast_hr = HeartRateLab.Models.simulate(vdp, params_fast_hr, n_beats=50)

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
    synthetic_data = HeartRateLab.Models.simulate(vdp, params, n_beats=200)
    fitted_grad = HeartRateLab.Models.fit(vdp, synthetic_data; method=:gradient)

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
    synthetic_data = HeartRateLab.Models.simulate(vdp, params, n_beats=150)
    fitted_result = HeartRateLab.Models.fit(vdp, synthetic_data; method=:bayesian, chains=2, samples=200)

    @test fitted_result.model isa HeartRateLab.Models.VanDerPol
    @test fitted_result.method == :bayesian
    @test fitted_result.posterior !== nothing
    @test haskey(fitted_result.posterior, "μ")
    @test haskey(fitted_result.posterior, "heart_rate")
    @test haskey(fitted_result.posterior, "σ_noise")

    # Test 9: Bayesian fit produces valid parameters
    @test haskey(fitted_result.params, :μ)
    @test haskey(fitted_result.params, :heart_rate)
    @test fitted_result.params.μ > 0
    @test fitted_result.params.heart_rate > 0

    # Test 10: Posterior samples have expected length
    expected_samples = 200 * 2  # samples * chains
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
    @test_broken begin
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
        ibis = HeartRateLab.Models.simulate(lorenz, params, n_beats=40)

        @test length(ibis) ≈ 40 atol=8
        @test all(ibis .> 0)
        @test all(300 .< ibis .< 2000)

        # Test 4: Different ρ (chaos parameter) produces different IBIs
        params_low_rho = (σ=10.0, ρ=20.0, β=8/3, threshold=10.0)
        ibis_low_rho = HeartRateLab.Models.simulate(lorenz, params_low_rho, n_beats=40)

        params_high_rho = (σ=10.0, ρ=35.0, β=8/3, threshold=10.0)
        ibis_high_rho = HeartRateLab.Models.simulate(lorenz, params_high_rho, n_beats=40)

        mean_low = mean(ibis_low_rho)
        mean_high = mean(ibis_high_rho)
        @test abs(mean_low - mean_high) / mean_low > 0.05

        # Test 5: fit(:bayesian) produces valid result
        synthetic_data = HeartRateLab.Models.simulate(lorenz, params, n_beats=150)
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
end

# ============================================================================
# LIF Model - IMPLEMENTED (requires DifferentialEquations)
# ============================================================================
@testset "LIF Model (requires DifferentialEquations)" begin
    @test_broken begin
        lif = HeartRateLab.Models.LIF(τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)

        # Test 1: Model can be created
        @test lif.τ ≈ 50.0
        @test lif.I_base ≈ 0.8
        @test lif.threshold ≈ 1.0
        @test lif.noise_amp ≈ 0.15

        # Test 2: parameter_space() returns expected parameters
        ps = HeartRateLab.Models.parameter_space(lif)
        @test haskey(ps, :τ)
        @test haskey(ps, :I_base)
        @test haskey(ps, :threshold)
        @test haskey(ps, :noise_amp)
        @test haskey(ps, :σ_noise)

        # Test 3: simulate() produces valid IBIs
        params = (τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        ibis = HeartRateLab.Models.simulate(lif, params, n_beats=50)

        @test length(ibis) == 50
        @test all(ibis .> 0)
        @test all(300 .< ibis .< 2000)

        # Test 4: Different parameters produce different dynamics
        params_slow_tau = (τ=80.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        ibis_slow = HeartRateLab.Models.simulate(lif, params_slow_tau, n_beats=50)

        # Slower time constant should affect variability
        @test std(ibis_slow) != std(ibis)

        # Test 5: fit(:gradient) produces valid result
        result = HeartRateLab.Models.fit(lif, ibis; method=:gradient)

        @test result.model isa HeartRateLab.Models.LIF
        @test result.method == :gradient
        @test haskey(result.diagnostics, "converged")
        @test haskey(result.diagnostics, "loss_final")
        @test result.posterior === nothing  # No posterior for gradient

        # Test 6: Gradient fit produces valid parameters
        @test 10.0 <= result.params.τ <= 100.0
        @test 0.5 <= result.params.I_base <= 1.5
        @test 0.5 <= result.params.threshold <= 1.5
        @test 0.05 <= result.params.noise_amp <= 0.5

        # Test 7: fit(:bayesian) produces valid result
        result_bayes = HeartRateLab.Models.fit(lif, ibis; method=:bayesian, chains=2, samples=100)

        @test result_bayes.model isa HeartRateLab.Models.LIF
        @test result_bayes.method == :bayesian
        @test result_bayes.posterior !== nothing
        @test haskey(result_bayes.posterior, "τ")
        @test haskey(result_bayes.posterior, "I_base")
        @test haskey(result_bayes.posterior, "threshold")
        @test haskey(result_bayes.posterior, "noise_amp")

        # Test 8: Bayesian fit produces valid parameters
        @test result_bayes.params.τ > 0
        @test result_bayes.params.I_base > 0
        @test result_bayes.params.threshold > 0
        @test result_bayes.params.noise_amp > 0

        # Test 9: Diagnostics include R-hat values
        @test haskey(result_bayes.diagnostics, "rhat_tau")
        @test haskey(result_bayes.diagnostics, "rhat_I_base")
        @test haskey(result_bayes.diagnostics, "rhat_threshold")
        @test haskey(result_bayes.diagnostics, "rhat_noise_amp")
        @test haskey(result_bayes.diagnostics, "rhat_sigma_noise")

        # Test 10: Posterior samples have expected length
        expected_samples = 100 * 2  # samples * chains
        @test length(result_bayes.posterior["τ"]) == expected_samples
        @test length(result_bayes.posterior["I_base"]) == expected_samples
        @test length(result_bayes.posterior["threshold"]) == expected_samples
        @test length(result_bayes.posterior["noise_amp"]) == expected_samples
    end
end
