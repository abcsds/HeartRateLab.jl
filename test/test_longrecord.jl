using HeartRateLab: HeartRateLab
using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

# d-24 (Approach A): long-record validation.
#
# example.txt is a ~1 h / 4193-beat recording. On it, DFA α2 (scales 16–64 beats)
# and the ULF band (≥ 24 h) are NOT physiologically meaningful — α2 ≈ 0.47 there,
# well below the ~1.0 expected of a healthy long-term exponent. To validate that
# these long-horizon features are meaningful, we exercise them on a genuine ~24 h
# record: NSRDB 16265 (`test/testdata/16265.{atr,dat,hea}`, ~99 819 beats).
#
# This is a MEANINGFULNESS check, not a regression baseline: we assert loose,
# physiologically-sane RANGES, never point values. The fast regression guard
# (target/example.csv etc.) stays on example.txt and is untouched.
#
# Only the long-horizon-meaningful features are run on the full 100k-beat record:
# dfa1/dfa2/hurst, the welch-band powers (ulf/vlf/lf/hf), and O(n)/O(n log n)
# time-domain scalars. The O(n²) entropy/nonlinear family is intentionally NOT
# run on the full record (runtime/RAM).
@testset "Long record (NSRDB 16265)" begin
    data = HeartRateLab.read_wfdb("testdata/16265", "atr")
    # read_wfdb must return Float64 ms (read_txt does); the feature pipeline
    # (lomb_scargle/welch/Hurst are typed ::Float64) rejects Vector{Int}.
    @test eltype(data) == Float64
    @test length(data) == 99819

    n = HeartRateLab.Features.HRMeasurement(data)
    fr = HeartRateLab.Features.function_registry

    @testset "DFA exponents meaningful on a 24h record" begin
        α1 = fr["dfa1"](n)
        α2 = fr["dfa2"](n)
        @test isfinite(α1) && isfinite(α2)
        # Healthy long-term scaling sits near 1 (1/f-like). Loose physiological
        # bounds, not point values. On 16265: α1 ≈ 1.25, α2 ≈ 0.99.
        @test 0.7 <= α1 <= 1.5
        @test 0.7 <= α2 <= 1.3

        # The meaningfulness contrast: α2 over the 16–64 beat scales is a real
        # long-term exponent on a 24 h record (≈ 1) but degenerate on the ~1 h
        # example.txt (≈ 0.47). This is exactly why d-24 adds the long record.
        short = HeartRateLab.Features.HRMeasurement(
            HeartRateLab.read_txt("testdata/example.txt")
        )
        α2_short = fr["dfa2"](short)
        @test α2_short < 0.7          # not meaningful on the short record
        @test α2 > α2_short + 0.2     # genuinely larger on the long record
    end

    @testset "DFA box density (d-06)" begin
        # The Peng/Francis split: α1 over geometric scales [4,8,16], α2 over
        # [16,32,64], crossover fixed at 16, no overlap. Verify the box density
        # the production dfa() relies on holds on the long record too.
        s1, _ = HeartRateLab.Features.DFA.dfa(n.data, boxmax=16, boxmin=4, boxratio=2, overlap=0.0)
        s2, _ = HeartRateLab.Features.DFA.dfa(n.data, boxmax=64, boxmin=16, boxratio=2, overlap=0.0)
        @test s1 == [4, 8, 16]
        @test s2 == [16, 32, 64]
    end

    @testset "Hurst exponent" begin
        H = fr["hurst"](n)
        @test isfinite(H)
        @test 0.0 < H < 1.0           # R/S Hurst exponent is bounded in (0,1)
    end

    @testset "Frequency-band powers (welch, 24h)" begin
        # ULF needs a ≥24h record to be meaningful at all; here it is finite and
        # positive (on a short record the welch ULF estimate is unreliable, and
        # under lomb_scargle ulf is NaN by design). Assert finite, positive powers.
        for f in ["ulf", "vlf", "lf", "hf"]
            v = fr[f](n)
            @test isfinite(v)
            @test v > 0
        end
    end

    @testset "Time-domain scalars" begin
        # Sane physiological ranges for a healthy ~24 h record (16265: HR ≈ 75,
        # SDNN ≈ 171 ms, RMSSD ≈ 45 ms, duration ≈ 79 641 s ≈ 22 h of beats).
        @test 40 < fr["mean_hr"](n) < 120
        @test 0 < fr["sdnn"](n) < 400
        @test 0 < fr["rmssd"](n) < 300
        @test fr["max_t"](n) > 60_000          # > 1000 min ⇒ genuinely long
        @test fr["duration"](n) > 0
    end
end
