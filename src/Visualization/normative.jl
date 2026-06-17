# =============================================================================
# normative.jl — Distribution comparison visualisations for normative analysis
#
# These functions compare windowed-feature distributions across datasets,
# supporting the normative reference framework.  Like the rest of
# Visualization.jl they render with Plots.jl (StatsPlots for `density!`), both
# hard `[deps]` of the package, called directly as `Plots.xxx`/`StatsPlots.xxx`
# — no user-side `using Plots` required.
#
# Public API:
#   plot_normative_kde_comparison  — KDE grid with optional σ-band overlay
#   plot_feature_correlogram       — Pearson correlation heatmap
#   plot_normative_pairplot        — Scatter matrix (pairplot)
# =============================================================================

import Random

# ─── Palette ─────────────────────────────────────────────────────────────────

const _PALETTE = [
    :navy, :crimson, :darkorange, :green4, :purple4,
    :teal, :brown4, :deeppink3, :royalblue, :goldenrod4
]

_pick_colour(i::Int) = _PALETTE[mod1(i, length(_PALETTE))]

# ─── Distribution support helpers ────────────────────────────────────────────
# These ensure quantile bands and x-axis ranges never extend beyond the
# natural support of the distribution (e.g. no negative values for Gamma).

"""Lower bound of the distribution's support."""
function _support_lower(d)::Float64
    T = typeof(d)
    (T <: Distributions.Gamma || T <: Distributions.LogNormal) && return 0.0
    T <: Distributions.Beta && return 0.0
    return -Inf
end

"""Upper bound of the distribution's support."""
function _support_upper(d)::Float64
    T = typeof(d)
    T <: Distributions.Beta && return 1.0
    return Inf
end

"""
Safe lower bound for PDF evaluation.  For distributions where the PDF diverges
at the support boundary (Gamma with α<1, Beta with α<1), step slightly inward
so the plotted curve stays finite and readable.
"""
function _pdf_safe_lower(d, q3_lo::Float64)::Float64
    T = typeof(d)
    if T <: Distributions.Gamma
        α = Distributions.shape(d)
        if α < 1.0
            # PDF → ∞ at 0; start at the 1st percentile or q3_lo, whichever is larger
            return max(Distributions.quantile(d, 0.01), q3_lo)
        end
    elseif T <: Distributions.Beta
        α = d.α
        if α < 1.0
            return max(Distributions.quantile(d, 0.01), q3_lo)
        end
    end
    return q3_lo
end

# =============================================================================
#  plot_normative_kde_comparison
# =============================================================================

