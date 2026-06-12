using HeartRateLab: HeartRateLab
using Test
using StatsBase
using Random

# Set working directory to test directory for relative paths
cd(@__DIR__)

# d-15: seed so the `rand`-based synthetic tests below are reproducible.
Random.seed!(20260612)

@testset "Preprocessing" begin
    @testset "replace_zeros" begin
        # Test replacing zeros with NaN
        @testset "Synthetic" begin
            @test isequal(
                HeartRateLab.replace_zeros([1, 2, 0, 4, 5, 0, 7]),
                Float64[1.0, 2.0, NaN, 4.0, 5.0, NaN, 7.0],
            )
        end
    end

    @testset "replace_bio_outliers" begin
        # Test replacing biological outliers with NaN
        @testset "synthetic" begin
            @test isequal(
                HeartRateLab.replace_bio_outliers([
                    400, 500, 200, 2000, 1000, 3000, 1500, 100
                ]),
                Float64[400.0, 500.0, NaN, 2000, 1000.0, NaN, 1500.0, NaN],
            )
        end
    end

    @testset "replace_statistical_outliers" begin
        # Test replacing statistical outliers with NaN
        @testset "synthetic" begin
            # Generate synthetic data
            N = 100
            a_dist = Float64.(rand(600:1200, N))
            q_high = quantile(a_dist, 0.75)
            q_low = quantile(a_dist, 0.25)
            ridx = [e<q_low || e>q_high for e in a_dist]
            goal = copy(a_dist)
            goal[ridx] .= repeat([NaN], sum(ridx))
            @test isequal(
                HeartRateLab.replace_statistical_outliers(
                    a_dist; low=0.25, high=0.75
                ),
                goal,
            )
        end
    end

    @testset "replace_ectopic_beats" begin
        # Test replacing ectopic beats with NaN
        if isfile("testdata/example.txt")
            @testset "rr-interval-healthy-subjects" begin
                hrv = HeartRateLab.read_txt("testdata/example.txt")
                n = hrv[1:1000]
                @test sum(isnan.(n))==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(n; method=:malik)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(n; method=:kamath)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:acar, threshold=0.2
                        ),
                    ),
                )==3
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:karlsson, threshold=0.2
                        ),
                    ),
                )==499
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:custom, threshold=0.2
                        ),
                    ),
                )==0

                n = hrv[1000:2000]
                @test sum(isnan.(n))==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(n; method=:malik)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(n; method=:kamath)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:acar, threshold=0.2
                        ),
                    ),
                )==8
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:karlsson, threshold=0.2
                        ),
                    ),
                )==500
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:custom, threshold=0.2
                        ),
                    ),
                )==0
            end
        else
            @warn "Ectopic beats test skipped: testdata/example.txt not found"
        end
    end

    @testset "strip_extremes" begin
        # Test stripping extremes from the data
        @testset "synthetic" begin
            n = [1.0e-10; rand(100)]
            result = HeartRateLab.strip_extremes(n)
            @test length(result) == length(n) - count(iszero.(n))
        end
    end

    @testset "interpolate_nans" begin
        # Test interpolating NaN values
        @testset "synthetic" begin
            @test isequal(
                HeartRateLab.interpolate_nans(
                    Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:constant
                ),
                Float64[1.0, 2.0, 2.0, 4.0, 5.0, 5.0, 7.0],
            )
            @test isequal(
                HeartRateLab.interpolate_nans(
                    Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:linear
                ),
                Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
            )
            @test isapprox(
                HeartRateLab.interpolate_nans(
                    Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:quadratic
                ),
                Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
                atol=1e-6,
            )
            @test isequal(
                HeartRateLab.interpolate_nans(
                    Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:cubic
                ),
                Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
            )
        end
    end

    @testset "Windowed" begin
        # Test windowed function
        @testset "synthetic" begin
            v = Float64[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            @test isequal(
                HeartRateLab.windowed(v; window_size=3),
                [
                    [1.0, 2.0, 3.0],
                    [2.0, 3.0, 4.0],
                    [3.0, 4.0, 5.0],
                    [4.0, 5.0, 6.0],
                    [5.0, 6.0, 7.0],
                    [6.0, 7.0, 8.0],
                    [7.0, 8.0, 9.0],
                    [8.0, 9.0, 10.0],
                ],
            )
            @test isequal(
                HeartRateLab.windowed(v; window_size=3, stride=3),
                [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]],
            )
            @test isequal(
                HeartRateLab.windowed(
                    v; window_size=3, stride=3, f=StatsBase.mean
                ),
                [2.0, 5.0, 8.0],
            )
        end
    end
end

