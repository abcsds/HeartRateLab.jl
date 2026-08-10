#!/usr/bin/env julia
# =============================================================================
# generate_participant_report.jl
#
# Generates docs/reports/{participant_id}_resonance_report.html — a
# personalised HRV training report for Resonant Frequency Breathing sessions.
#
# Loads all IBI .txt files from:
#   test/testdata/export/{PARTICIPANT_ID}/{timestamp}.txt
#
# Report structure (3 tabs):
#   1. All Normal  — nsrdb vs nsr2db reference comparison (with ANOVA)
#   2. Training HRV  — participant distributions vs normative reference
#   3. Timeline  — feature values across recording dates (interactive selector)
#      • 95% bootstrap CI shown for dates whose total windows ≥ MIN_WINDOWS_FOR_CI
#      • Normative reference bands overlaid on each feature chart
#
# Usage (from project root):
#   julia --project=. test/tools/generate_participant_report.jl
#
# Options (env vars):
#   PARTICIPANT=Alberto_Barradas   Participant folder name (default: first found)
#   EXPORT_DIR=test/testdata/export  Root for exported recording files
#   WINDOW_SIZE=60                   Beats per window (default: 60)
#   STRIDE=30                        Window stride in beats (default: 30)
#   MIN_WINDOWS_FOR_CI=20            Minimum windows per date for bootstrap CI
#   N_BOOTSTRAP=1000                 Bootstrap resamples (default: 1000)
#   TESTDATA=test/testdata           Root of normative windowed CSVs
#   PRIORS_CSV=docs/normative_priors.csv
#   OUTPUT_DIR=docs/reports          Output directory
# =============================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

# ─── stdlib & common deps ─────────────────────────────────────────────────────
using Dates, Printf, Statistics, Base64, Random

# ─── data deps ────────────────────────────────────────────────────────────────
using CSV, DataFrames

# ─── plotting (GR headless backend) ──────────────────────────────────────────
using Plots, StatsPlots
gr()
default(; fmt=:png, dpi=120)

# ─── project ──────────────────────────────────────────────────────────────────
using HeartRateLab
using HeartRateLab: plot_normative_kde_comparison, plot_feature_correlogram, plot_normative_pairplot
using HeartRateLab: normative_prior, load_normative_priors!, prior_registry
using HeartRateLab: windowed_feature_set, read_txt
using HeartRateLab: replace_zeros, replace_bio_outliers, interpolate_nans
using Distributions
using Memoization: empty_all_caches!

# =============================================================================
#  Configuration
# =============================================================================

const WINDOW_SIZE          = parse(Int, get(ENV, "WINDOW_SIZE",         "10"))
const STRIDE               = parse(Int, get(ENV, "STRIDE",              "05"))
const MIN_WINDOWS_FOR_CI   = parse(Int, get(ENV, "MIN_WINDOWS_FOR_CI",  "20"))
const N_BOOTSTRAP          = parse(Int, get(ENV, "N_BOOTSTRAP",         "1000"))
const EXPORT_DIR           = abspath(get(ENV, "EXPORT_DIR",
                                 joinpath(@__DIR__, "..", "testdata", "export")))
const TESTDATA_ROOT        = abspath(get(ENV, "TESTDATA",
                                 joinpath(@__DIR__, "..", "testdata")))
const OUTPUT_DIR_BASE      = abspath(get(ENV, "OUTPUT_DIR",
                                 joinpath(@__DIR__, "..", "..", "docs", "reports")))
const PRIORS_CSV           = abspath(get(ENV, "PRIORS_CSV",
                                 joinpath(@__DIR__, "..", "..", "docs", "normative_priors.csv")))

# ── HRV features to include in the report ─────────────────────────────────────
const REPORT_FEATURES  = ["rmssd", "mean", "sdnn", "lf", "hf", "sd1", "sd2",
                           "pnn50", "lf_hf_ratio"]
const PAIRPLOT_FEATURES = ["rmssd", "sdnn", "lf", "hf", "sd1", "sd2"]

const FEAT_LABELS = Dict(
    "rmssd"       => "RMSSD (ms)",
    "mean"        => "Mean IBI (ms)",
    "sdnn"        => "SDNN (ms)",
    "lf"          => "LF Power (ms²)",
    "hf"          => "HF Power (ms²)",
    "sd1"         => "SD1 (ms)",
    "sd2"         => "SD2 (ms)",
    "pnn50"       => "pNN50 (%)",
    "lf_hf_ratio" => "LF/HF ratio",
)

const NORMATIVE_DATASET_KEYS = ["nsrdb", "nsr2db"]

# =============================================================================
#  Participant discovery
# =============================================================================

"""Find all participant folders under EXPORT_DIR.  Filters out non-directory
entries and hidden folders."""
function discover_participants()::Vector{String}
    isdir(EXPORT_DIR) || error("Export directory not found: $(EXPORT_DIR)")
    dirs = filter(readdir(EXPORT_DIR)) do name
        isdir(joinpath(EXPORT_DIR, name)) && !startswith(name, ".")
    end
    return dirs
end

# ── Determine participant to process ──────────────────────────────────────────
const PARTICIPANT_ID = let
    env_p = get(ENV, "PARTICIPANT", "")
    if !isempty(env_p)
        env_p
    else
        avail = discover_participants()
        isempty(avail) && error("No participant folders found under $(EXPORT_DIR)")
        first(avail)
    end
end

const PARTICIPANT_DIR = joinpath(EXPORT_DIR, PARTICIPANT_ID)
isdir(PARTICIPANT_DIR) || error("Participant folder not found: $(PARTICIPANT_DIR)")

const OUTPUT_FILE = joinpath(OUTPUT_DIR_BASE,
                             "participant_$(replace(PARTICIPANT_ID, " " => "_"))_w$(WINDOW_SIZE)s$(STRIDE)_report.html")

# =============================================================================
#  Utilities
# =============================================================================