"""
    plot_normative_kde_comparison(
        datasets   :: Dict{String, DataFrame},
        features   :: Vector{String};
        reference_key :: Union{Nothing, String} = nothing,
        feat_labels   :: Dict{String, String}   = Dict{String,String}(),
        ncols         :: Int                     = 3,
        title         :: String                  = "Feature KDE Comparison",
    ) -> Figure

Grid of KDE plots comparing a feature's distribution across multiple datasets.
Each subplot shows one HRV feature; every dataset gets its own coloured curve.

When a fitted normative prior exists in `prior_registry` for a feature, the
prior distribution's quantile intervals are used to draw colour-coded bands:
  - ±1σ-equivalent  (68.27% central interval) — blue
  - 1–2σ-equivalent (95.45% central interval) — gold
  - 2–3σ-equivalent (99.73% central interval) — coral

This correctly represents the dispersion for all distribution families
(Normal, Gamma, Beta, LogNormal) without assuming symmetry.

When no prior is available but `reference_key` is provided, the function falls
back to the empirical mean ± σ (Normal assumption) for backward compatibility.

The fitted prior PDF is overlaid as a thin grey dashed curve when available.

# Arguments
- `datasets`      — `Dict` mapping dataset name → `DataFrame` of windowed features
- `features`      — names of feature columns to visualise
- `reference_key` — optional key in `datasets` to use as normative reference;
                    if `nothing`, no dispersion bands are drawn
- `feat_labels`   — optional human-readable labels for feature names
- `ncols`         — number of columns in the subplot grid
- `title`         — overall figure title

# Requirements
Requires Plots.jl (with StatsPlots for `density`) to be loaded.
"""
function plot_normative_kde_comparison(
    datasets::Dict{String, DataFrame},
    features::Vector{String};
    reference_key::Union{Nothing, String} = nothing,
    feat_labels::Dict{String, String}   = Dict{String,String}(),
    ncols::Int = 3,
    title::String = "Feature KDE Comparison",
)
    plot     = Plots.plot
    plot!    = Plots.plot!
    density! = StatsPlots.density!
    vspan!   = Plots.vspan!
    xlims!   = Plots.xlims!
    plot_fn! = Plots.plot!   # for overlaying fitted PDF

    n     = length(features)
    ncols = max(1, min(ncols, n))
    nrows = cond_ceil = ceil(Int, n / ncols)

    subplots = map(enumerate(features)) do (fi_idx, feat)
        label = get(feat_labels, feat, feat)
        p = plot(; title="", xlabel=label, ylabel="Density",
                   legend=false, grid=true, framestyle=:box)

        # ── Dispersion bands from fitted prior distribution ────────────────
        # We prefer the fitted prior from prior_registry (distribution-aware
        # quantile intervals). Falls back to empirical Normal if unavailable.
        prior_dist = normative_prior(feat)
        x_lo = nothing   # will hold lower x-limit for axis range
        x_hi = nothing   # will hold upper x-limit for axis range

        if prior_dist !== nothing && reference_key !== nothing
            # Determine support bounds for this distribution family
            sup_lo = _support_lower(prior_dist)
            sup_hi = _support_upper(prior_dist)

            # Distribution-aware quantile bands
            # 68.27% central interval (±1σ-equivalent)
            q1_lo = max(sup_lo, Distributions.quantile(prior_dist, 0.1587))
            q1_hi = min(sup_hi, Distributions.quantile(prior_dist, 0.8413))
            # 95.45% central interval (±2σ-equivalent)
            q2_lo = max(sup_lo, Distributions.quantile(prior_dist, 0.02275))
            q2_hi = min(sup_hi, Distributions.quantile(prior_dist, 0.97725))
            # 99.73% central interval (±3σ-equivalent)
            q3_lo = max(sup_lo, Distributions.quantile(prior_dist, 0.00135))
            q3_hi = min(sup_hi, Distributions.quantile(prior_dist, 0.99865))

            # Draw σ-equivalent bands (all clamped to valid support)
            q2_lo > q3_lo && vspan!([q3_lo, q2_lo]; alpha=0.13, color=:coral,      label=">2σ")
            q3_hi > q2_hi && vspan!([q2_hi, q3_hi]; alpha=0.13, color=:coral,      label="")
            q1_lo > q2_lo && vspan!([q2_lo, q1_lo]; alpha=0.18, color=:gold,       label="1–2σ")
            q1_hi < q2_hi && vspan!([q1_hi, q2_hi]; alpha=0.18, color=:gold,       label="")
            q1_hi > q1_lo && vspan!([q1_lo, q1_hi]; alpha=0.20, color=:steelblue,  label="±1σ")

            # Overlay the fitted prior PDF as a thin grey dashed curve.
            # For Gamma/LogNormal with shape < 1 the PDF diverges near 0;
            # start the PDF curve slightly above 0 to avoid an ugly spike.
            try
                pdf_lo = _pdf_safe_lower(prior_dist, q3_lo)
                x_pdf  = range(pdf_lo, q3_hi; length=200)
                y_pdf  = [Distributions.pdf(prior_dist, xi) for xi in x_pdf]
                # Cap any divergent values so the curve stays readable
                y_cap  = min(maximum(y_pdf), 50 * Statistics.median(y_pdf))
                y_pdf  = min.(y_pdf, y_cap)
                plot_fn!(p, collect(x_pdf), y_pdf;
                         color=:grey40, lw=1.2, ls=:dash, alpha=0.7,
                         label="prior", fill=false)
            catch; end

            # X-axis range: respect support bounds
            x_lo = max(sup_lo, q3_lo - 0.10 * (q3_hi - q3_lo))
            x_hi = min(sup_hi, q3_hi + 0.15 * (q3_hi - q3_lo))
        elseif reference_key !== nothing && haskey(datasets, reference_key)
            # Fallback: empirical mean ± σ (backward compatibility for Normal-like)
            ref_vals = filter(!isnan, datasets[reference_key][!, feat])
            if length(ref_vals) > 2
                μ_ref = Statistics.mean(ref_vals)
                σ_ref = Statistics.std(ref_vals)
                vspan!([μ_ref - 3σ_ref, μ_ref - 2σ_ref]; alpha=0.13, color=:coral,     label=">2σ")
                vspan!([μ_ref + 2σ_ref, μ_ref + 3σ_ref]; alpha=0.13, color=:coral,     label="")
                vspan!([μ_ref - 2σ_ref, μ_ref -   σ_ref]; alpha=0.18, color=:gold,     label="1–2σ")
                vspan!([μ_ref +   σ_ref, μ_ref + 2σ_ref]; alpha=0.18, color=:gold,     label="")
                vspan!([μ_ref -   σ_ref, μ_ref +   σ_ref]; alpha=0.20, color=:steelblue, label="±1σ")
                x_lo = μ_ref - 5σ_ref
                x_hi = μ_ref + 5σ_ref
            end
        end

        # ── One KDE curve per dataset ──────────────────────────────────────
        for (i, (name, df)) in enumerate(datasets)
            vals = filter(!isnan, df[!, feat])
            length(vals) < 5 && continue
            c     = _pick_colour(i)
            is_ref = (reference_key !== nothing && name == reference_key)
            lw    = is_ref ? 3.0 : 1.8
            ls    = is_ref ? :solid : :dashdot
            density!(vals; color=c, lw=lw, linestyle=ls, label=name,
                     fill=false, trim=true)
        end

        # ── Fix x-range using prior quantiles or empirical bounds ──────────
        if x_lo !== nothing && x_hi !== nothing && x_hi > x_lo
            xlims!(p, x_lo, x_hi)
        else
            # Fallback: use the combined data range across all datasets
            all_vals = vcat([filter(!isnan, df[!, feat]) for df in values(datasets)]...)
            if !isempty(all_vals)
                μ_all = Statistics.mean(all_vals)
                σ_all = Statistics.std(all_vals)
                σ_all > 0 && xlims!(p, μ_all - 5σ_all, μ_all + 5σ_all)
            end
        end

        p
    end

    return plot(subplots...;
                layout=(nrows, ncols),
                size=(420 * ncols, 310 * nrows),
                plot_title=title)
