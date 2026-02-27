#!/usr/bin/env julia
# =============================================================================
# collect_normative_datasets.jl
#
# Downloads registered PhysioNet datasets, extracts HRV features at both
# participant level (full recording) and windowed level, then stores results
# under test/testdata/<dataset>/ for normative reference.
#
# Usage (from project root, with WFDB tools on PATH):
#
#   julia --project=. test/tools/collect_normative_datasets.jl
#
# Options (env vars):
#   DATASETS=nsrdb,mitbih,...   Comma-separated dataset names (default: all)
#   WINDOW_SIZE=60              Beats per window (default: 60)
#   STRIDE=30                   Window stride in beats (default: 30)
#   OUTPUT_DIR=test/testdata    Output root (default: test/testdata)
#   SKIP_EXISTING=true          Skip already-processed records (default: true)
#   DRY_RUN=false               Print plan without downloading (default: false)
#
# Output structure (per dataset):
#
#   test/testdata/<dataset>/
#     metadata.toml                    ← dataset registry info + collection run info
#     participant_features.csv         ← one row per participant, all features
#     windowed_w<W>_s<S>_features.csv  ← windowed features with participant/window columns
#
# The windowed CSV includes metadata columns:
#   dataset, participant_id, window_id, window_start_beat, window_end_beat,
#   window_size, stride, collection_date, heartrateLab_version
#
# Adding new datasets: extend the DATASET_REGISTRY constant below.
# =============================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using HeartRateLab
using HeartRateLab: extract_feature_set, windowed_feature_set, valid_features
using HeartRateLab: FAST_FEATURES, ALL_FEATURES, NONLINEAR_FEATURES
using HeartRateLab: replace_zeros, replace_bio_outliers, interpolate_nans
using HeartRateLab: read_wfdb, read_txt

using Memoization          # for empty_all_caches!()
using Downloads
using DataFrames
using CSV
using TOML
using Dates
using Statistics
using SHA                  # for file integrity checking

# ─── Version helper ───────────────────────────────────────────────────────────

"""Return the package version string, falling back to Project.toml."""
function _pkg_version()::String
    try
        v = pkgversion(HeartRateLab)
        return string(v)
    catch
        proj = joinpath(@__DIR__, "..", "..", "Project.toml")
        isfile(proj) || return "unknown"
        d = TOML.parsefile(proj)
        return get(d, "version", "unknown")
    end
end

const PKG_VERSION = _pkg_version()

# ─── Configuration ────────────────────────────────────────────────────────────

const WINDOW_SIZE   = parse(Int, get(ENV, "WINDOW_SIZE", "60"))
const STRIDE        = parse(Int, get(ENV, "STRIDE",      "30"))
const OUTPUT_DIR    = abspath(get(ENV, "OUTPUT_DIR", joinpath(@__DIR__, "..", "testdata")))
const SKIP_EXISTING = get(ENV, "SKIP_EXISTING", "true") == "true"
const DRY_RUN       = get(ENV, "DRY_RUN", "false") == "true"
const SELECTED_DS   = let s = get(ENV, "DATASETS", "")
    isempty(s) ? nothing : Set(split(s, ","))
end

# Maximum IBI length for participant-level feature extraction.
# Long recordings (e.g. 99K beats) cause OOM on entropy/DFA features that are O(n²).
# Subsample to this many beats for the participant-level row; windowed analysis uses
# the full recording since each window is only WINDOW_SIZE beats.
const MAX_PARTICIPANT_BEATS = parse(Int, get(ENV, "MAX_PARTICIPANT_BEATS", "5000"))

# ─── Dataset Registry ─────────────────────────────────────────────────────────
#
# Each entry is a NamedTuple with:
#   name          : folder name under test/testdata/
#   description   : human-readable summary
#   physionet_url : landing page URL
#   files_url     : base URL for downloading individual records
#   version       : dataset version string
#   format        : :wfdb (needs .hea/.dat/.atr + ann2rr) or :txt (plain text RR file)
#   annotator     : WFDB annotator name (for :wfdb format)
#   txt_extension : file extension for :txt format records (e.g. ".txt")
#   population    : "healthy" | "mixed" | "arrhythmia" | "meditation" | ...
#   license       : short license string
#   records       : Vector{String} of record IDs to collect