function fig_to_b64(p)::String
    buf = IOBuffer()
    show(buf, MIME("image/png"), p)
    return base64encode(take!(buf))
end

function img_tag(b64::String, alt::String="plot", width::String="100%")
    """<img src="data:image/png;base64,$b64" alt="$alt" style="max-width:$width; height:auto;">"""
end

available_features(df::DataFrame) = intersect(REPORT_FEATURES, names(df))
available_pairplot(df::DataFrame) = intersect(PAIRPLOT_FEATURES, names(df))

"""Parse a filename like '2024-01-15 08-24-08.txt' into a DateTime."""
function parse_recording_dt(filename::String)::Union{DateTime, Nothing}
    base = splitext(basename(filename))[1]
    try
        # Format: YYYY-MM-DD HH-MM-SS
        return DateTime(base, "yyyy-mm-dd HH-MM-SS")
    catch
        try
            # Fallback: YYYY-MM-DD
            return DateTime(Date(base[1:10], "yyyy-mm-dd"))
        catch
            return nothing
        end
    end
end

"""Normalise IBI vector: replace zeros and biological outliers, interpolate NaNs."""
function preprocess_ibis(ibis::Vector{Float64})::Vector{Float64}
    n = replace_zeros(ibis)
    n = replace_bio_outliers(n)
    n = interpolate_nans(n)
    return n
end

"""Normalise numeric Union{T,Missing} columns in a DataFrame: Missing → NaN."""
function normalise_missing!(df::DataFrame)
    for col in names(df)
        T = nonmissingtype(eltype(df[!, col]))
        if eltype(df[!, col]) >: Missing && T <: Number
            df[!, col] = map(v -> ismissing(v) ? NaN : Float64(v), df[!, col])
        end
    end
    return df
end

# =============================================================================
#  Load normative reference datasets
# =============================================================================

if isfile(PRIORS_CSV)
    n_priors = load_normative_priors!(PRIORS_CSV)
    @info "Loaded $n_priors normative priors from $PRIORS_CSV"
else
    @warn "Priors CSV not found at $PRIORS_CSV — using empirical Normal fallback"
end

println("="^60)
println("  HeartRateLab — Participant Resonance Breathing Report")
println("  Participant : $(PARTICIPANT_ID)")
println("  Window      : $(WINDOW_SIZE) beats / stride $(STRIDE) beats")
println("="^60)

"""Load windowed_w{W}_s{S}_features.csv for a normative dataset."""
function load_normative_windowed(dataset::String)::Union{DataFrame, Nothing}
    fname = "windowed_w$(WINDOW_SIZE)_s$(STRIDE)_features.csv"
    path  = joinpath(TESTDATA_ROOT, dataset, fname)
    if !isfile(path)
        @warn "[$dataset] $fname not found — skipping"
        return nothing
    end
    df = CSV.read(path, DataFrame; silencewarnings=true)
    normalise_missing!(df)
    @info "[$dataset] loaded $(nrow(df)) windows"
    return df
end

norm_dfs = Dict{String, DataFrame}()
for k in NORMATIVE_DATASET_KEYS
    df = load_normative_windowed(k)
    df !== nothing && (norm_dfs[k] = df)
end

isempty(norm_dfs) && error("""
No normative windowed CSVs found for $(join(NORMATIVE_DATASET_KEYS, ", ")).
Run test/tools/collect_normative_datasets.jl first with WINDOW_SIZE=$(WINDOW_SIZE) STRIDE=$(STRIDE).
""")

normal_keys = collect(keys(norm_dfs))

# Build combined normative reference ──────────────────────────────────────────
combined_normal_df = let
    _cdf = vcat([norm_dfs[k] for k in normal_keys]...; cols=:union)
    normalise_missing!(_cdf)
    _cdf
end

@info "[all_normal] combined $(nrow(combined_normal_df)) windows from: $(join(normal_keys, ", "))"

const REF_LABEL = "All Normal"
const REF_DF    = combined_normal_df

# ── Per-recording metadata struct (module-level) ──────────────────────────────
struct RecordingMeta
    filepath :: String
    dt       :: DateTime
    ibis     :: Vector{Float64}
end

# =============================================================================
#  Load and window participant recordings
# =============================================================================

