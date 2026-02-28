#!/usr/bin/env julia
# =============================================================================
# fit_normative_distributions.jl
#
# Fits Distributions.jl parametric distribution families to each HRV feature
# using windowed normative dataset CSVs.  Each feature's analytical distribution
# family is declared in the feature registry (Features.jl) based on the
# computational graph from IBIs → feature value:
#
#   IBI ~ Normal(μ, σ²)  →  feature = f(IBIs)  →  distribution family
#
# The fitting procedure:
#   1. Load windowed feature CSVs from selected normative datasets
#   2. Pool all windows into a combined normative reference
#   3. For each scalar feature in the registry:
#      a. Read its analytical distribution family from feature_registry[name].distribution
#      b. Filter valid (non-NaN, finite) values
#      c. Fit MLE parameters via Distributions.fit(Family, data)
#      d. Run a Kolmogorov–Smirnov goodness-of-fit test
#   4. Output:
#      - docs/normative_priors.csv — machine-readable table with fitted params
#        (feature, definition, equation, family, prior_call, param names/values, KS p-value)
#      - test/testdata/normative_distribution_fits.toml — TOML for reference
#
# Analytical distribution families (from the computational graph):
#
#   Normal    — features that are means or sums of (possibly transformed) Normal
#               RVs: mean, median, max, min, mean_hr, max_hr, min_hr, lf_peak,
#               hf_peak, cvi, apen, sampen, dfa1, dfa2, renyi0/1/2
#
#   Gamma     — features involving √Var, √(mean of squares), or spectral band
#               power (sum of squared spectral components ≈ sum of Exp ≈ Gamma):
#               sdnn, rmssd, sdsd, sdann, range, cvsd, rRR, std_hr,
#               ulf, vlf, lf, hf, tp, sd1, sd2, triangular_index, tinn
#               (Note: lf_percentage, hf_percentage are Beta×100 — no
#               independent distribution; prior derived from _relative Beta)
#
#   Beta      — proportions bounded in [0,1]: pnn50, pnn20, lf_relative,
#               hf_relative, hurst
#
#   LogNormal — ratios or products of Gamma-distributed RVs whose log is
#               approximately Normal: lf_hf_ratio, sd2_sd1, sd1_sd2_area,
#               ccsi
#
# Usage (from project root):
#   julia --project=. test/tools/fit_normative_distributions.jl
#
# Options (env vars):
#   WINDOW_SIZE=360         Window size of collected features (default: 360)
#   STRIDE=120              Stride of collected features (default: 120)
#   DATASETS=nsrdb,nsr2db   Comma-separated normative dataset keys (default: nsrdb,nsr2db)
#   TESTDATA=test/testdata   Root of collected feature CSVs
#   OUTPUT_CSV=...          Output CSV path (default: docs/normative_priors.csv)
#   OUTPUT_TOML=...         Output TOML path (default: test/testdata/normative_distribution_fits.toml)
# =============================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using CSV, DataFrames, Dates, Statistics, Printf
using Distributions
using HypothesisTests

using HeartRateLab
using HeartRateLab: feature_registry, DISTRIBUTION_MAP

# =============================================================================
#  Configuration
# =============================================================================

const WINDOW_SIZE   = parse(Int, get(ENV, "WINDOW_SIZE", "360"))
const STRIDE        = parse(Int, get(ENV, "STRIDE",      "120"))
const TESTDATA_ROOT = abspath(get(ENV, "TESTDATA", joinpath(@__DIR__, "..", "testdata")))
const DATASET_KEYS  = split(get(ENV, "DATASETS", "nsrdb,nsr2db"), ',') .|> strip .|> String
const OUTPUT_CSV    = abspath(get(ENV, "OUTPUT_CSV",
                         joinpath(@__DIR__, "..", "..", "docs", "normative_priors.csv")))
const OUTPUT_TOML   = abspath(get(ENV, "OUTPUT_TOML",
                         joinpath(TESTDATA_ROOT, "normative_distribution_fits.toml")))

# =============================================================================
#  Feature metadata — definitions and equations
# =============================================================================

