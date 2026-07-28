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

    @testset "compute + write + load round-trip" begin
        # Three synthetic 300-beat recordings around 800 ms
        mkrec(seed) = (Random.seed!(seed);
                       800.0 .+ 30.0 .* randn(300))
        recs = [mkrec(1), mkrec(2), mkrec(3)]

        grids = VB.compute_baseline_grids(recs; window_size = 100, stride = 25)
        @test Set(keys(grids)) == Set(VB.BASELINE_QUANTITIES)
        for q in VB.BASELINE_QUANTITIES
            @test length(grids[q]) == 101
            g = filter(isfinite, grids[q])
            @test issorted(g)                       # quantile grid is monotone
        end

        tmp = tempname() * ".csv"
        VB.write_baseline_csv(tmp, grids, Dict("window_size" => "100", "stride" => "25"))
        @test isfile(tmp)

        bl = VB.load_personal_baseline(tmp)
        @test bl.meta["window_size"] == "100"
        for q in VB.BASELINE_QUANTITIES
            @test bl.grids[q] ≈ grids[q] nans = true
        end
        rm(tmp; force = true)
    end

    @testset "generator core on a temp fixture" begin
        # Build a tiny export dir: 2 recordings of 250 beats each
        dir = mktempdir()
        Random.seed!(7)
        for k in 1:2
            vals = round.(Int, 800.0 .+ 25.0 .* randn(250))
            open(joinpath(dir, "rec$k.txt"), "w") do io
                for v in vals
                    println(io, v)
                end
            end
        end

        # Reproduce the generator's load+compute using the public helpers
        recs = [Float64.(HeartRateLab.read_txt(joinpath(dir, f)))
                for f in readdir(dir) if endswith(f, ".txt")]
        grids = VB.compute_baseline_grids(recs; window_size = 100, stride = 25)

        out = joinpath(dir, "baseline.csv")
        VB.write_baseline_csv(out, grids, Dict("window_size" => "100"))
        bl = VB.load_personal_baseline(out)

        @test Set(keys(bl.grids)) == Set(VB.BASELINE_QUANTITIES)
        @test all(length(bl.grids[q]) == 101 for q in VB.BASELINE_QUANTITIES)
        # meanrr median should sit near the 800 ms generating mean
        @test VB.baseline_quantile(bl, "meanrr", 50) ≈ 800.0 atol = 25.0
        rm(dir; recursive = true, force = true)
    end

end
