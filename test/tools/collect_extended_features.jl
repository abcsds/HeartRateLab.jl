#!/usr/bin/env julia
# =============================================================================
# collect_extended_features.jl
#
# Computes normative windowed distributions for the 17 HRV features that were
# NOT included in the original windowed_w360_s120_features.csv tables:
#
#   cheap (all NSR2DB windows) : median_hr, range_hr, cvnni
#   ulf   (NSRDB long records) : ulf   — needs long recordings; windowed w2048/s1024
#   nonlinear (subsampled)     : apen, sampen, hurst, renyi0, renyi1, renyi2,
#                                shan_en, svd_en, fuzzyen, spec_en, perm_en,
#                                mse, dfa2   (O(N^2); random subsample)
#
# Windowing matches the existing normative tables: 360-beat windows, 120 stride.
# Nonlinear features are O(N^2) so a fixed-seed random subsample of windows is
# taken (documented n + seed) — enough to characterise the distribution SHAPE.
#
# Run in the WFDB-equipped container (headless; no display needed):
#   docker run --rm -v "$(pwd):/workdir" -w /workdir localhost/hrlab:latest \
#       "julia --project=. test/tools/collect_extended_features.jl"
#
# Outputs (does NOT overwrite any committed CSV):
#   test/testdata/nsr2db/windowed_w360_s120_features_extended.csv
#   docs/normative_priors_extended.csv
# =============================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using HeartRateLab
using HeartRateLab: extract_feature_set, read_wfdb
using HeartRateLab: replace_zeros, replace_bio_outliers, interpolate_nans
using Memoization
using DataFrames, CSV, Random, Statistics, Distributions, HypothesisTests, Printf

const REPO      = abspath(joinpath(@__DIR__, "..", ".."))
const TESTDATA  = joinpath(REPO, "test", "testdata")

# ─── Config ───────────────────────────────────────────────────────────────────
const SEED         = 20260729
const N_SUB        = 3000          # subsampled NSR2DB windows for nonlinear features
const WIN          = 360           # beats per window (matches existing tables)
const STRIDE       = 120           # window stride (matches existing tables)
const ULF_WIN      = 27000         # long window for ULF (~5.5-7h @ 700-950ms mean IBI)
const ULF_STRIDE   = 6750          # 75% overlap -> several windows per 18-24h record
# NB (2026-07): the true 0-0.003 Hz ULF band (Features.jl `ulf`, fixed to
# get_power(pgram, 0.0, 0.003)) needs Welch frequency resolution fs/nfft well
# below 0.003 Hz to resolve more than the single DC bin. With fs=4Hz and
# segment=N/8, that requires N well past 2048 beats (the old window resolved
# ONLY the freq=0 bin -> a degenerate all-zero "distribution"). 27000-beat
# windows (segment ≈ N/8 samples at fs=4) push the resolution to ~3e-4 Hz,
# giving ~8-9 bins inside the ULF band per window.

const CHEAP  = ["median_hr", "range_hr", "cvnni"]
const NONLIN = ["apen", "sampen", "hurst", "renyi0", "renyi1", "renyi2",
                "shan_en", "svd_en", "fuzzyen", "spec_en", "perm_en", "mse", "dfa2"]
const ULFSET = ["ulf"]

# Declared distribution families (from docs/zoo_gen/inventory.jl)
const FAMILY = Dict(
    "median_hr" => "Normal", "range_hr" => "Gamma", "cvnni" => "Normal", "ulf" => "Gamma",
    "apen" => "Normal", "sampen" => "Normal", "hurst" => "Beta",
    "renyi0" => "Normal", "renyi1" => "Normal", "renyi2" => "Normal",
    "shan_en" => "Normal", "svd_en" => "Normal", "fuzzyen" => "Normal",
    "spec_en" => "Normal", "perm_en" => "Normal", "mse" => "Normal", "dfa2" => "Normal",
)

const NSR2DB_RECORDS = ["nsr001","nsr002","nsr003","nsr004","nsr005","nsr006","nsr007",
    "nsr008","nsr009","nsr010","nsr011","nsr012","nsr013","nsr014","nsr015","nsr016",
    "nsr017","nsr018","nsr019","nsr020","nsr021","nsr022","nsr023","nsr024","nsr025",
    "nsr026","nsr027","nsr028","nsr029","nsr030","nsr031","nsr032","nsr033","nsr034",
    "nsr035","nsr036","nsr037","nsr038","nsr039","nsr040","nsr041","nsr042","nsr043",
    "nsr044","nsr045","nsr046","nsr047","nsr048","nsr049","nsr050","nsr051","nsr052",
    "nsr053","nsr054"]

const NSRDB_RECORDS = ["16265","16272","16273","16420","16483","16539","16773","16786",
    "16795","17052","17453","18177","18184","19088","19090","19093","19140","19830"]

