module Visualization

using Statistics
using DataFrames
using DataFrames: DataFrame
import Random

# Plotting backends. `Plots` (with `StatsPlots` for `density!`) are hard `[deps]`
# of the package, so the offline plotting API works out of the box with no
# user-side `using Plots`. We `import` them here and call `Plots.plot` / etc.
# directly rather than looking functions up in `Main` at call time.
import Plots
import CSV
import StatsPlots
# Render the GR backend headless to PNG (no display needed).
function __init__()
    get!(ENV, "GKSwstype", "100")
    try
        Plots.gr()
    catch
        # GR backend selection can fail in unusual environments; the default
        # backend will still produce a `Plots.Plot` object for the tests.
    end
end

# ── Backend dispatch (Plots ↔ GLMakie) ───────────────────────────────────────
#
# The public `plot_*` functions are single generics that render with **Plots.jl
# by default** (works with no extra packages). When the user additionally runs
# `using GLMakie`, the `HeartRateLabVisualizationExt` extension loads and
# registers GLMakie implementations of the *same* public names; from then on the
# default backend flips to `:glmakie`, so `plot_ibi_series(x)` returns an
# interactive GLMakie `Figure` through the identical function name.
#
# Mechanism: each public function accepts a `backend` keyword whose default is
# `default_backend()` — `:glmakie` if the extension is loaded, else `:plots`.
# The GLMakie code lives in the extension as methods of the internal
# `_glmakie_*` generics defined (empty) here; the extension adds methods to them.
# This keeps both paths in one place behind one public name and never breaks the
# Plots default. Pass `backend=:plots` to force the static Plots figure even when
# GLMakie is loaded.
const _GLMAKIE_LOADED = Ref(false)

"""
    default_backend() -> Symbol

Return the active plotting backend: `:glmakie` when the GLMakie extension is
loaded (via `using GLMakie`), otherwise `:plots`. Used as the default for the
`backend` keyword of every public `plot_*` function.
"""
default_backend() = _GLMAKIE_LOADED[] ? :glmakie : :plots

# Internal GLMakie generics. The extension adds concrete methods. The catch-all
# fallbacks below raise an informative error when GLMakie is not loaded.
_glmakie_unavailable(name) =
    error("$name requires GLMakie. Please run: using GLMakie")

_glmakie_plot_ibi_series(args...; kwargs...)    = _glmakie_unavailable("plot_ibi_series(backend=:glmakie)")
_glmakie_plot_poincare(args...; kwargs...)      = _glmakie_unavailable("plot_poincare(backend=:glmakie)")
_glmakie_plot_spectrum(args...; kwargs...)      = _glmakie_unavailable("plot_spectrum(backend=:glmakie)")
_glmakie_plot_comparison(args...; kwargs...)    = _glmakie_unavailable("plot_comparison")
_glmakie_plot_model_heatmap(args...; kwargs...) = _glmakie_unavailable("plot_model_heatmap")
_glmakie_plot_lorenz_3d(args...; kwargs...)     = _glmakie_unavailable("plot_lorenz_3d(::Vector)")
_glmakie_plot_radar(args...; kwargs...)         = _glmakie_unavailable("plot_radar(backend=:glmakie)")
_glmakie_plot_correlations(args...; kwargs...)  = _glmakie_unavailable("plot_correlations(backend=:glmakie)")
_glmakie_plot_flagship(args...; kwargs...)      = _glmakie_unavailable("plot_flagship(backend=:glmakie)")
_glmakie_plot_feature_violins(args...; kwargs...) = _glmakie_unavailable("plot_feature_violins")

# Import Models module for accessing simulate_lorenz_trajectory and types
# This is safe because Models is included in the parent module before Visualization
import ..Models
using ..Models: ModelFitResult

# Import Features module for extract_feature_set and valid_features
import ..Features
using ..Features: extract_feature_set, valid_features, normative_prior, prior_registry

# Import Frequency for the headless (Plots.jl) power spectrum
import ..Frequency
using ..Frequency: lomb_scargle, welch, get_power

# DFA and EntropyHub for the fractal-scaling and complexity branch visualizations (d-07)
import DFA
import EntropyHub

# Distributions.jl — needed for quantile-based dispersion bands in normative plots
import Distributions

function getellipsepoints(cx, cy, rx, ry, θ; length=100)
	t = range(0, 2*pi, length=length)
	ellipse_x_r = @. rx * cos(t)
	ellipse_y_r = @. ry * sin(t)
	R = [cos(θ) sin(θ); -sin(θ) cos(θ)]
	r_ellipse = [ellipse_x_r ellipse_y_r] * R
	x = @. cx + r_ellipse[:,1]
	y = @. cy + r_ellipse[:,2]
	(x,y)
end

function default()
    include(joinpath(@__DIR__, "default.jl"))
end

# ── default_normative: live viz with personal-baseline percentile overlays ──
const _NORMATIVE_LOW  = Ref{Float64}(10.0)
const _NORMATIVE_HIGH = Ref{Float64}(90.0)
const _NORMATIVE_BASELINE_PATH =
    Ref{String}(joinpath(@__DIR__, "..", "..", "docs", "personal_baseline_w100.csv"))