end

# =============================================================================
#  plot_feature_correlogram
# =============================================================================

"""
    plot_feature_correlogram(
        df       :: DataFrame,
        features :: Vector{String};
        title    :: String = "Feature Correlation Matrix",
    ) -> Figure

Pairwise Pearson correlation heatmap of the given features computed from all
non-NaN rows in `df`.

Colours run from deep blue (r = –1) through white (0) to deep red (r = +1)
using the `:RdBu` palette (reversed so red = positive correlation).

# Arguments
- `df`       — DataFrame whose rows are observations (e.g. windowed HRV features)
- `features` — column names to include in the matrix
- `title`    — plot title

# Requirements
Requires Plots.jl to be loaded.
"""
function plot_feature_correlogram(
    df::DataFrame,
    features::Vector{String};
    title::String = "Feature Correlation Matrix",
)
    heatmap_fn = Plots.heatmap
    annotate!  = Plots.annotate!
    plot_fn    = Plots.plot!
    cgrad_fn   = Plots.cgrad

    n   = length(features)
    mat = fill(NaN, n, n)

    for (i, fi) in enumerate(features), (j, fj) in enumerate(features)
        if i == j
            mat[i, j] = 1.0
        else
            mask = .!isnan.(df[!, fi]) .& .!isnan.(df[!, fj])
            if sum(mask) >= 3
                mat[i, j] = Statistics.cor(Vector{Float64}(df[mask, fi]),
                                            Vector{Float64}(df[mask, fj]))
            end
        end
    end

    cell_px = max(70, 280 ÷ n)
    w = cell_px * n + 200
    h = cell_px * n + 120

    # Reverse rows so feature[1] appears at the top.
    # Use numeric 1:n axes with explicit tick labels — passing string labels directly
    # to heatmap shifts the GR coordinate origin and misaligns annotate! coordinates.
    rev_features = reverse(features)
    rev_mat      = mat[end:-1:1, :]

    # Reverse :RdBu so red = positive correlation, blue = negative.
    cmap = cgrad_fn(:RdBu, rev=true)

    fig = heatmap_fn(
        1:n, 1:n, rev_mat;
        color     = cmap,
        clims     = (-1.0, 1.0),
        title     = title,
        xticks    = (1:n, features),
        yticks    = (1:n, rev_features),
        xrotation = 45,
        size      = (w, h),
        legend    = :right,
    )

    # Annotate cells at exact integer cell centers.
    # mat[i,j] → stored in rev_mat row (n+1-i) → data-space y = (n+1-i), x = j.
    text_fn = Plots.text
    for i in 1:n, j in 1:n
        isnan(mat[i, j]) && continue
        txt = string(round(mat[i, j]; digits=2))
        col = abs(mat[i, j]) > 0.5 ? :white : :black
        annotate!(fig, j, n + 1 - i, text_fn(txt, 7, col, :hcenter, :vcenter))
    end

    return fig