"""
Load and window all .txt files from the participant's export directory.
Returns:
  - `all_windows_df`  : pooled DataFrame of all windowed feature rows
  - `timeline_data`   : Vector of NamedTuples (recording_dt, n_windows, mean_feats, ci_feats)
"""
function load_participant_data()
    txt_files = filter(f -> endswith(f, ".txt"),
                       readdir(PARTICIPANT_DIR; join=true))
    sort!(txt_files)
    @info "Found $(length(txt_files)) recording files for participant $PARTICIPANT_ID"

    recordings = RecordingMeta[]
    for filepath in txt_files
        dt = parse_recording_dt(filepath)
        dt === nothing && (@warn "Could not parse date from $filepath — skipping"; continue)
        try
            raw = read_txt(filepath)
            if length(raw) < WINDOW_SIZE
                @info "  [skip] $(basename(filepath)) — only $(length(raw)) IBI samples (need ≥ $WINDOW_SIZE)"
                continue
            end
            ibis = preprocess_ibis(Vector{Float64}(raw))
            push!(recordings, RecordingMeta(filepath, dt, ibis))
        catch e
            @warn "  [error] $(basename(filepath)): $e"
        end
    end

    isempty(recordings) && error("No valid recordings found in $PARTICIPANT_DIR")
    @info "Loaded $(length(recordings)) valid recordings (≥ $WINDOW_SIZE IBIs each)"

    # ── Window each recording and extract features ────────────────────────────
    all_rows = DataFrame[]
    for rec in recordings
        empty_all_caches!()
        try
            df = windowed_feature_set(
                rec.ibis;
                window_size = WINDOW_SIZE,
                stride      = STRIDE,
                time        = :beats,
                features    = :default,
            )
            df[!, :recording_file] .= basename(rec.filepath)
            df[!, :recording_dt]   .= rec.dt
            df[!, :recording_date] .= Date(rec.dt)
            push!(all_rows, df)
        catch e
            @warn "  Windowing failed for $(basename(rec.filepath)): $e"
        end
    end

    isempty(all_rows) && error("Feature extraction produced no windows")

    pooled = vcat(all_rows...; cols=:union)
    normalise_missing!(pooled)
    pooled[!, :participant_id] .= PARTICIPANT_ID

    @info "Total windows extracted: $(nrow(pooled))"

    # ── Build per-date timeline data ──────────────────────────────────────────
    feats = available_features(pooled)
    grouped_by_date = groupby(pooled, :recording_date)

    timeline = map(collect(pairs(grouped_by_date))) do (key, gdf)
        date    = key.recording_date
        n_win   = nrow(gdf)
        n_files = length(unique(gdf[!, :recording_file]))

        # Compute mean per feature
        means = Dict{String, Float64}()
        ci_lo = Dict{String, Float64}()
        ci_hi = Dict{String, Float64}()
        has_ci = n_win >= MIN_WINDOWS_FOR_CI

        for feat in feats
            vals = filter(!isnan, gdf[!, feat])
            n_v  = length(vals)
            n_v == 0 && continue
            means[feat] = Statistics.mean(vals)

            if has_ci && n_v >= MIN_WINDOWS_FOR_CI
                # 95% bootstrap CI
                rng        = MersenneTwister(42)
                boot_means = [Statistics.mean(vals[rand(rng, 1:n_v, n_v)])
                              for _ in 1:N_BOOTSTRAP]
                ci_lo[feat] = quantile(boot_means, 0.025)
                ci_hi[feat] = quantile(boot_means, 0.975)
            end
        end

        (date    = date,
         n_win   = n_win,
         n_files = n_files,
         has_ci  = has_ci,
         means   = means,
         ci_lo   = ci_lo,
         ci_hi   = ci_hi)
    end

    sort!(timeline; by=t -> t.date)

    return pooled, timeline
end

participant_df, timeline_data = load_participant_data()

n_recordings = length(unique(participant_df[!, :recording_date]))
n_windows    = nrow(participant_df)

# =============================================================================
#  Distribution stats helpers (shared with normative report)
# =============================================================================

function _family_name(d)::String
    T = typeof(d)
    T <: Distributions.Normal    && return "Normal"
    T <: Distributions.Gamma     && return "Gamma"
    T <: Distributions.Beta      && return "Beta"
    T <: Distributions.LogNormal && return "LogNormal"
    return string(nameof(T))
end

function _location(d)::Float64
    typeof(d) <: Distributions.Normal    && return Distributions.mean(d)
    typeof(d) <: Distributions.LogNormal && return Distributions.median(d)
    typeof(d) <: Distributions.Gamma     && return Distributions.mean(d)
    typeof(d) <: Distributions.Beta      && return Distributions.mean(d)
    return Distributions.mean(d)
end

function _dispersion(d)::Float64
    typeof(d) <: Distributions.Normal && return Distributions.std(d)
    q75 = Distributions.quantile(d, 0.75)
    q25 = Distributions.quantile(d, 0.25)
    return q75 - q25
end

function _dispersion_label(d)::String
    typeof(d) <: Distributions.Normal && return "σ"
    return "IQR"
end

function zscore_interpretation(z::Float64)::Tuple{String,String}
    isnan(z) && return ("N/A", "table-secondary")
    az = abs(z)
    az <= 1.0 && return ("Within central 68% — typical",            "table-success")
    az <= 2.0 && return ("Within central 95% — slightly atypical",  "table-warning")
    az <= 3.0 && return ("Within central 99.7% — notably atypical", "table-danger")
    return ("Beyond 99.7% — rare", "table-danger fw-bold")
end

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
        isempty(ds_vals) && return (feature=feat, family="—", location=NaN,
                                    dispersion=NaN, ds_median=NaN,
                                    percentile=NaN, z_equiv=NaN, n_ds=0)
        md   = median(ds_vals)
        n_ds = length(ds_vals)

        prior = normative_prior(feat)
        if prior !== nothing
            fam  = _family_name(prior)
            loc  = _location(prior)
            disp = _dispersion(prior)
            pct  = Distributions.cdf(prior, md)
            pct_c = clamp(pct, 1e-8, 1.0 - 1e-8)
            z_eq = Distributions.quantile(Distributions.Normal(), pct_c)
            return (feature    = feat,
                    family     = fam,
                    location   = round(loc;  digits=2),
                    dispersion = round(disp; digits=2),
                    ds_median  = round(md;   digits=2),
                    percentile = round(pct;  digits=4),
                    z_equiv    = round(z_eq; digits=3),
                    n_ds       = n_ds)
        else
            ref_vals = filter(!isnan, ref_df[!, feat])
            isempty(ref_vals) && return (feature=feat, family="empirical",
                                          location=NaN, dispersion=NaN,
                                          ds_median=round(md; digits=2),
                                          percentile=NaN, z_equiv=NaN, n_ds=n_ds)
            μ = mean(ref_vals); σ = std(ref_vals)
            z = σ > 1e-12 ? (md - μ) / σ : NaN
            pct = σ > 1e-12 ? Distributions.cdf(Distributions.Normal(μ, σ), md) : NaN
            return (feature    = feat,
                    family     = "Normal*",
                    location   = round(μ;  digits=2),
                    dispersion = round(σ;  digits=2),
                    ds_median  = round(md; digits=2),
                    percentile = round(pct; digits=4),
                    z_equiv    = round(z;   digits=3),
                    n_ds       = n_ds)
        end
    end
    return DataFrame(rows)
end

# =============================================================================
#  HTML helpers
# =============================================================================

