module Features

using Distributed
using DataFrames

# if nprocs() == 1
#     addprocs(4)
# end
# if nworkers() >= 2
#     # @everywhere using Dagger, Base.Threads
# else
#     @warn "Not enough workers to make use of parallel processing."
#     using Base.Threads
#     # using Dagger: Dagger
# end
import ..ms2bpm, ..windowed
import ..Frequency: lomb_scargle, welch, get_power, find_peak
import Base.min, Base.max, Base.diff, Base.length, Base.cumsum, Base.maximum, Base.minimum
import Base: range
import StatsBase, StatsBase.mean, StatsBase.std, StatsBase.median
using Memoization
using MacroTools
import DFA
import EntropyHub
import LinearAlgebra
using Hurst: hurst_exponent
import Distributions

# config = Dict{String,Any}("freq_method" => :lomb_scargle, "fs" => 10)
config = Dict{String,Any}("freq_method" => :welch, "fs" => 10)

# ─── Distribution family lookup ────────────────────────────────────────────────
# Maps docstring names → Distributions.jl types, used by @register to store
# the analytical distribution family for each scalar feature.
const DISTRIBUTION_MAP = Dict{String, Any}(
    "Normal"    => Distributions.Normal,
    "Gamma"     => Distributions.Gamma,
    "Beta"      => Distributions.Beta,
    "LogNormal" => Distributions.LogNormal,
)

struct HRMeasurement
    data::Array{T,1} where {T<:Real} # Inter-Beat-Intervals (IBIs) in milliseconds
    length::Int # N: number of IBIs
    time::Float64 # total duration of the recording in milliseconds
    fs::Int # sampling frequency in Hz
    duration::Float64 # in seconds
end
function HRMeasurement(data::Array{T,1}, fs::Int=config["fs"]) where {T<:Real}
    time = cumsum(data)[end] - data[1] # total duration in milliseconds
    length::Int = Base.length(data)
    # @info "HRMeasurement created with $(length) samples, total duration: $(round(time/60_000, digits=2)) min."
    return HRMeasurement(data, length, time, fs, time / 1000) # duration in seconds
end
struct HRFeature
    name::String
    func::Function
    alias::Array{String}
    domains::Array{String}
    minimum_length::Int
    distribution::Any  # Distribution family from Distributions.jl (e.g., Normal, Gamma, Beta)
end
function HRFeature(
    name::String, func::Function;
    alias::Array{String}, domains::Array{String},
    minimum_length::Int=10, distribution=nothing,
)
    return HRFeature(name, func, alias, domains, minimum_length, distribution)
end
feature_registry = Dict{String,HRFeature}()
representation_registry = Dict{String,HRFeature}()

# ─── Normative prior registry ──────────────────────────────────────────────────
# Maps feature name → fitted Distributions.jl instance (e.g., Normal(780.0, 143.7))
# Populated at module load from docs/normative_priors.csv if it exists.
const prior_registry = Dict{String, Any}()
function_registry = Dict{String,Function}()
"""
    @register documented_function
"""
macro register(expr::Expr)
    @capture(expr, function f_(args__)
        body__
    end) || error("Invalid function definition")

    function_name = String(f)
    docstr = body[1] isa String ? body[1] : ""
    if docstr == ""
        @warn("No docstring found.")
    else
        @debug("Docstring found: ", docstr)
        body = body[2:end] # Remove the docstring from the body
    end

    # Pre-define function name
    if !isdefined(Features, f)
        @eval begin
            $(f)() = nothing
        end
    end
    domains, aliases, representation, minimum_length, distribution = parse_docstring(docstr)

    # Return the memoized function definition
    # with standard documentation conventions
    # for evaluation, then add to the registry
    function_name ∈ keys(function_registry) &&
        @warn("Function $(function_name) is already registered. Overwriting.")
    res = quote
        function_registry[$(function_name)] = @memoize function $(f)($(args...))
            (occursin("HRMeasurement", repr($args[1]))) ||  # Ensure the first argument is an HRMeasurement
                throw(ArgumentError("The first argument must be an HRMeasurement."))
            # n = $(args[1]).data # Extract the HRMeasurement data
            $(body...)
        end
        if !($representation)
            feature_registry[$(function_name)] = HRFeature(
                $(function_name), $(f), $(aliases), $(domains), $(minimum_length), $(distribution)
            )
            # for a in $(aliases) # Register aliases
            #     feature_registry[a] = feature_registry[$(function_name)]
            # end
        else
            representation_registry[$(function_name)] = HRFeature(
                $(function_name), $(f), $(aliases), $(domains), $(minimum_length), $(distribution)
            )
            for a in $(aliases) # Register aliases
                representation_registry[a] = representation_registry[$(function_name)]
            end
        end
    end
    return esc(res) # Ensure the expression is evaluated in the correct context
end
# Extract "Domains", "Aliases", "Representation", and "Minimum length" from the docstring
function parse_docstring(doc)
    domains = []
    aliases = []
    representation = false
    minimum_length = 10  # Default value
    distribution = nothing  # Distribution family (from Distributions.jl)
    # Use regular expressions to find the word "Domains" and "Aliases" at the start of a line
    for line in split(doc, '\n')
        # if matches(r"^\s*Domains:", line) # Halucination, don't use this
        if occursin("Domains:", line)
            # Extract the domains from the line
            domains = strip(line[9:end]) # Remove "Domains: " prefix
            domains = replace(domains, r"\[|\]" => "") # Remove brackets
            domains = replace(domains, r"\"" => "") # Remove quotes
            domains = String.(strip.(split(domains, ',')))
        elseif occursin("Aliases:", line)
            # Extract the aliases from the line
            aliases = strip(line[9:end]) # Remove "Aliases: " prefix
            aliases = replace(aliases, r"\[|\]" => "") # Remove brackets
            aliases = replace(aliases, r"\"" => "") # Remove quotes
            aliases = String.(strip.(split(aliases, ',')))
        elseif occursin("Representation:", line)
            occursin("true", line) ? representation = true : continue
        elseif occursin("Distribution:", line)
            # Extract the analytical distribution family name
            dist_name = strip(split(line, ':')[2])
            distribution = get(DISTRIBUTION_MAP, dist_name, nothing)
            if distribution === nothing && !isempty(dist_name)
                @warn "Unknown distribution family: $dist_name (valid: $(join(keys(DISTRIBUTION_MAP), ", ")))"
            end
        elseif occursin("Minimum length:", line)
            # Extract the minimum length value
            length_str = strip(split(line, ':')[2])
            minimum_length = tryparse(Int, length_str) !== nothing ? parse(Int, length_str) : 10
        else
            continue
        end
    end
    return domains, aliases, representation, minimum_length, distribution
