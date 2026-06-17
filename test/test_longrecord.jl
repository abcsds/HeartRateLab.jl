using HeartRateLab: HeartRateLab
using Test
import Memoization

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
        # bounds, not point values. On 16265 (default Peng/Francis 4–16 / 16–64,
        # dense all-integer grid): α1 ≈ 1.24, α2 ≈ 0.99.
        @test 0.7 <= α1 <= 1.5
        @test 0.7 <= α2 <= 1.3

        # The meaningfulness contrast: α2 over the 16–64 beat scales is a real
        # long-term exponent on a 24 h record (≈ 1) but degenerate on the ~1 h
        # example.txt (≈ 0.37 on the dense grid). This is exactly why d-24 adds
        # the long record.
        short = HeartRateLab.Features.HRMeasurement(
            HeartRateLab.read_txt("testdata/example.txt")
        )
        α2_short = fr["dfa2"](short)
        @test α2_short < 0.7          # not meaningful on the short record
        @test α2 > α2_short + 0.2     # genuinely larger on the long record

        # NOTE: 16265 is already a single >24 h record (≈ 99 819 beats). A future
        # extension could use the nsr2db multi-day records (2–7 day Holter) to
        # probe ultra-low-frequency / very-long-scale DFA, but we do NOT add a
        # network fetch here — 16265 already exercises a physiologically
        # meaningful long horizon for α2.
    end

    @testset "DFA box grid + configurability (d-06)" begin
        cfg = HeartRateLab.Features.config
        # Production dfa() now uses the DEFAULT dense all-integer Francis/Kubios
        # grid (every integer n in each range), not the legacy 3-point geometric
        # grid. Confirm the configured defaults are the Peng/Francis ranges.
        @test cfg["dfa_grid"] == :integer
        @test cfg["dfa_alpha1_range"] == (4, 16)   # 13 box sizes
        @test cfg["dfa_alpha2_range"] == (16, 64)  # 49 box sizes

        # DFA.jl's single-box method (the engine the integer grid loops over)
        # returns a finite, positive fluctuation F(n) for representative box sizes.
        for k in (4, 16, 64)
            Fn = HeartRateLab.Features.DFA.dfa(n.data, k; order=1, overlap=0.0)
            @test isfinite(Fn) && Fn > 0
        end
        # The legacy geometric dispatcher still yields the Peng powers-of-two grid.
        s1, _ = HeartRateLab.Features.DFA.dfa(n.data, boxmax=16, boxmin=4, boxratio=2, overlap=0.0)
        s2, _ = HeartRateLab.Features.DFA.dfa(n.data, boxmax=64, boxmin=16, boxratio=2, overlap=0.0)
        @test s1 == [4, 8, 16]
        @test s2 == [16, 32, 64]

        # Configurability: switch to the neurokit2 / Iyengar ranges
        # (α1 4–11, α2 12–N/10) and assert finite, physiologically sane exponents
        # on the long record. Restore the defaults afterwards via try/finally so
        # this testset cannot leak config into the rest of the suite.
        N = length(n.data)
        a1_default = fr["dfa1"](n)
        a2_default = fr["dfa2"](n)
        try
            cfg["dfa_alpha1_range"] = (4, 11)
            cfg["dfa_alpha2_range"] = (12, N ÷ 10)
            Memoization.empty_all_caches!()
            a1_iy = fr["dfa1"](n)
            a2_iy = fr["dfa2"](n)
            @test isfinite(a1_iy) && isfinite(a2_iy)
            @test 0.7 <= a1_iy <= 1.6      # on 16265: α1 ≈ 1.31
            @test 0.7 <= a2_iy <= 1.3      # on 16265: α2 ≈ 1.00
        finally
            cfg["dfa_alpha1_range"] = (4, 16)
            cfg["dfa_alpha2_range"] = (16, 64)
            cfg["dfa_grid"] = :integer
            cfg["dfa_boxratio"] = 2
            Memoization.empty_all_caches!()
        end
        # Defaults restored: dfa1/dfa2 recover their Peng/Francis values.
        @test fr["dfa1"](n) ≈ a1_default
        @test fr["dfa2"](n) ≈ a2_default
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