function zscore_table_html(zdf::DataFrame, ds_label::String; caption_extra="")::String
    rows = join(map(eachrow(zdf)) do r
        interp, row_class = zscore_interpretation(r.z_equiv)
        feat_label  = get(FEAT_LABELS, r.feature, r.feature)
        z_str       = isnan(r.z_equiv) ? "—" : @sprintf("%+.3f", r.z_equiv)
        pct_str     = isnan(r.percentile) ? "—" : @sprintf("%.1f%%", r.percentile * 100)
        badge_color = isnan(r.z_equiv) ? "bg-secondary" :
                      abs(r.z_equiv) <= 1.0 ? "bg-success" :
                      abs(r.z_equiv) <= 2.0 ? "bg-warning text-dark" : "bg-danger"
        prior       = normative_prior(r.feature)
        disp_lbl    = prior !== nothing ? _dispersion_label(prior) : "σ"
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
    end, "\n")

    """
    <div class="table-responsive mt-3">
    <table class="table table-sm table-bordered align-middle text-center caption-top">
      <caption>Distributional deviation — <em>$(ds_label)</em> median window vs fitted normative prior
               ($(WINDOW_SIZE)-beat windows)$(isempty(caption_extra) ? "" : " — " * caption_extra)</caption>
      <thead class="table-light">
        <tr>
          <th>Feature</th><th>Family</th><th>Location</th><th>Dispersion</th>
          <th>Participant median</th><th>Percentile</th><th>Z-equiv</th>
          <th>N (windows)</th><th>Interpretation</th>
        </tr>
      </thead>
      <tbody>$(rows)</tbody>
    </table>
    </div>
    """
end

# =============================================================================
#  TAB 1: All Normal comparison
# =============================================================================

@info "Building All Normal tab..."

function build_all_normal_section()::String
    feats    = available_features(combined_normal_df)
    pp_feats = available_pairplot(combined_normal_df)
    normal_overlay = Dict(k => norm_dfs[k] for k in normal_keys)

    between_b64 = ""
    try
        p = plot_normative_kde_comparison(
            normal_overlay, feats;
            feat_labels = Dict(k => get(FEAT_LABELS, k, k) for k in feats),
            ncols       = min(3, length(feats)),
            title       = "Between-dataset comparison — healthy populations",
        )
        between_b64 = fig_to_b64(p)
    catch e; @warn "All-normal KDE failed" exception=e; end

    corr_b64 = ""
    if length(feats) >= 3
        try
            p = plot_feature_correlogram(combined_normal_df, feats;
                    title="Combined Normal — Feature Correlation Matrix")
            corr_b64 = fig_to_b64(p)
        catch e; @warn "All-normal correlogram failed" exception=e; end
    end

    pair_b64 = ""
    if length(pp_feats) >= 2
        try
            p = plot_normative_pairplot(normal_overlay, pp_feats;
                    title="Healthy Populations — Pairplot")
            pair_b64 = fig_to_b64(p)
        catch e; @warn "All-normal pairplot failed" exception=e; end
    end

    nk_j       = join(normal_keys, " + ")
    n_total    = nrow(combined_normal_df)
    between_img = isempty(between_b64) ? "" : img_tag(between_b64, "KDE between healthy datasets")
    corr_img    = isempty(corr_b64)    ? "" : img_tag(corr_b64, "Correlation matrix")
    pair_img    = isempty(pair_b64)    ? "" : img_tag(pair_b64, "Pairplot")

    parts = String["""
    <div class="row mb-4 g-3">
      <div class="col-12">
        <div class="card">
          <div class="card-header bg-success text-white">
            <strong>Combined Healthy-Population Reference</strong>
            <span class="badge bg-light text-success ms-2">$(nk_j)</span>
          </div>
          <div class="card-body">
            <div class="row text-center mb-2">
              <div class="col">
                <span class="fs-4 fw-bold text-success">$(n_total)</span><br>
                <small class="text-muted">total $(WINDOW_SIZE)-beat windows</small>
              </div>
              <div class="col">
                <span class="fs-4 fw-bold text-success">$(length(normal_keys))</span><br>
                <small class="text-muted">datasets pooled</small>
              </div>
            </div>
            <p class="text-muted small mb-0">
              This combined group is the normative reference used for participant
              distribution scoring.  Fitted prior distributions (from
              <code>normative_priors.csv</code>) define the quantile-based
              dispersion bands, respecting each feature's distribution family.
            </p>
          </div>
        </div>
      </div>
    </div>"""]

    if !isempty(between_b64)
        push!(parts, """
    <div class="row mb-4">
      <div class="col-12">
        <h5 class="border-bottom pb-1">Between-Dataset Distributions (healthy populations)</h5>
        <p class="text-muted small">Each coloured curve represents one healthy-population dataset.
           Divergence indicates dataset-specific distributional differences.</p>
        $(between_img)
      </div>
    </div>""")
    end

    if !isempty(corr_b64)
        pair_col = isempty(pair_b64) ? "<div class=\"col-lg-6\"></div>" :
            "<div class=\"col-lg-6\"><h5 class=\"border-bottom pb-1\">Healthy-Population Pairplot</h5>$(pair_img)</div>"
        push!(parts, """
    <div class="row mb-4">
      <div class="col-lg-6">
        <h5 class="border-bottom pb-1">Combined-Normal Correlation Matrix</h5>
        $(corr_img)
      </div>
      $(pair_col)
    </div>""")
    end

    # ANOVA between the two normative datasets
    anova_html = ""
    if length(normal_keys) >= 2
        anova_html = build_anova_html()
    end
    if !isempty(anova_html)
        push!(parts, """
    <div class="card border-dark mt-4">
      <div class="card-header bg-dark text-white">
        <strong>One-way ANOVA across Normative Datasets</strong>
      </div>
      <div class="card-body">$(anova_html)</div>
    </div>""")
    end

    return join(parts, "\n")
end

# ── ANOVA helpers ─────────────────────────────────────────────────────────────