end

# Level 1 Direct staticstics
@register function mean(n::HRMeasurement)
    """
        mean(n::HRMeasurement)
    Calculate the average value in milliseconds of a given array of Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Domains: time, statistics
    Aliases: average, mean_rr, mean_nn
    Distribution: Normal
    
    Minimum length: 10
    """
    return StatsBase.mean(n.data)
end

@register function sdnn(n::HRMeasurement)
    """
        sdnn(n::HRMeasurement)
    Calculate the standard deviation of the array `n`. This is the `sdnn`.
    Domains: time, statistics
    Aliases: std
    Distribution: Gamma
    
    Minimum length: 10
    """
    return StatsBase.std(n.data)
end
sdnn(n::Array{T,1}) where {T<:Real} = function_registry["sdnn"](HRMeasurement(n))

@register function median(n::HRMeasurement)
    """
        median(n::HRMeasurement)
    Calculate the median value of the array `n`.
    Domains: time, statistics
    Aliases: median
    Distribution: Normal
    
    Minimum length: 10
    """
    return StatsBase.median(n.data)
end

@register function max(n::HRMeasurement)
    """
        max(n::HRMeasurement)
    Calculate the maximum value of the array `n`. This is the largest Inter-Beat-Interval (IBI) in milliseconds.
    Domains: time, statistics
    Aliases: max, maximum_rr, maximum_nn
    Distribution: Normal
    
    Minimum length: 10
    """
    return Base.maximum(n.data)
end

@register function min(n::HRMeasurement)
    """
        min(n::HRMeasurement)
    Calculate the minimum of the array `n`. This is the smallest Inter-Beat-Interval (IBI) in milliseconds.
    Domains: time, statistics
    Aliases: min, minimum_rr, minimum_nn
    Distribution: Normal
    
    Minimum length: 10
    """
    return Base.minimum(n.data)
end

@register function diff(n::HRMeasurement)
    """
        diff(n::HRMeasurement)
    Calculate the difference between sequential samples in the array `n`.
    This is the difference of sequential beats, also known as numeric differentiation.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds of size `N`.
    Returns:
        An array of size `N-1` containing the differences between each pair of sequential samples.
    Domains: time
    Aliases: dnn, difference_of_sequential_beats, numeric_differentiation
    Representation: true
    
    Minimum length: 10
    """
    # return n[2:end] .- n[1:end-1]
    return Base.diff(n.data)
end

@register function length(n::HRMeasurement)
    """
        length(n::HRMeasurement)
    Calculate the number of IBIs in the array `n`.
    Arguments:
        - `n`: An array of IBIs in milliseconds.
    Returns:
        The number `N` of samples in the array `n`.
    Domains: statistics
    Aliases: n, measurement_length, number_of_measurements, measurement_size
    Representation: true
    
    Minimum length: 10
    """
    return Base.length(n.data)
end

@register function duration(n::HRMeasurement)
    """
        duration(n::HRMeasurement)
    Calculate the total duration of the recording in milliseconds.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The total duration of the recording in milliseconds.
    Domains: time
    Aliases: recording_duration
    Representation: true
    
    Minimum length: 10
    """
    return Base.cumsum(n.data)[end] # Record duration in ms
end

# Level 2 Alternate representations
@register function mean_hr(n::HRMeasurement)
    """
        mean_hr(n::HRMeasurement)
    Calculate the average heart rate in beats per minute (BPM) from the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The average heart rate in BPM.
    Domains: time, statistics
    Aliases: mean_hr, average_hr
    Distribution: Normal
    
    Minimum length: 10
    """
    return ms2bpm(function_registry["mean"](n))
end
@register function std_hr(n::HRMeasurement)
    """
        std_hr(n::HRMeasurement)
    Calculate the standard deviation of the heart rate in BPM from the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The standard deviation of the heart rate in BPM.
    Domains: time, statistics
    Aliases: std_hr
    Distribution: Gamma
    
    Minimum length: 10
    """
    return ms2bpm(function_registry["sdnn"](n))
end
@register function max_hr(n::HRMeasurement)
    """
        max_hr(n::HRMeasurement)
    Calculate the maximum heart rate in BPM from the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The maximum heart rate in BPM.
    Domains: time, statistics
    Aliases: max_hr, maximum_hr
    Distribution: Normal
    
    Minimum length: 10
    """
    return ms2bpm(function_registry["max"](n))
end
@register function min_hr(n::HRMeasurement)
    """
        min_hr(n::HRMeasurement)
    Calculate the minimum heart rate in BPM from the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The minimum heart rate in BPM.
    Domains: time, statistics
    Aliases: min_hr, minimum_hr
    Distribution: Normal
    
    Minimum length: 10
    """
    return ms2bpm(function_registry["min"](n))
end
@register function median_hr(n::HRMeasurement)
    """
        median_hr(n::HRMeasurement)
    Calculate the median heart rate in BPM from the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The median heart rate in BPM.
    Domains: time, statistics
    Aliases: median_hr
    Distribution: Normal

    Minimum length: 10
    """
    # median is preserved under the monotonic ms2bpm transform
    return ms2bpm(function_registry["median"](n))
end
@register function range_hr(n::HRMeasurement)
    """
        range_hr(n::HRMeasurement)
    Calculate the range (max − min) of the instantaneous heart rate in BPM.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The heart-rate range in BPM.
    Domains: time, statistics
    Aliases: range_hr, hr_range
    Distribution: Gamma

    Minimum length: 10
    """
    hr = ms2bpm.(n.data)
    return maximum(hr) - minimum(hr)
end
# Level 3 Time domain features
@register function sdsd(n::HRMeasurement)
    """
        sdsd(n::HRMeasurement)
    Calculate the standard deviation of the successive differences of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The standard deviation of the successive differences.
    Domains: time, statistics
    Aliases: sdsd
    Distribution: Gamma
    
    Minimum length: 20
    """
    return function_registry["sdnn"](function_registry["diff"](n))
