using HeartRateLab: HeartRateLab
using Test
using Random: MersenneTwister, randn

# Set working directory to test directory for relative paths.
# (The runner does this too, but keep the file self-contained.)
cd(@__DIR__)

const Freq = HeartRateLab.Frequency

# HRV band edges (Hz), per SPEC-FR. ULF and VLF lower edge of the Lomb-Scargle
# plan is 0.003 Hz, so ULF (0-0.003) is outside the computed periodogram range.
const ULF = (0.0, 0.003)
const VLF = (0.003, 0.04)
const LF = (0.04, 0.15)
const HF = (0.15, 0.4)

"""
    synthetic_ibis(f_hz; n=2000, base_ms=1000.0, amp_ms=80.0, seed=42)

Build an unevenly-sampled IBI series (milliseconds) whose values oscillate at a
known frequency `f_hz`, expressed in cycles per second of elapsed time. The IBI
values themselves form the signal that Lomb-Scargle analyses, sampled at the
irregular beat times. A small amount of seeded jitter keeps the sampling uneven.
"""
function synthetic_ibis(f_hz; n=2000, base_ms=1000.0, amp_ms=80.0, seed=42)
    rng = MersenneTwister(seed)
    ibis = Float64[]
    t_s = 0.0  # elapsed time in seconds
    for _ in 1:n
        # IBI as a function of current elapsed time: a sinusoid at f_hz.
        ibi = base_ms + amp_ms * sin(2pi * f_hz * t_s)
        # Add small jitter so the beat-to-beat sampling is genuinely uneven.
        ibi += 5.0 * randn(rng)
        push!(ibis, ibi)
        t_s += ibi / 1000.0
    end
    return ibis
end

@testset "Frequency" begin
    @testset "lomb_scargle on example data" begin
        n = HeartRateLab.read_txt("testdata/example.txt")
        pgram = Freq.lomb_scargle(n)
        @test !isempty(pgram.freq)
        @test !isempty(pgram.power)
        @test length(pgram.freq) == length(pgram.power)
        @test all(isfinite, pgram.freq)
        @test all(isfinite, pgram.power)
        @test all(p -> p >= 0, pgram.power)
        # Plan constrains frequencies to [0.003, 0.4] Hz.
        @test minimum(pgram.freq) >= 0.003 - 1e-9
        @test maximum(pgram.freq) <= 0.4 + 1e-9
    end

    @testset "find_peak correctness" begin
        # Known dominant oscillation at 0.1 Hz, which sits inside the LF band.
        f_known = 0.1
        ibis = synthetic_ibis(f_known)
        pgram = Freq.lomb_scargle(ibis)

        peak_lf = Freq.find_peak(pgram, LF...)
        @test isfinite(peak_lf)
        # Peak should land near the injected frequency.
        @test isapprox(peak_lf, f_known; atol=0.02)
        @test LF[1] <= peak_lf < LF[2]

        # The HF band carries no injected power, so its peak (if any) must not be
        # near 0.1 Hz and must stay strictly inside the HF band.
        peak_hf = Freq.find_peak(pgram, HF...)
        @test isnan(peak_hf) || (HF[1] <= peak_hf < HF[2])

        # Empty / out-of-range band must return NaN (documented empty result).
        # ULF (0-0.003) is below the periodogram's minimum frequency, so the
        # band index is empty.
        @test isnan(Freq.find_peak(pgram, ULF...))
        # A band entirely above the plan's maximum frequency is also empty.
        @test isnan(Freq.find_peak(pgram, 0.45, 0.5))

        # find_peak must return an element of pgram.freq for a populated band:
        # this guards against the historical "wrong index" bug.
        @test peak_lf in pgram.freq
        # Cross-check against a manual argmax over the band.
        idx = findall(x -> x >= LF[1] && x < LF[2], pgram.freq)
        manual_peak = pgram.freq[idx[argmax(pgram.power[idx])]]
        @test peak_lf == manual_peak
    end

    @testset "band integration powers" begin
        n = HeartRateLab.read_txt("testdata/example.txt")
        pgram = Freq.lomb_scargle(n)

        # ULF is below the computed frequency range -> empty band -> NaN.
        @test isnan(Freq.get_power(pgram, ULF...))

        vlf = Freq.get_power(pgram, VLF...)
        lf = Freq.get_power(pgram, LF...)
        hf = Freq.get_power(pgram, HF...)
        total = Freq.get_power(pgram, 0.003, 0.4)

        for p in (vlf, lf, hf, total)
            @test isfinite(p)
            @test p >= 0
        end

        # Total power over the full computed range should be at least the sum of
        # the disjoint sub-bands (trapezoidal integration over the union vs.
        # pieces; equal up to the boundary-segment contributions).
        @test total >= vlf + lf + hf - 1e-6
        # And it should not be wildly larger than the sum of the pieces; the only
        # extra contributions are the trapezoid segments bridging band edges.
        @test total <= (vlf + lf + hf) * 1.5 + 1e-6

        # LF/HF ratio, the canonical derived feature, is finite and positive.
        ratio = lf / hf
        @test isfinite(ratio)
        @test ratio > 0
    end
end