function _participant_means(df::DataFrame, feat::String)::Vector{Float64}
    pid_col = "participant_id"
    pid_col in names(df) || return filter(!isnan, df[!, feat])
    result = Float64[]
    for gdf in groupby(df, pid_col)
        vals = filter(!isnan, gdf[!, feat])
        length(vals) >= 1 && push!(result, Statistics.mean(vals))
    end
    return result
end

function build_anova_html()::String
    feats = available_features(combined_normal_df)
    avail = [k for k in normal_keys if haskey(norm_dfs, k)]
    length(avail) < 2 && return ""

    ds_n = Dict(k => length(unique(norm_dfs[k][!, "participant_id"]))
                for k in avail if "participant_id" in names(norm_dfs[k]))
    total_p = sum(values(ds_n); init=0)

    results = map(feats) do feat
        groups = [_participant_means(norm_dfs[k], feat) for k in avail]
        filter!(g -> length(g) >= 2, groups)
        length(groups) < 2 && return (feature=feat, F=NaN, p_value=NaN,
                                       n_total=0, significant=false,
                                       interpretation="Insufficient data")
        n_g = length(groups); N = sum(length.(groups))
        gm  = Statistics.mean(vcat(groups...))
        SS_b = sum(length(g) * (Statistics.mean(g) - gm)^2 for g in groups)
        SS_w = sum(sum((x - Statistics.mean(g))^2 for x in g) for g in groups)
        df_b = n_g - 1; df_w = N - n_g
        F = (SS_w > 0 && df_w > 0) ? (SS_b/df_b)/(SS_w/df_w) : NaN
        p = isnan(F) ? NaN : 1.0 - Distributions.cdf(Distributions.FDist(df_b, df_w), F)
        interp = if isnan(p);  "Insufficient data"
            elseif p < 0.001;  "Highly significant (p < 0.001)"
            elseif p < 0.05;   "Significant (p < 0.05)"
            elseif p < 0.10;   "Marginal (p < 0.10)"
            else;              "Not significant"
        end
        (feature=feat, F=round(F; digits=3), p_value=p,
         n_total=N, significant=(!isnan(p) && p < 0.05),
         interpretation=interp)
    end

    rows = join(map(results) do r
        fl = get(FEAT_LABELS, r.feature, r.feature)
        fs = isnan(r.F) ? "—" : string(r.F)
        ps = isnan(r.p_value) ? "—" :
             r.p_value < 1e-10 ? @sprintf("%.2e", r.p_value) :
             @sprintf("%.5f", r.p_value)
        badge = r.significant ? """<span class="badge bg-danger">significant</span>""" :
                                """<span class="badge bg-success">not sig.</span>"""
        rc    = r.significant ? "table-warning" : ""
        "<tr class=\"$rc\"><td class=\"text-start fw-semibold\">$fl</td>" *
        "<td><code>$fs</code></td><td><code>$ps</code></td>" *
        "<td>$(r.n_total)</td><td>$badge</td>" *
        "<td class=\"text-start small\">$(r.interpretation)</td></tr>"
    end, "\n")

    n_sig = count(r -> r.significant, results)
    n_f   = length(results)
    sc    = n_sig == 0 ? "success" : n_sig <= 2 ? "warning" : "danger"
    msg   = n_sig == 0 ? "All features are <strong>statistically consistent</strong> across normative datasets." :
            "<strong>$(n_sig) / $(n_f) features</strong> show significant differences."

    glist = join(["$k (n=$(get(ds_n, k, "?")))" for k in avail], ", ")

    return """
    <div class="alert alert-secondary small mb-3">
      Participant-level one-way ANOVA across <strong>$(length(avail)) normative datasets</strong>
      ($glist; <strong>$(total_p) participants total</strong>).
    </div>
    <div class="table-responsive">
    <table class="table table-sm table-bordered align-middle text-center">
      <thead class="table-dark">
        <tr>
          <th class="text-start">Feature</th><th>F</th><th>p-value</th>
          <th>N participants</th><th>Result</th><th class="text-start">Interpretation</th>
        </tr>
      </thead>
      <tbody>$rows</tbody>
    </table>
    </div>
    <div class="alert alert-$sc mt-3"><strong>Summary:</strong> $msg</div>
    """
end

# =============================================================================
#  TAB 2: Participant HRV vs Normative Reference
# =============================================================================

@info "Building Participant HRV tab..."