# ─── IBI loading (mirrors collect_normative_datasets.jl load_record) ───────────
function load_ibis(dir::String, record::String, annotator::String)
    prev = pwd()
    cd(dir)
    local ibis
    try
        ibis = read_wfdb(record, annotator)
    finally
        cd(prev)
    end
    ibis = replace_zeros(Float64.(ibis))
    ibis = replace_bio_outliers(ibis)
    ibis = interpolate_nans(ibis)
    ibis = clamp.(ibis, 200.0, 3000.0)
    return ibis
end

# window k (1-indexed) beats, matching preprocessing.windowed(:beats)
windows_of(ibis, wsize, stride) =
    [(k, ibis[(1 + (k-1)*stride):((k-1)*stride + wsize)])
     for k in 1:length(1:stride:(length(ibis) - wsize + 1))]

# ─── Pass A: NSR2DB cheap features (all windows) + collect window refs ─────────
println("═"^70)
println("Pass A — NSR2DB cheap features + window enumeration")
cheap_rows = NamedTuple[]
allwins    = Tuple{String,Int,Vector{Float64}}[]   # (participant, window_id, ibis)
nsr2db_dir = joinpath(TESTDATA, "nsr2db", "_downloads")
for rec in NSR2DB_RECORDS
    ibis = try
        load_ibis(nsr2db_dir, rec, "ecg")
    catch e
        @warn "  skip $rec: $e"; continue
    end
    length(ibis) < WIN && continue
    ws = windows_of(ibis, WIN, STRIDE)
    for (wid, w) in ws
        cf = extract_feature_set(w; features=CHEAP)
        push!(cheap_rows, (dataset="nsr2db", participant_id=rec, window_id=wid,
                           median_hr=cf[1,"median_hr"], range_hr=cf[1,"range_hr"],
                           cvnni=cf[1,"cvnni"]))
        push!(allwins, (rec, wid, w))
    end
    Memoization.empty_all_caches!(); GC.gc()
    @printf("  %s: %d windows (running total %d)\n", rec, length(ws), length(allwins))
end
println("  NSR2DB total windows: ", length(allwins))

# ─── Pass B: nonlinear features on a fixed-seed subsample ──────────────────────
println("═"^70)
println("Pass B — nonlinear features on subsample (n=$N_SUB, seed=$SEED)")
Random.seed!(SEED)
nsub = min(N_SUB, length(allwins))
idx  = sort(randperm(length(allwins))[1:nsub])
nonlin_rows = NamedTuple[]
t0 = time()
for (j, i) in enumerate(idx)
    rec, wid, w = allwins[i]
    nf = extract_feature_set(w; features=NONLIN)
    push!(nonlin_rows, (dataset="nsr2db", participant_id=rec, window_id=wid,
        (Symbol(f) => nf[1, f] for f in NONLIN)...))
    Memoization.empty_all_caches!()
    if j % 250 == 0
        el = time() - t0
        @printf("  %d/%d  (%.1fs, ETA %.0fs)\n", j, nsub, el, el/j*(nsub-j))
    end
end
GC.gc()
println("  nonlinear windows computed: ", length(nonlin_rows))

# ─── Pass C: ULF over NSRDB long records (long window to resolve 0.003 Hz) ─────
println("═"^70)
println("Pass C — ULF over NSRDB (window=$ULF_WIN, stride=$ULF_STRIDE beats)")
ulf_rows = NamedTuple[]
nsrdb_dir = joinpath(TESTDATA, "nsrdb", "_downloads")
for rec in NSRDB_RECORDS
    ibis = try
        load_ibis(nsrdb_dir, rec, "atr")
    catch e
        @warn "  skip $rec: $e"; continue
    end
    length(ibis) < ULF_WIN && continue
    ws = windows_of(ibis, ULF_WIN, ULF_STRIDE)
    for (wid, w) in ws
        uf = extract_feature_set(w; features=ULFSET)
        push!(ulf_rows, (dataset="nsrdb", participant_id=rec, window_id=wid,
                         ulf=uf[1, "ulf"]))
    end
    Memoization.empty_all_caches!(); GC.gc()
    @printf("  %s: %d ULF windows\n", rec, length(ws))
end
println("  ULF windows: ", length(ulf_rows))

# ─── Assemble wide extended CSV (per-column finite counts differ; NaN elsewhere)
println("═"^70)
println("Writing extended CSV")
df_cheap  = DataFrame(cheap_rows)
df_nonlin = DataFrame(nonlin_rows)
df_ulf    = DataFrame(ulf_rows)
wide = vcat(df_cheap, df_nonlin, df_ulf; cols=:union)
for c in names(wide)
    if eltype(wide[!, c]) <: Union{Missing,Real}
        wide[!, c] = coalesce.(wide[!, c], NaN)
    end