end
@register function range(n::HRMeasurement)
    """
        range(n::HRMeasurement)
    Calculate the range of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The range of the IBIs.
    Domains: time, statistics
    Aliases: range
    Distribution: Gamma
    
    Minimum length: 10
    """
    return function_registry["max"](n) - function_registry["min"](n)
end
@register function rmssd(n::HRMeasurement)
    """
        rmssd(n::HRMeasurement)
    Calculate the root mean square of successive differences of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The RMSSD value.
    Domains: time, statistics
    Aliases: rmssd
    Distribution: Gamma
    
    Minimum length: 20
    """
    return sqrt(sum(function_registry["diff"](n) .^ 2)) / sqrt(function_registry["length"](n) - 1)
end
@register function sdann(n::HRMeasurement)
    """
        sdann(n::HRMeasurement)
    Calculate the standard deviation of the average Inter-Beat-Intervals (IBIs) in 5-minute windows.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The standard deviation of the average IBIs in 5-minute windows.
    Domains: time, statistics
    Aliases: sdann
    Distribution: Gamma
    
    Minimum length: 50
    """
    return StatsBase.std(
        windowed(
            n.data; window_size=5*60*1000, stride=5*60*1000, time=:ms, f=function_registry["mean"]
        ),
    )
end
@register function pnn50(n::HRMeasurement)
    """
        pnn50(n::HRMeasurement)
    Calculate the proportion of successive differences of the Inter-Beat-Intervals (IBIs) that are greater than 50 ms.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The proportion of successive differences greater than 50 ms.
    Domains: time, statistics
    Aliases: pnn50
    Distribution: Beta
    
    Minimum length: 50
    """
    return sum(function_registry["diff"](n) .> 50) / function_registry["length"](n)
end
@register function pnn20(n::HRMeasurement)
    """
        pnn20(n::HRMeasurement)
    Calculate the proportion of successive differences of the Inter-Beat-Intervals (IBIs) that are greater than 20 ms.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The proportion of successive differences greater than 20 ms.
    Domains: time, statistics
    Aliases: pnn20
    Distribution: Beta
    
    Minimum length: 50
    """
    return sum(function_registry["diff"](n) .> 20) / function_registry["length"](n)
end
@register function cvsd(n::HRMeasurement)
    """
        cvsd(n::HRMeasurement)
    Calculate the coefficient of variation of the successive differences of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The coefficient of variation of the successive differences.
    Domains: time, statistics
    Aliases: cvsd
    Distribution: Gamma
    
    Minimum length: 20
    """
    return function_registry["sdsd"](n) / function_registry["mean"](n)
end
@register function cvnni(n::HRMeasurement)
    """
        cvnni(n::HRMeasurement)
    Calculate the coefficient of variation of the NN intervals (SDNN / mean).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The coefficient of variation of the NN intervals.
    Domains: time, statistics
    Aliases: cvnni, cv_nni, coefficient_of_variation
    Distribution: Normal

    Minimum length: 10
    """
    return function_registry["sdnn"](n) / function_registry["mean"](n)
end
@register function rRR(n::HRMeasurement)
    """
        rRR(n::HRMeasurement)
    Measures the median of the euclidean distances between the relative RR intervals to the average of the relative RR intervals.
    Relative RR intervales are calculated as the difference between two successive RR intervals divided by the sum of the two intervals[^1].
    [^1]: Vollmer, M. (2015). A robust, simple and reliable measure of heart rate variability using relative RR intervals. 2015 Computing in Cardiology Conference (CinC), 609–612. https://doi.org/10.1109/CIC.2015.7410984
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The RMSSD value.
    Domains: time, statistics
    Aliases: rRR
    Distribution: Gamma
    
    Minimum length: 10
    """
    n = n.data
    rr = 2 .* function_registry["diff"](n) ./ (n[1:end-1] .+ n[2:end])
    m = StatsBase.mean(rr)
    d = [sqrt((m-rr[i])^2 + (m-rr[i+1])^2) for i in 1:length(rr)-1]
    return StatsBase.median(d)*100
end

# Frequency features
config["freq_method"] ∉ [:lomb_scargle, :welch] &&
    throw(ArgumentError("Unsupported frequency method: $method"))

@register function pgram(n::HRMeasurement)
    """
        pgram(n::HRMeasurement)
    Calculate the power spectrum of the Inter-Beat-Intervals (IBIs) using the specified frequency method.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The power spectrum of the IBIs.
    Domains: frequency
    Aliases: periodogram, power_spectrum
    Representation: true
    
    Minimum length: 128
    """
    config["freq_method"] ∉ [:lomb_scargle, :welch] && throw(ArgumentError("Unsupported method: $(config["freq_method"])"))
    if config["freq_method"] == :lomb_scargle
        return lomb_scargle(n.data)
    elseif config["freq_method"] == :welch
        return welch(n.data, method=:linear, fs=4) # TODO: all other interpolation methods: config
    else
        throw(ArgumentError("Unsupported frequency method: $(config["freq_method"])"))
    end
end
@register function max_t(n::HRMeasurement)
    """
        max_t(n::HRMeasurement)
    Calculate the maximum time of the recording in seconds.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The maximum time of the recording in seconds.
    Domains: time
    Aliases: max_time, recording_duration_s
    Representation: true
    
    Minimum length: 128
    """
    return function_registry["duration"](n) / 1000 # Record duration in seconds
end
@register function ulf(n::HRMeasurement)
    """
        ulf(n::HRMeasurement)
    Calculate the ultra low frequency power of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The ultra low frequency power.
    Domains: frequency
    Aliases: ultra_low_frequency
    Distribution: Gamma
    
    Minimum length: 128
    """
    if config["freq_method"] == :lomb_scargle
        # @warn "No ultra low frequency in Lomb-Scargle. Returning NaN."
        return NaN # No ultra low frequency in Lomb-Scargle # TODO: why?
    elseif config["freq_method"] == :welch
        function_registry["max_t"](n) < 86000 && @warn "Recording duration is less than 24 hours. ULF power may not be reliable."
        return get_power(function_registry["pgram"](n), 0.003, 0.04)
    else
        @warn "Unsupported frequency method: $(config["freq_method"]). Returning NaN."
        return NaN
    end