function build_participant_section()::String
    feats    = available_features(participant_df)
    pp_feats = available_pairplot(participant_df)

    overlay = Dict(REF_LABEL => REF_DF, PARTICIPANT_ID => participant_df)

    kde_b64 = ""
    try
        p = plot_normative_kde_comparison(
            overlay, feats;
            reference_key = REF_LABEL,
            feat_labels   = Dict(k => get(FEAT_LABELS, k, k) for k in feats),
            ncols         = min(3, length(feats)),
            title         = "$(PARTICIPANT_ID)  vs  $(REF_LABEL) reference",
        )
        kde_b64 = fig_to_b64(p)
    catch e; @warn "Participant KDE failed" exception=e; end

    zdf         = compute_zscores(participant_df, REF_DF)
    zscore_html = zscore_table_html(zdf, PARTICIPANT_ID;
                      caption_extra="$(n_recordings) recording dates, $(n_windows) windows")

    corr_b64 = ""
    if length(feats) >= 3
        try
            p = plot_feature_correlogram(participant_df, feats;
                    title="$(PARTICIPANT_ID) — Feature Correlation Matrix")
            corr_b64 = fig_to_b64(p)
        catch e; @warn "Participant correlogram failed" exception=e; end
    end

    pair_b64 = ""
    if length(pp_feats) >= 2
        try
            p = plot_normative_pairplot(overlay, pp_feats;
                    title="$(PARTICIPANT_ID) — Pairplot vs $(REF_LABEL)")
            pair_b64 = fig_to_b64(p)
        catch e; @warn "Participant pairplot failed" exception=e; end
    end

    kde_img  = isempty(kde_b64)  ? "" : img_tag(kde_b64, "KDE comparison")
    corr_img = isempty(corr_b64) ? "" : img_tag(corr_b64, "Correlation matrix")
    pair_img = isempty(pair_b64) ? "" : img_tag(pair_b64, "Pairplot")
    nk_j     = join(normal_keys, " + ")

    parts = String["""
    <div class="row mb-4 g-3">
      <div class="col-12">
        <div class="card">
          <div class="card-header bg-primary text-white d-flex align-items-center gap-2">
            <strong>$(PARTICIPANT_ID)</strong>
            <span class="badge bg-light text-primary">resonant breathing training</span>
          </div>
          <div class="card-body">
            <div class="row text-center mb-3">
              <div class="col">
                <span class="fs-4 fw-bold text-primary">$(n_windows)</span><br>
                <small class="text-muted">$(WINDOW_SIZE)-beat windows</small>
              </div>
              <div class="col">
                <span class="fs-4 fw-bold text-primary">$(n_recordings)</span><br>
                <small class="text-muted">recording dates</small>
              </div>
              <div class="col">
                <span class="fs-4 fw-bold text-primary">$(length(feats))</span><br>
                <small class="text-muted">features extracted</small>
              </div>
            </div>
            <p class="text-muted small mb-0">
              Normative reference: <strong>$(nk_j)</strong> ($(nrow(REF_DF)) windows).
              Distribution bands derived from fitted priors (Normal/Gamma/Beta/LogNormal per feature).
            </p>
          </div>
        </div>
      </div>
    </div>"""]

    if !isempty(kde_b64)
        push!(parts, """
    <div class="row mb-4">
      <div class="col-12">
        <h5 class="border-bottom pb-1">Feature Distributions vs Normative Reference</h5>
        <p class="text-muted small">KDE curves for each HRV feature. Dispersion bands (central 68% / 95% / 99.7%) derived from fitted normative prior distributions ($(nk_j)).</p>
        $(kde_img)
      </div>
    </div>""")
    end

    push!(parts, """
    <div class="row mb-4">
      <div class="col-12">
        <h5 class="border-bottom pb-1">Distributional Deviation Analysis</h5>
        $(zscore_html)
      </div>
    </div>""")

    if !isempty(corr_b64)
        pair_col = isempty(pair_b64) ? "<div class=\"col-lg-6\"></div>" :
            "<div class=\"col-lg-6\"><h5 class=\"border-bottom pb-1\">Feature Pairplot</h5>" *
            "<p class=\"text-muted small\">Scatter matrix of core features. $(REF_LABEL) reference overlaid.</p>$(pair_img)</div>"
        push!(parts, """
    <div class="row mb-4">
      <div class="col-lg-6">
        <h5 class="border-bottom pb-1">Feature Correlation Matrix</h5>
        <p class="text-muted small">Pearson correlations across all $(n_windows) windows.</p>
        $(corr_img)
      </div>
      $(pair_col)
    </div>""")
    end

    return join(parts, "\n")
end

# =============================================================================
#  TAB 3: HRV Timeline
# =============================================================================

@info "Building Timeline tab..."

"""
Generate a timeline plot for a single HRV feature.

- X axis: recording date
- Y axis: feature value (mean per date)
- Error bars: 95% bootstrap CI where n_windows ≥ MIN_WINDOWS_FOR_CI
- Horizontal reference bands: normative µ ± σ, µ ± 2σ (from prior or empirical)
"""
function build_timeline_plot(feat::String)
    feat_label = get(FEAT_LABELS, feat, feat)

    # ── Collect timeline points ────────────────────────────────────────────────
    dates   = Date[]
    means   = Float64[]
    lo_ci   = Float64[]
    hi_ci   = Float64[]
    has_ci  = Bool[]

    for t in timeline_data
        haskey(t.means, feat) || continue
        push!(dates,  t.date)
        push!(means,  t.means[feat])
        push!(has_ci, t.has_ci && haskey(t.ci_lo, feat))
        push!(lo_ci,  get(t.ci_lo, feat, t.means[feat]))
        push!(hi_ci,  get(t.ci_hi, feat, t.means[feat]))
    end

    isempty(dates) && return nothing

    # ── Normative reference bands ──────────────────────────────────────────────
    ref_vals = filter(!isnan, REF_DF[!, feat])
    prior    = normative_prior(feat)

    ref_loc, ref_lo1, ref_hi1, ref_lo2, ref_hi2 = if prior !== nothing
        loc = _location(prior)
        lo1 = Distributions.quantile(prior, 0.1587)   # µ - σ equiv
        hi1 = Distributions.quantile(prior, 0.8413)   # µ + σ equiv
        lo2 = Distributions.quantile(prior, 0.0228)   # µ - 2σ equiv
        hi2 = Distributions.quantile(prior, 0.9772)   # µ + 2σ equiv
        loc, lo1, hi1, lo2, hi2
    elseif !isempty(ref_vals)
        μ = mean(ref_vals); σ = std(ref_vals)
        μ, μ-σ, μ+σ, μ-2σ, μ+2σ
    else
        NaN, NaN, NaN, NaN, NaN
    end

    # ── Build the Plots.jl figure ──────────────────────────────────────────────
    all_vals = vcat(means, lo_ci, hi_ci,
                    filter(!isnan, [ref_lo2, ref_hi2]))
    ymin = minimum(filter(!isnan, all_vals))
    ymax = maximum(filter(!isnan, all_vals))
    ypad = (ymax - ymin) * 0.12
    ymin -= ypad; ymax += ypad

    x_numeric = 1:length(dates)
    date_strs  = string.(dates)

    # Ref band: ±2σ (gold)
    p = plot(; xlabel="Recording date", ylabel=feat_label,
               title="$(feat_label) over time — $(PARTICIPANT_ID)",
               ylims=(ymin, ymax),
               legend=:outertopright,
               xticks=(x_numeric, date_strs),
               xrotation=45,
               size=(900, 420),
               left_margin=5*(Plots.mm),
               bottom_margin=12*(Plots.mm))

    if !isnan(ref_lo2)
        plot!(p, [1, length(dates)], [ref_lo2, ref_lo2];
              fillrange=[ref_hi2, ref_hi2],
              fillalpha=0.18, fillcolor=:gold, linewidth=0, label="ref ±2σ")
    end
    if !isnan(ref_lo1)
        plot!(p, [1, length(dates)], [ref_lo1, ref_lo1];
              fillrange=[ref_hi1, ref_hi1],
              fillalpha=0.25, fillcolor=:steelblue, linewidth=0, label="ref ±1σ")
    end
    if !isnan(ref_loc)
        hline!(p, [ref_loc]; color=:steelblue, linewidth=2,
               linestyle=:dash, label="ref median/mean")
    end

    # Points without CI
    no_ci_idx = findall(.!has_ci)
    if !isempty(no_ci_idx)
        scatter!(p, x_numeric[no_ci_idx], means[no_ci_idx];
                 color=:darkorange, markersize=6, label="recording (no CI)",
                 markerstrokewidth=1, markerstrokecolor=:white)
    end

    # Points with CI (plot in two passes: error bars then scatter)
    ci_idx = findall(has_ci)
    if !isempty(ci_idx)
        # error bars
        for i in ci_idx
            plot!(p, [x_numeric[i], x_numeric[i]], [lo_ci[i], hi_ci[i]];
                  color=:crimson, linewidth=2, label="")
        end
        # cap ticks
        for i in ci_idx
            scatter!(p, [x_numeric[i] - 0.2, x_numeric[i] + 0.2],
                        [lo_ci[i], lo_ci[i]]; color=:crimson,
                     markersize=4, markershape=:hline, label="")
            scatter!(p, [x_numeric[i] - 0.2, x_numeric[i] + 0.2],
                        [hi_ci[i], hi_ci[i]]; color=:crimson,
                     markersize=4, markershape=:hline, label="")
        end
        scatter!(p, x_numeric[ci_idx], means[ci_idx];
                 color=:crimson, markersize=7, label="recording (95% CI)",
                 markerstrokewidth=1, markerstrokecolor=:white)
    end

    # Trend line (linear least-squares)
    if length(dates) >= 4
        try
            xs_f  = Float64.(collect(x_numeric))
            n_t   = length(xs_f)
            xmean = sum(xs_f) / n_t
            ymean = sum(means) / n_t
            b     = sum((xs_f .- xmean) .* (means .- ymean)) / sum((xs_f .- xmean).^2)
            a     = ymean - b * xmean
            trend = a .+ b .* xs_f
            plot!(p, x_numeric, trend; color=:gray60, linewidth=2,
                  linestyle=:dot, label="linear trend")
        catch; end
    end

    return p
