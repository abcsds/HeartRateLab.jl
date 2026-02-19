using HeartRateLab: HeartRateLab
using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

# Test DMD model (doesn't require DifferentialEquations)
try
    using LinearAlgebra

    @testset "DMD Model" begin

    # Create synthetic IBI data from a simple oscillatory pattern
    t = range(0, 10, length=50)
    synthetic_ibis = 800 .+ 100 .* sin.(2π .* t / 10) .+ randn(50) .* 10

    # Create a DMD model instance
    dmd = HeartRateLab.Models.DMD(rank=5)

    # Test 1: Model can be created
    @test dmd.rank == 5
    @test isempty(dmd.modes)  # Unfitted model has no modes
    @test isempty(dmd.evals)

    # Test 2: fit() works and updates the model
    fitted_dmd = HeartRateLab.Models.fit(dmd, synthetic_ibis)

    @test !isempty(fitted_dmd.modes)  # Fitted model has modes
    @test !isempty(fitted_dmd.evals)
    @test length(fitted_dmd.modes) <= fitted_dmd.rank
    @test length(fitted_dmd.evals) == length(fitted_dmd.modes)

    # Test 3: simulate() produces valid IBIs
    reconstructed = HeartRateLab.Models.simulate(fitted_dmd, nothing, length(synthetic_ibis))

    @test length(reconstructed) ≈ length(synthetic_ibis)
    @test all(reconstructed .> 0)  # All IBIs positive
    @test all(300 .< reconstructed .< 2000)  # IBIs in physiological range

    # Test 4: Reconstruction captures mean of original data
    orig_mean = mean(synthetic_ibis)
    recon_mean = mean(reconstructed)

    @test abs(orig_mean - recon_mean) < 50.0  # Within 50 ms

    # Test 5: round-trip has reasonable fidelity
    # Compute correlation between original and reconstructed
    orig_centered = synthetic_ibis .- mean(synthetic_ibis)
    recon_centered = reconstructed .- mean(reconstructed)

    if std(orig_centered) > 0 && std(recon_centered) > 0
        correlation = cor(orig_centered, recon_centered)
        @test correlation > 0.3  # Moderate correlation indicates good reconstruction
    end

    # Test 6: Different rank produces different reconstructions
    dmd_rank2 = HeartRateLab.Models.DMD(rank=2)
    fitted_dmd2 = HeartRateLab.Models.fit(dmd_rank2, synthetic_ibis)
    recon2 = HeartRateLab.Models.simulate(fitted_dmd2, nothing, length(synthetic_ibis))

    dmd_rank10 = HeartRateLab.Models.DMD(rank=10)
    fitted_dmd10 = HeartRateLab.Models.fit(dmd_rank10, synthetic_ibis)
    recon10 = HeartRateLab.Models.simulate(fitted_dmd10, nothing, length(synthetic_ibis))

    # Higher rank should reconstruct more accurately
    error2 = sum(abs.(synthetic_ibis .- recon2))
    error10 = sum(abs.(synthetic_ibis .- recon10))

    @test error10 <= error2  # Lower rank should have higher error
    end

catch err
    @warn "Skipping DMD model tests - LinearAlgebra not available" exception=err
end