# Short human-readable definition for each feature
const FEATURE_DEFINITIONS = Dict{String,String}(
    "mean"           => "Mean inter-beat interval",
    "sdnn"           => "Standard deviation of NN intervals",
    "median"         => "Median inter-beat interval",
    "max"            => "Maximum inter-beat interval",
    "min"            => "Minimum inter-beat interval",
    "mean_hr"        => "Mean heart rate",
    "std_hr"         => "Standard deviation of heart rate",
    "max_hr"         => "Maximum heart rate",
    "min_hr"         => "Minimum heart rate",
    "sdsd"           => "Standard deviation of successive differences",
    "range"          => "Range of inter-beat intervals",
    "rmssd"          => "Root mean square of successive differences",
    "sdann"          => "Standard deviation of 5-min average NN intervals",
    "pnn50"          => "Proportion of successive differences > 50 ms",
    "pnn20"          => "Proportion of successive differences > 20 ms",
    "cvsd"           => "Coefficient of variation of successive differences",
    "rRR"            => "Median relative RR interval distance",
    "ulf"            => "Ultra-low frequency power (0-0.003 Hz)",
    "vlf"            => "Very low frequency power (0.003-0.04 Hz)",
    "lf"             => "Low frequency power (0.04-0.15 Hz)",
    "hf"             => "High frequency power (0.15-0.4 Hz)",
    "tp"             => "Total power (0.003-0.4 Hz)",
    "lf_peak"        => "Peak frequency in LF band",
    "hf_peak"        => "Peak frequency in HF band",
    "lf_hf_ratio"    => "LF/HF power ratio",
    "lf_relative"    => "LF power as proportion of total power",
    "hf_relative"    => "HF power as proportion of total power",
    "lf_percentage"  => "LF power as percentage of total power",
    "hf_percentage"  => "HF power as percentage of total power",
    "sd1"            => "Poincare plot short-term variability",
    "sd2"            => "Poincare plot long-term variability",
    "sd2_sd1"        => "Ratio of SD2 to SD1 (cardiac sympathetic index)",
    "sd1_sd2_area"   => "Poincare plot ellipse area",
    "cvi"            => "Cardiac vagal index",
    "ccsi"           => "Corrected cardiac sympathetic index",
    "triangular_index" => "HRV triangular index",
    "tinn"           => "Triangular interpolation of NN interval histogram",
    "apen"           => "Approximate entropy",
    "sampen"         => "Sample entropy",
    "hurst"          => "Hurst exponent",
    "dfa1"           => "DFA short-term scaling exponent alpha1",
    "dfa2"           => "DFA long-term scaling exponent alpha2",
    "renyi0"         => "Renyi entropy of order 0",
    "renyi1"         => "Renyi entropy of order 1",
    "renyi2"         => "Renyi entropy of order 2",
)

# Equations (plain text for CSV compatibility)
const FEATURE_EQUATIONS = Dict{String,String}(
    "mean"           => "mean(IBI)",
    "sdnn"           => "std(IBI)",
    "median"         => "median(IBI)",
    "max"            => "max(IBI)",
    "min"            => "min(IBI)",
    "mean_hr"        => "60000 / mean(IBI)",
    "std_hr"         => "60000 / std(IBI)",
    "max_hr"         => "60000 / max(IBI)",
    "min_hr"         => "60000 / min(IBI)",
    "sdsd"           => "std(diff(IBI))",
    "range"          => "max(IBI) - min(IBI)",
    "rmssd"          => "sqrt(mean(diff(IBI).^2))",
    "sdann"          => "std(5-min means of IBI)",
    "pnn50"          => "sum(|diff(IBI)| > 50) / N",
    "pnn20"          => "sum(|diff(IBI)| > 20) / N",
    "cvsd"           => "sdsd / mean(IBI)",
    "rRR"            => "median(euclidean_dist(relRR; mean(relRR)))*100",
    "ulf"            => "integral(PSD; 0; 0.003) Hz",
    "vlf"            => "integral(PSD; 0.003; 0.04) Hz",
    "lf"             => "integral(PSD; 0.04; 0.15) Hz",
    "hf"             => "integral(PSD; 0.15; 0.4) Hz",
    "tp"             => "integral(PSD; 0.003; 0.4) Hz",
    "lf_peak"        => "argmax(PSD; 0.04; 0.15)",
    "hf_peak"        => "argmax(PSD; 0.15; 0.4)",
    "lf_hf_ratio"    => "LF / HF",
    "lf_relative"    => "LF / TP",
    "hf_relative"    => "HF / TP",
    "lf_percentage"  => "100 * LF / TP",
    "hf_percentage"  => "100 * HF / TP",
    "sd1"            => "std((IBI[1:end-1] - IBI[2:end]) / sqrt(2))",
    "sd2"            => "std((IBI[1:end-1] + IBI[2:end]) / sqrt(2))",
    "sd2_sd1"        => "SD2 / SD1",
    "sd1_sd2_area"   => "pi * SD1 * SD2",
    "cvi"            => "log10(SD1 * SD2 * 16)",
    "ccsi"           => "4 * SD2^2 / SD1",
    "triangular_index" => "N / max(histogram_weights)",
    "tinn"           => "M - N  (triangle base width)",
    "apen"           => "log(C_m(r) / C_{m+1}(r))",
    "sampen"         => "log(A / B)  (template matches)",
    "hurst"          => "H from R/S analysis",
    "dfa1"           => "alpha1 from DFA (scales 4-16)",
    "dfa2"           => "alpha2 from DFA (scales 4-64)",
    "renyi0"         => "H_0(IBI)  (Renyi entropy order 0)",
    "renyi1"         => "H_1(IBI)  (Renyi entropy order 1)",
    "renyi2"         => "H_2(IBI)  (Renyi entropy order 2)",
)

