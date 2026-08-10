#!/usr/bin/env julia
# =============================================================================
# generate_normative_report.jl
#
# Generates docs/normative_report.html — a tabbed HTML report comparing HRV
# feature distributions across all collected normative datasets.
#
# For each dataset the report includes:
#   • Feature KDE distributions overlaid against the combined-normal reference
#   • Z-score table (median of dataset windows vs combined-normal reference)
#   • Feature correlation matrix
#   • Feature pairplot (scatter matrix)
#
# A final "All Normal" tab pools all healthy-population datasets.
# The ANOVA section tests for significant between-dataset differences across
# the normative datasets (the ones we want to establish as reference).
#
# Usage (from project root):
#   julia --project=. test/tools/generate_normative_report.jl
#
# Options (env vars):
#   WINDOW_SIZE=360          Window size used when collecting features (default: 360)
#   STRIDE=120               Stride used when collecting features (default: 120)
#   OUTPUT_FILE=...          Output HTML path (default: docs/normative_report.html)
#   TESTDATA=test/testdata   Root of collected feature CSVs
#   AUTO_COLLECT=true        Attempt to collect missing 360-beat CSVs (default: false)
# =============================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

# ─── stdlib & common deps ─────────────────────────────────────────────────────
using Dates, Printf, Statistics, Base64

# ─── data deps ────────────────────────────────────────────────────────────────
using CSV, DataFrames

# ─── plotting (GR headless backend) ────────────────────────────────────────
using Plots, StatsPlots
gr()
default(; fmt=:png, dpi=120)

# ─── project ──────────────────────────────────────────────────────────────────
using HeartRateLab
using HeartRateLab: plot_normative_kde_comparison, plot_feature_correlogram, plot_normative_pairplot
using HeartRateLab: normative_prior, load_normative_priors!, prior_registry
using Distributions

# =============================================================================
#  Configuration
# =============================================================================

const WINDOW_SIZE   = parse(Int, get(ENV, "WINDOW_SIZE", "360"))
const STRIDE        = parse(Int, get(ENV, "STRIDE",      "120"))
const TESTDATA_ROOT = abspath(get(ENV, "TESTDATA", joinpath(@__DIR__, "..", "testdata")))
const OUTPUT_FILE   = abspath(get(ENV, "OUTPUT_FILE",
                          joinpath(@__DIR__, "..", "..", "docs", "normative_report.html")))
const AUTO_COLLECT  = get(ENV, "AUTO_COLLECT", "false") == "true"

# ── HRV features to include in the report ─────────────────────────────────────
const REPORT_FEATURES = ["rmssd", "mean", "sdnn", "lf", "hf", "sd1", "sd2",
                          "pnn50", "lf_hf_ratio"]

# Subset used in the pairplot (keep ≤ 6 for readability)
const PAIRPLOT_FEATURES = ["rmssd", "sdnn", "lf", "hf", "sd1", "sd2"]

const FEAT_LABELS = Dict(
    "rmssd"      => "RMSSD (ms)",
    "mean"       => "Mean IBI (ms)",
    "sdnn"       => "SDNN (ms)",
    "lf"         => "LF Power (ms²)",
    "hf"         => "HF Power (ms²)",
    "sd1"        => "SD1 (ms)",
    "sd2"        => "SD2 (ms)",
    "pnn50"      => "pNN50 (%)",
    "lf_hf_ratio"=> "LF/HF ratio",
    "cvsd"       => "CVSD",
)

# =============================================================================
#  Dataset registry — population metadata
#  (mirrors DATASET_REGISTRY in collect_normative_datasets.jl)
# =============================================================================

const DATASET_META = Dict(
    "nsrdb"       => (description = "Normal Sinus Rhythm Database",
                      population  = "healthy",
                      source      = "PhysioNet nsrdb 1.0.0"),
    "nsr2db"      => (description = "Normal Sinus Rhythm RR Interval Database",
                      population  = "healthy",
                      source      = "PhysioNet nsr2db 1.0.0"),
    "meditation"  => (description = "Heart Rate Oscillations during Meditation",
                      population  = "healthy",
                      source      = "PhysioNet meditation 1.0.0"),
    "mitbih"      => (description = "MIT-BIH Arrhythmia Database",
                      population  = "mixed",
                      source      = "PhysioNet mitdb 1.0.0"),
    "challenge2002" => (description = "PhysioNet Challenge 2002 RR Intervals",
                        population  = "mixed",
                        source      = "PhysioNet challenge-2002 1.0.0"),
    "chaos"       => (description = "Is the Normal Heart Rate Chaotic?",
                      population  = "mixed",
                      source      = "PhysioNet chaos-heart-rate 1.0.0"),
    "mvtdb"       => (description = "Ventricular Tachyarrhythmia Database",
                      population  = "arrhythmia",
                      source      = "PhysioNet mvtdb 1.0"),
)

const POPULATION_BADGE = Dict(
    "healthy"    => """<span class="badge bg-success">healthy</span>""",
    "mixed"      => """<span class="badge bg-warning text-dark">mixed</span>""",
    "arrhythmia" => """<span class="badge bg-danger">arrhythmia</span>""",
)

