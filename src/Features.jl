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
using Hurst: hurst_exponent

# config = Dict{String,Any}("freq_method" => :lomb_scargle, "fs" => 10)
config = Dict{String,Any}("freq_method" => :welch, "fs" => 10)

struct HRMeasurement
    data::Array{T,1} where {T<:Real} # Inter-Beat-Intervals (IBIs) in milliseconds
    length::Int # N: number of IBIs
    time::Float64 # total duration of the recording in milliseconds
    fs::Int # sampling frequency in Hz
    duration::Float64 # in seconds
end
function HRMeasurement(data::Array{T,1} where {T<:Real}, fs::Int=config["fs"])
    time = cumsum(data)[end] - data[1] # total duration in milliseconds
    length::Int = Base.length(data)
    @info "HRMeasurement created with $(length) samples, total duration: $(round(time/60_000, digits=2)) min."
    return HRMeasurement(data, length, time, fs, time / 1000) # duration in seconds
end
struct HRFeature
    name::String
    func::Function
    alias::Array{String}
    domains::Array{String}
end
function HRFeature(
    name::String, func::Function; alias::Array{String}, domains::Array{String}
)
    return HRFeature(name, func, alias, domains)
end
feature_registry = Dict{String,HRFeature}()
representation_registry = Dict{String,HRFeature}()
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
    domains, aliases, representation = parse_docstring(docstr)

    # Return the memoized function definition
    # with standard documentation conventions
    # for evaluation, then add to the registry
    function_name ∈ keys(function_registry) &&
        @warn("Function $(function_name) is already registered. Overwriting.")
    res = quote
        """
        $($docstr)
        """
        function_registry[$(function_name)] = @memoize function $(f)($(args...))
            (occursin("HRMeasurement", repr($args[1]))) ||  # Ensure the first argument is an HRMeasurement
                throw(ArgumentError("The first argument must be an HRMeasurement."))
            # n = $(args[1]).data # Extract the HRMeasurement data
            $(body...)
        end
        if !($representation)
            feature_registry[$(function_name)] = HRFeature(
                $(function_name), $(f), $(aliases), $(domains)
            )
            # for a in $(aliases) # Register aliases
            #     feature_registry[a] = feature_registry[$(function_name)]
            # end
        else
            representation_registry[$(function_name)] = HRFeature(
                $(function_name), $(f), $(aliases), $(domains)
            )
            for a in $(aliases) # Register aliases
                representation_registry[a] = representation_registry[$(function_name)]
            end
        end
    end
    return esc(res) # Ensure the expression is evaluated in the correct context
end
# Extract "Domains", "Aliases", and "Representation" from the docstring
function parse_docstring(doc)
    domains = []
    aliases = []
    representation = false
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
        else
            continue
        end
    end
    return domains, aliases, representation
end

# Level 1 Direct staticstics
@register function mean(n::HRMeasurement)
    """
        mean(n::HRMeasurement)
    Calculate the average value in milliseconds of a given array of Inter-Beat-Intervals (IBIs).
    Arguments:
        - `n`: An array of Inter-Beat-Intervals in milliseconds.
    Domains: time, statistics
    Aliases: mean, average
    """
    return StatsBase.mean(n.data)
end

@register function std(n::HRMeasurement)
    """
        std(n::HRMeasurement)
    Calculate the standard deviation of the array `n`. This is the `sdnn`.
    Domains: time, statistics
    Aliases: std, sdnn
    """
    return StatsBase.std(n.data)
end

@register function median(n::HRMeasurement)
    """
        median(n::HRMeasurement)
    Calculate the median value of the array `n`.
    Domains: time, statistics
    Aliases: median
    """
    return StatsBase.median(n.data)
end

@register function max(n::HRMeasurement)
    """
        max(n::HRMeasurement)
    Calculate the maximum value of the array `n`. This is the largest Inter-Beat-Interval (IBI) in milliseconds.
    Domains: time, statistics
    Aliases: max, maximum_rr, maximum_nn
    """
    return Base.maximum(n.data)
end

@register function min(n::HRMeasurement)
    """
        min(n::HRMeasurement)
    Calculate the minimum of the array `n`. This is the smallest Inter-Beat-Interval (IBI) in milliseconds.
    Domains: time, statistics
    Aliases: min, minimum_rr, minimum_nn
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
    """
    return Base.cumsum(n.data)[end] - n.data[1] # Record duration in ms
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
    Aliases: std_hr, sdnn_hr
    """
    return ms2bpm(function_registry["std"](n))
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
    """
    return ms2bpm(function_registry["min"](n))
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
    """
    return function_registry["std"](function_registry["diff"](n))
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
    """
    return sqrt(sum(function_registry["diff"](n) .^ 2))
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
    """
    return function_registry["sdsd"](n) / function_registry["mean"](n)
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
    """
    if config["freq_method"] == :lomb_scargle
        # @warn "No ultra low frequency in Lomb-Scargle. Returning NaN."
        return NaN # No ultra low frequency in Lomb-Scargle # TODO: why?
    elseif config["freq_method"] == :welch && function_registry["max_t"](n) > 86000 # 24 hours
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
    Aliases: corrected_cardiac_sympathetic_index, corrected_csi
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
    """
    return function_registry["renyi"](n, 0)
end
@register function renyi1(n::HRMeasurement)
    """
        renyi1(n::HRMeasurement)
    See `renyi(n::HRMeasurement, order::Int=1)`.
    """
    return function_registry["renyi"](n, 1)
end
@register function renyi2(n::HRMeasurement)
    """
        renyi2(n::HRMeasurement)
    See `renyi(n::HRMeasurement, order::Int=2)`.
    """
    return function_registry["renyi"](n, 2)
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
    """
    scales, fluc = DFA.dfa(n.data, boxmax=64, boxmin=4, boxratio=2, overlap=0.0)
    log_scales = log10.(scales)
    log_fluc = log10.(fluc)
    intercept, α1 = DFA.polyfit(log_scales, log_fluc) # TODO: Viz
        
    scales, fluc = DFA.dfa(n.data, boxmax=16, boxmin=4, boxratio=2, overlap=0.0)
    log_scales = log10.(scales)
    log_fluc = log10.(fluc)
    intercept, α2 = DFA.polyfit(log_scales, log_fluc) # TODO: Viz
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
    """
    return function_registry["dfa"](n)[2]
end

function extract_feature_set(
    n::Array{Float64,1};
    features::AbstractArray{String}=String.(keys(feature_registry)),
    config::Dict{String,Any}=config,
)
    n = HRMeasurement(n)
    # Extract the features
    result = Dict{String,Any}()
    for f in features # TODO: parallel processing
        f ∈ keys(feature_registry) || throw(ArgumentError("Invalid feature: $f"))
        feature = function_registry[f](n)
        result[f] = feature
    end
    # cols = Symbol.(keys(result))
    return DataFrame(result) # Convert the result to a DataFrame
end

function windowed_feature_set(
    n::Array{Float64,1};
    window_size::Int=60, # Heart beats
    stride::Int=1,
    time::Symbol=:beats,
    features::AbstractArray{String}=String.(keys(feature_registry)),
    config::Dict{String,Any}=config,
)
    res = windowed(
        n; window_size=window_size, stride=stride, time=time,
        f=(x -> extract_feature_set(Array(x); features=features, config=config)),
    )
    println("Extracted $(length(res)) windows with $(length(features)) features each.")
    return vcat(res...) # Concatenate the windows into a single DataFrame
end

end # Features