# =============================================================================
#  Data loading
# =============================================================================

function load_windowed(dataset::String)::Union{DataFrame, Nothing}
    fname = "windowed_w$(WINDOW_SIZE)_s$(STRIDE)_features.csv"
    path  = joinpath(TESTDATA_ROOT, dataset, fname)
    if !isfile(path)
        @warn "[$dataset] Missing $fname — skipping"
        return nothing
    end
    df = CSV.read(path, DataFrame; silencewarnings=true)
    # Normalise Missing → NaN
    for col in names(df)
        T = nonmissingtype(eltype(df[!, col]))
        if eltype(df[!, col]) >: Missing && T <: Number
            df[!, col] = map(v -> ismissing(v) ? NaN : Float64(v), df[!, col])
        end
    end
    return df
end

# =============================================================================
#  Load & combine normative datasets
# =============================================================================

println("=" ^ 72)
println("  HeartRateLab — Normative Distribution Fitting")
println("  Window: $(WINDOW_SIZE) beats, stride: $(STRIDE) beats")
println("  Datasets: $(join(DATASET_KEYS, ", "))")
println("=" ^ 72)

loaded = Dict{String, DataFrame}()
for key in DATASET_KEYS
    df = load_windowed(key)
    if df !== nothing
        loaded[key] = df
        @info "[$key] loaded $(nrow(df)) windows"
    end
end

if isempty(loaded)
    error("No datasets loaded.  Run collect_normative_datasets.jl first for: $(join(DATASET_KEYS, ", "))")
end

combined_df = vcat(values(loaded)...; cols=:union)
# Normalise after vcat
for col in names(combined_df)
    T = nonmissingtype(eltype(combined_df[!, col]))
    if eltype(combined_df[!, col]) >: Missing && T <: Number
        combined_df[!, col] = map(v -> ismissing(v) ? NaN : Float64(v), combined_df[!, col])
    end
end

n_total = nrow(combined_df)
@info "Combined normative dataset: $n_total windows from $(join(keys(loaded), " + "))"

# =============================================================================
#  Distribution fitting helpers
# =============================================================================

"""
    distribution_family_name(d)

Return the short string name for a Distributions.jl type (e.g., `Normal` → "Normal").
"""
function distribution_family_name(d)::String
    d === nothing && return "none"
    s = string(d)
    parts = split(s, '.')
    return last(parts)
end

