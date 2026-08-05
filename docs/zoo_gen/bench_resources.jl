#!/usr/bin/env julia
# ─────────────────────────────────────────────────────────────────────────────
# bench_resources.jl — measured resource-intensity benchmark for the HRV Pokédex
#
# Times every one of the 53 registered HRV features (Features.feature_registry,
# i.e. EXCLUDING the 11 representation primitives) over representative window
# sizes {60, 360, 1000 beats}, reporting COLD (fresh caches) vs WARM (shared
# representations already memoized) median wall-time + allocations.
#
# Headless & dependency-light: `using HeartRateLab` (GLMakie is a weakdep, so no
# GPU/display needed), synthetic realistic RR input. Run under the pkg project:
#
#     GKSwstype=100 julia --project=. docs/zoo_gen/bench_resources.jl
#
# Emits:
#   docs/zoo_gen/resource_bench.csv   — full grid (feature × window × mode)
#   docs/zoo_gen/resource_rank.jl     — feature → {tier, median_ms_360, allocs, note}
#                                        (consumed by make_entry.jl)
#
# Methodology:
#   * Timing = median of N `@elapsed` repeats (robust, JIT-warmed once). We use
#     the sanctioned @elapsed/@allocated fallback rather than BenchmarkTools to
#     stay inside the package env with no extra resolution.
#   * COLD: `Memoization.empty_all_caches!()` before every timed call — measures
#     end-to-end cost incl. building shared representations (diff, pgram, px/py,
#     histogram, dfa …).
#   * WARM: representations pre-populated once, then only the feature's OWN cache
#     is cleared (`empty_cache!`) before each timed call — measures the marginal
#     feature cost when the shared periodogram / Poincaré coords already exist.
#     For self-contained features (apen/sampen/fuzzyen/mse embed their own O(N²)
#     work, no memoized sub-call) warm ≈ cold by construction — that is the point.
# ─────────────────────────────────────────────────────────────────────────────

ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")

using HeartRateLab
using Random, Statistics, Printf
const F   = HeartRateLab.Features
const Mem = HeartRateLab.Features.Memoization

const HERE = @__DIR__
const WINDOWS = (60, 360, 1000)
const REPEATS = 25

# ── Synthetic realistic RR series (ms): AR(1) mean-reversion + respiratory RSA ──
# Reproducible; timing is insensitive to realism but a physiological series
# exercises the histogram/dfa/pgram branches the way real windows do.
function synth_rr(N; seed = 20260729)
    rng = MersenneTwister(seed)
    x = zeros(N)
    x[1] = 800.0
    φ, μ, σ = 0.75, 800.0, 25.0
    for i in 2:N
        x[i] = μ + φ * (x[i-1] - μ) + σ * randn(rng)
    end
    # respiratory sinus arrhythmia component (~0.25 Hz over the beat index)
    x .+= 35.0 .* sin.(2π .* (1:N) ./ 4.0)
    clamp.(x, 500.0, 1200.0)
end

const LONG = synth_rr(maximum(WINDOWS))
measurement(w) = F.HRMeasurement(LONG[1:w])

featfunc(name) = F.feature_registry[name].func

# ── Robust cold/warm timing of one feature at one window ─────────────────────
# Returns (median_ms, allocs_bytes, ok::Bool, note::String)
function bench_one(name, m; mode::Symbol)
    f = featfunc(name)
    # JIT + validity probe
    try
        Mem.empty_all_caches!()
        f(m)
    catch err
        return (NaN, 0, false, "errored: $(sprint(showerror, err) |> x->first(x, 80))")
    end
    setup! = if mode === :cold
        () -> Mem.empty_all_caches!()
    else
        # WARM: populate every cache once, then in-loop clear only this feature's.
        Mem.empty_all_caches!(); f(m)
        () -> Mem.empty_cache!(f)
    end
    # allocations on a single freshly-set-up call
    setup!()
    allocs = try
        @allocated f(m)
    catch
        0
    end
    times = Float64[]
    for _ in 1:REPEATS
        setup!()
        push!(times, @elapsed f(m))
    end
    return (median(times) * 1000, allocs, true, "")
end

# ── Run the full grid ────────────────────────────────────────────────────────
names = sort(collect(keys(F.feature_registry)))
domain_of(name) = F.feature_registry[name].domains
primary_domain(name) = (ds = domain_of(name); isempty(ds) ? "nonlinear" : ds[1])

rows = NamedTuple[]
result = Dict{String,Any}()  # name -> Dict(window => Dict(mode => (ms, allocs, ok, note)))
for name in names
    result[name] = Dict{Int,Any}()
    for w in WINDOWS
        m = measurement(w)
        cold = bench_one(name, m; mode = :cold)
        warm = bench_one(name, m; mode = :warm)
        result[name][w] = (cold = cold, warm = warm)
        push!(rows, (feature = name, primary_domain = primary_domain(name), window = w,
                     cold_ms = cold[1], cold_allocs = cold[2],
                     warm_ms = warm[1], warm_allocs = warm[2],
                     ok = cold[3], note = cold[4]))
        @printf("%-18s w=%-4d cold=%9.4f ms (%8d B)  warm=%9.4f ms  %s\n",
                name, w, cold[1], cold[2], warm[1], cold[3] ? "" : "[FAIL] " * cold[4])
    end