end
# order columns
meta = ["dataset","participant_id","window_id"]
featcols = vcat(CHEAP, ULFSET, NONLIN)
select!(wide, vcat(meta, featcols))
out_csv = joinpath(TESTDATA, "nsr2db", "windowed_w360_s120_features_extended.csv")
CSV.write(out_csv, wide)
println("  → ", out_csv, "  (", nrow(wide), " rows, ", ncol(wide), " cols)")

# ─── Fit priors (mirror docs/normative_priors.csv schema) ─────────────────────
println("═"^70)
println("Fitting priors")

clean(v) = filter(isfinite, Float64.(collect(skipmissing(v))))

function fit_one(name, v)
    fam = FAMILY[name]
    n = length(v)
    dist = nothing; p1n=""; p1=NaN; p2n=""; p2=NaN; used=fam
    try
        if fam == "Gamma" && all(>(0), v)
            d = fit_mle(Gamma, v); dist=d; p1n="α"; p1=shape(d); p2n="θ"; p2=scale(d)
        elseif fam == "Beta" && all(x -> 0 < x < 1, v)
            d = fit_mle(Beta, v); dist=d; p1n="α"; p1=d.α; p2n="β"; p2=d.β
        elseif fam == "LogNormal" && all(>(0), v)
            d = fit_mle(LogNormal, v); dist=d; p1n="μ"; p1=d.μ; p2n="σ"; p2=d.σ
        else
            d = fit_mle(Normal, v); dist=d; p1n="μ"; p1=d.μ; p2n="σ"; p2=d.σ; used="Normal"
        end
    catch e
        d = fit_mle(Normal, v); dist=d; p1n="μ"; p1=d.μ; p2n="σ"; p2=d.σ; used="Normal"
    end
    ksp = try
        pvalue(ExactOneSampleKSTest(v, dist))
    catch
        NaN
    end
    call = used == "Gamma"     ? @sprintf("Gamma(%.6g, %.6g)", p1, p2) :
           used == "Beta"      ? @sprintf("Beta(%.6g, %.6g)", p1, p2) :
           used == "LogNormal" ? @sprintf("LogNormal(%.6g, %.6g)", p1, p2) :
                                 @sprintf("Normal(%.6g, %.6g)", p1, p2)
    return (family=used, prior_call=call, p1n=p1n, p1=p1, p2n=p2n, p2=p2, ksp=ksp, n=n)
end

DEFN = Dict(
    "median_hr"=>"Median heart rate (BPM)", "range_hr"=>"Range of instantaneous heart rate (BPM)",
    "cvnni"=>"Coefficient of variation of NN intervals (SDNN/mean)",
    "ulf"=>"Ultra-low frequency power (0-0.003 Hz)",
    "apen"=>"Approximate entropy", "sampen"=>"Sample entropy", "hurst"=>"Hurst exponent (R/S)",
    "renyi0"=>"Rényi entropy order 0", "renyi1"=>"Rényi entropy order 1", "renyi2"=>"Rényi entropy order 2",
    "shan_en"=>"Shannon entropy", "svd_en"=>"SVD entropy", "fuzzyen"=>"Fuzzy entropy",
    "spec_en"=>"Spectral entropy", "perm_en"=>"Permutation entropy",
    "mse"=>"Multiscale entropy complexity index", "dfa2"=>"DFA long-term exponent α2",
)

prior_rows = NamedTuple[]
for f in vcat(CHEAP, ULFSET, NONLIN)
    v = clean(wide[!, f])
    isempty(v) && (println("  ! no data for $f"); continue)
    r = fit_one(f, v)
    ds = f == "ulf" ? "nsrdb" : "nsr2db"
    wsz = f == "ulf" ? ULF_WIN : WIN
    st  = f == "ulf" ? ULF_STRIDE : STRIDE
    push!(prior_rows, (feature=f, definition=DEFN[f], equation="", family=r.family,
        prior_call=r.prior_call, param1_name=r.p1n, param1_value=r.p1,
        param2_name=r.p2n, param2_value=r.p2, n_valid=r.n, n_total=r.n,
        ks_pvalue=r.ksp, datasets=ds, window_size=wsz, stride=st, status="ok"))
    @printf("  %-10s %-9s n=%-6d %s  KSp=%.2g\n", f, r.family, r.n, r.prior_call, r.ksp)
end
prior_csv = joinpath(REPO, "docs", "normative_priors_extended.csv")
CSV.write(prior_csv, DataFrame(prior_rows))
println("  → ", prior_csv, "  (", length(prior_rows), " priors)")
println("═"^70)
println("DONE. seed=$SEED  nonlinear_subsample_n=$nsub")
