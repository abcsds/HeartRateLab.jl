# test/tools/dataset_loaders.jl
#
# PhysioNet dataset loaders — SALVAGED from the deleted ext/HeartRateLabModelsExt.jl
# (which never loaded: its BlackBoxOptim trigger weakdep was never imported).
#
# Status: NOT package API. These are a development/baseline-generation utility only.
# See backlog d-18 for the planned cleanup into a real, tested, offline-first tool:
#   - the `fill(800.0, 100)` fake-data fallbacks below must be replaced with honest errors
#   - resolve a record ID to a bundled `test/testdata/` fixture before hitting the network
#
# Usage (dev only):
#   using HeartRateLab
#   include("test/tools/dataset_loaders.jl")
#   rr = load_nsrdb("16265")
#
# Requires WFDB tools (ann2rr) on PATH.

import Downloads

"""
    load_physionet(url::String; annotator="atr", preprocessed=true) -> Vector{Float64}

Generic PhysioNet record loader: downloads the record + annotation, parses via `read_wfdb`,
optionally preprocesses, returns the IBI series in milliseconds.
"""
function load_physionet(url::String; annotator::String="atr", preprocessed::Bool=true)::Vector{Float64}
    temp_dir = mktempdir()
    try
        record_name = basename(url)
        record_file = joinpath(temp_dir, record_name)

        dat_url = url * ".dat"
        hea_url = url * ".hea"
        ann_url = url * "." * annotator

        try
            Downloads.download(hea_url, record_file * ".hea")
        catch e
            @warn "Failed to download header file from $hea_url: $e"
            return fill(800.0, 100)  # FIXME(d-18): honest error, not fake data
        end

        try
            Downloads.download(dat_url, record_file * ".dat")
        catch e
            @warn "Failed to download data file from $dat_url: $e"
            return fill(800.0, 100)  # FIXME(d-18)
        end

        try
            Downloads.download(ann_url, record_file * "." * annotator)
        catch e
            @warn "Failed to download annotation file from $ann_url: $e"
            return fill(800.0, 100)  # FIXME(d-18)
        end

        try
            ibis = HeartRateLab.Input.read_wfdb(record_file, annotator)
            if preprocessed
                ibis = HeartRateLab.Preprocessing.replace_zeros(ibis)
                ibis = HeartRateLab.Preprocessing.replace_bio_outliers(ibis)
                ibis = HeartRateLab.Preprocessing.interpolate_nans(ibis)
            end
            return ibis
        catch e
            @warn "Failed to read WFDB record: $e"
            return fill(800.0, 100)  # FIXME(d-18)
        end
    finally
        try
            rm(temp_dir, recursive=true)
        catch
        end
    end
end

# --- Database-specific wrappers (record ID → PhysioNet URL → load_physionet) ---

"Normal Sinus Rhythm Database (nsrdb). Records e.g. \"16265\"."
load_nsrdb(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/nsrdb/1.0.0/" * record; kwargs...)

"MIT-BIH Arrhythmia Database (mitdb). Records e.g. \"100\"."
load_mitbih(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/mitdb/1.0.0/" * record; kwargs...)

"Normal Sinus Rhythm RR Interval Database (nsr2db)."
load_nsr2db(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/nsr2db/1.0.0/" * record; kwargs...)

"RR Interval Time Series from Healthy Subjects."
load_healthy_rr_intervals(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/rr-interval-healthy-subjects/1.0.0/" * record; kwargs...)

"Heart Rate Oscillations during Meditation."
load_meditation(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/meditation/1.0.0/" * record; kwargs...)

"PhysioNet/CinC Challenge 2002 (RR interval modeling)."
load_challenge_2002(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/challenge-2002/1.0.0/" * record; kwargs...)

"Is the Normal Heart Rate Chaotic? (chaos-heart-rate)."
load_chaos(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/chaos-heart-rate/1.0.0/" * record; kwargs...)

"Information-Based Similarity (ibs)."
load_ibs(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/ibs/1.0.0/" * record; kwargs...)

"Simultaneous Physiological Measurements with Five Devices."
load_simultaneous_measurements(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/simultaneous-measurements/1.0.2/" * record; kwargs...)

"Spontaneous Ventricular Tachyarrhythmia Database (mvtdb)."
load_mvtdb(record::String; kwargs...)::Vector{Float64} =
    load_physionet("https://physionet.org/files/mvtdb/1.0/" * record; kwargs...)
