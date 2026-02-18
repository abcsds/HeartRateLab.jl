module HeartRateLab
# input.jl
using Base.Filesystem: mktemp
using XDF: XDF

include("input.jl")
include("preprocessing.jl")
include("Frequency.jl")
include("Features.jl")
include("Models.jl")
include("Evaluation.jl")
# include("Models/Models.jl")  # TODO: implement model implementations in Phase 3
include("Visualization/Visualization.jl")

# Test power calculation from periodogram
# using Plots
# n = read_txt("test/testdata/example.txt")[1:50] # Compare with HeartRateVariability.jl
# p = plot(n);
# display(p)
# pgram = Frequency.welch(n; method=:quadratic)
# p = plot(pgram.freq, pgram.power, xlabel="Frequency (Hz)", ylabel="Power", title="Welch Periodogram")
# display(p)
# display(plot(pgram.power))
# Frequency.get_power(pgram, 0.003, 0.4)

# infile = "test/testdata/example.txt"
# data = HeartRateLab.Input.read_txt(infile)
# using Input: read_xdf, read_txt, read_wfdb
# using Preprocessing: replace_zeros, replace_bio_outliers, replace_statistical_outliers, replace_ectopic_beats!, replace_ectopic_beats, strip_extremes, interpolate_nans!, interpolate_nans, interpolate, windowed

# export all functions
# for f in names(Features.registry)
#     eval(:(export $f))
# end

# export Input
export read_xdf
export read_txt
export read_wfdb
export Preprocessing
# export Preprocessing
export replace_zeros
export replace_bio_outliers
export replace_statistical_outliers
export replace_ectopic_beats!
export replace_ectopic_beats
export strip_extremes
export interpolate_nans!
export interpolate_nans
export interpolate
export windowed
# export Features
# export lomb_scargle
# export welch
# export get_power
# export get_peaks
export windowed_feature_set, simulate_ensemble, extract_ensemble_features, eval_distributional, eval_scalar
end