end

# ── Write full CSV ───────────────────────────────────────────────────────────
csvpath = joinpath(HERE, "resource_bench.csv")
open(csvpath, "w") do io
    println(io, "feature,primary_domain,window,cold_ms,cold_allocs,warm_ms,warm_allocs,ok,note")
    for r in rows
        @printf(io, "%s,%s,%d,%.6g,%d,%.6g,%d,%s,%s\n",
                r.feature, r.primary_domain, r.window, r.cold_ms, r.cold_allocs,
                r.warm_ms, r.warm_allocs, r.ok, replace(r.note, "," => ";"))
    end
end
println("\nwrote $csvpath")

# ── 5-tier ordinal rank ──────────────────────────────────────────────────────
# Primary signal: COLD median wall-time at the canonical 360-beat window (the
# window the normative tables use). Thresholds are fixed, log-spaced decade cuts
# — defensible and independent of the sample — and were sanity-checked against
# the computational-graph depth (docs/slides/computational-graph.mmd): Level-1
# base stats land "very low", periodogram-derived frequency features "moderate",
# and the O(N²) nonlinear entropies "high"/"very high".
const GLYPH = Dict(
    "very low"  => "◍◌◌◌◌  very low",
    "low"       => "◍◍◌◌◌  low",
    "moderate"  => "◍◍◍◌◌  moderate",
    "high"      => "◍◍◍◍◌  high",
    "very high" => "◍◍◍◍◍  very high",
)
# decade thresholds on cold ms @ 360 beats
function tier_of(ms)
    isnan(ms) && return "moderate"
    ms < 0.005 && return "very low"   #   < 5 µs
    ms < 0.05  && return "low"        #   5–50 µs
    ms < 0.5   && return "moderate"   #  50–500 µs
    ms < 5.0   && return "high"       # 0.5–5 ms
    return "very high"                #   ≥ 5 ms
end

graphlevel = Dict(
    "time" => "Level 1–2 (base statistics over successive differences)",
    "frequency" => "Frequency subgraph (requires a Welch/Lomb–Scargle periodogram first)",
    "geometric" => "Geometric subgraph (Poincaré coords / RR histogram + reductions)",
    "nonlinear" => "Nonlinear subgraph (template matching / embedding — O(N²) worst case)",
)

rankpath = joinpath(HERE, "resource_rank.jl")
open(rankpath, "w") do io
    println(io, "# AUTO-GENERATED by docs/zoo_gen/bench_resources.jl -- do not edit by hand.")
    println(io, "# Measured resource-intensity ranks for the 53 registered HRV features.")
    println(io, "# tier from COLD median wall-time @ 360-beat window; see resource_bench.csv")
    println(io, "# for the full {feature × window × cold/warm} grid.  (report §D7)")
    println(io, "const RESOURCE_RANK_BY_FEATURE = Dict{String,NamedTuple}(")
    for name in names
        r360 = result[name][360]
        cold_ms = r360.cold[1]
        warm_ms = r360.warm[1]
        allocs  = r360.cold[2]
        ok      = r360.cold[3]
        pd = primary_domain(name)
        tier = tier_of(cold_ms)
        speedup = (warm_ms > 0 && cold_ms > 0) ? cold_ms / max(warm_ms, eps()) : 1.0
        note = if !ok
            "benchmark failed at 360 beats: $(r360.cold[4])"
        else
            base = graphlevel[pd]
            warmnote = speedup > 3 ? @sprintf(" Warm (shared representation cached) is %.0f× cheaper.", speedup) : ""
            @sprintf("%s.%s", base, warmnote)
        end
        @printf(io, "    %-16s => (rank = %-24s tier = %-13s median_ms_360 = %.5g, allocs = %d, warm_ms_360 = %.5g, note = %s),\n",
                "\"$name\"", "\"$(GLYPH[tier])\",", "\"$tier\",", cold_ms, allocs, warm_ms,
                repr(note))
    end
    println(io, ")")
end
println("wrote $rankpath")

# ── Console summary: sorted table ────────────────────────────────────────────
println("\n── ranked by cold median ms @ 360 beats ──")
order = sort(names; by = n -> (isnan(result[n][360].cold[1]) ? Inf : result[n][360].cold[1]))
for name in order
    r = result[name][360]
    @printf("  %-18s %-11s cold=%9.4f ms  warm=%9.4f ms  allocs=%9d B\n",
            name, tier_of(r.cold[1]), r.cold[1], r.warm[1], r.cold[2])
end