"""
    default_normative(; low=10, high=90, baseline=<docs/personal_baseline_w100.csv>)

Live online HRV visualization — identical panels to [`default`](@ref) — with the
user's **personal-baseline** percentile bands overlaid on every panel: shaded
`low`–`high` band + median line on RR (window-mean)/SDNN/RMSSD, band edges on
ΔRR, a live-centred median + dashed `low`/`high` marginal SD1/SD2 envelope on the
Poincaré, and a full-height dashed line at the median LF/HF peak frequency on the
spectrum. Each panel title also shows the current value's **personal** percentile
and z-equivalent (spec §9.1). `low`/`high` are percentiles in 0–100; the baseline
artifact is built by `test/tools/generate_personal_baseline.jl`. Requires GLMakie
+ an LSL RR stream.
"""
function default_normative(; low = 10, high = 90, baseline = _NORMATIVE_BASELINE_PATH[])
    isfile(baseline) || error(
        "Personal-baseline artifact not found: $(baseline)\n" *
        "Generate it first:  julia --project=. test/tools/generate_personal_baseline.jl\n" *
        "(or call default() for the plain viz without normative overlays)")
    _NORMATIVE_LOW[]  = float(low)
    _NORMATIVE_HIGH[] = float(high)
    _NORMATIVE_BASELINE_PATH[] = String(baseline)
    # Evaluate the live script in `Main`, not this module: it does `using GLMakie`
    # / `using LSL`, which are *weakdeps* of HeartRateLab (a bare `using` from the
    # package module fails to resolve them). In `Main` the caller's
    # `using HeartRateLab, GLMakie, LSL` has already made them available, and the
    # script reaches back via `HeartRateLab.Visualization.…` for its overlay helpers.
    Base.include(Main, joinpath(@__DIR__, "default_normative.jl"))
end

function bpm()
    include(joinpath(@__DIR__, "heart_rate.jl"))
end

function bpm_tt()
    include(joinpath(@__DIR__, "heart_rate_tt.jl"))
end

function geometric()
    include(joinpath(@__DIR__, "geometric.jl"))
end

"""
    vdp_field()

Animated Van der Pol phase portrait + X(t) + Y(t) + IBI panels.
Peaks of Y(t) (local maxima) are marked with ✕; the interval between
consecutive peaks is displayed as an IBI in milliseconds.
"""
function vdp_field()
    include(joinpath(@__DIR__, "VDP_field.jl"))
end

"""
    plot_flagship(data::Vector, fit_result; backend=default_backend(), title="Flagship Visualization")

Create a comprehensive visualization of HRV analysis results.

Renders with Plots.jl by default (no extra packages needed). With `using GLMakie`
loaded the same call returns an interactive GLMakie figure (`backend=:glmakie`);
pass `backend=:plots` to force the static figure.
"""
function plot_flagship(data::Vector, fit_result; backend=default_backend(),
                       title::String="Flagship Visualization")
    backend === :glmakie && return _glmakie_plot_flagship(data, fit_result; title=title)

    # Create 2x2 subplot layout
    fig = Plots.plot(layout=(2, 2), size=(1000, 800), plot_title=title)

    # Panel 1: IBI time series
    Plots.plot!(fig[1], data, label="IBI", xlabel="Beat", ylabel="Interval (ms)", title="Inter-Beat Intervals")

    # Panel 2: IBI histogram
    Plots.histogram!(fig[2], data, label="IBI Distribution", xlabel="Interval (ms)", ylabel="Count", title="Distribution")

    # Panel 3: Poincaré plot
    if length(data) > 1
        Plots.scatter!(fig[3], data[1:end-1], data[2:end], label="Poincaré", xlabel="IBIₙ (ms)", ylabel="IBIₙ₊₁ (ms)", title="Poincaré Plot", markersize=3, alpha=0.6)
    end

    # Panel 4: Cumulative time
    Plots.plot!(fig[4], cumsum(data), label="Cumulative Time", xlabel="Beat", ylabel="Cumulative Time (ms)", title="Cumulative Duration")

    return fig
end

"""
    plot_ibi_series(data::Vector{Float64}; title="IBI Time Series", show_grid=true) → Figure

Create a simple line plot of inter-beat-interval values over beat index.

# Arguments
- `data::Vector{Float64}` — IBI series in milliseconds
- `title::String` — plot title
- `show_grid::Bool` — whether to show grid lines

# Returns
- Figure with X-axis=beat index, Y-axis=IBI (ms)
- Physiological bounds marked as horizontal lines (300-2000 ms typical range)

# Backend
Renders with Plots.jl by default; with `using GLMakie` loaded the same call
returns an interactive GLMakie figure (`backend=:glmakie`). Pass `backend=:plots`
to force the static figure.
"""
function plot_ibi_series(data::Vector{Float64}; backend=default_backend(),
                         title="IBI Time Series", show_grid=true)
    backend === :glmakie && return _glmakie_plot_ibi_series(data; title=title)

    # Create the plot
    fig = Plots.plot(data,
               label="IBI",
               xlabel="Beat Index",
               ylabel="IBI (ms)",
               title=title,
               legend=:topright,
               size=(900, 500))

    # Add physiological bounds as horizontal lines
    Plots.hline!(fig, [300], label="Min bound (300 ms)", line=:dash, color=:red, alpha=0.5)
    Plots.hline!(fig, [2000], label="Max bound (2000 ms)", line=:dash, color=:red, alpha=0.5)

    # Control grid visibility
    if show_grid
        Plots.plot!(grid=true)
    end

    return fig
end

