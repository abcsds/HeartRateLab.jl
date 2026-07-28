# =============================================================================
# personal_baseline.jl — personal-baseline percentile support for the live
# normative online visualization (`default_normative`).
#
# Pure, headless (no GLMakie / no LSL). Everything here is testable without a
# display or an RR stream. The canonical per-window statistics match
# src/Features.jl exactly, so baseline percentiles and the live values drawn by
# default_normative.jl measure the same quantity.
# =============================================================================

# Quantities tracked. `drr` is beat-level; the rest are per-window summaries
# (`meanrr` = per-window mean RR — see spec §9.2, why NOT pooled beat-level RR).
const BASELINE_QUANTITIES =
    ["meanrr", "drr", "sdnn", "rmssd", "sd1", "sd2", "lf_peak", "hf_peak"]

# ── Canonical per-window HRV statistics (see src/Features.jl) ─────────────────
_win_sdnn(w)  = Statistics.std(w)                                # Features.sdnn  (l.235)
_win_rmssd(w) = sqrt(sum(diff(w) .^ 2)) / sqrt(length(w) - 1)    # Features.rmssd (l.476)

function _win_sd1(w)                                             # Features.sd1   (l.891)
    x = @view w[1:end-1]
    y = @view w[2:end]
    return sqrt(Statistics.var((x .- y) ./ sqrt(2)))
end

function _win_sd2(w)                                             # Features.sd2   (l.909)
    x = @view w[1:end-1]
    y = @view w[2:end]
    return sqrt(Statistics.var((x .+ y) ./ sqrt(2)))
end

# NOTE (B1): `find_peak` is QUALIFIED `Frequency.find_peak` — it must NOT be
# `using`-imported (the scripts define a local `find_peak(pgram)`; see Step 1).
_win_lf_peak(w) = Frequency.find_peak(lomb_scargle(Float64.(w)), 0.04, 0.15)  # Features.lf_peak (l.739)
_win_hf_peak(w) = Frequency.find_peak(lomb_scargle(Float64.(w)), 0.15, 0.4)   # Features.hf_peak (l.755)

# ── Baseline container + queries ─────────────────────────────────────────────

"""
    PersonalBaseline

Holds per-quantity 101-point quantile grids (`grids[q][i+1]` = the value at the
i-th percentile, i = 0…100) plus optional metadata parsed from the artifact's
leading `# key=value …` comment.
"""
struct PersonalBaseline
    grids :: Dict{String, Vector{Float64}}
    meta  :: Dict{String, String}
end

"""
    baseline_quantile(bl, key, p) -> Float64

Value at percentile `p` (0–100) for quantity `key`, linearly interpolated
between the two nearest integer-percentile grid points. `NaN` if `key` is
absent.
"""
function baseline_quantile(bl::PersonalBaseline, key::AbstractString, p::Real)
    haskey(bl.grids, key) || return NaN
    g  = bl.grids[key]
    pc = clamp(float(p), 0.0, 100.0)
    lo = floor(Int, pc)
    hi = ceil(Int, pc)
    lo == hi && return g[lo + 1]
    frac = pc - lo
    return g[lo + 1] * (1 - frac) + g[hi + 1] * frac
end

"""
    baseline_band(bl, key; low=10, high=90) -> (lo, med, hi)

Convenience triple: the `low`, 50th, and `high` percentiles of `key`.
"""
function baseline_band(bl::PersonalBaseline, key::AbstractString; low = 10, high = 90)
    return (lo  = baseline_quantile(bl, key, low),
            med = baseline_quantile(bl, key, 50),
            hi  = baseline_quantile(bl, key, high))
end

"""
    baseline_ellipse(bl; p, cx=nothing, cy=nothing) -> (xs, ys)

Poincaré ellipse points at percentile `p` of `sd1`/`sd2`. When `cx`/`cy` are
given the ellipse is centred there (the live viz passes the CURRENT cloud centre
each frame so only shape/size is compared — spec §9.3); otherwise it falls back
to the baseline median `meanrr` on the identity line. `getellipsepoints(cx, cy,
rx=sd2, ry=sd1, θ=π/4)`. This is a **marginal** SD1/SD2 ellipse, not a joint
density contour.
"""
function baseline_ellipse(bl::PersonalBaseline; p, cx = nothing, cy = nothing)
    s1 = baseline_quantile(bl, "sd1", p)
    s2 = baseline_quantile(bl, "sd2", p)
    m  = baseline_quantile(bl, "meanrr", 50)
    ecx = cx === nothing ? m : cx
    ecy = cy === nothing ? m : cy
    return getellipsepoints(ecx, ecy, s2, s1, π / 4)
end

"""
    baseline_percentile_of(bl, key, value) -> Float64

Inverse of [`baseline_quantile`](@ref): the percentile (0–100) at which `value`
falls in quantity `key`'s grid, linearly interpolated. Clamped to [0,100]; `NaN`
if `key` absent or the grid is all-NaN.
"""
function baseline_percentile_of(bl::PersonalBaseline, key::AbstractString, value::Real)
    haskey(bl.grids, key) || return NaN
    g = bl.grids[key]
    any(isfinite, g) || return NaN
    value <= g[1]   && return 0.0
    value >= g[end] && return 100.0
    i = findlast(x -> x <= value, g)      # g is non-decreasing (a quantile grid)
    i === nothing && return 0.0
    i >= length(g) && return 100.0
    span = g[i + 1] - g[i]
    frac = span > 0 ? (value - g[i]) / span : 0.0
    return clamp((i - 1) + frac, 0.0, 100.0)   # grid index 1↔p0
end

"""
    baseline_z(bl, key, value) -> Float64

Personal z-equivalent (spec §9.1): Φ⁻¹ of the personal percentile of `value`.
This is z vs the USER'S OWN baseline, not the population — the honest live
counterpart of the report's population z-equivalent.
"""
function baseline_z(bl::PersonalBaseline, key::AbstractString, value::Real)
    p = baseline_percentile_of(bl, key, value)
    isnan(p) && return NaN
    return Distributions.quantile(Distributions.Normal(),
                                  clamp(p / 100, 1e-6, 1 - 1e-6))
end