"""
    fit_feature_distribution(data::Vector{Float64}, dist_type)

Fit `dist_type` to `data` using MLE, with special handling for edge cases.
Returns `(fitted_dist, success::Bool, msg::String)`.
"""
function fit_feature_distribution(data::Vector{Float64}, dist_type)
    n = length(data)
    n < 10 && return (nothing, false, "too few valid observations ($n)")

    try
        if dist_type === Distributions.Beta
            # Beta requires data strictly in (0,1)
            clamped = clamp.(data, 1e-10, 1.0 - 1e-10)
            d = Distributions.fit(dist_type, clamped)
            return (d, true, "ok")
        elseif dist_type === Distributions.Gamma
            # Gamma requires strictly positive data
            pos = filter(x -> x > 0, data)
            length(pos) < 10 && return (nothing, false, "too few positive observations ($(length(pos)))")
            d = Distributions.fit(dist_type, pos)
            return (d, true, "ok ($(length(data) - length(pos)) non-positive values excluded)")
        elseif dist_type === Distributions.LogNormal
            # LogNormal requires strictly positive data
            pos = filter(x -> x > 0, data)
            length(pos) < 10 && return (nothing, false, "too few positive observations")
            d = Distributions.fit(dist_type, pos)
            return (d, true, "ok ($(length(data) - length(pos)) non-positive values excluded)")
        elseif dist_type === Distributions.Normal
            d = Distributions.fit(dist_type, data)
            return (d, true, "ok")
        else
            d = Distributions.fit(dist_type, data)
            return (d, true, "ok")
        end
    catch e
        return (nothing, false, "fit failed: $(sprint(showerror, e))")
    end
end

"""
    ks_pvalue(data, dist)

Kolmogorov–Smirnov p-value for `data` against fitted `dist`.
"""
function ks_pvalue(data::Vector{Float64}, dist::Distribution)::Float64
    try
        test = ExactOneSampleKSTest(data[1:min(5000, length(data))], dist)
        return pvalue(test)
    catch
        try
            test = ApproximateOneSampleKSTest(data, dist)
            return pvalue(test)
        catch
            return NaN
        end
    end
end

"""
    extract_params(dist)

Extract parameter names and values from a fitted distribution.
Returns `(param_names::Vector{String}, param_values::Vector{Float64})`.
"""
function extract_params(dist::Distribution)
    if dist isa Distributions.Normal
        return (["μ", "σ"], [dist.μ, dist.σ])
    elseif dist isa Distributions.Gamma
        return (["α", "θ"], [Distributions.shape(dist), Distributions.scale(dist)])
    elseif dist isa Distributions.Beta
        return (["α", "β"], [dist.α, dist.β])
    elseif dist isa Distributions.LogNormal
        return (["μ", "σ"], [dist.μ, dist.σ])
    else
        p = Distributions.params(dist)
        names = ["p$i" for i in 1:length(p)]
        return (names, collect(Float64, p))
    end
end

"""
    make_prior_call(dist, family_name)

Return the Distributions.jl constructor call string: e.g., "Normal(780.0, 143.7)".
"""
function make_prior_call(dist::Distribution, family_name::String)::String
    _, pvals = extract_params(dist)
    params_str = join([@sprintf("%.6g", v) for v in pvals], ", ")
    return "$(family_name)($(params_str))"
end

# =============================================================================
#  Main fitting loop
# =============================================================================

results = []

# Get all scalar features from the registry (sorted alphabetically)
feature_names = sort(collect(keys(feature_registry)))
available_cols = names(combined_df)

println("\nFitting distributions for $(length(feature_names)) registered features...")
println("-" ^ 90)
@printf("  %-20s  %-12s  %-35s  %-10s  %s\n", "Feature", "Family", "Prior Call", "KS p-val", "Status")
println("-" ^ 90)