const DATASET_REGISTRY = [

    # ── Normal Sinus Rhythm Database ───────────────────────────────────────
    (
        name          = "nsrdb",
        description   = "Normal Sinus Rhythm Database — 24-hour ECGs from healthy adults",
        physionet_url = "https://physionet.org/content/nsrdb/",
        files_url     = "https://physionet.org/files/nsrdb/1.0.0",
        version       = "1.0.0",
        format        = :wfdb,
        annotator     = "atr",
        txt_extension = "",
        population    = "healthy",
        license       = "Open Data Commons Attribution License v1.0",
        records       = ["16265", "16272", "16273", "16420", "16483", "16539",
                         "16773", "16786", "16795", "17052", "17453", "18177",
                         "18184", "19088", "19090", "19093", "19140", "19830"],
    ),

    # ── MIT-BIH Arrhythmia Database ────────────────────────────────────────
    (
        name          = "mitbih",
        description   = "MIT-BIH Arrhythmia Database — 48 half-hour ECGs with annotated arrhythmias",
        physionet_url = "https://physionet.org/content/mitdb/",
        files_url     = "https://physionet.org/files/mitdb/1.0.0",
        version       = "1.0.0",
        format        = :wfdb,
        annotator     = "atr",
        txt_extension = "",
        population    = "mixed",
        license       = "Open Data Commons Attribution License v1.0",
        records       = ["100", "101", "102", "103", "104", "105", "106", "107",
                         "108", "109", "111", "112", "113", "114", "115", "116",
                         "117", "118", "119", "121", "122", "123", "124",
                         "200", "201", "202", "203", "205", "207", "208", "209",
                         "210", "212", "213", "214", "215", "217", "219", "220",
                         "221", "222", "223", "228", "230", "231", "232", "233", "234"],
    ),

    # ── Normal Sinus Rhythm RR Interval Database ───────────────────────────
    (
        name          = "nsr2db",
        description   = "Normal Sinus Rhythm RR Interval Database — RR intervals from healthy subjects",
        physionet_url = "https://physionet.org/content/nsr2db/",
        files_url     = "https://physionet.org/files/nsr2db/1.0.0",
        version       = "1.0.0",
        format        = :txt,
        annotator     = "",
        txt_extension = ".txt",
        population    = "healthy",
        license       = "Open Data Commons Attribution License v1.0",
        records       = ["nsr001", "nsr002", "nsr003", "nsr004", "nsr005",
                         "nsr006", "nsr007", "nsr008", "nsr009", "nsr010",
                         "nsr011", "nsr012", "nsr013", "nsr014", "nsr015",
                         "nsr016", "nsr017", "nsr018", "nsr019", "nsr020",
                         "nsr021", "nsr022", "nsr023", "nsr024", "nsr025",
                         "nsr026", "nsr027", "nsr028", "nsr029", "nsr030",
                         "nsr031", "nsr032", "nsr033", "nsr034", "nsr035",
                         "nsr036", "nsr037", "nsr038", "nsr039", "nsr040",
                         "nsr041", "nsr042", "nsr043", "nsr044", "nsr045",
                         "nsr046", "nsr047", "nsr048", "nsr049", "nsr050",
                         "nsr051", "nsr052"],
    ),

    # ── Heart Rate Oscillations during Meditation ──────────────────────────
    (
        name          = "meditation",
        description   = "Heart Rate Oscillations during Meditation — ECG during meditation vs rest",
        physionet_url = "https://physionet.org/content/meditation/",
        files_url     = "https://physionet.org/files/meditation/1.0.0",
        version       = "1.0.0",
        format        = :wfdb,
        annotator     = "atr",
        txt_extension = "",
        population    = "healthy",
        license       = "Open Data Commons Attribution License v1.0",
        # Records: med1–med8, rest1–rest8
        records       = ["med1", "med2", "med3", "med4", "med5", "med6", "med7", "med8",
                         "rest1", "rest2", "rest3", "rest4", "rest5", "rest6", "rest7", "rest8"],
    ),

    # ── RR Interval Time Series Modeling Challenge 2002 ───────────────────
    (
        name          = "challenge2002",
        description   = "PhysioNet Challenge 2002 — RR interval modeling benchmark",
        physionet_url = "https://physionet.org/content/challenge-2002/",
        files_url     = "https://physionet.org/files/challenge-2002/1.0.0",
        version       = "1.0.0",
        format        = :txt,
        annotator     = "",
        txt_extension = ".txt",
        population    = "mixed",
        license       = "Open Data Commons Attribution License v1.0",
        # Events: learning set records e0100..e0161 (even numbers), test set t0100..
        records       = ["e0100", "e0102", "e0104", "e0106", "e0108",
                         "e0110", "e0112", "e0114", "e0116", "e0118",
                         "e0120", "e0122", "e0124", "e0126", "e0128",
                         "e0130", "e0132", "e0134", "e0136", "e0138"],
    ),

    # ── Is the Normal Heart Rate Chaotic? ──────────────────────────────────
    (
        name          = "chaos",
        description   = "Is the Normal Heart Rate Chaotic? — Long RR timeseries from healthy subjects",
        physionet_url = "https://physionet.org/content/chaos-heart-rate/",
        files_url     = "https://physionet.org/files/chaos-heart-rate/1.0.0",
        version       = "1.0.0",
        format        = :txt,
        annotator     = "",
        txt_extension = ".txt",
        population    = "healthy",
        license       = "Open Data Commons Attribution License v1.0",
        records       = ["rr01", "rr02", "rr03", "rr04", "rr05", "rr06",
                         "rr07", "rr08", "rr09", "rr10"],
    ),

    # ── Spontaneous Ventricular Tachyarrhythmia Database ──────────────────
    (
        name          = "mvtdb",
        description   = "Spontaneous Ventricular Tachyarrhythmia Database — ECG with ventricular arrhythmias",
        physionet_url = "https://physionet.org/content/mvtdb/",
        files_url     = "https://physionet.org/files/mvtdb/1.0",
        version       = "1.0",
        format        = :wfdb,
        annotator     = "atr",
        txt_extension = "",
        population    = "arrhythmia",
        license       = "Open Data Commons Attribution License v1.0",
        records       = ["v301l", "v302l", "v303l", "v304l", "v305l",
                         "v306l", "v307l", "v308l", "v309l", "v310l"],
    ),

]