"""
    plot_poincare(data::Vector; title="Poincaré Plot") → Figure

Create a Poincaré plot of inter-beat-interval variability with SD1/SD2 ellipse overlay.

# Arguments
- `data::Vector` — IBI series in milliseconds (numeric vector)
- `title::String` — plot title

# Returns
- Figure showing:
  - Scatter plot of consecutive IBI pairs (RR[n-1], RR[n]) in purple
  - SD1/SD2 ellipse overlay in limegreen
  - Diagonal reference line
  - SD1, SD2 values in legend

# Details
The Poincaré plot visualizes HRV by plotting each IBI against the next IBI.
SD1 measures short-term variability, SD2 measures long-term variability.

# Backend
Renders with Plots.jl by default; with `using GLMakie` loaded the same call
returns an interactive GLMakie figure (`backend=:glmakie`). Pass `backend=:plots`
to force the static figure.
"""
function plot_poincare(data::Vector; backend=default_backend(), title="Poincaré Plot")
    backend === :glmakie && return _glmakie_plot_poincare(Float64.(data); title=title)

    # Handle edge case: need at least 2 data points
    if length(data) < 2
        println("Poincaré plot requires at least 2 IBI values")
        return nothing
    end

    # Calculate consecutive RR pairs
    pp_x = data[1:end-1]
    pp_y = data[2:end]

    # Calculate SD1 and SD2
    # SD1 = sqrt(var((pp_x - pp_y) / sqrt(2)))
    # SD2 = sqrt(var((pp_x + pp_y) / sqrt(2)))
    sd1 = sqrt(var((pp_x .- pp_y) ./ sqrt(2)))
    sd2 = sqrt(var((pp_x .+ pp_y) ./ sqrt(2)))

    # Calculate ellipse center
    cx = mean(pp_x)
    cy = mean(pp_y)

    # Calculate ellipse points
    ex, ey = getellipsepoints(cx, cy, sd2, sd1, π/4)

    # Create the plot
    fig = Plots.plot(legend=:topleft, size=(700, 600), title=title)

    # Add scatter plot of Poincaré points in purple
    Plots.scatter!(fig, pp_x, pp_y,
             color=:purple,
             markersize=4,
             alpha=0.6,
             label="IBI Pairs")

    # Add SD1/SD2 ellipse in limegreen
    Plots.plot!(fig, ex, ey,
          color=:limegreen,
          linewidth=2,
          label="SD1/SD2 Ellipse")

    # Add diagonal reference line (y = x)
    min_val = min(minimum(pp_x), minimum(pp_y))
    max_val = max(maximum(pp_x), maximum(pp_y))
    Plots.plot!(fig, [min_val, max_val], [min_val, max_val],
          color=:gray,
          linestyle=:dash,
          alpha=0.5,
          label="")

    # Add axis labels and SD values to legend label
    Plots.plot!(fig,
          xlabel="RR[n-1] (ms)",
          ylabel="RR[n] (ms)",
          grid=true,
          aspect_ratio=:equal)

    # Add text annotation for SD values
    mid_x = cx + (max_val - min_val) * 0.05
    mid_y = cy + (max_val - min_val) * 0.05

    return fig
end


"""
    plot_spectrum(ibis::Vector{Float64}; method=:lomb, title="HRV Power Spectrum") -> Figure

Power spectrum of an IBI series with the HRV frequency bands shaded by colour
(ULF gray, VLF blueviolet, LF teal, HF coral) and the spectral peak marked.

`method` selects the estimator: `:lomb` (Lomb-Scargle, default; handles the uneven IBI
sampling) or `:welch`. Renders headless via Plots.jl by default; with `using GLMakie`
loaded the same call returns an interactive GLMakie figure (`backend=:glmakie`).
"""
function plot_spectrum(ibis::Vector{Float64}; backend=default_backend(),
                       method=:lomb, title="HRV Power Spectrum")
    backend === :glmakie && return _glmakie_plot_spectrum(ibis; method=method, title=title)

    pgram = method === :welch ? welch(ibis) : lomb_scargle(ibis)
    freq = collect(pgram.freq)
    power = collect(pgram.power)

    fig = Plots.plot(; size=(800, 500), title=title, xlabel="Frequency (Hz)",
               ylabel="Power (ms²/Hz)", legend=:topright, xlims=(0.0, 0.4))

    # HRV frequency bands as colour-shaded regions (drawn first, behind the spectrum).
    Plots.vspan!(fig, [0.0, 0.0033];   color=:gray,       alpha=0.15, label="ULF")
    Plots.vspan!(fig, [0.0033, 0.04];  color=:blueviolet, alpha=0.16, label="VLF")
    Plots.vspan!(fig, [0.04, 0.15];    color=:teal,       alpha=0.18, label="LF")
    Plots.vspan!(fig, [0.15, 0.4];     color=:coral,      alpha=0.20, label="HF")

    Plots.plot!(fig, freq, power; color=:black, linewidth=1.5, label="Spectrum")

    # Mark the spectral peak.
    if !isempty(power)
        pk = argmax(power)
        Plots.scatter!(fig, [freq[pk]], [power[pk]]; marker=:x, markersize=7,
                 color=:red, label="Peak")
    end
    return fig
end