end
@register function vlf(n::HRMeasurement)
    """
        vlf(n::HRMeasurement)
    Calculate the very low frequency power: between 0.003 Hz and 0.04 Hz.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The very low frequency power.
    Domains: frequency
    Aliases: very_low_frequency
    Distribution: Gamma
    
    Minimum length: 128
    """
    return get_power(function_registry["pgram"](n), 0.003, 0.04)
end
@register function lf(n::HRMeasurement)
    """
        lf(n::HRMeasurement)
    Calculate the low frequency power: between 0.04 Hz and 0.15 Hz.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The low frequency power.
    Domains: frequency
    Aliases: low_frequency
    Distribution: Gamma
    
    Minimum length: 128
    """
    return get_power(function_registry["pgram"](n), 0.04, 0.15)
end
@register function hf(n::HRMeasurement)
    """
        hf(n::HRMeasurement)
    Calculate the high frequency power: between 0.15 Hz and 0.4 Hz.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The high frequency power.
    Domains: frequency
    Aliases: high_frequency
    Distribution: Gamma
    
    Minimum length: 128
    """
    return get_power(function_registry["pgram"](n), 0.15, 0.4)
end
@register function tp(n::HRMeasurement)
    """
        tp(n::HRMeasurement)
    Calculate the total power of the Inter-Beat-Intervals (IBIs): between 0.003 Hz and 0.4 Hz.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The total power of the IBIs.
    Domains: frequency
    Aliases: total_power
    Distribution: Gamma
    
    Minimum length: 128
    """
    return get_power(function_registry["pgram"](n), 0.003, 0.4)
end
@register function lf_peak(n::HRMeasurement)
    """
        lf_peak(n::HRMeasurement)
    Find the peak frequency in the low frequency band: between 0.04 Hz and 0.15 Hz.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The peak frequency in the low frequency band.
    Domains: frequency
    Aliases: lf_peak
    Distribution: Normal
    
    Minimum length: 128
    """
    return find_peak(function_registry["pgram"](n), 0.04, 0.15)
end
@register function hf_peak(n::HRMeasurement)
    """
        hf_peak(n::HRMeasurement)
    Find the peak frequency in the high frequency band: between 0.15 Hz and 0.4 Hz.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The peak frequency in the high frequency band.
    Domains: frequency
    Aliases: hf_peak
    Distribution: Normal
    
    Minimum length: 128
    """
    return find_peak(function_registry["pgram"](n), 0.15, 0.4)
end
# Frequency: Proportions and ratios
@register function lf_hf_ratio(n::HRMeasurement)
    """
        lf_hf_ratio(n::HRMeasurement)
    Calculate the ratio of low frequency power to high frequency power.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The ratio of low frequency power to high frequency power.
    Domains: frequency
    Aliases: lf_hf_ratio
    Distribution: LogNormal
    
    Minimum length: 128
    """
    return function_registry["lf"](n) / function_registry["hf"](n)
end
@register function lf_relative(n::HRMeasurement)
    """
        lf_relative(n::HRMeasurement)
    Calculate the relative low frequency power as a proportion of total power.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The relative low frequency power.
    Domains: frequency
    Aliases: lf_relative_power
    Distribution: Beta
    
    Minimum length: 128
    """
    lf = function_registry["lf"](n)
    tp = function_registry["tp"](n)
    return isnan(lf) || isnan(tp) ? NaN : lf / tp
end
@register function hf_relative(n::HRMeasurement)
    """
        hf_relative(n::HRMeasurement)
    Calculate the relative high frequency power as a proportion of total power.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The relative high frequency power.
    Domains: frequency
    Aliases: hf_relative_power
    Distribution: Beta
    
    Minimum length: 128
    """
    hf = function_registry["hf"](n)
    tp = function_registry["tp"](n)
    return isnan(hf) || isnan(tp) ? NaN : hf / tp
end
# Alternative representations
@register function lf_percentage(n::HRMeasurement)
    """
        lf_percentage(n::HRMeasurement)
    Calculate the low frequency power as a percentage of total power.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The low frequency power as a percentage.
    Domains: frequency
    Aliases: lf_%
    Distribution: Gamma

    Minimum length: 128
    """
    return function_registry["lf_relative"](n) * 100
end
@register function hf_percentage(n::HRMeasurement)
    """
        hf_percentage(n::HRMeasurement)
    Calculate the high frequency power as a percentage of total power.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The high frequency power as a percentage.
    Domains: frequency
    Aliases: hf_%
    Distribution: Gamma

    Minimum length: 128
    """
    return function_registry["hf_relative"](n) * 100
end
# Geometric features
@register function px(n::HRMeasurement)
    """
        px(n::HRMeasurement)
    Extract the x-axis values for the Poincare plot.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        An array of x-axis values for the Poincare plot.
    Domains: geometric
    Aliases: poincare_x, poincare_x_axis
    Representation: true
    
    Minimum length: 20
    """
    return [n.data[i] for i in 1:length(n.data)-1]
end
@register function py(n::HRMeasurement)
    """
        py(n::HRMeasurement)
    Extract the y-axis values for the Poincare plot.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        An array of y-axis values for the Poincare plot.
    Domains: geometric
    Aliases: poincare_y, poincare_y_axis
    Representation: true
    
    Minimum length: 20
    """
    return [n.data[i+1] for i in 1:length(n.data)-1]
end
@register function sd1(n::HRMeasurement)
    """
        sd1(n::HRMeasurement)
    Calculate the standard deviation of the points in the Poincare plot along the line perpendicular to the line of identity.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The standard deviation of the points in the Poincare plot along the line perpendicular to the line of identity.
    Domains: geometric
    Aliases: sd1, sd1_width
    Distribution: Gamma
    
    Minimum length: 20
    """
    x = function_registry["px"](n)
    y = function_registry["py"](n)
    return sqrt(StatsBase.var((x - y) / sqrt(2)))
end
@register function sd2(n::HRMeasurement)
    """
        sd2(n::HRMeasurement)
    Calculate the standard deviation of the points in the Poincare plot along the line of identity.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The standard deviation of the points in the Poincare plot along the line of identity.
    Domains: geometric
    Aliases: sd2, sd2_length
    Distribution: Gamma
    
    Minimum length: 20
    """
    x = function_registry["px"](n)
    y = function_registry["py"](n)
    return sqrt(StatsBase.var((x + y) / sqrt(2)))