# ─── SHA Integrity Helpers ─────────────────────────────────────────────────────

const SHA_MANIFEST_FILE = "sha256_manifest.toml"

"""Compute SHA-256 hex digest of a file."""
function sha256_file(path::String)::String
    return open(path, "r") do io
        bytes2hex(sha256(io))
    end
end

"""
Load the SHA manifest (TOML) for a dataset directory.
Returns a Dict{String,String} mapping relative filenames to their SHA-256 hex digests.
"""
function load_sha_manifest(dir::String)::Dict{String,String}
    manifest_path = joinpath(dir, SHA_MANIFEST_FILE)
    if isfile(manifest_path)
        raw = TOML.parsefile(manifest_path)
        hashes = get(raw, "hashes", Dict{String,Any}())
        return Dict{String,String}(string(k) => string(v) for (k, v) in hashes)
    else
        return Dict{String,String}()
    end
end

"""Save the SHA manifest (TOML) for a dataset directory."""
function save_sha_manifest(dir::String, manifest::Dict{String,String})
    data = Dict("hashes" => manifest,
                "_meta"  => Dict("description" => "SHA-256 hashes of downloaded files",
                                 "updated"     => string(now())))
    open(joinpath(dir, SHA_MANIFEST_FILE), "w") do io
        TOML.print(io, data)
    end
end

"""
Check if a local file matches the stored SHA. Returns:
  :match    — file exists and SHA matches manifest
  :mismatch — file exists but SHA does NOT match (corrupted / changed)
  :missing  — file does not exist on disk
"""
function file_integrity(path::String, manifest::Dict{String,String})::Symbol
    fname = basename(path)
    if !isfile(path)
        return :missing
    end
    expected = get(manifest, fname, nothing)
    if isnothing(expected)
        # File exists but not in manifest — treat as needing verification
        return :missing
    end
    actual = sha256_file(path)
    return actual == expected ? :match : :mismatch
end

"""
Download a single file from `url` to `dest`, compute its SHA-256, and record
it in `manifest` under `basename(dest)`.  Returns true on success.
If the file already exists and matches the manifest hash, skip download.
"""
function download_with_sha!(url::String, dest::String,
                            manifest::Dict{String,String})::Bool
    status = file_integrity(dest, manifest)
    if status == :match
        return true          # already verified
    elseif status == :mismatch
        @warn "  ⟳ SHA mismatch for $(basename(dest)) — re-downloading"
        rm(dest; force=true)
    end
    # :missing or :mismatch — download
    try
        Downloads.download(url, dest)
        manifest[basename(dest)] = sha256_file(dest)
        return true
    catch e
        # Clean up any partial / error-page file left by the failed download
        rm(dest; force=true)
        @warn "  ✗ Download failed: $url  ($e)"
        return false
    end