end

# =============================================================================
#  plot_normative_pairplot
# =============================================================================

"""
    plot_normative_pairplot(
        datasets :: Dict{String, DataFrame},
        features :: Vector{String};
        title    :: String = "HRV Feature Pairplot",
        max_pts  :: Int    = 2_000,
    ) -> Figure

N × N scatter matrix (pairplot) of feature pairs, coloured by dataset origin.

- **Diagonal cells**: overlaid KDE curves, one per dataset, for that feature.
- **Off-diagonal cells**: scatter of feature pairs; each dataset is drawn in
  its own colour with small, semi-transparent markers.

Only up to `max_pts` points per dataset are plotted (random sub-sample) to
keep rendering fast.

# Arguments
- `datasets` — `Dict` mapping dataset name → `DataFrame` of windowed features
- `features` — feature column names (≤ 6 recommended for readability)
- `title`    — overall figure title
- `max_pts`  — maximum scatter points drawn per dataset per cell

# Requirements
Requires Plots.jl (with StatsPlots for `density`) to be loaded.
"""
function plot_normative_pairplot(
    datasets::Dict{String, DataFrame},
    features::Vector{String};
    title::String = "HRV Feature Pairplot",
    max_pts::Int  = 2_000,
)
    plot      = Plots.plot
    plot!     = Plots.plot!
    scatter!  = Plots.scatter!
    density!  = StatsPlots.density!

    n         = length(features)
    cell_px   = 130
    layout    = Plots.grid(n, n)
    fig       = plot(layout     = layout,
                     size       = (cell_px * n, cell_px * n),
                     plot_title = title)

    dataset_names = collect(keys(datasets))

    for i in 1:n, j in 1:n
        cell = (i - 1) * n + j
        fi   = features[i]
        fj   = features[j]

        if i == j
            # ── Diagonal: one KDE per dataset ────────────────────────────
            for (ki, name) in enumerate(dataset_names)
                df   = datasets[name]
                vals = filter(!isnan, df[!, fi])
                length(vals) < 5 && continue
                c    = _pick_colour(ki)
                density!(fig[cell], vals;
                         color=c, lw=1.5, label="",
                         trim=true, fill=false,
                         xtickfontsize=5, ytickfontsize=5)
            end
            # Set cell attributes once, after all curves
            plot!(fig[cell];
                  title=fi, titlefontsize=8,
                  xlabel=(i == n ? fj : ""), ylabel=(j == 1 ? fi : ""),
                  xlabelfontsize=7, ylabelfontsize=7)
        else
            # ── Off-diagonal: scatter ─────────────────────────────────────
            for (ki, name) in enumerate(dataset_names)
                df   = datasets[name]
                mask = .!isnan.(df[!, fi]) .& .!isnan.(df[!, fj])
                sum(mask) < 2 && continue
                x = Vector{Float64}(df[mask, fj])
                y = Vector{Float64}(df[mask, fi])
                # Sub-sample for performance
                if length(x) > max_pts
                    idx = sort(Random.randperm(length(x))[1:max_pts])
                    x, y = x[idx], y[idx]
                end
                c = _pick_colour(ki)
                scatter!(fig[cell], x, y;
                         color=c, markersize=2, alpha=0.35, label="",
                         markerstrokewidth=0, xtickfontsize=5, ytickfontsize=5)
            end
            # Set cell attributes once, after all points
            plot!(fig[cell];
                  xlabel=(i == n ? fj : ""), ylabel=(j == 1 ? fi : ""),
                  xlabelfontsize=7, ylabelfontsize=7)
        end
    end

    return fig
end