end
@register function sd2_sd1(n::HRMeasurement)
    """
        sd2_sd1(n::HRMeasurement)
    Calculate the ratio of the standard deviations sd2 and sd1 in the Poincare plot.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The ratio of sd2 to sd1.
    Domains: geometric
    Aliases: sd2_sd1_ratio, csi, cardiac_sympathetic_index
    Distribution: LogNormal
    
    Minimum length: 20
    """
    return function_registry["sd2"](n) / function_registry["sd1"](n)
end
@register function sd1_sd2_area(n::HRMeasurement)
    """
        sd1_sd2_area(n::HRMeasurement)
    Calculate the area of the Poincare plot defined by sd1 and sd2.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The area of the Poincare plot defined by sd1 and sd2.
    Domains: geometric
    Aliases: poincare_area
    Distribution: LogNormal
    
    Minimum length: 20
    """
    return π * function_registry["sd1"](n) * function_registry["sd2"](n)
end
@register function cvi(n::HRMeasurement)
    """
        cvi(n::HRMeasurement)
    Calculate the cardiac vagal index from the Poincare plot.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The cardiac vagal index.
    Domains: geometric
    Aliases: cardiac_vagal_index
    Distribution: Normal
    
    Minimum length: 20
    """
    return log10(function_registry["sd2"](n) * function_registry["sd1"](n) * 16)
end
@register function ccsi(n::HRMeasurement)
    """
        ccsi(n::HRMeasurement)
    Calculate the corrected cardiac sympathetic index from the Poincare plot.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The corrected cardiac sympathetic index.
    Domains: geometric
    Aliases: corrected_cardiac_sympathetic_index, corrected_csi, modified_csi, csi_mod
    Distribution: LogNormal
    
    Minimum length: 20
    """
    return (4 * function_registry["sd2"](n) ^ 2) / function_registry["sd1"](n)
end
@register function histogram(n::HRMeasurement)
    """
        histogram(n::HRMeasurement)
    Calculate the histogram of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        A histogram of the IBIs.
    Domains: geometric
    Aliases: histogram
    Representation: true
    
    Minimum length: 20
    """
    h = StatsBase.fit(StatsBase.Histogram, n.data, range(300, 2000, step=8))
    return h
end
@register function triangular_index(n::HRMeasurement)
    """
        triangular_index(n::HRMeasurement)
    Calculate the triangular index of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The triangular index.
    Domains: geometric
    Aliases: triangular_index
    Distribution: Gamma
    
    Minimum length: 20
    """
    histogram_weights = function_registry["histogram"](n).weights
    return function_registry["length"](n) / maximum(histogram_weights)
end
@register function tinn(n::HRMeasurement)
    """
        tinn(n::HRMeasurement)
    Calculate the Triangular Interpolation of NN intervals (TINN) index.
    This is the width of the RR interval histogram.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The TINN index.
    Domains: geometric
    Aliases: triangular_interpolation_of_nn_intervals
    Distribution: Gamma
    
    Minimum length: 20
    """
    h = function_registry["histogram"](n)
    iX = argmax(h.weights)
    X = [h.edges[1];][iX]
    Y = maximum(h.weights)
    N_range = X<=300 ? [300] : range(300, X, step=8)
    M_range = X>=2000 ? [2000] : range(X, 2000, step=8)
    min_sse = 1e10
    vars = []
    for (i,n) in enumerate(N_range)
        for (j,m) in enumerate(M_range)
            D_edges = h.edges[1]
            D_weights = h.weights
            # @assert length(D_edges) == length(D_weights)
            iN = findfirst(x->x==n, D_edges)
            iM = findfirst(x->x==m, D_edges)
            @assert iM <= length(D_edges)

            Q_weights = zeros(length(D_weights))
            a = iX - iN
            b = iM - iX
            a == 0 && (redg = [])
            a == 1 && (Q_weights[iX] = Y)
            a >= 2 && (Q_weights[iN:iX] = [i for i in LinRange(0, Y, iX-iN+1)])

            b == 0 && (fedg = [])
            b == 1 && (Q_weights[iX] = Y)
            b >= 2 && (Q_weights[iX:iM-1] = [i for i in LinRange(Y, 0, iM-iX)])
            Q_edges = D_edges
            @assert length(D_weights) == length(Q_weights)
            # Catch Float overflow
            sse = Inf
            try
                sse = sum((Q_weights .- D_weights) .^ 2)
            catch
                @debug "Overflow, M: $m, N: $n"
            end
            if sse < min_sse
                min_sse = sse
                vars = [n, m, i, j]
            end
        end
    end
    N, M = vars[1], vars[2]
    return M - N
end

# # Nonlinear features
@register function apen(n::HRMeasurement, m::Int64=2, r::Number=6)
    """
        apen(n::HRMeasurement, m::Int64=2, r::Number=6)
    Calculate the approximate entropy of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
        - `m`: The embedding dimension (default is 2).
        - `r`: The Radius Distance Threshold, a positive scalar (default is 6).
    Returns:
        The approximate entropy of the IBIs.
    Domains: nonlinear
    Aliases: approximate_entropy, apen
    Distribution: Normal

    Minimum length: 100
    """
    apens, _ = EntropyHub.ApEn(n.data, m=m, r=r)
    return log(apens[end-1] / apens[end])
end
@register function sampen(n::HRMeasurement, m::Int64=2, r::Number=6)
    """
        sampen(n::HRMeasurement, m::Int64=2, r::Number=6)
    Calculate the sample entropy of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
        - `m`: The embedding dimension (default is 2).
        - `r`: The Radius Distance Threshold, a positive scalar (default is 6).
    Returns:
        The sample entropy of the IBIs.
    Domains: nonlinear
    Aliases: sample_entropy, sampen
    Distribution: Normal

    Minimum length: 100
    """
    sampen1, _ = EntropyHub.SampEn(n.data, m=m, r=r)
    sampen2, _ = EntropyHub.SampEn(n.data, m=+1, r=r)
    return log(sampen1[end] / sampen2[end])
end
@register function hurst(n::HRMeasurement)
    """
        hurst(n::HRMeasurement)
    Calculate the Hurst exponent of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The Hurst exponent of the IBIs.
    Domains: nonlinear
    Aliases: hurst_exponent, hurst
    Distribution: Beta
    
    Minimum length: 100
    """
    τ_range = 1:min(10, length(n.data)) # 
    H, SD = hurst_exponent(n.data, τ_range)
    # TODO: viz, maybe use dfa functionality instead of dependency
    return H