end

# ─── Helpers ──────────────────────────────────────────────────────────────────

"""Progress bar helper — returns a formatted string ETA line."""
function progress_line(done::Int, total::Int, elapsed_s::Float64, label::String)
    pct = done / total * 100
    eta_s = done > 0 ? elapsed_s / done * (total - done) : NaN
    bar_width = 30
    filled = round(Int, bar_width * done / total)
    bar = "█"^filled * "░"^(bar_width - filled)
    eta_str = isnan(eta_s) ? "  --:--" : "  ETA $(lpad(round(Int, eta_s ÷ 60), 2, '0')):$(lpad(round(Int, eta_s % 60), 2, '0'))"
    return "  [$bar] $(lpad(done, ndigits(total)))/$(total) ($(round(pct; digits=1))%)$eta_str  $label"
end

"""
Download a single WFDB record (.hea, .dat, annotator) into dest_dir.
Uses the SHA manifest to skip files whose hashes already match.
Returns the local record path (no extension) on success, nothing on failure.
"""
function download_wfdb_record(base_url::String, record::String, annotator::String,
                               dest_dir::String,
                               manifest::Dict{String,String})::Union{String, Nothing}
    local_base = joinpath(dest_dir, record)
    for ext in [".hea", ".dat", ".$annotator"]
        url  = joinpath(base_url, record * ext)
        dest = local_base * ext
        if !download_with_sha!(url, dest, manifest)
            return nothing
        end
    end
    return local_base
end

"""
Download a plain-text RR file into dest_dir.
Uses the SHA manifest to skip files whose hashes already match.
Returns the local file path on success, nothing on failure.
"""
function download_txt_record(base_url::String, record::String, ext::String,
                              dest_dir::String,
                              manifest::Dict{String,String})::Union{String, Nothing}
    url  = joinpath(base_url, record * ext)
    dest = joinpath(dest_dir, record * ext)
    if !download_with_sha!(url, dest, manifest)
        return nothing
    end
    return dest
end

"""
Load IBIs from a downloaded record. Returns Vector{Float64} in milliseconds.
Applies standard preprocessing: replace_zeros → replace_bio_outliers → interpolate_nans.
"""
function load_record(ds, record::String, local_path::String)::Union{Vector{Float64}, Nothing}
    try
        ibis = if ds.format == :wfdb
            # ann2rr does not support absolute paths in this WFDB build —
            # mirror what the tests do: cd to the record directory and pass basename.
            dl_dir   = dirname(abspath(local_path))
            rec_base = basename(abspath(local_path))
            prev_dir = pwd()
            cd(dl_dir)
            local result
            try
                result = read_wfdb(rec_base, ds.annotator)
            finally
                cd(prev_dir)
            end
            result
        else
            read_txt(abspath(local_path))
        end

        # Standard preprocessing
        ibis = replace_zeros(Float64.(ibis))
        ibis = replace_bio_outliers(ibis)
        ibis = interpolate_nans(ibis)

        # Sanity check
        if length(ibis) < WINDOW_SIZE
            @warn "  ⚠ Record $record has only $(length(ibis)) beats (< window_size=$WINDOW_SIZE), skipping"
            return nothing
        end

        # Clamp to physiological range [200, 3000] ms
        ibis = clamp.(ibis, 200.0, 3000.0)

        return ibis
    catch e
        @warn "  ✗ Could not load record $record: $e"
        return nothing
    end
end

"""
Extract all participant-level features from an IBI vector.
Returns a Dict{String,Any} suitable for a DataFrame row.
"""
function participant_features(ibis::Vector{Float64}, participant_id::String,
                               dataset_name::String, n_beats_original::Int)::Dict{String,Any}
    row = Dict{String,Any}(
        "participant_id"  => participant_id,
        "dataset"         => dataset_name,
        "n_beats"         => n_beats_original,
        "recording_ok"    => true,
    )
    try
        # Subsample long recordings to avoid OOM on O(n²) features (entropy, DFA)
        ibis_sub = if length(ibis) > MAX_PARTICIPANT_BEATS
            # Take evenly-spaced subsample preserving temporal structure
            step = length(ibis) ÷ MAX_PARTICIPANT_BEATS
            ibis[1:step:end][1:min(MAX_PARTICIPANT_BEATS, length(1:step:length(ibis)))]
        else
            ibis
        end
        row["n_beats_used"] = length(ibis_sub)
        feats = extract_feature_set(ibis_sub)
        for col in names(feats)
            row[col] = feats[1, col]
        end
    catch e
        @warn "    Feature extraction failed for $participant_id: $e"
        row["recording_ok"] = false
    end
    return row