"""
    plot_lif(model::LIF; n_beats=6, dt=0.5, title="LIF Membrane Dynamics") -> Figure

Visualise the Leaky Integrate-and-Fire membrane trajectory V(t): the characteristic
charge-up / threshold-crossing / reset sawtooth, with the resting and threshold
potentials marked. Integrates the LIF ODE `τ dV/dt = -(V - V_rest) + R·I` (Euler, step
`dt` ms) for `n_beats` spike cycles. Renders headless via Plots.jl.
"""
function plot_lif(model::Models.LIF; n_beats::Int=6, dt::Float64=0.5,
                  title="LIF Membrane Dynamics")
    τ, Vr, Vreset, Vth, R, I = model.τ, model.V_rest, model.V_reset,
                               model.V_threshold, model.R, model.I
    ts = Float64[]; Vs = Float64[]
    V = Vr; t = 0.0; spikes = 0
    # cap steps so a non-spiking (sub-threshold) parameterisation still terminates
    maxsteps = round(Int, n_beats * 50 * τ / dt) + 100_000
    step = 0
    while spikes < n_beats && step < maxsteps
        push!(ts, t); push!(Vs, V)
        V += dt * (-(V - Vr) + R * I) / τ
        t += dt
        step += 1
        if V >= Vth
            push!(ts, t); push!(Vs, Vth)        # draw the spike to threshold
            push!(ts, t); push!(Vs, Vreset)     # …then the instantaneous reset
            V = Vreset
            spikes += 1
        end
    end

    fig = Plots.plot(ts, Vs; color=:teal, linewidth=1.6, label="V(t)", size=(800, 450),
               title=title, xlabel="Time (ms)", ylabel="Membrane potential (mV)",
               legend=:bottomright)
    Plots.hline!(fig, [Vth]; color=:red, linestyle=:dash, label="V_threshold")
    Plots.hline!(fig, [Vr]; color=:gray, linestyle=:dot, label="V_rest")
    return fig
end

"""
    plot_dmd(dmd_result::ModelFitResult; title="DMD Modes & Reconstruction") -> Figure

Two-panel DMD visualisation: (top) the mode spectrum — each dynamic mode's amplitude
|b| against its oscillation frequency (from the eigenvalue phase), with marker size
scaled by amplitude; (bottom) the original IBI series overlaid with the DMD
reconstruction. Renders headless via Plots.jl.
"""
function plot_dmd(dmd_result::ModelFitResult; title="DMD Modes & Reconstruction")
    dmd = dmd_result.model
    data = dmd_result.data
    evals = dmd.evals
    b = dmd.b

    # Mode frequency (cycles per beat) from the eigenvalue phase; amplitude = |b|.
    freqs = abs.(angle.(evals)) ./ (2π)
    amps = abs.(b)
    ampsz = isempty(amps) ? Float64[] : 4 .+ 16 .* (amps ./ maximum(amps))

    p1 = Plots.scatter(freqs, amps; markersize=ampsz, color=:purple, alpha=0.7,
                      legend=false, xlabel="Mode frequency (cycles/beat)",
                      ylabel="Amplitude |b|", title="Mode spectrum")

    recon = try
        Models.simulate(dmd, nothing, length(data))
    catch
        Float64[]
    end
    p2 = Plots.plot(1:length(data), data; color=:black, linewidth=1.2, label="Original",
              xlabel="Beat", ylabel="IBI (ms)", title="Reconstruction")
    if !isempty(recon)
        m = min(length(recon), length(data))
        Plots.plot!(p2, 1:m, recon[1:m]; color=:coral, linewidth=1.4, linestyle=:dash,
              label="DMD reconstruction")
    end

    return Plots.plot(p1, p2; layout=(2, 1), size=(800, 700), plot_title=title)
end

"""
    plot_dfa(ibis::Vector{Float64}; title="Detrended Fluctuation Analysis") -> Figure

Canonical DFA log-log scaling plot: log₁₀ F(n) vs log₁₀ n (box size), with the two
scaling-exponent fits overlaid — α1 over the short-term window 4≤n≤16 and α2 over the
long-term window 16≤n≤64 (Peng/Francis convention; see Features `dfa`). The fitted
slopes (α1, α2) are shown in the legend. Renders headless via Plots.jl.
"""
function plot_dfa(ibis::Vector{Float64}; title="Detrended Fluctuation Analysis")
    scales, fluc = DFA.dfa(ibis; boxmax=64, boxmin=4, boxratio=2, overlap=0.0)
    ls = log10.(Float64.(scales)); lf = log10.(Float64.(fluc))
    m1 = scales .<= 16
    m2 = scales .>= 16
    b1, α1 = DFA.polyfit(ls[m1], lf[m1])
    b2, α2 = DFA.polyfit(ls[m2], lf[m2])

    fig = Plots.plot(; size=(750, 550), title=title, xlabel="log₁₀ n (box size, beats)",
               ylabel="log₁₀ F(n)", legend=:topleft)
    Plots.scatter!(fig, ls, lf; color=:black, markersize=5, label="F(n)")
    # α1 fit line over the short-term window
    x1 = ls[m1]
    Plots.plot!(fig, x1, b1 .+ α1 .* x1; color=:teal, linewidth=2,
          label="α1 = $(round(α1, digits=3)) (n 4–16)")
    # α2 fit line over the long-term window
    x2 = ls[m2]
    Plots.plot!(fig, x2, b2 .+ α2 .* x2; color=:coral, linewidth=2,
          label="α2 = $(round(α2, digits=3)) (n 16–64)")
    return fig
end