end # TODO
@register function renyi(n::HRMeasurement, order::Int)
    """
        renyi(n::HRMeasurement, order::Int)
    Calculate the Renyi entropy of order 0 of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
        - `order`: The order of the Renyi entropy (default is 2).
    Returns:
        The Renyi entropy of order 0 of the IBIs.
    Domains: nonlinear
    Aliases: renyi_entropy
    Representation: true
    """
    return StatsBase.renyientropy(n.data, order)
end
@register function renyi0(n::HRMeasurement)
    """
        renyi0(n::HRMeasurement)
    See `renyi(n::HRMeasurement, order::Int=0)`.
    Distribution: Normal
    
    Minimum length: 100
    """
    return function_registry["renyi"](n, 0)
end
@register function renyi1(n::HRMeasurement)
    """
        renyi1(n::HRMeasurement)
    See `renyi(n::HRMeasurement, order::Int=1)`.
    Distribution: Normal
    
    Minimum length: 100
    """
    return function_registry["renyi"](n, 1)
end
@register function renyi2(n::HRMeasurement)
    """
        renyi2(n::HRMeasurement)
    See `renyi(n::HRMeasurement, order::Int=2)`.
    Distribution: Normal
    
    Minimum length: 100
    """
    return function_registry["renyi"](n, 2)
end
@register function shan_en(n::HRMeasurement)
    """
        shan_en(n::HRMeasurement)
    Calculate the Shannon entropy of the Inter-Beat-Interval histogram.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The Shannon entropy (nats) of the binned RR distribution.
    Domains: nonlinear
    Aliases: shannon_entropy, shan_en
    Distribution: Normal

    Minimum length: 20
    """
    w = function_registry["histogram"](n).weights
    p = w ./ sum(w)
    p = p[p .> 0]
    return -sum(p .* log.(p))
end
@register function svd_en(n::HRMeasurement, m::Int64=2, tau::Int64=1)
    """
        svd_en(n::HRMeasurement, m=2, tau=1)
    Calculate the Singular Value Decomposition (SVD) entropy of the IBIs: the Shannon
    entropy of the normalized singular-value spectrum of the delay-embedded series.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
        - `m`: Embedding dimension (default 2).
        - `tau`: Embedding delay (default 1).
    Returns:
        The normalized SVD entropy in [0, 1].
    Domains: nonlinear
    Aliases: svd_entropy, svd_en
    Distribution: Normal

    Minimum length: 100
    """
    x = n.data
    M = length(x) - (m - 1) * tau
    Y = reduce(hcat, [x[(1:M) .+ (i - 1) * tau] for i in 1:m])
    s = LinearAlgebra.svdvals(Y)
    s = s ./ sum(s)
    s = s[s .> 0]
    return -sum(s .* log.(s)) / log(m)
end
@register function fuzzyen(n::HRMeasurement, m::Int64=2)
    """
        fuzzyen(n::HRMeasurement, m=2)
    Calculate the fuzzy entropy of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
        - `m`: The embedding dimension (default 2).
    Returns:
        The fuzzy entropy of the IBIs.
    Domains: nonlinear
    Aliases: fuzzy_entropy, fuzzyen
    Distribution: Normal

    Minimum length: 100
    """
    # standard fuzzy-membership tolerance ~0.2·SD (data is in ms; default r=0.2 is mis-scaled)
    r = (0.2 * StatsBase.std(n.data), 2.0)
    Fuzz, _, _ = EntropyHub.FuzzEn(n.data, m=m, r=r)
    return Fuzz[end]
end
@register function spec_en(n::HRMeasurement)
    """
        spec_en(n::HRMeasurement)
    Calculate the spectral entropy of the Inter-Beat-Intervals (IBIs): the Shannon
    entropy of the normalized power spectral density.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The spectral entropy of the IBIs.
    Domains: nonlinear, frequency
    Aliases: spectral_entropy, spec_en
    Distribution: Normal

    Minimum length: 20
    """
    Spec, _ = EntropyHub.SpecEn(n.data)
    return Spec
end
@register function perm_en(n::HRMeasurement, m::Int64=3, tau::Int64=1)
    """
        perm_en(n::HRMeasurement, m=3, tau=1)
    Calculate the permutation entropy of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
        - `m`: The embedding (order) dimension (default 3).
        - `tau`: The embedding delay (default 1).
    Returns:
        The permutation entropy of the IBIs.
    Domains: nonlinear
    Aliases: permutation_entropy, perm_en
    Distribution: Normal

    Minimum length: 100
    """
    Perm, _, _ = EntropyHub.PermEn(n.data, m=m, tau=tau)
    return Perm[end]
end
@register function mse(n::HRMeasurement, m::Int64=2, r::Number=6, scales::Int64=3)
    """
        mse(n::HRMeasurement, m=2, r=6, scales=3)
    Calculate the Multiscale Entropy (MSE) complexity index of the IBIs: the summed
    sample entropy across coarse-grained time scales.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
        - `m`: The embedding dimension (default 2).
        - `r`: The radius distance threshold (default 6).
        - `scales`: The number of temporal scales (default 3).
    Returns:
        The MSE complexity index (sum over scales).
    Domains: nonlinear
    Aliases: multiscale_entropy, mse
    Distribution: Normal

    Minimum length: 100
    """
    Mobj = EntropyHub.MSobject(EntropyHub.SampEn, m=m, r=r)
    _, CI = EntropyHub.MSEn(n.data, Mobj, Scales=scales)
    return CI
