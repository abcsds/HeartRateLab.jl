using Test
using HeartRateLab
using Statistics
using Random

const VB = HeartRateLab.Visualization

@testset "personal_baseline" begin

    @testset "canonical win-stats match library formulas" begin
        w = Float64[800, 820, 790, 810, 805, 795, 815, 800, 830, 780,
                    800, 820, 790, 810, 805, 795, 815, 800, 830, 780]
        x = w[1:end-1]; y = w[2:end]

        @test VB._win_sdnn(w)  ≈ std(w)
        @test VB._win_rmssd(w) ≈ sqrt(sum(diff(w).^2)) / sqrt(length(w) - 1)
        @test VB._win_sd1(w)   ≈ sqrt(var((x .- y) ./ sqrt(2)))
        @test VB._win_sd2(w)   ≈ sqrt(var((x .+ y) ./ sqrt(2)))
    end

    @testset "baseline_quantile interpolation" begin
        grids = Dict("sdnn" => collect(0.0:1.0:100.0))   # q_i == i
        bl = VB.PersonalBaseline(grids, Dict{String,String}())

        @test VB.baseline_quantile(bl, "sdnn", 0)   ≈ 0.0
        @test VB.baseline_quantile(bl, "sdnn", 100) ≈ 100.0
        @test VB.baseline_quantile(bl, "sdnn", 10)  ≈ 10.0     # exact grid point
        @test VB.baseline_quantile(bl, "sdnn", 10.5) ≈ 10.5    # interpolated
        @test VB.baseline_quantile(bl, "sdnn", 150) ≈ 100.0    # clamped
        @test isnan(VB.baseline_quantile(bl, "absent", 50))

        band = VB.baseline_band(bl, "sdnn"; low = 10, high = 90)
        @test band.lo ≈ 10.0 && band.med ≈ 50.0 && band.hi ≈ 90.0
    end

    @testset "baseline_ellipse geometry" begin
        grids = Dict(
            "meanrr" => fill(800.0, 101),
            "sd1"    => collect(range(5.0, 45.0; length = 101)),
            "sd2"    => collect(range(15.0, 95.0; length = 101)),
        )
        bl = VB.PersonalBaseline(grids, Dict{String,String}())
        xs, ys = VB.baseline_ellipse(bl; p = 50)              # default centre = median meanrr
        @test length(xs) == length(ys) == 100
        @test all(isfinite, xs) && all(isfinite, ys)
        @test sum(xs) / length(xs) ≈ 800.0 atol = 1.0
        @test sum(ys) / length(ys) ≈ 800.0 atol = 1.0
        # Explicit live centre overrides the default
        xs2, ys2 = VB.baseline_ellipse(bl; p = 50, cx = 700.0, cy = 720.0)
        @test sum(xs2) / length(xs2) ≈ 700.0 atol = 1.0
        @test sum(ys2) / length(ys2) ≈ 720.0 atol = 1.0
    end

    @testset "personal percentile + z round-trip" begin
        grids = Dict("sdnn" => collect(0.0:1.0:100.0))   # q_i == i
        bl = VB.PersonalBaseline(grids, Dict{String,String}())
        # baseline_percentile_of inverts baseline_quantile
        @test VB.baseline_percentile_of(bl, "sdnn", 50.0) ≈ 50.0
        @test VB.baseline_percentile_of(bl, "sdnn", 10.0) ≈ 10.0
        @test VB.baseline_percentile_of(bl, "sdnn", 10.5) ≈ 10.5
        @test VB.baseline_percentile_of(bl, "sdnn", -5.0) ≈ 0.0     # below grid
        @test VB.baseline_percentile_of(bl, "sdnn", 999.0) ≈ 100.0  # above grid
        @test isnan(VB.baseline_percentile_of(bl, "absent", 1.0))
        # z = Φ⁻¹(p/100): median → 0, p≈84 → ≈ +1
        @test VB.baseline_z(bl, "sdnn", 50.0) ≈ 0.0 atol = 1e-6
        @test VB.baseline_z(bl, "sdnn", 84.0) ≈ 0.9945 atol = 1e-3
        @test VB.baseline_z(bl, "sdnn", 16.0) ≈ -0.9945 atol = 1e-3
    end

end