"""
    plot_complexity(ibis::Vector{Float64}; m=2, r=6, scales=10,
                    title="Multiscale Entropy") -> Figure

Multiscale-entropy complexity curve: sample entropy of the coarse-grained series at
each temporal scale (EntropyHub `MSEn` with a `SampEn` object). A flat/rising curve
indicates higher complexity; a decaying one indicates simpler dynamics. The complexity
index (area under the curve) is shown in the title. Renders headless via Plots.jl.
"""
function plot_complexity(ibis::Vector{Float64}; m::Int=2, r::Number=6, scales::Int=10,
                         title="Multiscale Entropy")
    Mobj = EntropyHub.MSobject(EntropyHub.SampEn; m=m, r=r)
    MSx, CI = EntropyHub.MSEn(ibis, Mobj; Scales=scales)
    sc = collect(1:length(MSx))

    fig = Plots.plot(sc, MSx; color=:purple, linewidth=2, marker=:circle, markersize=4,
               label="SampEn", size=(750, 500),
               title="$title (CI = $(round(CI, digits=2)))",
               xlabel="Scale factor τ", ylabel="Sample entropy", legend=:topright)
    return fig
end

"""
    plot_time_frequency_3d(ibis::Vector{Float64}; window_size=120, stride=30,
                           method=:lomb, title="Time–Frequency Spectrum") -> Figure

3D time–frequency waterfall: a sliding window is swept across the IBI series and a
power spectrum computed per window, then stacked into a surface (x = frequency,
y = window position in beats, z = power). Shows how the LF/HF content evolves over the
recording. Renders headless via Plots.jl (GR 3D).
"""
function plot_time_frequency_3d(ibis::Vector{Float64}; window_size::Int=120,
                                stride::Int=30, method=:lomb,
                                title="Time–Frequency Spectrum")
    n = length(ibis)
    n < window_size && (window_size = n)
    starts = collect(1:stride:max(1, n - window_size + 1))
    freqgrid = nothing
    rows = Vector{Vector{Float64}}()
    for s in starts
        w = ibis[s:min(s + window_size - 1, n)]
        length(w) < 8 && continue
        pg = method === :welch ? welch(w) : lomb_scargle(w)
        fg = collect(pg.freq); pw = collect(pg.power)
        if freqgrid === nothing
            freqgrid = fg
        elseif length(fg) != length(freqgrid)
            continue   # keep a rectangular grid (consistent window length → same freq grid)
        end
        push!(rows, pw)
    end
    Z = permutedims(reduce(hcat, rows))           # (num_windows × num_freq)
    ytimes = collect(1:length(rows)) .* stride    # window position (beats)
    return Plots.surface(freqgrid, ytimes, Z; size=(850, 600), title=title,
                        xlabel="Frequency (Hz)", ylabel="Beat", zlabel="Power",
                        colormap=:viridis, xlims=(0.0, 0.4))
end

"""
    plot_poincare_3d(ibis::Vector{Float64}; title="Time-Evolving Poincaré") -> Figure

3D Poincaré trajectory: the usual ΔRR scatter lifted by time on the z-axis
(x = RR[n-1], y = RR[n], z = beat index), so the recurrence cloud becomes a path. During
steady sinus rhythm it reads as an elliptical spiral (SD1/SD2 diameters) whose radius
changes with the HRV state. Coloured by time. Renders headless via Plots.jl (GR 3D).
"""
function plot_poincare_3d(ibis::Vector{Float64}; title="Time-Evolving Poincaré")
    length(ibis) < 3 && (println("plot_poincare_3d needs ≥ 3 IBIs"); return nothing)
    px = ibis[1:end-1]
    py = ibis[2:end]
    z = collect(1:length(px))
    fig = Plots.plot(px, py, z; line_z=z, color=:viridis, linewidth=2, label="trajectory",
               size=(820, 640), title=title, xlabel="RR[n-1] (ms)",
               ylabel="RR[n] (ms)", zlabel="Beat", legend=false, colorbar=true)
    Plots.scatter!(fig, px, py, z; marker_z=z, color=:viridis, markersize=2, label="")
    return fig
end

"""
    live(; source=:lsl, sample_size=100, frames=typemax(Int), title="Heart Rate") → Figure

Open a real-time heart-rate / RR-interval visualization (scrolling BPM tachogram).

`source` selects the data feed:
- `:lsl` — connect to a live Lab Streaming Layer RR/PP stream (requires `using LSL`),
  e.g. from [HRBand-LSL](https://github.com/abcsds/HRBand-LSL) or
  [RRStreamer](https://github.com/abcsds/RRStreamer). Selects the first stream whose
  name matches `^RR` or `^PP` (int32 milliseconds).
- `:simulate` — drive the display from a synthetic RR generator (no hardware/LSL;
  for demos and testing the render pipeline).
- a zero-argument `Function` returning the next RR interval in ms (`nothing` to stop).

Requires `using GLMakie` (and `using LSL` for `source=:lsl`). This is the launcher
behind `nix run .#viz`.
"""
function live(; kwargs...)
    ext = Base.get_extension(parentmodule(parentmodule(@__MODULE__)), :HeartRateLabVisualizationExt)
    ext === nothing && error("live() requires GLMakie. Please run: using GLMakie (and `using LSL` for source=:lsl)")
    return ext.live_impl(; kwargs...)
end