end

"""
Extract windowed features. Returns a DataFrame with per-window rows + metadata columns.
"""
function windowed_features(ibis::Vector{Float64}, participant_id::String,
                            dataset_name::String,
                            window_size::Int, stride::Int)::DataFrame

    try
        df = windowed_feature_set(ibis; window_size=window_size, stride=stride,
                                        time=:beats, features=:default)
        if isempty(df)
            return DataFrame()
        end
        n_windows = nrow(df)
        # stride is the step (beats between window starts); overlap = window_size - stride
        overlap = window_size - stride

        # Add metadata columns
        df[!, :participant_id]    .= participant_id
        df[!, :dataset]           .= dataset_name
        df[!, :window_id]          = 1:n_windows
        df[!, :window_start_beat]  = [1 + (i-1)*stride for i in 1:n_windows]
        df[!, :window_end_beat]    = [1 + (i-1)*stride + window_size - 1 for i in 1:n_windows]
        df[!, :window_size]       .= window_size
        df[!, :stride]            .= stride
        df[!, :overlap]           .= overlap
        return df
    catch e
        @warn "    Windowed features failed for $participant_id: $e"
        return DataFrame()
    end
end

"""Write metadata TOML file for a dataset."""
function write_metadata(ds, out_dir::String, window_size::Int, stride::Int,
                        n_collected::Int, n_failed::Int, elapsed_s::Float64)
    meta = Dict(
        "dataset" => Dict(
            "name"          => ds.name,
            "description"   => ds.description,
            "physionet_url" => ds.physionet_url,
            "files_url"     => ds.files_url,
            "version"       => ds.version,
            "format"        => string(ds.format),
            "annotator"     => ds.annotator,
            "population"    => ds.population,
            "license"       => ds.license,
            "all_records"   => ds.records,
        ),
        "collection" => Dict(
            "date"                 => string(now()),
            "heartrateLab_version" => PKG_VERSION,
            "window_size"          => window_size,
            "stride"               => stride,
            "overlap"              => window_size - stride,
            "n_records_attempted"  => length(ds.records),
            "n_records_collected"  => n_collected,
            "n_records_failed"     => n_failed,
            "elapsed_seconds"      => round(elapsed_s; digits=1),
        ),
        "files" => Dict(
            "participant_features" => "participant_features.csv",
            "windowed_features"    => "windowed_w$(window_size)_s$(stride)_features.csv",
        ),
        "normative" => Dict(
            "description" => "Use participant_features.csv for recording-level normative ranges.",
            "sigma_threshold"   => 4,
            "reference"  => "Evaluate new values: flag if |x - μ| > 4σ for any feature.",
        ),
    )
    open(joinpath(out_dir, "metadata.toml"), "w") do io
        TOML.print(io, meta)
    end
end

# ─── Per-Dataset Processing ───────────────────────────────────────────────────