# =============================================================================
#  Data loading
# =============================================================================

"""
Load `windowed_w{W}_s{S}_features.csv` for `dataset`, returning `nothing`
if the file is absent and AUTO_COLLECT is false.
"""
function load_windowed(dataset::String)::Union{DataFrame, Nothing}
    fname = "windowed_w$(WINDOW_SIZE)_s$(STRIDE)_features.csv"
    path  = joinpath(TESTDATA_ROOT, dataset, fname)

    if !isfile(path)
        if AUTO_COLLECT
            @info "[$dataset] CSV not found — attempting to collect..."
            run_collector(dataset)
            isfile(path) || return nothing
        else
            @warn "[$dataset] Missing $fname — skipping (set AUTO_COLLECT=true to collect)"
            return nothing
        end
    end

    df = CSV.read(path, DataFrame; silencewarnings=true)
    # Normalise numeric Union{T,Missing} columns: convert Missing → NaN
    for col in names(df)
        T = nonmissingtype(eltype(df[!, col]))
        if eltype(df[!, col]) >: Missing && T <: Number
            df[!, col] = map(v -> ismissing(v) ? NaN : Float64(v), df[!, col])
        end
    end
    return df
end

function run_collector(dataset::String)
    script = joinpath(@__DIR__, "collect_normative_datasets.jl")
    env    = Dict("DATASETS"     => dataset,
                  "WINDOW_SIZE"  => string(WINDOW_SIZE),
                  "STRIDE"       => string(STRIDE))
    cmd    = `$(Base.julia_cmd()) --project=$(dirname(@__DIR__)) $script`
    run(addenv(cmd, env))
end

# ── Filter to only columns in REPORT_FEATURES that actually exist ─────────────
available_features(df::DataFrame) =
    intersect(REPORT_FEATURES, names(df))

available_pairplot(df::DataFrame) =
    intersect(PAIRPLOT_FEATURES, names(df))

# =============================================================================
#  Load all datasets
# =============================================================================

# ── Load fitted normative priors (distribution-aware dispersion bands) ────────
const PRIORS_CSV = abspath(get(ENV, "PRIORS_CSV",
    joinpath(@__DIR__, "..", "..", "docs", "normative_priors.csv")))

if isfile(PRIORS_CSV)
    n_priors = load_normative_priors!(PRIORS_CSV)
    @info "Loaded $n_priors normative prior distributions from $(PRIORS_CSV)"
else
    @warn "Normative priors CSV not found at $(PRIORS_CSV) — falling back to empirical Normal bands"
end

println("="^60)
println("  HeartRateLab — Normative Dataset Report")
println("  Window: $(WINDOW_SIZE) beats, stride: $(STRIDE) beats")
println("="^60)

datasets_raw = Dict{String, DataFrame}()
for name in sort(collect(keys(DATASET_META)))
    df = load_windowed(name)
    if df !== nothing
        datasets_raw[name] = df
        @info "[$name] loaded $(nrow(df)) windows"
    end
end

if isempty(datasets_raw)
    error("No datasets loaded.  Run collect_normative_datasets.jl first.")
end

# ── Normative reference datasets ──────────────────────────────────────────────
# Only datasets listed here are used to build the combined-normal reference for
# z-score computation and σ-band overlays.  Edit this list to add/remove datasets.
const NORMATIVE_DATASET_KEYS = ["nsrdb", "nsr2db"]

# Build combined "All Normal" dataset ─────────────────────────────────────────
# Filter to only those that were actually loaded
normal_keys = filter(k -> haskey(datasets_raw, k), NORMATIVE_DATASET_KEYS)
combined_normal_df = if isempty(normal_keys)
    nothing
else
    _cdf = vcat([datasets_raw[k] for k in normal_keys]...; cols=:union)
    # Normalise Union{T,Missing} columns after vcat
    for col in names(_cdf)
        T = nonmissingtype(eltype(_cdf[!, col]))
        if eltype(_cdf[!, col]) >: Missing && T <: Number
            _cdf[!, col] = map(v -> ismissing(v) ? NaN : Float64(v), _cdf[!, col])
        end
    end
    _cdf
end

if combined_normal_df !== nothing
    @info "[all_normal] combined $(nrow(combined_normal_df)) windows \
           from datasets: $(join(normal_keys, ", "))"
end

# The reference for Z-score computation throughout the report
REF_KEY     = "all_normal"
REF_LABEL   = "All Normal"
REF_DF      = combined_normal_df

# All datasets dict — include the combined group as a named entry for overlays
all_datasets = merge(datasets_raw,
                     combined_normal_df !== nothing ?
                         Dict(REF_KEY => combined_normal_df) : Dict())

# =============================================================================
#  Utility: plot → base64-encoded PNG
# =============================================================================

function fig_to_b64(p)::String
    buf = IOBuffer()
    show(buf, MIME("image/png"), p)
    return base64encode(take!(buf))
end

function img_tag(b64::String, alt::String="plot", width::String="100%")
    return """<img src="data:image/png;base64,$b64" alt="$alt" style="max-width:$width; height:auto;">"""