end
@register function dfa(n::HRMeasurement)
    """
        dfa(n::HRMeasurement)
    Calculate the detrended fluctuation analysis of the Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        The detrended fluctuation analysis of the IBIs.
    Domains: nonlinear
    Aliases: detrended_fluctuation_analysis, dfa
    Representation: true
    
    Minimum length: 100
    """
    # DFA scaling windows follow the Peng/Francis convention: α1 over 4≤n≤16, α2 over
    # 16≤n≤64, with the short/long crossover fixed at n=16. The two ranges do NOT overlap
    # (α2's boxmin is 16, not 4) so α2 is a genuine long-term exponent.
    # Refs:
    #   Peng CK, Havlin S, Stanley HE, Goldberger AL. Chaos 1995;5(1):82–87.
    #     doi:10.1063/1.166141  — origin of the n=16 crossover and α1/α2 decomposition.
    #   Francis DP et al. J Physiol 2002;542:619–629. doi:10.1113/jphysiol.2001.013389
    #     — verbatim "α1 over n=4 to 16 and α2 between n=16 and 64".
    #   Vest AN et al. Physiol Meas 2018;39:105004. doi:10.1088/1361-6579/aae021
    #     — PhysioNet Cardiovascular Signal Toolbox: minBox=4, midBox=16, α2 16≤n≤N/4(=64).
    # NB a competing clinical convention uses α1=4–11, α2=>11 (Iyengar 1996; Kubios 4–12/13–64;
    # neurokit2 4–11/12–None). HeartRateLab implements the Peng/Francis 4–16 / 16–64 split.
    # With boxratio=2 the geometric box sizes are α1→[4,8,16], α2→[16,32,64].
    scales, fluc = DFA.dfa(n.data, boxmax=16, boxmin=4, boxratio=2, overlap=0.0)
    log_scales = log10.(scales)
    log_fluc = log10.(fluc)
    intercept, α1 = DFA.polyfit(log_scales, log_fluc)

    scales, fluc = DFA.dfa(n.data, boxmax=64, boxmin=16, boxratio=2, overlap=0.0)
    log_scales = log10.(scales)
    log_fluc = log10.(fluc)
    intercept, α2 = DFA.polyfit(log_scales, log_fluc)
    return α1, α2
end
@register function dfa1(n::HRMeasurement)
    """
        dfa1(n::HRMeasurement)
    Calculate the first exponent of the detrended fluctuation analysis: α1.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        α1
    Domains: nonlinear
    Aliases: dfa1, dfa_exponent_1
    Representation: true
    
    Minimum length: 100
    """
    return function_registry["dfa"](n)[1]
end
@register function dfa2(n::HRMeasurement)
    """
        dfa2(n::HRMeasurement)
    Calculate the second exponent of the detrended fluctuation analysis: α2.
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Returns:
        α2
    Domains: nonlinear
    Aliases: dfa2, dfa_exponent_2
    Distribution: Normal
    
    Minimum length: 100
    """
    return function_registry["dfa"](n)[2]
end

# ─── Feature Sets ──────────────────────────────────────────────────────────────
#
# Features are grouped by computational cost so callers can choose the right
# trade-off between richness and wall-clock time.
#
#   NONLINEAR_FEATURES  — O(n²) or worse: entropy, DFA, Hurst, Rényi.
#                         These dominate runtime on long recordings (>5 000 beats)
#                         and can cause OOM on very long ones (>50 000 beats).
#
#   FAST_FEATURES       — All features *except* the nonlinear set.
#                         Safe to run on any recording length; O(n) or O(n log n).
#                         This is the **default** for `extract_feature_set`.
#
#   ALL_FEATURES        — The complete set: FAST_FEATURES ∪ NONLINEAR_FEATURES.
#
# Use `features=ALL_FEATURES` (or `features=:all`) for the full 53-feature
# extraction when the recording is short enough, or when you have time.

"""Features with O(n²) or higher complexity (entropy, DFA, Hurst, Rényi).  Expensive on long recordings."""
const NONLINEAR_FEATURES = [
    "apen", "sampen",          # Approximate & sample entropy (EntropyHub, O(n²))
    "fuzzyen",                 # Fuzzy entropy (EntropyHub, O(n²))
    "shan_en", "svd_en",       # Shannon (histogram) & SVD entropy
    "spec_en", "perm_en",      # Spectral & permutation entropy (EntropyHub)
    "mse",                     # Multiscale entropy complexity index (EntropyHub)
    "hurst",                   # Hurst exponent (R/S analysis)
    "dfa1", "dfa2",            # Detrended Fluctuation Analysis exponents
    "renyi0", "renyi1", "renyi2",  # Rényi entropies of order 0, 1, 2
]

"""
    FAST_FEATURES

All registered features **except** the computationally expensive nonlinear ones
(entropy family `apen`/`sampen`/`fuzzyen`/`shan_en`/`svd_en`/`spec_en`/`perm_en`/`mse`,
plus `hurst`, `dfa1`, `dfa2`, `renyi0`, `renyi1`, `renyi2`).
Runs in O(n) or O(n log n) and is safe for arbitrarily long recordings.
"""
const FAST_FEATURES  = sort(setdiff(String.(keys(feature_registry)), NONLINEAR_FEATURES))

"""
    DEFAULT_FEATURES

The recommended default feature set.  Same as `FAST_FEATURES` but also excludes
`ulf` (ultra-low frequency power), which requires ≥ 24-hour recordings to be
meaningful.

This is the **default** for `extract_feature_set` and `windowed_feature_set`.
"""
const DEFAULT_FEATURES = sort(setdiff(FAST_FEATURES, ["ulf"]))

"""
    ALL_FEATURES

The complete feature set (53 features).  Includes the nonlinear features that
are O(n²) or worse.  Use only on recordings shorter than ~5 000 beats, or when
you can afford the compute.
"""
const ALL_FEATURES   = sort(String.(keys(feature_registry)))

""" Resolve a feature-set selector to a concrete `Vector{String}`. """
function _resolve_features(features)::Vector{String}
    if features isa Symbol
        features === :default && return DEFAULT_FEATURES
        features === :fast && return FAST_FEATURES
        features === :all  && return ALL_FEATURES
        features === :nonlinear && return NONLINEAR_FEATURES
        throw(ArgumentError("Unknown feature set symbol :$features.  Use :default, :fast, :all, or :nonlinear."))
    end
    return collect(String, features)
end

function extract_feature_set(
    n::AbstractArray{Float64,1};
    features::Union{Symbol, AbstractArray{String}}=:default,
    config::Dict{String,Any}=config,
)
    feat_names = _resolve_features(features)
    n = HRMeasurement(n)
    # Extract the features
    result = Dict{String,Any}()
    for f in feat_names # TODO: parallel processing
        f ∈ keys(feature_registry) || throw(ArgumentError("Invalid feature: $f"))
        feature = function_registry[f](n)
        result[f] = feature
    end
    return DataFrame(result) # Convert the result to a DataFrame
end