"""
    plot_comparison(real::Vector{Float64}, models::Dict{String, Vector{Float64}}; title="Time Series Comparison") → Figure

Overlay multiple model-generated IBI series against real data for visual inspection and comparison.

# Arguments
- `real::Vector{Float64}` — real IBI data (milliseconds)
- `models::Dict{String, Vector{Float64}}` — Dict mapping model names → synthetic IBI series
- `title::String` — overall plot title

# Returns
- Multi-panel figure with one panel per model, plus real data reference
- Each panel shows time series overlay:
  - Real data in blue
  - Model in red/orange/green (cycle through colors)
- Legend showing real vs model names
- X-axis: beat index, Y-axis: IBI (ms)
- Physiological bounds marked (300-2000 ms)

# Backend
Renders with Plots.jl by default. The GLMakie 2×2 comparison is reachable via the
`plot_comparison(real, synthetic)` (two-vector) method when `using GLMakie`.
"""
function plot_comparison(real::Vector{Float64}, models::Dict{String, Vector{Float64}}; title="Time Series Comparison")
    plot = Plots.plot
    plot! = Plots.plot!
    hline! = Plots.hline!

    # Handle empty models dict
    if isempty(models)
        # Return plot with real data only
        fig = plot(real,
                   label="Real Data",
                   xlabel="Beat Index",
                   ylabel="IBI (ms)",
                   title=title,
                   legend=:topright,
                   size=(900, 500))
        hline!(fig, [300, 2000], label="", line=:dash, color=:gray, alpha=0.5)
        return fig
    end

    # Prepare data
    n_models = length(models)
    model_names = collect(keys(models))
    colors = [:red, :orange, :green, :purple, :cyan]  # Cycle through colors

    # Create subplot layout
    # Total panels = n_models + 1 (for real data as reference in each panel)
    fig = plot(layout=(n_models + 1, 1), size=(900, 150 * (n_models + 1)), plot_title=title)

    # Panel 0: Real data only
    plot!(fig[1], real,
          label="Real Data",
          xlabel="Beat Index",
          ylabel="IBI (ms)",
          title="Real Data",
          legend=:topright,
          color=:blue,
          linewidth=2)
    hline!(fig[1], [300, 2000], label="", line=:dash, color=:gray, alpha=0.5)

    # For each model
    for (i, (name, synthetic)) in enumerate(models)
        # Ensure same length
        min_len = min(length(synthetic), length(real))
        synthetic_truncated = synthetic[1:min_len]
        real_truncated = real[1:min_len]

        # Create subplot
        beat_idx = 1:min_len
        color_idx = (i - 1) % length(colors) + 1
        model_color = colors[color_idx]

        plot!(fig[i + 1], beat_idx, real_truncated,
              label="Real",
              xlabel="Beat Index",
              ylabel="IBI (ms)",
              title=name,
              legend=:topright,
              color=:blue,
              linewidth=2)

        plot!(fig[i + 1], beat_idx, synthetic_truncated,
              label=name,
              color=model_color,
              linewidth=2)

        # Add physiological bounds
        hline!(fig[i + 1], [300, 2000], label="", line=:dash, color=:gray, alpha=0.5)
    end

    return fig
end

"""
    plot_comparison(real_ibis::Vector{Float64}, synthetic_ibis::Vector{Float64}; model_name="Model") -> Figure

Create a side-by-side 2×2 comparison (time series, Poincaré, histogram, Q-Q) of
real vs synthetic IBI data. This GLMakie figure is provided by the
`HeartRateLabVisualizationExt` extension; run `using GLMakie` to enable it.
"""
function plot_comparison(real_ibis::Vector{Float64}, synthetic_ibis::Vector{Float64}; model_name="Model")
    _glmakie_plot_comparison(real_ibis, synthetic_ibis; model_name=model_name)
end

"""
    plot_model_heatmap(results::DataFrame; title="Model × Feature Reproduction") → Figure

Create a matrix visualization showing which (model, feature) pairs reproduce well.

# Arguments
- `results::DataFrame` — evaluation results with columns:
  - `:model` (String) — model name (e.g., "VanDerPol", "Lorenz", "DMD")
  - `:feature` (String) — feature name (e.g., "SDNN", "RMSSD", "LF/HF")
  - `:score` (Float64) — 0-1 reproduction quality (0=fail, 1=perfect)
- `title::String` — plot title

# Returns
- Heatmap with:
  - Rows = models
  - Columns = features
  - Color = score (white=0/fail, red=1/perfect)
  - Values displayed in cells
  - Row/column labels visible

# Backend
Renders with Plots.jl by default. The GLMakie variant is reachable via the
`plot_model_heatmap(errors::Dict, features::Vector)` method when `using GLMakie`.
"""
function plot_model_heatmap(results::DataFrame; title="Model × Feature Reproduction")
    heatmap = Plots.heatmap

    # Extract unique models and features, preserving order
    models = unique(results.model)
    features = unique(results.feature)

    # Create matrix where rows=models, cols=features, values=scores
    Z = fill(NaN, length(models), length(features))

    for (i, model) in enumerate(models)
        for (j, feature) in enumerate(features)
            # Find matching row in results
            row_mask = (results.model .== model) .& (results.feature .== feature)
            row_idx = findfirst(row_mask)

            if row_idx !== nothing
                Z[i, j] = results.score[row_idx]
            end
        end
    end

    # Create heatmap with Plots.jl
    fig = heatmap(
        features,  # x-axis (columns)
        models,    # y-axis (rows)
        Z,
        color=:heat,
        xlabel="Features",
        ylabel="Models",
        title=title,
        clims=(0, 1),
        size=(600, 400),
        legend=:right,
        aspect_ratio=:auto
    )

    return fig
end