end

# =============================================================================
#  Per-dataset statistics
# =============================================================================

"""
Compute distributional deviation scores for `dataset_df` relative to the fitted
normative prior (from `prior_registry`).  Falls back to empirical z-scoring
when no prior is available.

For features with a fitted prior distribution `d`:
  - `percentile` = `cdf(d, median(dataset_values))`
  - `z_equiv`    = equivalent Normal quantile of that percentile
  - `location`   = distribution location (mean for Normal, mode or mean for others)
  - `dispersion` = distribution-appropriate spread (σ, or IQR for skewed families)

For features without a prior: classic z = (median - μ_empirical) / σ_empirical.

Returns a DataFrame with columns:
  feature, family, location, dispersion, ds_median, percentile, z_equiv, n_ds.
"""
function compute_zscores(dataset_df::DataFrame, ref_df::DataFrame)::DataFrame
    feats = available_features(dataset_df)
    rows  = map(feats) do feat
        ds_vals = nothing
        try
            ds_vals = filter(!isnan, dataset_df[!, feat])
        catch
            return (feature=feat, family="—", location=NaN, dispersion=NaN,
                    ds_median=NaN, percentile=NaN, z_equiv=NaN, n_ds=0)
        end
        md = median(ds_vals)
        n_ds = length(ds_vals)

        prior = normative_prior(feat)
        if prior !== nothing
            # Distribution-aware scoring
            fam = _family_name(prior)
            loc = _location(prior)
            disp = _dispersion(prior)
            pct  = Distributions.cdf(prior, md)
            # Clamp to avoid ±Inf from quantile(Normal(), 0 or 1)
            pct_clamped = clamp(pct, 1e-8, 1.0 - 1e-8)
            z_eq = Distributions.quantile(Distributions.Normal(), pct_clamped)
            return (feature   = feat,
                    family    = fam,
                    location  = round(loc;  digits=2),
                    dispersion= round(disp; digits=2),
                    ds_median = round(md; digits=2),
                    percentile= round(pct; digits=4),
                    z_equiv   = round(z_eq; digits=3),
                    n_ds      = n_ds)
        else
            # Fallback: empirical Normal z-score from reference data
            ref_vals = nothing
            try
                ref_vals = filter(!isnan, ref_df[!, feat])
            catch
                return (feature=feat, family="empirical", location=NaN, dispersion=NaN,
                        ds_median=round(md; digits=2), percentile=NaN, z_equiv=NaN, n_ds=n_ds)
            end
            μ  = mean(ref_vals)
            σ  = std(ref_vals)
            z  = σ > 1e-12 ? (md - μ) / σ : NaN
            pct = σ > 1e-12 ? Distributions.cdf(Distributions.Normal(μ, σ), md) : NaN
            return (feature   = feat,
                    family    = "Normal*",
                    location  = round(μ;  digits=2),
                    dispersion= round(σ;  digits=2),
                    ds_median = round(md; digits=2),
                    percentile= round(pct; digits=4),
                    z_equiv   = round(z;  digits=3),
                    n_ds      = n_ds)
        end
    end
    return DataFrame(rows)
end

# ── Helpers for distribution summary statistics ──────────────────────────────

"""Return a short human-readable name for a distribution instance."""
function _family_name(d)::String
    T = typeof(d)
    T <: Distributions.Normal    && return "Normal"
    T <: Distributions.Gamma     && return "Gamma"
    T <: Distributions.Beta      && return "Beta"
    T <: Distributions.LogNormal && return "LogNormal"
    return string(nameof(T))
end

"""Return the location measure appropriate for the distribution family."""
function _location(d)::Float64
    typeof(d) <: Distributions.Normal    && return Distributions.mean(d)
    typeof(d) <: Distributions.LogNormal && return Distributions.median(d)
    typeof(d) <: Distributions.Gamma     && return Distributions.mean(d)
    typeof(d) <: Distributions.Beta      && return Distributions.mean(d)
    return Distributions.mean(d)
end

"""
Return the dispersion measure appropriate for the distribution family:
  - Normal:    σ (standard deviation)
  - LogNormal: IQR (inter-quartile range) — asymmetric, σ misleads
  - Gamma:     IQR
  - Beta:      IQR
"""
function _dispersion(d)::Float64
    typeof(d) <: Distributions.Normal && return Distributions.std(d)
    # For skewed distributions, IQR is more informative
    q75 = Distributions.quantile(d, 0.75)
    q25 = Distributions.quantile(d, 0.25)
    return q75 - q25
end

"""Return a short label for the dispersion type used."""
function _dispersion_label(d)::String
    typeof(d) <: Distributions.Normal && return "σ"
    return "IQR"
end

function zscore_interpretation(z::Float64)::Tuple{String,String}
    isnan(z) && return ("N/A", "table-secondary")
    az = abs(z)
    az <= 1.0 && return ("Within central 68% — typical",              "table-success")
    az <= 2.0 && return ("Within central 95% — slightly atypical",    "table-warning")
    az <= 3.0 && return ("Within central 99.7% — notably atypical",   "table-danger")
    return ("Beyond 99.7% — rare", "table-danger fw-bold")