function windowed_feature_set(
    n::AbstractArray{Float64,1};
    window_size::Int=60, # Heart beats
    stride::Int=1,
    time::Symbol=:beats,
    features::Union{Symbol, AbstractArray{String}}=:default,
    config::Dict{String,Any}=config,
)
    feat_names = _resolve_features(features)
    res = windowed(
        n; window_size=window_size, stride=stride, time=time,
        f=(x -> extract_feature_set(Array(x); features=feat_names, config=config)),
    )
    println("Extracted $(length(res)) windows with $(length(feat_names)) features each.")
    return vcat(res...) # Concatenate the windows into a single DataFrame
end

"""
    valid_features(n_beats::Int) -> Vector{String}

Return a vector of feature names from the registry that are valid for a signal of `n_beats` inter-beat-intervals.

A feature is valid if its `minimum_length` requirement is ≤ `n_beats`. This is essential for
model evaluation, as generated synthetic IBI series may be short and cannot support all 44 features.

# Arguments
- `n_beats::Int`: Number of inter-beat-intervals (signal length)

# Returns
- `Vector{String}`: Names of features that can be computed for this signal length

# Example
```julia
valid_features(50)   # Features valid for 50-beat signals
valid_features(500)  # Features valid for 500-beat signals
```
"""
function valid_features(n_beats::Int)::Vector{String}
    valid = String[]
    for (fname, feature) in feature_registry
        if feature.minimum_length <= n_beats
            push!(valid, fname)
        end
    end
    return sort(valid)
end

# ─── Normative prior loading ───────────────────────────────────────────────────

"""
    load_normative_priors!(csv_path::String)

Load fitted normative distribution parameters from a CSV file and populate
the `prior_registry`.  Each row must have columns: `feature`, `family`,
`param1_name`, `param1_value`, `param2_name`, `param2_value`, `status`.

Only rows with `status == "ok"` are loaded.  The resulting entry is a concrete
`Distributions.jl` instance (e.g., `Normal(780.0, 143.7)`) that can be used
directly for PDF evaluation, sampling, or as a Bayesian prior.

# Example
```julia
load_normative_priors!(joinpath(@__DIR__, "..", "docs", "normative_priors.csv"))
prior_registry["rmssd"]  # => Gamma(1.234, 26.7)
```
"""
function load_normative_priors!(csv_path::String)
    isfile(csv_path) || error("Normative priors CSV not found: $csv_path")
    return _load_priors_csv_fallback(csv_path)
end

# Internal: fallback CSV parser (no CSV.jl dependency)
# Handles quoted fields containing commas.
function _parse_csv_line(line::AbstractString)::Vector{String}
    fields = String[]
    current = IOBuffer()
    in_quotes = false
    for c in line
        if c == '"'
            in_quotes = !in_quotes
        elseif c == ',' && !in_quotes
            push!(fields, String(take!(current)))
        else
            write(current, c)
        end
    end
    push!(fields, String(take!(current)))
    return fields
end

function _load_priors_csv_fallback(csv_path::String)
    lines = readlines(csv_path)
    isempty(lines) && return 0
    header = _parse_csv_line(lines[1])
    idx = Dict(strip(col) => i for (i, col) in enumerate(header))
    # Require essential columns
    for required in ("feature", "family", "param1_name", "param1_value",
                     "param2_name", "param2_value", "status")
        haskey(idx, required) || error("Missing column '$required' in $csv_path")
    end
    n_loaded = 0
    for line in lines[2:end]
        fields = _parse_csv_line(line)
        length(fields) < length(header) && continue
        strip(fields[idx["status"]]) != "ok" && continue
        dist = _reconstruct_distribution(
            strip(fields[idx["family"]]),
            strip(fields[idx["param1_name"]]), tryparse(Float64, strip(fields[idx["param1_value"]])),
            strip(fields[idx["param2_name"]]), tryparse(Float64, strip(fields[idx["param2_value"]]))
        )
        if dist !== nothing
            prior_registry[strip(fields[idx["feature"]])] = dist
            n_loaded += 1
        end
    end
    @info "Loaded $n_loaded normative priors from $csv_path"
    return n_loaded
end

"""
    _reconstruct_distribution(family, p1_name, p1_val, p2_name, p2_val)

Reconstruct a `Distributions.jl` instance from the CSV row fields.
"""
function _reconstruct_distribution(family::AbstractString,
                                    p1_name, p1_val,
                                    p2_name, p2_val)
    p1 = p1_val isa Number ? Float64(p1_val) : tryparse(Float64, string(p1_val))
    p2 = p2_val isa Number ? Float64(p2_val) : tryparse(Float64, string(p2_val))
    (p1 === nothing || isnan(p1)) && return nothing
    (p2 === nothing || isnan(p2)) && return nothing
    family_str = strip(String(family))
    if family_str == "Normal"
        return Distributions.Normal(p1, p2)
    elseif family_str == "Gamma"
        return Distributions.Gamma(p1, p2)
    elseif family_str == "Beta"
        return Distributions.Beta(p1, p2)
    elseif family_str == "LogNormal"
        return Distributions.LogNormal(p1, p2)
    else
        @warn "Unknown distribution family in priors CSV: $family_str"
        return nothing
    end
end

"""
    normative_prior(feature_name::String) -> Distribution or nothing

Return the fitted normative prior distribution for a feature, or `nothing`
if no prior has been loaded for that feature.

# Example
```julia
d = normative_prior("rmssd")
if d !== nothing
    println("RMSSD ~ ", typeof(d), params(d))
    println("95% CI: ", quantile(d, 0.025), " – ", quantile(d, 0.975))
end
```
"""
function normative_prior(feature_name::String)
    return get(prior_registry, feature_name, nothing)
end

"""
    prior_call_string(feature_name::String) -> String

Return a string representation of the Distributions.jl constructor call for the
normative prior of `feature_name`.  Returns `"nothing"` if no prior exists.

# Example
```julia
prior_call_string("rmssd")  # => "Gamma(1.234, 26.7)"
```
"""
function prior_call_string(feature_name::String)::String
    d = normative_prior(feature_name)
    d === nothing && return "nothing"
    return string(d)
end

# ─── Auto-load normative priors at module init ─────────────────────────────────
const _PRIORS_CSV_PATH = joinpath(@__DIR__, "..", "docs", "normative_priors.csv")
if isfile(_PRIORS_CSV_PATH)
    try
        _load_priors_csv_fallback(_PRIORS_CSV_PATH)
    catch e
        @warn "Failed to auto-load normative priors" exception=e
    end
end

end # Features