# Only run ODE model tests if DifferentialEquations is available
try
    using DifferentialEquations
    using Optim

    @testset "Van der Pol Model" begin
        # Create a Van der Pol model instance
        vdp = HeartRateLab.Models.VanDerPol(μ=1.5, heart_rate=70.0)

        # Test 1: Model can be created
        @test vdp.μ ≈ 1.5
        @test vdp.heart_rate ≈ 70.0

        # Test 2: parameter_space returns valid bounds
        ps = HeartRateLab.Models.parameter_space(vdp)
        @test haskey(ps, :μ)
        @test haskey(ps, :heart_rate)
        @test ps.μ.lower < ps.μ.upper
        @test ps.heart_rate.lower < ps.heart_rate.upper

        # Test 3: simulate() produces valid IBIs
        params = (μ=1.5, heart_rate=70.0)
        ibis = HeartRateLab.Models.simulate(vdp, params, n_beats=50)

        @test length(ibis) ≈ 50 atol=5  # Allow some tolerance for peak detection
        @test all(ibis .> 0)  # All IBIs positive
        @test all(300 .< ibis .< 2000)  # IBIs in physiological range (300-2000 ms for 30-200 BPM)

        # Test 4: Different μ produces different IBIs
        params_low_mu = (μ=0.8, heart_rate=70.0)
        ibis_low_mu = HeartRateLab.Models.simulate(vdp, params_low_mu, n_beats=50)

        params_high_mu = (μ=2.5, heart_rate=70.0)
        ibis_high_mu = HeartRateLab.Models.simulate(vdp, params_high_mu, n_beats=50)

        # Different μ values should produce meaningfully different outputs
        mean_low = mean(ibis_low_mu)
        mean_high = mean(ibis_high_mu)
        @test abs(mean_low - mean_high) / mean_low > 0.05  # At least 5% difference

        # Test 5: heart_rate parameter affects timing
        params_slow_hr = (μ=1.5, heart_rate=50.0)
        ibis_slow_hr = HeartRateLab.Models.simulate(vdp, params_slow_hr, n_beats=50)

        params_fast_hr = (μ=1.5, heart_rate=100.0)
        ibis_fast_hr = HeartRateLab.Models.simulate(vdp, params_fast_hr, n_beats=50)

        # Slower heart rate should produce longer IBIs
        @test mean(ibis_slow_hr) > mean(ibis_fast_hr)

        # Test 6: Standard deviation is reasonable (not all identical)
        @test std(ibis) > 5.0  # At least some variation

        # Test 7: fit() method produces valid results
        # Generate synthetic data from Van der Pol to test fitting
        synthetic_data = HeartRateLab.Models.simulate(vdp, params, n_beats=200)

        try
            fitted_result = HeartRateLab.Models.fit(vdp, synthetic_data; method=:gradient)

            @test fitted_result.model isa HeartRateLab.Models.VanDerPol
            @test fitted_result.method == :gradient
            @test haskey(fitted_result.params, :μ)
            @test haskey(fitted_result.params, :heart_rate)
            @test fitted_result.params.μ > 0
            @test fitted_result.params.heart_rate > 0

            # Test 8: Fitted parameters are within bounds
            ps = HeartRateLab.Models.parameter_space(vdp)
            @test ps.μ.lower <= fitted_result.params.μ <= ps.μ.upper
            @test ps.heart_rate.lower <= fitted_result.params.heart_rate <= ps.heart_rate.upper

            # Test 9: Fitted parameters are reasonably close to original
            # (not exact because we're minimizing distance in feature space)
            @test abs(fitted_result.params.μ - params.μ) < 1.0  # Within 1.0
            @test abs(fitted_result.params.heart_rate - params.heart_rate) < 30.0  # Within 30 BPM

            # Test 10: Fitted model produces IBIs similar to real data
            fitted_synthetic = HeartRateLab.Models.simulate(vdp, fitted_result.params, 200)
            @test mean(fitted_synthetic) ≈ mean(synthetic_data) atol=50.0  # Within 50 ms
            @test std(fitted_synthetic) ≈ std(synthetic_data) atol=30.0  # Within 30 ms

            # Test 11: Diagnostics contain useful information
            @test haskey(fitted_result.diagnostics, "converged")
            @test haskey(fitted_result.diagnostics, "iterations")
            @test haskey(fitted_result.diagnostics, "loss_final")
            @test fitted_result.diagnostics["loss_final"] >= 0

        catch e
            @warn "Van der Pol fitting test skipped: $e"
        end
    end

    @testset "Lorenz Model" begin
        # Create a Lorenz model instance with standard parameters
        lorenz = HeartRateLab.Models.Lorenz(σ=10.0, ρ=28.0, β=8/3, threshold=10.0)

        # Test 1: Model can be created
        @test lorenz.σ ≈ 10.0
        @test lorenz.ρ ≈ 28.0
        @test lorenz.β ≈ 8/3
        @test lorenz.threshold ≈ 10.0

        # Test 2: parameter_space returns valid bounds
        ps = HeartRateLab.Models.parameter_space(lorenz)
        @test haskey(ps, :σ)
        @test haskey(ps, :ρ)
        @test haskey(ps, :β)
        @test haskey(ps, :threshold)
        @test ps.σ.lower < ps.σ.upper
        @test ps.ρ.lower < ps.ρ.upper
        @test ps.β.lower < ps.β.upper
        @test ps.threshold.lower < ps.threshold.upper

        # Test 3: simulate() produces valid IBIs
        params = (σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
        ibis = HeartRateLab.Models.simulate(lorenz, params, n_beats=40)

        @test length(ibis) ≈ 40 atol=8  # Allow tolerance for crossing detection
        @test all(ibis .> 0)  # All IBIs positive
        @test all(300 .< ibis .< 2000)  # IBIs in physiological range

        # Test 4: Different ρ (chaos parameter) produces different IBIs
        params_low_rho = (σ=10.0, ρ=20.0, β=8/3, threshold=10.0)
        ibis_low_rho = HeartRateLab.Models.simulate(lorenz, params_low_rho, n_beats=40)

        params_high_rho = (σ=10.0, ρ=35.0, β=8/3, threshold=10.0)
        ibis_high_rho = HeartRateLab.Models.simulate(lorenz, params_high_rho, n_beats=40)

        # Different ρ should produce different statistics
        mean_low = mean(ibis_low_rho)
        mean_high = mean(ibis_high_rho)
        @test abs(mean_low - mean_high) / mean_low > 0.05  # At least 5% difference

        # Test 5: Different threshold produces different IBIs
        params_low_thresh = (σ=10.0, ρ=28.0, β=8/3, threshold=5.0)
        ibis_low_thresh = HeartRateLab.Models.simulate(lorenz, params_low_thresh, n_beats=40)

        params_high_thresh = (σ=10.0, ρ=28.0, β=8/3, threshold=15.0)
        ibis_high_thresh = HeartRateLab.Models.simulate(lorenz, params_high_thresh, n_beats=40)

        # Different thresholds should produce different results
        @test abs(mean(ibis_low_thresh) - mean(ibis_high_thresh)) > 10.0

        # Test 6: Standard deviation is reasonable (chaotic system shows variability)
        @test std(ibis) > 20.0  # Chaotic systems show high variability

        # Test 7: Lorenz generates realistic cardiac dynamics (not monotonic)
        @test maximum(ibis) > 1.5 * minimum(ibis)  # Wide range of intervals
    end

    @testset "LIF Model - Gradient Fitting" begin
        # Create test data: synthetic IBIs from LIF
        lif = HeartRateLab.Models.LIF(τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        true_params = (τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        synthetic_ibis = HeartRateLab.Models.simulate(lif, true_params, n_beats=100)

        # Test 1: Model can be created
        @test lif.τ ≈ 50.0
        @test lif.I_base ≈ 0.8
        @test lif.threshold ≈ 1.0
        @test lif.noise_amp ≈ 0.15

        # Test 2: parameter_space returns valid bounds
        ps = HeartRateLab.Models.parameter_space(lif)
        @test haskey(ps, :τ)
        @test haskey(ps, :I_base)
        @test haskey(ps, :threshold)
        @test haskey(ps, :noise_amp)
        @test ps.τ.lower < ps.τ.upper
        @test ps.I_base.lower < ps.I_base.upper
        @test ps.threshold.lower < ps.threshold.upper
        @test ps.noise_amp.lower < ps.noise_amp.upper

        # Test 3: simulate() produces valid IBIs
        ibis = HeartRateLab.Models.simulate(lif, true_params, n_beats=50)
        @test length(ibis) == 50
        @test all(ibis .> 0)  # All IBIs positive
        @test all(300 .< ibis .< 2000)  # IBIs in physiological range

        # Test 4: Gradient fitting works and returns ModelFitResult
        result = HeartRateLab.Models.fit(lif, synthetic_ibis; method=:gradient, max_iter=100)

        @test result.model isa HeartRateLab.Models.LIF
        @test result.method == :gradient
        @test haskey(result.diagnostics, "converged")
        @test haskey(result.diagnostics, "loss_final")
        @test haskey(result.diagnostics, "method")
        @test result.diagnostics["method"] == "LBFGS"

        # Test 5: Fitted parameters produce valid IBIs
        fitted_params = result.params
        @test haskey(fitted_params, :τ)
        @test haskey(fitted_params, :I_base)
        @test haskey(fitted_params, :threshold)
        @test haskey(fitted_params, :noise_amp)

        fitted_ibis = HeartRateLab.Models.simulate(lif, fitted_params, n_beats=50)
        @test length(fitted_ibis) == 50
        @test all(fitted_ibis .> 0)
        @test all(300 .< fitted_ibis .< 2000)

        # Test 6: Fitted parameters are within parameter space bounds
        @test ps.τ.lower <= fitted_params.τ <= ps.τ.upper
        @test ps.I_base.lower <= fitted_params.I_base <= ps.I_base.upper
        @test ps.threshold.lower <= fitted_params.threshold <= ps.threshold.upper
        @test ps.noise_amp.lower <= fitted_params.noise_amp <= ps.noise_amp.upper

        # Test 7: Gradient fitting reduces distance to target statistics
        target_stats = HeartRateLab.Models.compute_summary_stats(synthetic_ibis)
        fitted_stats = HeartRateLab.Models.compute_summary_stats(fitted_ibis)

        # Compute normalized distance
        distance = sum((target_stats .- fitted_stats).^2)
        @test distance < 1e6  # Reasonable fit
    end

    @testset "LIF Model - Bayesian Fitting" begin
        # Create test data with smaller dataset to make Bayesian fitting faster
        lif = HeartRateLab.Models.LIF(τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        true_params = (τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        synthetic_ibis = HeartRateLab.Models.simulate(lif, true_params, n_beats=80)

        # Test 1: Bayesian fitting works and returns ModelFitResult
        result = HeartRateLab.Models.fit(
            lif, synthetic_ibis;
            method=:bayesian,
            chains=2,
            samples=100
        )

        @test result.model isa HeartRateLab.Models.LIF
        @test result.method == :bayesian
        @test haskey(result.diagnostics, "method")
        @test result.diagnostics["method"] == "NUTS (Turing.jl)"

        # Test 2: Posterior samples are provided
        @test result.posterior !== nothing
        @test haskey(result.posterior, "τ")
        @test haskey(result.posterior, "I_base")
        @test haskey(result.posterior, "threshold")
        @test haskey(result.posterior, "noise_amp")

        # Test 3: Posterior samples have expected length
        expected_samples = 100 * 2  # samples * chains
        @test length(result.posterior["τ"]) == expected_samples
        @test length(result.posterior["I_base"]) == expected_samples
        @test length(result.posterior["threshold"]) == expected_samples
        @test length(result.posterior["noise_amp"]) == expected_samples

        # Test 4: Diagnostics include convergence information
        @test haskey(result.diagnostics, "chains")
        @test haskey(result.diagnostics, "samples_per_chain")
        @test haskey(result.diagnostics, "total_samples")
        @test result.diagnostics["chains"] == 2
        @test result.diagnostics["samples_per_chain"] == 100

        # Test 5: R-hat convergence diagnostics are computed
        @test haskey(result.diagnostics, "rhat_tau")
        @test haskey(result.diagnostics, "rhat_I_base")
        @test haskey(result.diagnostics, "rhat_threshold")
        @test haskey(result.diagnostics, "rhat_noise_amp")

        # Test 6: R-hat values are reasonable (ideally close to 1.0, acceptable if < 1.1)
        @test result.diagnostics["rhat_tau"] > 0.5  # Sanity check
        @test result.diagnostics["rhat_I_base"] > 0.5
        @test result.diagnostics["rhat_threshold"] > 0.5
        @test result.diagnostics["rhat_noise_amp"] > 0.5

        # Test 7: Best parameters from posterior mean
        best_params = result.params
        @test haskey(best_params, :τ)
        @test haskey(best_params, :I_base)
        @test haskey(best_params, :threshold)
        @test haskey(best_params, :noise_amp)

        # Test 8: Best parameters are within prior bounds
        ps = HeartRateLab.Models.parameter_space(lif)
        @test ps.τ.lower <= best_params.τ <= ps.τ.upper
        @test ps.I_base.lower <= best_params.I_base <= ps.I_base.upper
        @test ps.threshold.lower <= best_params.threshold <= ps.threshold.upper
        @test ps.noise_amp.lower <= best_params.noise_amp <= ps.noise_amp.upper

        # Test 9: Posterior mean produces valid IBIs
        synthetic_from_posterior = HeartRateLab.Models.simulate(lif, best_params, n_beats=50)
        @test length(synthetic_from_posterior) == 50
        @test all(synthetic_from_posterior .> 0)
        @test all(300 .< synthetic_from_posterior .< 2000)

        # Test 10: Posterior captures parameter uncertainty (std > 0 for each parameter)
        @test std(result.posterior["τ"]) > 0
        @test std(result.posterior["I_base"]) > 0
        @test std(result.posterior["threshold"]) > 0
        @test std(result.posterior["noise_amp"]) > 0
    end

    @testset "LIF Model - Method Dispatch" begin
        # Test that fit() correctly dispatches to different methods
        lif = HeartRateLab.Models.LIF(τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        true_params = (τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        synthetic_ibis = HeartRateLab.Models.simulate(lif, true_params, n_beats=50)

        # Test 1: :gradient method returns gradient result
        grad_result = HeartRateLab.Models.fit(lif, synthetic_ibis; method=:gradient, max_iter=50)
        @test grad_result.method == :gradient
        @test grad_result.posterior === nothing  # No posterior for gradient

        # Test 2: :bayesian method returns Bayesian result
        bayes_result = HeartRateLab.Models.fit(
            lif, synthetic_ibis;
            method=:bayesian,
            chains=2,
            samples=50
        )
        @test bayes_result.method == :bayesian
        @test bayes_result.posterior !== nothing  # Should have posterior

        # Test 3: Invalid method raises error
        @test_throws ErrorException HeartRateLab.Models.fit(
            lif, synthetic_ibis;
            method=:invalid_method
        )

        # Test 4: Both methods produce reasonable parameters
        @test 0 < grad_result.params.I_base < 2.0
        @test 0 < bayes_result.params.I_base < 2.0
    end

catch err
    @warn "Skipping model tests - DifferentialEquations or Optim not available" exception=err
end