end

# =============================================================================
#  HTML helpers
# =============================================================================

zscore_table_html(zdf::DataFrame, ds_label::String) = """
<div class="table-responsive mt-3">
<table class="table table-sm table-bordered align-middle text-center caption-top">
  <caption>Distributional deviation — <em>$(ds_label)</em> median window vs fitted normative prior ($(WINDOW_SIZE)-beat windows)</caption>
  <thead class="table-light">
    <tr>
      <th>Feature</th>
      <th>Family</th>
      <th>Location</th>
      <th>Dispersion</th>
      <th>Dataset median</th>
      <th>Percentile</th>
      <th>Z-equiv</th>
      <th>N (windows)</th>
      <th>Interpretation</th>
    </tr>
  </thead>
  <tbody>
    $(join(map(eachrow(zdf)) do r
        interp, row_class = zscore_interpretation(r.z_equiv)
        feat_label = get(FEAT_LABELS, r.feature, r.feature)
        z_str = isnan(r.z_equiv) ? "—" : @sprintf("%+.3f", r.z_equiv)
        pct_str = isnan(r.percentile) ? "—" : @sprintf("%.1f%%", r.percentile * 100)
        badge_color = isnan(r.z_equiv) ? "bg-secondary" :
                      abs(r.z_equiv) <= 1.0 ? "bg-success" :
                      abs(r.z_equiv) <= 2.0 ? "bg-warning text-dark" : "bg-danger"
        prior = normative_prior(r.feature)
        disp_lbl = prior !== nothing ? _dispersion_label(prior) : "σ"
        "<tr class=\"" * row_class * "\">" *
        "  <td class=\"text-start fw-semibold\">" * feat_label * "</td>" *
        "  <td><span class=\"badge bg-info text-dark\">" * r.family * "</span></td>" *
        "  <td>" * string(r.location) * "</td>" *
        "  <td>" * string(r.dispersion) * " <small class=\"text-muted\">(" * disp_lbl * ")</small></td>" *
        "  <td>" * string(r.ds_median) * "</td>" *
        "  <td>" * pct_str * "</td>" *
        "  <td><span class=\"badge " * badge_color * "\">" * z_str * "</span></td>" *
        "  <td>" * string(r.n_ds) * "</td>" *
        "  <td class=\"text-start\">" * interp * "</td>" *
        "</tr>"
    end, "\n"))
  </tbody>
</table>
</div>
"""

# =============================================================================
#  Build per-dataset tab content
# =============================================================================