"""
    plot_model_heatmap(errors::Dict{String, Vector{Float64}}, features::Vector{String}) -> Figure

Create a GLMakie heatmap showing model reproduction quality across features.
Provided by the `HeartRateLabVisualizationExt` extension; run `using GLMakie`.
"""
function plot_model_heatmap(errors::Dict{String, Vector{Float64}}, features::Vector{String})
    _glmakie_plot_model_heatmap(errors, features)
end

"""
    plot_lorenz_3d(lorenz_result::ModelFitResult; title="Lorenz Phase Space") -> Figure

Create a 3D visualization of the Lorenz system phase space trajectory from fitted parameters.

# Arguments
- `lorenz_result::ModelFitResult`: Result from fit(Lorenz(), data) containing fitted parameters
- `title::String`: Plot title (default "Lorenz Phase Space")

# Returns
3D line plot showing:
- Teal trajectory line representing the system evolution
- Color gradient along the trajectory indicating time flow
- Green marker at trajectory start
- Red marker at trajectory end
- XYZ axes labeled

# Details
Solves the Lorenz ODE system using the fitted parameters (σ, ρ, β) and plots the full
(x, y, z) trajectory in 3D space. This shows the characteristic butterfly-shaped
strange attractor behavior of the Lorenz system.

# Backend
Renders with Plots.jl by default. The GLMakie 3D embedding is reachable via the
`plot_lorenz_3d(ibis::Vector)` method when `using GLMakie`.
Requires DifferentialEquations.jl (included in dependency chain).
"""
function plot_lorenz_3d(lorenz_result::ModelFitResult; title="Lorenz Phase Space")
    plot = Plots.plot
    scatter! = Plots.scatter!

    # Extract parameters from ModelFitResult
    params = lorenz_result.params

    # Solve ODE to get full trajectory using the helper function from Models
    sol = Models.simulate_lorenz_trajectory(params; duration=100.0)

    # Extract (x, y, z) points from solution
    x = [sol.u[i][1] for i in 1:length(sol.u)]
    y = [sol.u[i][2] for i in 1:length(sol.u)]
    z = [sol.u[i][3] for i in 1:length(sol.u)]

    # Create 3D plot with teal trajectory
    fig = plot(x, y, z,
               color=:teal,
               linewidth=2.5,
               label="Trajectory",
               xlabel="x",
               ylabel="y",
               zlabel="z",
               title=title,
               legend=:topright,
               size=(800, 700),
               aspectratio=:equal)

    # Mark start point in green
    scatter!(fig, [x[1]], [y[1]], [z[1]],
             color=:green,
             markersize=8,
             label="Start",
             markerstrokewidth=0)

    # Mark end point in red
    scatter!(fig, [x[end]], [y[end]], [z[end]],
             color=:red,
             markersize=8,
             label="End",
             markerstrokewidth=0)

    return fig
end

"""
    plot_lorenz_3d(ibis::Vector{Float64}; title="IBI 3D Phase Space") -> Figure

Create an interactive GLMakie 3D scatter plot showing IBI[n] vs IBI[n+1] vs IBI[n+2].
Provided by the `HeartRateLabVisualizationExt` extension; run `using GLMakie`.
"""
function plot_lorenz_3d(ibis::Vector{Float64}; title="IBI 3D Phase Space")
    _glmakie_plot_lorenz_3d(ibis; title=title)
end

"""
    plot_radar(datasets::Dict{String, Vector{Float64}}; features=nothing, title="Feature Comparison") → Figure

Create a spider/radar chart of normalized feature values for multi-dataset comparison.

# Arguments
- `datasets::Dict{String, Vector{Float64}}` — Dict mapping dataset names → IBI series
- `features::Union{Nothing, Vector{String}}` — which features to include
  - `nothing` (default): use valid_features() for all available features
- `title::String` — plot title

# Returns
- Radar/spider chart with:
  - One polygon per dataset (color-coded)
  - Each axis = one feature (z-scored across datasets)
  - Axes labeled with feature names
  - Values normalized (z-scored) across datasets
  - Legend showing dataset names

# Requirements
Requires Plots.jl to be loaded in the calling environment.
"""
function plot_radar(datasets::Dict{String, Vector{Float64}}; backend=default_backend(),
                    features=nothing, title="Feature Comparison")
    backend === :glmakie && return _glmakie_plot_radar(datasets; features=features, title=title)
    plot = Plots.plot
    plot! = Plots.plot!

    # Handle empty datasets
    if isempty(datasets)
        println("No datasets provided for radar plot")
        return nothing
    end

    # Determine features to plot
    if features === nothing
        # Use first dataset to determine available features
        first_data = first(values(datasets))
        valid_len = length(first_data)
        features = valid_features(valid_len)

        # Handle case where no features are valid for this length
        if isempty(features)
            println("No valid features available for dataset length $(valid_len)")
            return nothing
        end
    end

    # Extract feature values for each dataset
    feature_matrix = Dict()
    for (name, data) in datasets
        feature_row = extract_feature_set(data)
        # Convert DataFrame row to vector of values for requested features
        feature_vec = Float64[]
        for f in features
            if hasproperty(feature_row, Symbol(f))
                val = getproperty(feature_row, Symbol(f))[1]
                push!(feature_vec, val)
            else
                push!(feature_vec, 0.0)  # Default to 0 if feature not found
            end
        end
        feature_matrix[name] = feature_vec
    end

    # Normalize features (z-score across all datasets and features)
    all_values = vcat([feature_matrix[k] for k in keys(datasets)]...)
    μ = mean(all_values)
    σ = std(all_values)

    # Avoid division by zero
    σ = σ > 1e-10 ? σ : 1e-10

    # Normalize each dataset
    normalized = Dict()
    for (name, values) in feature_matrix
        normalized[name] = (values .- μ) ./ σ
    end

    # Create angles for each feature axis
    n_features = length(features)
    angles = range(0, 2π, length=n_features+1)[1:end-1]

    # Create radar plot with polar projection
    p = plot([], [], projection=:polar, title=title, legend=true, size=(800, 800))

    # Plot each dataset
    colors = [:blue, :red, :green, :purple, :orange, :brown, :pink, :gray]
    for (idx, (name, values)) in enumerate(normalized)
        # Close the polygon by repeating first point
        plot_angles = vcat(angles, angles[1])
        plot_values = vcat(values, values[1])

        # Cycle through colors
        color_idx = ((idx - 1) % length(colors)) + 1
        color = colors[color_idx]

        plot!(p, plot_angles, plot_values,
            label=name,
            color=color,
            linewidth=2,
            fillalpha=0.15)
    end

    # Set radial axis limits (based on z-scores, typically -3 to +3)
    plot!(p, ylims=(-3, 3))

    return p