function process_dataset(ds; window_size::Int, stride::Int, output_root::String)::NamedTuple{(:ok,:fail), Tuple{Int,Int}}

    println("\n" * "═"^70)
    println("  Dataset : $(ds.name)")
    println("  Records : $(length(ds.records))")
    println("  Format  : $(ds.format)  $(ds.format == :wfdb ? "(annotator=$(ds.annotator))" : "(ext=$(ds.txt_extension))")")
    println("  Windows : size=$(window_size) beats, stride=$(stride) beats")
    println("═"^70)

    out_dir = joinpath(output_root, ds.name)
    mkpath(out_dir)

    # Temp dir for downloads
    dl_dir = joinpath(out_dir, "_downloads")
    mkpath(dl_dir)

    # Load SHA manifest for integrity checking
    sha_manifest = load_sha_manifest(dl_dir)

    participant_rows = Vector{Dict{String,Any}}()
    windowed_dfs     = DataFrame[]

    n_ok = 0
    n_fail = 0
    t_start = time()

    for (idx, record) in enumerate(ds.records)

        elapsed = time() - t_start
        print("\r" * progress_line(idx - 1, length(ds.records), elapsed, record))
        flush(stdout)

        if DRY_RUN
            println("\n  [DRY RUN] Would process: $record")
            continue
        end

        # ── Check for previously processed record ──────────────────────────
        part_cache = joinpath(out_dir, "_cache", "$(record)_participant.csv")
        wind_cache = joinpath(out_dir, "_cache", "$(record)_windowed_w$(window_size)_s$(stride).csv")
        mkpath(joinpath(out_dir, "_cache"))

        if SKIP_EXISTING && isfile(part_cache) && isfile(wind_cache)
            try
                cached_p = CSV.read(part_cache, DataFrame)
                cached_w = CSV.read(wind_cache, DataFrame)
                for r in eachrow(cached_p)
                    push!(participant_rows, Dict(pairs(r)))
                end
                push!(windowed_dfs, cached_w)
                n_ok += 1
                continue
            catch _
                # Cache corrupted — re-process
            end
        end

        # ── Download ───────────────────────────────────────────────────────
        local_path = if ds.format == :wfdb
            download_wfdb_record(ds.files_url, record, ds.annotator, dl_dir, sha_manifest)
        else
            download_txt_record(ds.files_url, record, ds.txt_extension, dl_dir, sha_manifest)
        end

        if isnothing(local_path)
            n_fail += 1
            continue
        end

        # ── Load IBIs ──────────────────────────────────────────────────────
        ibis = load_record(ds, record, local_path)
        if isnothing(ibis)
            n_fail += 1
            continue
        end
        n_beats_orig = length(ibis)

        # ── Participant-level features ─────────────────────────────────────
        println("\n    [$record] Extracting participant features ($(n_beats_orig) beats)...")
        prow = participant_features(ibis, record, ds.name, n_beats_orig)
        push!(participant_rows, prow)

        # Clear memoization caches to free memory before windowed analysis
        Memoization.empty_all_caches!()
        GC.gc()

        # ── Windowed features ──────────────────────────────────────────────
        println("    [$record] Extracting windowed features...")
        wdf = windowed_features(ibis, record, ds.name, window_size, stride)

        # ── Cache individual record results ────────────────────────────────
        try
            CSV.write(part_cache, DataFrame([prow]))
            isempty(wdf) || CSV.write(wind_cache, wdf)
        catch _
        end

        isempty(wdf) || push!(windowed_dfs, wdf)
        n_ok += 1

        # ── Free memory after each record ──────────────────────────────────
        Memoization.empty_all_caches!()
        GC.gc()
    end

    elapsed_total = time() - t_start
    print("\r" * progress_line(length(ds.records), length(ds.records), elapsed_total, "done"))
    println()

    if DRY_RUN
        println("  [DRY RUN] Skipping file write.")
        return (ok=0, fail=0)
    end

    # ── Always save SHA manifest (even if feature extraction failed) ────
    if !isempty(sha_manifest)
        save_sha_manifest(dl_dir, sha_manifest)
        println("  → _downloads/$(SHA_MANIFEST_FILE)  ($(length(sha_manifest)) file hashes)")
    end

    if n_ok == 0
        @error "  ✗ ALL $(length(ds.records)) records failed for $(ds.name) — no output produced"
        return (ok=n_ok, fail=n_fail)
    end

    println("  ✓ Collected $(n_ok)/$(length(ds.records)) records  ($(n_fail) failed)")

    if isempty(participant_rows)
        @warn "  No participant rows — skipping CSV write for $(ds.name)"
        return (ok=n_ok, fail=n_fail)
    end

    # ── Write participant features CSV ─────────────────────────────────────
    # Build a consistent DataFrame (NaN-fill missing feature columns)
    all_keys = union(keys.(participant_rows)...)
    aligned  = [Dict(k => get(r, k, NaN) for k in all_keys) for r in participant_rows]
    part_df  = DataFrame(aligned)

    # Reorder: metadata columns first
    meta_cols = ["participant_id", "dataset", "n_beats", "recording_ok"]
    other_cols = sort(setdiff(names(part_df), meta_cols))
    select!(part_df, vcat(meta_cols, other_cols))

    part_path = joinpath(out_dir, "participant_features.csv")
    CSV.write(part_path, part_df)
    println("  → $(basename(part_path))  ($(nrow(part_df)) participants, $(ncol(part_df)) columns)")

    # ── Write windowed features CSV ────────────────────────────────────────
    if !isempty(windowed_dfs)
        wind_df = vcat(windowed_dfs...; cols=:union)

        # Fill missing columns with NaN for uniform schema
        for col in names(wind_df)
            if eltype(wind_df[!, col]) == Union{Missing, Float64} ||
               eltype(wind_df[!, col]) == Float64
                wind_df[!, col] = coalesce.(wind_df[!, col], NaN)
            end
        end

        # Reorder: metadata columns first
        wind_meta  = ["dataset", "participant_id", "window_id",
                      "window_start_beat", "window_end_beat",
                      "window_size", "stride", "overlap"]
        wind_feats = sort(setdiff(names(wind_df), wind_meta))
        select!(wind_df, vcat(wind_meta, wind_feats))

        wind_fname = "windowed_w$(window_size)_s$(stride)_features.csv"
        wind_path  = joinpath(out_dir, wind_fname)
        CSV.write(wind_path, wind_df)
        println("  → $(wind_fname)  ($(nrow(wind_df)) windows from $(n_ok) participants, $(ncol(wind_df)) columns)")
    else
        @warn "  No windowed rows produced for $(ds.name)"
    end

    # ── Write metadata TOML ────────────────────────────────────────────────
    write_metadata(ds, out_dir, window_size, stride, n_ok, n_fail, elapsed_total)
    println("  → metadata.toml")

    return (ok=n_ok, fail=n_fail)