function build_dataset_section(name::String, df::DataFrame)::String
    meta        = get(DATASET_META, name,
                      (description="Unknown", population="unknown", source=""))
    pop_badge   = get(POPULATION_BADGE, meta.population,
                      """<span class="badge bg-secondary">$(meta.population)</span>""")
    n_windows   = nrow(df)
    n_subj      = length(unique(df[!, :participant_id]))
    feats       = available_features(df)
    pp_feats    = available_pairplot(df)

    # Build dataset dict for overlay plots (reference + this dataset)
    has_ref = REF_DF !== nothing
    overlay = has_ref ?
        Dict(REF_LABEL => REF_DF, meta.description => df) :
        Dict(meta.description => df)

    # ── KDE comparison ────────────────────────────────────────────────────────
    kde_b64 = ""
    if !isempty(feats)
        try
            p = plot_normative_kde_comparison(
                overlay, feats;
                reference_key = has_ref ? REF_LABEL : nothing,
                feat_labels   = Dict(k => get(FEAT_LABELS, k, k) for k in feats),
                ncols         = min(3, length(feats)),
                title         = "$(meta.description) (-·-)  vs  $(REF_LABEL) (—)",
            )
            kde_b64 = fig_to_b64(p)
        catch e
            @warn "KDE plot failed for $name" exception=e
        end
    end

    # ── Z-score table ─────────────────────────────────────────────────────────
    zscore_html = ""
    if has_ref
        try
            zdf = compute_zscores(df, REF_DF)
            zscore_html = zscore_table_html(zdf, meta.description)
        catch e
            @warn "Z-score computation failed for $name" exception=e
        end
    end

    # ── Correlation matrix ───────────────────────────────────────────────────
    corr_b64 = ""
    if length(feats) >= 3
        try
            p = plot_feature_correlogram(df, feats;
                    title="$(meta.description) — Feature Correlation Matrix")
            corr_b64 = fig_to_b64(p)
        catch e
            @warn "Correlogram failed for $name" exception=e
        end
    end

    # ── Pairplot ──────────────────────────────────────────────────────────────
    pair_b64 = ""
    if length(pp_feats) >= 2
        try
            pp_datasets = has_ref ?
                Dict(REF_LABEL => REF_DF, meta.description => df) :
                Dict(meta.description => df)
            p = plot_normative_pairplot(pp_datasets, pp_feats;
                    title="$(meta.description) — Pairplot vs $(REF_LABEL)")
            pair_b64 = fig_to_b64(p)
        catch e
            @warn "Pairplot failed for $name" exception=e
        end
    end

    # ── Pre-compute img tags (avoid semicolons inside string interpolation) ──
    kde_img   = isempty(kde_b64)  ? "" : img_tag(kde_b64, "KDE comparison")
    corr_img  = isempty(corr_b64) ? "" : img_tag(corr_b64, "Correlation matrix")
    pair_img  = isempty(pair_b64) ? "" : img_tag(pair_b64, "Pairplot")
    n_feats   = length(feats)
    norm_keys_joined = join(normal_keys, " + ")

    # ── Assemble HTML ─────────────────────────────────────────────────────────
    parts = String[]

    # Header card
    push!(parts, """
    <div class="row mb-4 g-3">
      <div class="col-12">
        <div class="card">
          <div class="card-header bg-dark text-white d-flex align-items-center gap-2">
            <strong>$(meta.description)</strong>
            $(pop_badge)
            <small class="ms-auto text-white-50">$(meta.source)</small>
          </div>
          <div class="card-body">
            <div class="row text-center mb-3">
              <div class="col"><span class="fs-4 fw-bold text-primary">$(n_windows)</span><br><small class="text-muted">360-beat windows</small></div>
              <div class="col"><span class="fs-4 fw-bold text-primary">$(n_subj)</span><br><small class="text-muted">participants</small></div>
              <div class="col"><span class="fs-4 fw-bold text-primary">$(n_feats)</span><br><small class="text-muted">features</small></div>
            </div>
          </div>
        </div>
      </div>
    </div>""")

    # KDE section
    if !isempty(kde_b64)
        push!(parts, """
    <div class="row mb-4">
      <div class="col-12">
        <h5 class="border-bottom pb-1">Feature Distributions vs Combined-Normal Reference</h5>
        <p class="text-muted small">KDE curves for each feature. Dispersion bands (central 68% blue, 95% gold, 99.7% coral) derived from the fitted normative prior distribution for each feature ($(norm_keys_joined)). The dashed grey curve is the fitted prior PDF. Band shapes reflect each feature's distribution family (Normal, Gamma, Beta, LogNormal).</p>
        $(kde_img)
      </div>
    </div>""")
    end

    # Z-score section
    if !isempty(zscore_html)
        push!(parts, """
    <div class="row mb-4">
      <div class="col-12">
        <h5 class="border-bottom pb-1">Distributional Deviation Analysis</h5>
        $(zscore_html)
      </div>
    </div>""")
    end

    # Correlation + Pairplot section
    if !isempty(corr_b64)
        pair_col = isempty(pair_b64) ? "<div class=\"col-lg-6\"></div>" : """
      <div class="col-lg-6">
        <h5 class="border-bottom pb-1">Feature Pairplot</h5>
        <p class="text-muted small">Scatter matrix of core features. $(REF_LABEL) reference is overlaid for context.</p>
        $(pair_img)
      </div>"""
        push!(parts, """
    <div class="row mb-4">
      <div class="col-lg-6">
        <h5 class="border-bottom pb-1">Feature Correlation Matrix</h5>
        <p class="text-muted small">Pearson correlations across all $(n_windows) windows. Red = positive, blue = negative.</p>
        $(corr_img)
      </div>
      $(pair_col)
    </div>""")
    end

    return join(parts, "\n")
end

# =============================================================================
#  "All Normal" combined tab
# =============================================================================

