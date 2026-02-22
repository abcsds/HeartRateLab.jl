using HeartRateLab: HeartRateLab
using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

# ============================================================================
# DMD Model - NOT YET IMPLEMENTED
# ============================================================================
@testset "DMD Model (NOT YET IMPLEMENTED)" begin
    @test_broken begin
        # This test is BROKEN until DMD is actually implemented
        # It will fail loudly, not silently skip
        using LinearAlgebra

        synthetic_ibis = 800 .+ 100 .* sin.(2π .* range(0, 10, length=50) / 10) .+ randn(50) .* 10

        dmd = HeartRateLab.Models.DMD(rank=5)
        @test dmd.rank == 5
        @test isempty(dmd.modes)

        fitted_dmd = HeartRateLab.Models.fit(dmd, synthetic_ibis)
        @test !isempty(fitted_dmd.modes)

        reconstructed = HeartRateLab.Models.simulate(fitted_dmd, nothing, length(synthetic_ibis))
        @test length(reconstructed) ≈ length(synthetic_ibis)
        @test all(300 .< reconstructed .< 2000)
    end
end

# ============================================================================
# Van der Pol Model - PARTIALLY IMPLEMENTED (simulate only)
# ============================================================================
@testset "Van der Pol Model" begin
    vdp = HeartRateLab.Models.VanDerPol()

    # Test 1: Model can be created
    @test vdp isa HeartRateLab.Models.VanDerPol

    # Test 2: simulate() works
    params = (μ=1.5, heart_rate=70.0)
    ibis = HeartRateLab.Models.simulate(vdp, params, 50)

    @test length(ibis) == 50
    @test all(ibis .> 0)
    @test all(300 .< ibis .< 2000)

    # Test 3: Different μ produces different outputs
    params_low = (μ=0.8, heart_rate=70.0)
    params_high = (μ=2.5, heart_rate=70.0)

    ibis_low = HeartRateLab.Models.simulate(vdp, params_low, 50)
    ibis_high = HeartRateLab.Models.simulate(vdp, params_high, 50)

    @test abs(mean(ibis_low) - mean(ibis_high)) / mean(ibis_low) > 0.05

    # Test 4: parameter_space() - NOT YET IMPLEMENTED
    @test_broken begin
        ps = HeartRateLab.Models.parameter_space(vdp)
        @test haskey(ps, :μ)
        @test haskey(ps, :heart_rate)
    end

    # Test 5: fit() - NOT YET IMPLEMENTED
    @test_broken begin
        synthetic_data = HeartRateLab.Models.simulate(vdp, params, 100)
        fit_result = HeartRateLab.Models.fit(vdp, synthetic_data; method=:gradient)
        @test fit_result.model isa HeartRateLab.Models.VanDerPol
        @test haskey(fit_result.params, :μ)
    end
end

# ============================================================================
# Lorenz Model - NOT YET IMPLEMENTED
# ============================================================================
@testset "Lorenz Model (NOT YET IMPLEMENTED)" begin
    @test_broken begin
        using DifferentialEquations

        lorenz = HeartRateLab.Models.Lorenz(σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
        @test lorenz.σ ≈ 10.0
        @test lorenz.ρ ≈ 28.0

        params = (σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
        ibis = HeartRateLab.Models.simulate(lorenz, params, n_beats=40)

        @test length(ibis) ≈ 40 atol=8
        @test all(ibis .> 0)
        @test all(300 .< ibis .< 2000)
    end
end

# ============================================================================
# LIF Model - NOT YET IMPLEMENTED
# ============================================================================
@testset "LIF Model (NOT YET IMPLEMENTED)" begin
    @test_broken begin
        using DifferentialEquations, Optim

        lif = HeartRateLab.Models.LIF(τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        @test lif.τ ≈ 50.0

        params = (τ=50.0, I_base=0.8, threshold=1.0, noise_amp=0.15)
        ibis = HeartRateLab.Models.simulate(lif, params, n_beats=50)

        @test length(ibis) == 50
        @test all(ibis .> 0)
        @test all(300 .< ibis .< 2000)

        # Test fitting
        fit_result = HeartRateLab.Models.fit(lif, ibis; method=:gradient, max_iter=100)
        @test fit_result.model isa HeartRateLab.Models.LIF
        @test haskey(fit_result.params, :τ)
    end
end
