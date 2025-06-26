module HeartRateLab
include("Input.jl")
include("Preprocessing.jl")
include("Features/Features.jl")

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
end