end

# ── Pre-render all timeline plots ──────────────────────────────────────────────
feats_for_timeline = available_features(participant_df)

timeline_b64 = Dict{String, String}()
for feat in feats_for_timeline
    @info "  Timeline plot: $feat"
    p = nothing
    try; p = build_timeline_plot(feat); catch e; @warn "$feat timeline failed" exception=e; end
    if p !== nothing
        try; timeline_b64[feat] = fig_to_b64(p); catch e; @warn "$feat save failed" exception=e; end
    end
end

# ── Build timeline tab HTML ────────────────────────────────────────────────────
function build_timeline_section()::String
    isempty(timeline_b64) && return """
    <div class="alert alert-warning">No timeline data could be generated.</div>"""

    n_dates    = length(timeline_data)
    n_ci_dates = count(t -> t.has_ci, timeline_data)
    first_rec  = isempty(timeline_data) ? "—" : string(first(timeline_data).date)
    last_rec   = isempty(timeline_data) ? "—" : string(last(timeline_data).date)

    # Options for the feature selector
    opts = join(map(feats_for_timeline) do f
        haskey(timeline_b64, f) || return ""
        lbl = get(FEAT_LABELS, f, f)
        """<option value="tl-$(f)">$(lbl)</option>"""
    end, "\n")

    # Image blocks (all hidden except first)
    img_blocks = join(map(enumerate(feats_for_timeline)) do (i, f)
        haskey(timeline_b64, f) || return ""
        display_style = i == 1 ? "" : "display:none;"
        img = img_tag(timeline_b64[f], get(FEAT_LABELS, f, f))
        """<div id="tl-$(f)" class="tl-panel" style="$(display_style)">$(img)</div>"""
    end, "\n")

    # Summary table of CI-eligible dates
    ci_table_rows = join(map(timeline_data) do t
        n_files_str = t.n_files > 1 ? " ($(t.n_files) sessions)" : ""
        ci_badge = t.has_ci ?
            """<span class="badge bg-success">yes — $(t.n_win) windows</span>""" :
            """<span class="badge bg-secondary">no — $(t.n_win) window$(t.n_win == 1 ? "" : "s")</span>"""
        "<tr><td>$(t.date)$(n_files_str)</td><td>$(t.n_win)</td><td>$(ci_badge)</td></tr>"
    end, "\n")

    return """
    <div class="row mb-4 g-3">
      <div class="col-12">
        <div class="card">
          <div class="card-header bg-dark text-white">
            <strong>HRV Feature Timeline — $(PARTICIPANT_ID)</strong>
          </div>
          <div class="card-body">
            <div class="row text-center">
              <div class="col">
                <span class="fs-4 fw-bold">$(first_rec)</span><br>
                <small class="text-muted">first recording</small>
              </div>
              <div class="col">
                <span class="fs-4 fw-bold">$(last_rec)</span><br>
                <small class="text-muted">last recording</small>
              </div>
              <div class="col">
                <span class="fs-4 fw-bold text-primary">$(n_dates)</span><br>
                <small class="text-muted">recording dates</small>
              </div>
              <div class="col">
                <span class="fs-4 fw-bold text-success">$(n_ci_dates)</span><br>
                <small class="text-muted">dates with 95% CI</small>
              </div>
              <div class="col">
                <span class="fs-4 fw-bold text-warning">$(MIN_WINDOWS_FOR_CI)</span><br>
                <small class="text-muted">min windows for CI</small>
              </div>
            </div>
            <p class="text-muted small mt-3 mb-0">
              Each point represents the <strong>mean feature value</strong> across all
              $(WINDOW_SIZE)-beat windows from that recording date.
              <strong>95% bootstrap confidence intervals</strong> ($(N_BOOTSTRAP)
              resamples, α = 0.05) are shown for dates with ≥ $(MIN_WINDOWS_FOR_CI) windows.
              Shaded bands show the normative ±1σ (blue) and ±2σ (gold) reference range;
              dashed line = normative median/mean.
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- Feature selector -->
    <div class="row mb-3">
      <div class="col-md-4">
        <label for="feature-select" class="form-label fw-semibold">Select feature to display:</label>
        <select id="feature-select" class="form-select" onchange="showTimeline(this.value)">
          $(opts)
        </select>
      </div>
    </div>

    <!-- Timeline plots (one img per feature, toggled by JS) -->
    <div id="timeline-container">
      $(img_blocks)
    </div>

    <!-- Recording-by-date summary table -->
    <div class="mt-4">
      <details>
        <summary class="text-primary fw-semibold" style="cursor:pointer">
          Recording details — $(n_dates) dates (click to expand)
        </summary>
        <div class="table-responsive mt-2">
        <table class="table table-sm table-bordered">
          <thead class="table-light">
            <tr><th>Date</th><th>Windows</th><th>Bootstrap CI eligible</th></tr>
          </thead>
          <tbody>$(ci_table_rows)</tbody>
        </table>
        </div>
      </details>
    </div>

    <script>
    function showTimeline(panelId) {
      document.querySelectorAll('.tl-panel').forEach(function(el) {
        el.style.display = 'none';
      });
      var target = document.getElementById(panelId);
      if (target) { target.style.display = ''; }
    }
    </script>
    """