function build_all_normal_section()::String
    combined_normal_df === nothing && return """
    <div class="alert alert-warning">
      No normative datasets with $(WINDOW_SIZE)-beat windowed CSVs found.
      Run <code>collect_normative_datasets.jl</code> for: $(join(NORMATIVE_DATASET_KEYS, " / ")).
    </div>"""

    feats    = available_features(combined_normal_df)
    pp_feats = available_pairplot(combined_normal_df)

    # Overlay of individual normal datasets (no combined group — they ARE the reference)
    normal_datasets_overlay = Dict(k => datasets_raw[k] for k in normal_keys)

    # ── Between-normal KDE overlay ────────────────────────────────────────────
    between_b64 = ""
    if !isempty(feats) && length(normal_keys) > 0
        try
            p = plot_normative_kde_comparison(
                normal_datasets_overlay, feats;
                feat_labels = Dict(k => get(FEAT_LABELS, k, k) for k in feats),
                ncols       = min(3, length(feats)),
                title       = "Between-dataset comparison — all healthy populations",
            )
            between_b64 = fig_to_b64(p)
        catch e
            @warn "All-normal KDE failed" exception=e
        end
    end

    # ── Correlation matrix (combined) ─────────────────────────────────────────
    corr_b64 = ""
    if length(feats) >= 3
        try
            p = plot_feature_correlogram(combined_normal_df, feats;
                    title="Combined Normal — Feature Correlation Matrix")
            corr_b64 = fig_to_b64(p)
        catch e
            @warn "All-normal correlogram failed" exception=e
        end
    end

    # ── Pairplot (between normal datasets) ────────────────────────────────────
    pair_b64 = ""
    if length(pp_feats) >= 2 && length(normal_datasets_overlay) >= 1
        try
            p = plot_normative_pairplot(normal_datasets_overlay, pp_feats;
                    title="All Healthy Populations — Pairplot")
            pair_b64 = fig_to_b64(p)
        catch e
            @warn "All-normal pairplot failed" exception=e
        end
    end

    n_total  = nrow(combined_normal_df)
    n_subj   = "participant_id" in names(combined_normal_df) ?
                   string(length(unique(combined_normal_df[!, :participant_id]))) : "—"
    n_normal = length(normal_keys)
    nk_joined = join(normal_keys, " + ")

    # Pre-compute img tags
    between_img = isempty(between_b64) ? "" : img_tag(between_b64, "Between-normal KDE")
    corr_img    = isempty(corr_b64)    ? "" : img_tag(corr_b64, "Combined normal correlation matrix")
    pair_img    = isempty(pair_b64)    ? "" : img_tag(pair_b64, "All-normal pairplot")

    header_html = """
    <div class="row mb-4 g-3">
      <div class="col-12">
        <div class="card">
          <div class="card-header bg-success text-white">
            <strong>Combined Healthy-Population Reference</strong>
            <span class="badge bg-light text-success ms-2">$(nk_joined)</span>
          </div>
          <div class="card-body">
            <div class="row text-center mb-2">
              <div class="col"><span class="fs-4 fw-bold text-success">$(n_total)</span><br>
                <small class="text-muted">total $(WINDOW_SIZE)-beat windows</small></div>
              <div class="col"><span class="fs-4 fw-bold text-success">$(n_normal)</span><br>
                <small class="text-muted">datasets pooled</small></div>
            </div>
            <p class="text-muted small mb-0">This combined group is the normative reference used for distributional deviation scoring throughout the report.  Fitted prior distributions (from <code>normative_priors.csv</code>) define the quantile-based dispersion bands in every individual-dataset tab, respecting each feature's distribution family.</p>
          </div>
        </div>
      </div>
    </div>"""

    parts = String[header_html]

    if !isempty(between_b64)
        push!(parts, """
    <div class="row mb-4">
      <div class="col-12">
        <h5 class="border-bottom pb-1">Between-Dataset Distributions (healthy populations)</h5>
        <p class="text-muted small">Each coloured curve represents one healthy-population dataset.  Divergence between curves indicates dataset-specific distributional differences that will affect normative interpretations.</p>
        $(between_img)
      </div>
    </div>""")
    end

    if !isempty(corr_b64)
        pair_col = isempty(pair_b64) ? "<div class=\"col-lg-6\"></div>" : """
      <div class="col-lg-6">
        <h5 class="border-bottom pb-1">Healthy-Population Pairplot</h5>
        $(pair_img)
      </div>"""
        push!(parts, """
    <div class="row mb-4">
      <div class="col-lg-6">
        <h5 class="border-bottom pb-1">Combined-Normal Correlation Matrix</h5>
        $(corr_img)
      </div>
      $(pair_col)
    </div>""")
    end

    return join(parts, "\n")
end

# =============================================================================
#  ANOVA conclusion
# =============================================================================

"""Compute participant-level means for `feat` from a windowed DataFrame.
Groups by `participant_id`, takes the mean of non-NaN windows per participant,
and returns a Float64 vector (one value per participant)."""
function _participant_means(df::DataFrame, feat::String)::Vector{Float64}
    pid_col = "participant_id"
    pid_col in names(df) || error("DataFrame has no $pid_col column")
    result = Float64[]
    for gdf in groupby(df, pid_col)
        vals = filter(!isnan, gdf[!, feat])
        length(vals) >= 1 && push!(result, Statistics.mean(vals))
    end
    return result
end

