#!/usr/bin/env julia
# =============================================================================
# generate_personal_baseline.jl
#
# Windows the user's own IBI recordings at the SAME sliding-window length the
# live online viz uses (100 beats) and writes a 101-point quantile grid per
# quantity to docs/personal_baseline_w100.csv. That artifact drives the
# personal-baseline overlays in Visualization.default_normative().
#
# Usage (from project root):
#   julia --project=. test/tools/generate_personal_baseline.jl
#
# Env vars:
#   PARTICIPANT=Resonant_Breathing   Folder under EXPORT_DIR
#   EXPORT_DIR=test/testdata/export
#   WINDOW_SIZE=100                  Beats per window (match the live viz)
#   STRIDE=25                        Window stride in beats
#   OUTPUT=docs/personal_baseline_w100.csv
# =============================================================================

using Pkg
Pkg.activate(joinpath(@__DIR__, "..", ".."))

using HeartRateLab
using HeartRateLab: read_txt, replace_zeros, replace_bio_outliers, interpolate_nans

const VB = HeartRateLab.Visualization

const WINDOW_SIZE = parse(Int, get(ENV, "WINDOW_SIZE", "100"))
const STRIDE      = parse(Int, get(ENV, "STRIDE",      "25"))
const PARTICIPANT = get(ENV, "PARTICIPANT", "Resonant_Breathing")
const EXPORT_DIR  = abspath(get(ENV, "EXPORT_DIR",
                        joinpath(@__DIR__, "..", "testdata", "export")))
const OUTPUT      = abspath(get(ENV, "OUTPUT",
                        joinpath(@__DIR__, "..", "..", "docs",
                                 "personal_baseline_w100.csv")))

const PARTICIPANT_DIR = joinpath(EXPORT_DIR, PARTICIPANT)
isdir(PARTICIPANT_DIR) || error("Participant folder not found: $(PARTICIPANT_DIR)")

preprocess(ibis) = interpolate_nans(replace_bio_outliers(replace_zeros(ibis)))

function load_recordings()
    files = filter(f -> endswith(f, ".txt"),
                   readdir(PARTICIPANT_DIR; join = true))
    recs = Vector{Float64}[]
    for f in files
        try
            raw = Float64.(read_txt(f))
            length(raw) < 2 && continue
            push!(recs, preprocess(raw))
        catch e
            @warn "skipping $(basename(f))" exception = e
        end
    end
    return recs
end

println("="^60)
println("  HeartRateLab — Personal Baseline Generator")
println("  Participant : $(PARTICIPANT)")
println("  Window      : $(WINDOW_SIZE) beats / stride $(STRIDE)")
println("="^60)

recs = load_recordings()
isempty(recs) && error("No usable recordings in $(PARTICIPANT_DIR)")
@info "Loaded $(length(recs)) recordings"

grids = VB.compute_baseline_grids(recs; window_size = WINDOW_SIZE, stride = STRIDE)

n_windows = sum(length(r) >= WINDOW_SIZE ?
                length(1:STRIDE:(length(r) - WINDOW_SIZE + 1)) : 0 for r in recs)

mkpath(dirname(OUTPUT))
VB.write_baseline_csv(OUTPUT, grids, Dict(
    "participant"  => PARTICIPANT,
    "window_size"  => string(WINDOW_SIZE),
    "stride"       => string(STRIDE),
    "n_recordings" => string(length(recs)),
    "n_windows"    => string(n_windows),
))

println("\nWrote baseline → $(OUTPUT)  ($(length(recs)) recordings, $(n_windows) windows)")