end

# =============================================================================
#  Assemble full HTML page
# =============================================================================

println("\nAssembling report HTML...")

all_normal_html    = build_all_normal_section()
participant_html   = build_participant_section()
timeline_html      = build_timeline_section()

gen_ts    = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
nk_joined = join(normal_keys, " + ")

html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>HeartRateLab — $(PARTICIPANT_ID) — Resonance Breathing Report</title>
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
  </style>
</head>
<body>

<nav class="navbar navbar-expand-lg navbar-dark bg-dark mb-0">
  <div class="container-xl">
    <span class="navbar-brand">HeartRateLab</span>
    <span class="text-white-50 small ms-3">Resonant Frequency Breathing — $(PARTICIPANT_ID)</span>
    <span class="text-white-50 small ms-auto">$(gen_ts)</span>
  </div>
</nav>

<div class="container-xl py-4">

  <!-- Summary card -->
  <div class="row mb-4">
    <div class="col-12">
      <div class="card border-primary">
        <div class="card-body">
          <h4 class="card-title">Resonant Frequency Breathing — HRV Training Report</h4>
          <p class="card-text text-muted">
            Personal HRV training analysis for <strong>$(PARTICIPANT_ID)</strong>.
            All comparisons use <strong>$(WINDOW_SIZE)-beat windows / $(STRIDE)-beat stride</strong>.
            Normative reference: <em>$(nk_joined)</em> ($(nrow(REF_DF)) windows pooled).
          </p>
          <div class="row text-center">
            <div class="col">
              <span class="fs-5 fw-bold text-primary">$(n_windows)</span><br>
              <small class="text-muted">total windows</small>
            </div>
            <div class="col">
              <span class="fs-5 fw-bold text-primary">$(n_recordings)</span><br>
              <small class="text-muted">recording dates</small>
            </div>
            <div class="col">
              <span class="fs-5 fw-bold text-success">$(nrow(REF_DF))</span><br>
              <small class="text-muted">normative windows</small>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- Main tabs -->
  <ul class="nav nav-tabs" id="mainTabs" role="tablist">
    <li class="nav-item" role="presentation">
      <button class="nav-link active" id="btn-allnormal" data-bs-toggle="tab"
              data-bs-target="#tab-allnormal" type="button" role="tab">
        All Normal&nbsp;<span class="badge bg-success">reference</span>
      </button>
    </li>
    <li class="nav-item" role="presentation">
      <button class="nav-link" id="btn-participant" data-bs-toggle="tab"
              data-bs-target="#tab-participant" type="button" role="tab">
        Training HRV&nbsp;<span class="badge bg-primary">$(PARTICIPANT_ID)</span>
      </button>
    </li>
    <li class="nav-item" role="presentation">
      <button class="nav-link" id="btn-timeline" data-bs-toggle="tab"
              data-bs-target="#tab-timeline" type="button" role="tab">
        Timeline&nbsp;<span class="badge bg-secondary">$(n_recordings) dates</span>
      </button>
    </li>
  </ul>

  <div class="tab-content border border-top-0 rounded-bottom bg-white p-3 mb-5" id="mainTabContent">

    <div class="tab-pane fade show active" id="tab-allnormal" role="tabpanel">
      <div class="pt-3">
        $(all_normal_html)
      </div>
    </div>

    <div class="tab-pane fade" id="tab-participant" role="tabpanel">
      <div class="pt-3">
        $(participant_html)
      </div>
    </div>

    <div class="tab-pane fade" id="tab-timeline" role="tabpanel">
      <div class="pt-3">
        $(timeline_html)
      </div>
    </div>

  </div>

  <footer class="text-center text-muted small pb-4">
    Generated by HeartRateLab · $(gen_ts) ·
    Participant: $(PARTICIPANT_ID) · Window: $(WINDOW_SIZE) beats, stride: $(STRIDE) beats
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

mkpath(OUTPUT_DIR_BASE)
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