for fname in feature_names
    feat = feature_registry[fname]
    dist_type = feat.distribution
    family_name = distribution_family_name(dist_type)
    definition = get(FEATURE_DEFINITIONS, fname, "")
    equation   = get(FEATURE_EQUATIONS, fname, "")

    # Skip features not present in the CSV
    if fname ∉ available_cols
        push!(results, (
            feature      = fname,
            definition   = definition,
            equation     = equation,
            family       = family_name,
            prior_call   = "",
            param1_name  = "", param1_value = NaN,
            param2_name  = "", param2_value = NaN,
            n_valid      = 0,
            n_total      = n_total,
            ks_pvalue    = NaN,
            datasets     = join(DATASET_KEYS, "+"),
            window_size  = WINDOW_SIZE,
            stride       = STRIDE,
            status       = "not in CSV",
        ))
        @printf("  %-20s  %-12s  %-35s  %-10s  %s\n", fname, family_name, "—", "—", "not in CSV")
        continue
    end

    # Skip features without an assigned distribution
    if dist_type === nothing
        push!(results, (
            feature      = fname,
            definition   = definition,
            equation     = equation,
            family       = "none",
            prior_call   = "",
            param1_name  = "", param1_value = NaN,
            param2_name  = "", param2_value = NaN,
            n_valid      = 0,
            n_total      = n_total,
            ks_pvalue    = NaN,
            datasets     = join(DATASET_KEYS, "+"),
            window_size  = WINDOW_SIZE,
            stride       = STRIDE,
            status       = "no distribution assigned",
        ))
        @printf("  %-20s  %-12s  %-35s  %-10s  %s\n", fname, "none", "—", "—", "no dist")
        continue
    end

    # Extract and clean data
    raw = combined_df[!, fname]
    data = filter(x -> !isnan(x) && isfinite(x), Float64.(raw))

    # Fit the distribution
    fitted_dist, success, msg = fit_feature_distribution(data, dist_type)

    if !success
        push!(results, (
            feature      = fname,
            definition   = definition,
            equation     = equation,
            family       = family_name,
            prior_call   = "",
            param1_name  = "", param1_value = NaN,
            param2_name  = "", param2_value = NaN,
            n_valid      = length(data),
            n_total      = n_total,
            ks_pvalue    = NaN,
            datasets     = join(DATASET_KEYS, "+"),
            window_size  = WINDOW_SIZE,
            stride       = STRIDE,
            status       = msg,
        ))
        @printf("  %-20s  %-12s  %-35s  %-10s  %s\n", fname, family_name, msg, "—", "FAIL")
        continue
    end

    # Extract parameters
    pnames, pvals = extract_params(fitted_dist)

    # Build the Distributions.jl constructor call string
    call_str = make_prior_call(fitted_dist, family_name)

    # Goodness-of-fit (KS test)
    p_ks = ks_pvalue(data, fitted_dist)
    p_ks_str = isnan(p_ks) ? "NaN" : @sprintf("%.4g", p_ks)

    push!(results, (
        feature      = fname,
        definition   = definition,
        equation     = equation,
        family       = family_name,
        prior_call   = call_str,
        param1_name  = length(pnames) >= 1 ? pnames[1] : "",
        param1_value = length(pvals) >= 1 ? pvals[1] : NaN,
        param2_name  = length(pnames) >= 2 ? pnames[2] : "",
        param2_value = length(pvals) >= 2 ? pvals[2] : NaN,
        n_valid      = length(data),
        n_total      = n_total,
        ks_pvalue    = p_ks,
        datasets     = join(DATASET_KEYS, "+"),
        window_size  = WINDOW_SIZE,
        stride       = STRIDE,
        status       = "ok",
    ))

    @printf("  %-20s  %-12s  %-35s  %-10s  %s\n", fname, family_name, call_str, p_ks_str, "ok")
end

println("-" ^ 90)

# =============================================================================
#  Save results
# =============================================================================

results_df = DataFrame(results)

# ── CSV output (docs/normative_priors.csv) ────────────────────────────────────
mkpath(dirname(OUTPUT_CSV))
CSV.write(OUTPUT_CSV, results_df)
@info "Normative priors CSV saved to: $OUTPUT_CSV"