# d-13: mutating `!` pairs, the resampling `interpolate`, and NaN/edge cases that the
# main suite leaves untested.
@testset "Preprocessing edge paths & mutating pairs" begin
    @testset "interpolate_nans fills interior NaN — all 4 methods on RR-scale data" begin
        # Regression for the reversed-argument bug: on real RR-scale data each method must
        # RUN (the reversed form threw ExtrapolationError, since values 790–810 lie far
        # outside the index range 1–5) and fill the interior NaN with a method-consistent
        # value — NOT only :linear (the other 3 branches were previously only exercised by
        # the degenerate [1,2,NaN,…] fixture where the bug is invisible).
        rr = [800.0, 810.0, NaN, 790.0, 805.0]
        for (m, expected) in ((:constant, 810.0),   # last-value hold (left neighbour)
                              (:linear, 800.0),      # midpoint of 810, 790
                              (:quadratic, 791.667),
                              (:cubic, 799.062))
            out = HeartRateLab.interpolate_nans(copy(rr); method=m)
            @test length(out) == length(rr)
            @test !any(isnan, out)
            @test out[3] ≈ expected atol = 0.01
        end
        @test HeartRateLab.interpolate_nans([800.0, NaN, 800.0]) ≈ [800.0, 800.0, 800.0]
        @test all(x -> x ≈ 810.0, HeartRateLab.interpolate_nans([810.0, NaN, NaN, 810.0]))
        @test isequal(HeartRateLab.interpolate_nans([800.0]), [800.0])   # single, no NaN
    end

    @testset "interpolate_nans preserves length and fills boundary NaNs (d-25)" begin
        # Length is PRESERVED: leading/trailing NaNs are filled by extrapolation, not trimmed
        # (the old strip_extremes behaviour shortened the array — a footgun for length-sensitive
        # callers). Interior NaN interpolated; boundary NaNs linearly extrapolated.
        out = HeartRateLab.interpolate_nans([NaN, 800.0, 810.0, NaN, 790.0, NaN])
        @test length(out) == 6                  # SAME length as the input
        @test !any(isnan, out)
        @test out ≈ [790.0, 800.0, 810.0, 800.0, 790.0, 780.0]
    end

    @testset "interpolate_nans error & non-Float paths" begin
        # > half the series is NaN → ArgumentError.
        @test_throws ArgumentError HeartRateLab.interpolate_nans([800.0, NaN, NaN, NaN, 810.0])
        # Unsupported method → ArgumentError.
        @test_throws ArgumentError HeartRateLab.interpolate_nans([800.0, NaN, 810.0]; method=:bogus)
        # Signature is Array{Float64,1}: integer input → MethodError (documented contract).
        @test_throws MethodError HeartRateLab.interpolate_nans([1, 2, 3])
        # Empty input → no NaNs to fill → returns empty (length-preserving, no error).
        @test HeartRateLab.interpolate_nans(Float64[]) == Float64[]
    end

    @testset "interpolate_nans! mutates IN PLACE and matches the non-mutating pair (d-25)" begin
        # d-25 fixed: interpolate_nans! now genuinely mutates its argument in place (no
        # strip_extremes rebind), the point of the `!`.
        x  = [800.0, 810.0, NaN, 790.0, 805.0]
        x0 = copy(x)
        out = HeartRateLab.interpolate_nans(x)        # non-mutating
        @test isequal(x, x0)                           # the non-mutating pair leaves input intact
        z = copy(x)
        r = HeartRateLab.interpolate_nans!(z)
        @test r === z                                  # returns the SAME array (mutated in place)
        @test !any(isnan, z)                           # filled in place
        @test isequal(z, out)                          # same result as the non-mutating pair
    end

    @testset "replace_ectopic_beats! mutates IN PLACE and matches the non-mutating pair" begin
        e  = [800.0, 810.0, 400.0, 805.0, 800.0, 795.0]  # 400 ms is ectopic
        e0 = copy(e)
        out = HeartRateLab.replace_ectopic_beats(e)
        @test isequal(e, e0)                          # the non-mutating pair leaves input intact
        z = copy(e)
        r = HeartRateLab.replace_ectopic_beats!(z)
        @test r === z                                  # returns the SAME array (mutated in place)
        @test isequal(z, out)                          # same result as the pair
    end

    @testset "interpolate (resampling) — numerical contract" begin
        sig = collect(800.0:5.0:1000.0)             # 41 RR intervals, 800..1000 ms
        out = HeartRateLab.interpolate(sig; method=:linear, fs=10)
        @test out isa Vector{Float64}
        @test all(isfinite, out)
        @test out[1] == sig[1]                       # resampled series starts at the first value
        @test out[end] ≈ sig[end]                    # …and ends at the last
        @test length(out) == 362                     # one sample / 100 ms over the cumulative span
        # NaN input must be rejected, not silently propagated.
        @test_throws ArgumentError HeartRateLab.interpolate([800.0, NaN, 810.0])
    end
end