end

# ─── Main ─────────────────────────────────────────────────────────────────────

function main()
    println()
    println("HeartRateLab — Normative Dataset Collection Tool")
    println("Version : $(PKG_VERSION)")
    println("Date    : $(now())")
    println("Output  : $(abspath(OUTPUT_DIR))")
    println("Windows : size=$(WINDOW_SIZE) beats, stride=$(STRIDE) beats")
    DRY_RUN && println("⚠  DRY RUN — no files will be written")
    println()

    # Check WFDB tools
    if isnothing(Sys.which("ann2rr"))
        @warn "ann2rr not found on PATH — WFDB-format datasets will fail to process."
        @warn "Install WFDB tools: https://physionet.org/content/wfdb-software/"
    else
        println("ann2rr found at: $(Sys.which("ann2rr"))")
    end
    println()

    # Filter datasets
    datasets = if isnothing(SELECTED_DS)
        DATASET_REGISTRY
    else
        filter(ds -> ds.name ∈ SELECTED_DS, DATASET_REGISTRY)
    end

    if isempty(datasets)
        names_available = join([ds.name for ds in DATASET_REGISTRY], ", ")
        error("No matching datasets. Available: $names_available")
    end

    println("Datasets to collect ($(length(datasets))):")
    for ds in datasets
        n = lpad(length(ds.records), 4)
        println("  $(rpad(ds.name, 18))  $n records  [$(ds.population)]  $(ds.format)")
    end
    println()

    total_ok   = 0
    total_fail = 0
    failed_datasets = String[]

    total_t = @elapsed begin
        for ds in datasets
            result = process_dataset(ds;
                window_size  = WINDOW_SIZE,
                stride       = STRIDE,
                output_root  = OUTPUT_DIR,
            )
            total_ok   += result.ok
            total_fail += result.fail
            if result.ok == 0 && !DRY_RUN
                push!(failed_datasets, ds.name)
            end
        end
    end

    println()
    println("═"^70)

    if !isempty(failed_datasets)
        println("⚠  FAILED datasets (0 records collected): $(join(failed_datasets, ", "))")
    end

    if total_ok == 0 && !DRY_RUN
        println("✗  No records collected across any dataset.")
        println("   Elapsed: $(round(total_t / 60; digits=1)) minutes.")
        println("═"^70)
        exit(1)
    end

    println("Done in $(round(total_t / 60; digits=1)) minutes.  "
            * "$(total_ok) records OK, $(total_fail) failed.")
    println("Normative data stored under: $(abspath(OUTPUT_DIR))")
    println()
    println("Normative evaluation guide:")
    println("  1. Load participant_features.csv per dataset")
    println("  2. Compute μ and σ per feature column")
    println("  3. Flag new observations where |x − μ| > 4σ")
    println("═"^70)

    if !isempty(failed_datasets)
        exit(1)
    end
end

main()