function build_anova_section()::String
    avail_normal = [k for k in normal_keys if haskey(datasets_raw, k)]
    if length(avail_normal) < 2
        return """<div class="alert alert-warning">
            Fewer than 2 healthy-population datasets loaded — ANOVA requires ≥ 2 groups.
        </div>"""
    end

    feats = available_features(combined_normal_df)

    # Collect per-dataset participant counts for the description
    ds_n_participants = Dict{String,Int}()
    for dskey in avail_normal
        dsdf = datasets_raw[dskey]
        if "participant_id" in names(dsdf)
            ds_n_participants[dskey] = length(unique(dsdf[!, :participant_id]))
        end
    end
    total_participants = sum(values(ds_n_participants); init=0)

    results = map(feats) do feat
        # Aggregate to participant-level means: each participant contributes
        # one observation (their mean across windows).  This avoids inflating
        # N with correlated, overlapping windows.
        groups = Vector{Float64}[]
        n_participants_per_group = Int[]
        for dskey in avail_normal
            pmeans = _participant_means(datasets_raw[dskey], feat)
            if length(pmeans) >= 2
                push!(groups, pmeans)
                push!(n_participants_per_group, length(pmeans))
            end
        end
        if length(groups) < 2
            return (feature=feat, F=NaN, p_value=NaN,
                    n_groups=length(groups), n_total=0,
                    significant=false,
                    interpretation="Not enough data")
        end
        # One-way ANOVA on participant means
        n_g = length(groups)
        N   = sum(length.(groups))
        grand_mean = Statistics.mean(vcat(groups...))
        SS_between = sum(length(g) * (Statistics.mean(g) - grand_mean)^2 for g in groups)
        SS_within  = sum(sum((x - Statistics.mean(g))^2 for x in g) for g in groups)
        df_between = n_g - 1
        df_within  = N - n_g
        F = (SS_within > 0 && df_within > 0) ?
            (SS_between / df_between) / (SS_within / df_within) : NaN
        p = isnan(F) ? NaN : 1.0 - Distributions.cdf(Distributions.FDist(df_between, df_within), F)
        interp = if p < 0.001
            "Highly significant (p < 0.001) — participant means differ between datasets"
        elseif p < 0.05
            "Significant (p < 0.05) — moderate difference detected"
        elseif p < 0.10
            "Marginal (p < 0.10) — weak evidence of difference"
        else
            "Not significant — datasets appear consistent for this feature"
        end
        (feature        = feat,
         F              = round(F; digits=3),
         p_value        = p,
         n_groups       = length(groups),
         n_total        = N,
         significant    = p < 0.05,
         interpretation = interp)
    end

    rows_html = join(map(results) do r
        feat_label = get(FEAT_LABELS, r.feature, r.feature)
        f_str = isnan(r.F) ? "—" : string(r.F)
        p_str = if isnan(r.p_value)
            "—"
        elseif r.p_value < 1e-10
            @sprintf("%.2e", r.p_value)
        else
            @sprintf("%.5f", r.p_value)
        end
        badge = r.significant ? """<span class="badge bg-danger">significant</span>""" :
                                """<span class="badge bg-success">not significant</span>"""
        row_class = r.significant ? "table-warning" : ""
        """<tr class="$(row_class)">
             <td class="text-start fw-semibold">$(feat_label)</td>
             <td><code>$(f_str)</code></td>
             <td><code>$(p_str)</code></td>
             <td>$(r.n_total)</td>
             <td>$(badge)</td>
             <td class="text-start small">$(r.interpretation)</td>
           </tr>"""
    end, "\n")

    n_sig = count(r -> r.significant, results)
    n_feat = length(results)
    summary_color = n_sig == 0 ? "success" : n_sig <= 2 ? "warning" : "danger"
    summary_msg = if n_sig == 0
        "All features are <strong>statistically consistent</strong> across normative datasets.  These datasets form a reliable combined reference."
    elseif n_sig == n_feat
        "All features show <strong>significant between-dataset differences</strong>.  Consider stratified normative references per dataset."
    else
        "<strong>$(n_sig) / $(n_feat) features</strong> show significant differences.  Review highlighted features before pooling datasets into a single normative reference."
    end

    groups_list = join(["$(k) (n=$(get(ds_n_participants, k, "?")))"
                        for k in avail_normal], ", ")

    return """
    <div class="alert alert-secondary small mb-3">
      <strong>Participant-level one-way ANOVA.</strong>
      For each participant, the mean feature value across all their $(WINDOW_SIZE)-beat
      windows is computed.  The ANOVA then tests whether these <em>participant means</em>
      differ significantly across the
      <strong>$(length(avail_normal)) normative datasets</strong>
      ($(groups_list); <strong>$(total_participants) participants total</strong>).
      This avoids pseudoreplication from correlated, overlapping windows.  α = 0.05.
    </div>

    <div class="table-responsive">
    <table class="table table-sm table-bordered align-middle text-center">
      <thead class="table-dark">
        <tr>
          <th class="text-start">Feature</th>
          <th>F statistic</th>
          <th>p-value</th>
          <th>N (participants)</th>
          <th>Result</th>
          <th class="text-start">Interpretation</th>
        </tr>
      </thead>
      <tbody>
        $(rows_html)
      </tbody>
    </table>
    </div>

    <div class="alert alert-$(summary_color) mt-3">
      <strong>Summary:</strong> $(summary_msg)
    </div>
    """
end

# =============================================================================
#  Assemble full HTML
# =============================================================================

println("\nGenerating plots and building report...")

# ── Ordered dataset list ───────────────────────────────────────────────────────
ordered_datasets = sort(collect(keys(datasets_raw)))

# ── Build tab buttons and pane contents ────────────────────────────────────────
tab_buttons = String[]
tab_panes   = String[]

for (i, name) in enumerate(ordered_datasets)
    meta     = get(DATASET_META, name, (description=name, population="unknown", source=""))
    pop_badge = get(POPULATION_BADGE, meta.population,
                    """<span class="badge bg-secondary">$(meta.population)</span>""")
    tab_id   = "tab-$name"
    is_first = (i == 1)

    push!(tab_buttons, """
    <li class="nav-item" role="presentation">
      <button class="nav-link $(is_first ? "active" : "")"
              id="btn-$name" data-bs-toggle="tab"
              data-bs-target="#$tab_id" type="button" role="tab">
        $(name)&nbsp;$(pop_badge)
      </button>
    </li>""")

    @info "Building section for [$name]..."
    content = build_dataset_section(name, datasets_raw[name])

    push!(tab_panes, """
    <div class="tab-pane fade $(is_first ? "show active" : "")"
         id="$tab_id" role="tabpanel">
      <div class="pt-3">
        $(content)
      </div>
    </div>""")

    GC.gc()
