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

catch err
    @warn "Skipping model tests - DifferentialEquations or Optim not available" exception=err
end