# ── TOML output ───────────────────────────────────────────────────────────────
open(OUTPUT_TOML, "w") do io
    println(io, "# HeartRateLab — Normative Distribution Parameters (Scientific Priors)")
    println(io, "# Generated: $(Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS"))")
    println(io, "# Datasets: $(join(DATASET_KEYS, ", "))")
    println(io, "# Window: $(WINDOW_SIZE) beats, stride: $(STRIDE) beats")
    println(io, "# Total windows: $n_total")
    println(io, "# Method: MLE via Distributions.fit()")
    println(io, "#")
    println(io, "# Each [features.X] section contains fitted parameters that can be used")
    println(io, "# to construct a Distributions.jl instance: e.g., Normal(μ, σ) or Gamma(α, θ)")
    println(io, "")
    println(io, "[metadata]")
    println(io, "datasets = [$(join(["\"$k\"" for k in DATASET_KEYS], ", "))]")
    println(io, "window_size = $WINDOW_SIZE")
    println(io, "stride = $STRIDE")
    println(io, "n_windows = $n_total")
    println(io, "generated = \"$(Dates.format(Dates.now(), "yyyy-mm-dd"))\"")
    println(io, "")

    for r in eachrow(results_df)
        r.status != "ok" && continue
        println(io, "[features.$(r.feature)]")
        println(io, "family = \"$(r.family)\"")
        println(io, "prior_call = \"$(r.prior_call)\"")
        !isempty(r.definition) && println(io, "definition = \"$(r.definition)\"")
        !isempty(r.equation) && println(io, "equation = \"$(r.equation)\"")
        if !isempty(r.param1_name) && !isnan(r.param1_value)
            println(io, "$(r.param1_name) = $(r.param1_value)")
        end
        if !isempty(r.param2_name) && !isnan(r.param2_value)
            println(io, "$(r.param2_name) = $(r.param2_value)")
        end
        println(io, "n_valid = $(r.n_valid)")
        if !isnan(r.ks_pvalue)
            println(io, "ks_pvalue = $(r.ks_pvalue)")
        end
        println(io, "")
    end
end
@info "TOML parameter file saved to: $OUTPUT_TOML"

# =============================================================================
#  Summary
# =============================================================================

n_ok = count(r -> r.status == "ok", eachrow(results_df))
n_fail = count(r -> r.status != "ok" && r.status != "not in CSV" && r.status != "no distribution assigned", eachrow(results_df))
n_skip = count(r -> r.status == "not in CSV" || r.status == "no distribution assigned", eachrow(results_df))

println("\n" * "=" ^ 72)
println("  Summary")
println("=" ^ 72)
println("  Features fitted:  $n_ok / $(length(feature_names))")
println("  Fit failures:     $n_fail")
println("  Skipped:          $n_skip")
println("  Output CSV:       $OUTPUT_CSV")
println("  Output TOML:      $OUTPUT_TOML")

# Print distribution family breakdown
families = Dict{String,Int}()
for r in eachrow(results_df)
    r.status != "ok" && continue
    families[r.family] = get(families, r.family, 0) + 1
end
println("\n  Distribution families used:")
for (fam, count) in sort(collect(families))
    println("    $fam: $count features")
end

# KS test summary
ok_rows = filter(r -> r.status == "ok" && !isnan(r.ks_pvalue), results_df)
if nrow(ok_rows) > 0
    n_good_fit = count(r -> r.ks_pvalue > 0.05, eachrow(ok_rows))
    n_poor_fit = count(r -> r.ks_pvalue <= 0.05, eachrow(ok_rows))
    println("\n  KS goodness-of-fit (α = 0.05):")
    println("    Good fit (p > 0.05):  $n_good_fit")
    println("    Poor fit (p ≤ 0.05):  $n_poor_fit")
    if n_poor_fit > 0
        println("    Poor-fit features:")
        for r in eachrow(ok_rows)
            r.ks_pvalue <= 0.05 || continue
            @printf("      %-20s  %-12s  %-30s  p = %.4g\n", r.feature, r.family, r.prior_call, r.ks_pvalue)
        end
    end
end

# Display the full prior table
println("\n" * "=" ^ 72)
println("  Normative Prior Table (Distributions.jl constructor calls)")
println("=" ^ 72)
@printf("  %-20s  %-12s  %s\n", "Feature", "Family", "Prior Call")
println("-" ^ 72)
for r in eachrow(results_df)
    r.status != "ok" && continue
    @printf("  %-20s  %-12s  %s\n", r.feature, r.family, r.prior_call)
end

println("\n" * "=" ^ 72)
println("  Done.")
println("  The CSV at $(OUTPUT_CSV) is auto-loaded by HeartRateLab.Features")
println("  at module init.  Access priors via:")
println("    using HeartRateLab")
println("    normative_prior(\"rmssd\")  # => Gamma(α, θ)")
println("    prior_call_string(\"rmssd\") # => \"Gamma(1.23, 26.7)\"")
println("=" ^ 72)