end

# ── "All Normal" tab ──────────────────────────────────────────────────────────
if !isempty(normal_keys)
    push!(tab_buttons, """
    <li class="nav-item" role="presentation">
      <button class="nav-link"
              id="btn-all-normal" data-bs-toggle="tab"
              data-bs-target="#tab-all-normal" type="button" role="tab">
        All Normal&nbsp;<span class="badge bg-success">combined</span>
      </button>
    </li>""")

    @info "Building All Normal section..."
    push!(tab_panes, """
    <div class="tab-pane fade" id="tab-all-normal" role="tabpanel">
      <div class="pt-3">
        $(build_all_normal_section())
      </div>
    </div>""")
end

# ── ANOVA section ─────────────────────────────────────────────────────────────
@info "Computing ANOVA..."
anova_html = build_anova_section()

# ── Full page ─────────────────────────────────────────────────────────────────
gen_ts     = Dates.format(now(), "yyyy-mm-dd HH:MM:SS UTC")
ds_summary = join(["<li><strong>$k</strong> — $(get(DATASET_META, k, (description=k,)).description)</li>"
                   for k in ordered_datasets], "\n")

html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>HeartRateLab — Normative Dataset Comparison Report</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css"
        rel="stylesheet"
        integrity="sha384-T3c6CoIi6uLrA9TneNEoa7RxnatzjcDSCmG1MXxSR1GAsXEV/Dwwykc2MPK8M2HN"
        crossorigin="anonymous">
  <style>
    body { background: #f8f9fa; }
    .navbar-brand { font-weight: 700; letter-spacing: .04em; }
    .nav-tabs .nav-link { font-size: .875rem; }
    .tab-pane img { border-radius: .375rem; box-shadow: 0 2px 8px rgba(0,0,0,.12); }
    table caption { caption-side: top; font-size: .85rem; color: #6c757d; }
    code { background: #f0f0f0; padding: .1em .35em; border-radius:.25em; }
    .section-header { background: linear-gradient(90deg,#0d6efd22,transparent);
                      padding: .5rem 1rem; border-left: 4px solid #0d6efd;
                      border-radius: 0 .375rem .375rem 0; margin-bottom: 1.5rem; }
  </style>
</head>
<body>

<nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-0">
  <div class="container-xl">
    <span class="navbar-brand">HeartRateLab</span>
    <span class="text-white-50 small ms-3">Normative Dataset Comparison Report</span>
    <span class="text-white-50 small ms-auto">Generated: $(gen_ts)</span>
  </div>
</nav>

<div class="container-xl py-4">

  <!-- Report summary card -->
  <div class="row mb-4">
    <div class="col-12">
      <div class="card border-primary">
        <div class="card-body">
          <h4 class="card-title">Normative Dataset Comparison</h4>
          <p class="card-text text-muted">
            This report evaluates whether the collected PhysioNet datasets are suitable as
            HeartRateLab normative references.  All comparisons use
            <strong>$(WINDOW_SIZE)-beat windows / $(STRIDE)-beat stride</strong>
            — a session-length–independent unit.  The combined
            <em>$(REF_LABEL)</em> reference pools all healthy-population datasets
            (<strong>$(join(normal_keys, " + "))</strong>).
          </p>
          <details>
            <summary class="text-primary" style="cursor:pointer">Datasets included in this report</summary>
            <ul class="mt-2 mb-0 small">
              $(ds_summary)
            </ul>
          </details>
        </div>
      </div>
    </div>
  </div>

  <!-- Dataset tabs -->
  <ul class="nav nav-tabs" id="datasetTabs" role="tablist">
    $(join(tab_buttons, "\n"))
  </ul>
  <div class="tab-content border border-top-0 rounded-bottom bg-white p-3 mb-5"
       id="datasetTabContent">
    $(join(tab_panes, "\n"))
  </div>

  <!-- ANOVA conclusion -->
  <div class="card border-dark mb-5">
    <div class="card-header bg-dark text-white">
      <h5 class="mb-0">📊 Statistical Conclusion — One-way ANOVA across Normative Datasets</h5>
    </div>
    <div class="card-body">
      $(anova_html)
    </div>
  </div>

  <footer class="text-center text-muted small pb-4">
    Generated by HeartRateLab · $(gen_ts) ·
    Window: $(WINDOW_SIZE) beats, stride: $(STRIDE) beats
  </footer>

</div><!-- /container-xl -->

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"
        integrity="sha384-C6RzsynM9kWDrMNeT87bh95OGNyZPhcTNXj1NW7RuBCsyN/o0jlpcV8Qyq46cDfL"
        crossorigin="anonymous"></script>
</body>
</html>"""

# =============================================================================
#  Write output
# =============================================================================

mkpath(dirname(OUTPUT_FILE))
write(OUTPUT_FILE, html)

println()
println("="^60)
println("  Report written to:")
println("  $(OUTPUT_FILE)")
println("="^60)
println()
println("  Open with:")
println("  xdg-open \"$(OUTPUT_FILE)\"")
println()