end

"""
    plot_correlations(feature_sets::Dict{String, DataFrame}; features=nothing, title="Feature Correlations") → Figure

Create a pairwise scatter matrix showing feature correlations across datasets.

# Arguments
- `feature_sets::Dict{String, DataFrame}` — Dict mapping dataset names → DataFrame(rows=samples, cols=features)
- `features::Union{Nothing, Vector{String}}` — which features to plot (default: all available)
- `title::String` — plot title

# Returns
- N×N grid of subplots where N = number of features:
  - Diagonal cells: histograms of feature distributions
  - Lower triangle: scatter plots of feature pairs (one color per dataset)
  - Upper triangle: correlation coefficients (optional, can be empty)
  - Points colored by dataset origin

# Details
The correlation matrix visualization reveals feature covariance structure and dependencies
across multiple models or datasets. Points are colored differently for each dataset origin
to show how feature relationships vary across data sources.

# Requirements
Requires Plots.jl to be loaded in the calling environment.
"""
function plot_correlations(feature_sets::Dict{String, DataFrame}; backend=default_backend(),
                           features=nothing, title="Feature Correlations")
    backend === :glmakie && return _glmakie_plot_correlations(feature_sets; features=features, title=title)
    # Handle empty feature_sets
    if isempty(feature_sets)
        println("No feature sets provided for correlation plot")
        return nothing
    end

    # Determine features to plot
    if features === nothing
        features = names(first(values(feature_sets)))
    end

    # Handle empty features
    if isempty(features)
        println("No features available for correlation plot")
        return nothing
    end

    plot = Plots.plot
    scatter! = Plots.scatter!
    histogram! = Plots.histogram!
    plot! = Plots.plot!

    n_features = length(features)
    colors = [:blue, :red, :green, :purple, :orange, :brown, :pink, :cyan]

    # Create grid layout with dynamic size
    subplot_size = 100 * n_features
    fig = plot(layout=Plots.grid(n_features, n_features),
               size=(subplot_size, subplot_size),
               plot_title=title)

    # For each cell in the grid
    for i in 1:n_features
        for j in 1:n_features
            cell_idx = (i - 1) * n_features + j

            if i == j
                # Diagonal: histogram of feature i
                all_vals = Float64[]
                for (name, df) in feature_sets
                    col_data = df[!, Symbol(features[i])]
                    append!(all_vals, col_data)
                end

                histogram!(fig[cell_idx], all_vals,
                          label="",
                          title=features[i],
                          titlefontsize=10,
                          xlabel="",
                          ylabel="",
                          xtickfontsize=7,
                          ytickfontsize=7,
                          legend=false)

            elseif i > j
                # Lower triangle: scatter plot of feature j vs i
                for (idx, (name, df)) in enumerate(feature_sets)
                    x_data = df[!, Symbol(features[j])]
                    y_data = df[!, Symbol(features[i])]

                    color_idx = ((idx - 1) % length(colors)) + 1
                    color = colors[color_idx]

                    scatter!(fig[cell_idx], x_data, y_data,
                            label=name,
                            color=color,
                            markersize=4,
                            alpha=0.6,
                            markerstrokewidth=0,
                            xtickfontsize=7,
                            ytickfontsize=7,
                            titlefontsize=10,
                            legend=(j == 1 && i == 2))  # Only legend on one cell
                end

                # Add axis labels
                plot!(fig[cell_idx],
                     xlabel=j == 1 ? features[j] : "",
                     ylabel=j == n_features - 1 ? features[i] : "",
                     xlabelfontsize=8,
                     ylabelfontsize=8)

            else
                # Upper triangle: empty or correlation text
                plot!(fig[cell_idx], [], [],
                     label="",
                     axis=false,
                     legend=false)
            end
        end
    end

    return fig
end

"""
    plot_feature_violins(real::DataFrame, ensembles::Dict{String, DataFrame}; features=nothing) -> Figure

Create GLMakie violin plots comparing real vs synthetic feature distributions.
Provided by the `HeartRateLabVisualizationExt` extension; run `using GLMakie`.
"""
function plot_feature_violins(real, ensembles; features=nothing)
    _glmakie_plot_feature_violins(real, ensembles; features=features)
end

# ── Normative distribution comparison ──────────────────────────────────────
include("normative.jl")
include("personal_baseline.jl")

end