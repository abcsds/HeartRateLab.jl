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

import ..Preprocessing: ms2bpm, windowed
import .Frequency
using Base.max: max
using Base.min: min
using Base.diff: diff
using Base.length: length
using Base.cumsum: cumsum
using StatsBase: StatsBase
using Memoization
using MacroTools

config = Dict{String,Any}("freq_method" => :lomb_scargle, "fs" => 10)

struct HRMeasurement
    data::Array{T,1} where {T<:Real} # Inter-Beat-Intervals (IBIs) in milliseconds
    length::Int # N: number of IBIs
    time::Float64 # total duration of the recording in milliseconds
    fs::Int # sampling frequency in Hz
    duration::Float64 # in seconds
end
function HRMeasurement(data::Array{T,1} where {T<:Real}, fs::Int=config["fs"])
    time = cumsum(data)[end]
    length::Int = Base.length(data)
    @info "HRMeasurement created with $(length) samples, total duration: $(time) ms, sampling frequency: $(fs) Hz."
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

    # @debug "============================"
    # @debug ("Function name: ", function_name)
    # @debug ("Type of function_name: ", typeof(function_name))
    # @debug ("Arguments: ", args)
    # @debug ("Docstring: \n\fn", docstr)
    # @debug ("Domains: ", domains)
    # @debug ("Aliases: ", aliases)
    # @debug ("Representation: ", representation)
    # @debug "============================"

    # Return the memoized function definition
    # with standard documentation conventions
    # for evaluation, then add to the registry
    function_name ∈ keys(function_registry) &&
        @warn("Function $(function_name) is already registered. Overwriting.")
    res = quote
        """
        $($docstr)
        """
        # @memoize function $(f)($(args...))
        #     (args[1] isa HRMeasurement) ||  # Ensure the first argument is an HRMeasurement
        #         throw(ArgumentError("The first argument must be an HRMeasurement."))
        #     n = args[1].data # Extract the HRMeasurement data
        #     $(body...)
        # end
        function_registry[$(function_name)] = @memoize function $(f)($(args...))
            println("HRmeasurement? for $($function_name): ", $args[1])
            println(" ", occursin("HRMeasurement", repr($args[1])))
            (occursin("HRMeasurement", repr($args[1]))) ||  # Ensure the first argument is an HRMeasurement
                throw(ArgumentError("The first argument must be an HRMeasurement."))
            # n = $(args[1]).data # Extract the HRMeasurement data
            # println("type of n: ", typeof(n))
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
    # @debug "Memoized function definition: \n ==========================="
    # @debug esc(res)
    # @debug "============================"
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

# How about a register for the intermediate representation?
# Level 1 Direct staticstics
# @register "mean", [], ["time", "statistics"], StatsBase.mean
# @register "std", ["sdnn"], ["time", "statistics"], StatsBase.std
# @register "median", [], ["time", "statistics"], StatsBase.median
# @register "max", ["maximum_rr", "maximum_nn"], ["time", "statistics"], maximum
# @register "min", ["minimum_rr", "minimum_nn"], ["time", "statistics"], minimum
# @register_representation "diff", ["dnn", "difference_of_sequential_beats", "numeric_differentiation"], ["time"], diff
# @register_representation "length", ["n", "measurement_length", "number_of_measurements", "measurement_size"], ["statistics"], length
# @register_representation "duration", ["duration", "recording_duration"], ["time"], x -> cumsum(x)[end] # Record duration in ms

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
    return Base.cumsum(n.data)[end] # Record duration in ms
end

# # Level 2 Alternate representations
# @register "mean_hr", [], ["time", "statistics"], x -> ms2bpm(function_registry["mean"](x))
# @register "std_hr", [], ["time", "statistics"], x -> ms2bpm(function_registry["std"](x))
# @register "max_hr", [], ["time", "statistics"], x -> ms2bpm(function_registry["max"](x))
# @register "min_hr", [], ["time", "statistics"], x -> ms2bpm(function_registry["min"](x))
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

# # Level 3 Infered Statistics
# @register "sdsd", [], ["time", "statistics"], x -> function_registry["std"](function_registry["diff"](x))
# @register "range", [], ["time", "statistics"], x -> function_registry["max"](x) - function_registry["min"](x)
# @register "rmssd", [], ["time", "statistics"], x -> sqrt(sum(function_registry["diff"](x) .^ 2))
# @register "sdann" [],
# ["time", "statistics"],
# x -> StatsBase.std(
#     windowed(
#         x; window_size=5*60*1000, stride=5*60*1000, time=:ms, f=function_registry["mean"]
#     ),
# )
# @register "pnn50", [], ["time", "statistics"], x -> sum(function_registry["diff"](x) > 50) / function_registry["length"](x)
# @register "pnn20", [], ["time", "statistics"], x -> sum(function_registry["diff"](x) > 20) / function_registry["length"](x)
# @register "cvsd",
# [], ["time", "statistics"],
# x -> function_registry["sdsd"](x) / function_registry["mean"](x) # cvsd(n) = sqrt(StatsBase.mean(diff(n).^2))/StatsBase.mean(n)

# # rRR? TODO

# # Frequency features
# config["freq_method"] ∉ [:lomb_scargle, :welch] &&
#     throw(ArgumentError("Unsupported frequency method: $method"))

# # Frequency representation
# @register_representation "pgram", ["periodogram", "power_spectrum"], ["frequency"], x -> begin
#     config["freq_method"] ∉ [:lomb_scargle, :welch] && throw(ArgumentError("Unsupported method: $method"))
#     # max_t = function_registry["duration"](x) / 1000 # Record duration in seconds
#     if config["freq_method"] == :lomb_scargle
#         return Frequency.lomb_scargle(n)
#         # ulf=NaN
#     elseif config["freq_method"] == :welch
#         return Frequency.welch(n, method=:linear, fs=4) #TODO all other interpolation methods: config
#     else
#         throw(ArgumentError("Unsupported frequency method: $(config["freq_method"])"))
#     end
# end
# @register_representation "max_t", ["max_time", "recording_duration_s"], ["time"], x -> function_registry["duration"](x) / 1000 # Record duration in seconds
# @register "ulf", ["ultra_low_frequency"], ["frequency"], x -> begin
#     if config["freq_method"] == :lomb_scargle
#         return NaN # No ultra low frequency in Lomb-Scargle # TODO: why?
#     elseif config["freq_method"] == :welch && function_registry["max_t"](x) > 86000 # 24 hours
#         return Frequency.get_power(function_registry["pgram"](x), 0.003, 0.04)
#     else
#         return NaN
#     end
# end
# @register "vlf", ["very_low_frequency"], ["frequency"], x -> Frequency.get_power(function_registry["pgram"](x), 0.003, 0.04)
# @register "lf", ["low_frequency"], ["frequency"], x -> Frequency.get_power(function_registry["pgram"](x), 0.04, 0.15)
# @register "hf", ["high_frequency"], ["frequency"], x -> Frequency.get_power(function_registry["pgram"](x), 0.15, 0.4)
# @register "tp", ["total_power"], ["frequency"], x -> Frequency.get_power(function_registry["pgram"](x), 0.003, 0.4)
# @register "lf_peak", ["lf_peak"], ["frequency"], x -> find_peak(function_registry["pgram"](x), 0.04, 0.15)
# @register "hf_peak", ["hf_peak"], ["frequency"], x -> find_peak(function_registry["pgram"](x), 0.15, 0.4)
# # Proportions and ratios
# @register "lf_hf_ratio", ["lf_hf"], ["frequency"], x -> function_registry["lf"](x) / function_registry["hf"](x)
# @register "lf_relative", ["lf_relative_power"], ["frequency"], x -> begin
#     lf = function_registry["lf"](x)
#     tp = function_registry["tp"](x)
#     isnan(lf) || isnan(tp) ? NaN : lf / tp
# end
# @register "hf_relative", ["hf_relative_power"], ["frequency"], x -> begin
#     hf = function_registry["hf"](x)
#     tp = function_registry["tp"](x)
#     isnan(hf) || isnan(tp) ? NaN : hf / tp
# end
# # Alternative representations
# @register "lf_percentage", ["lf_%"], ["frequency"], x -> function_registry["lf_relative"](x) * 100
# @register "hf_percentage", ["hf_%"], ["frequency"], x -> function_registry["hf_relative"](x) * 100

# # Geometric features
# @register_representation "px", ["poincare_x", "poincare_x_axis"], ["geometric"], x -> begin
#     return [x[i] for i in 1:length(x)-1]
# end
# @register_representation "py", ["poincare_y", "poincare_y_axis"], ["geometric"], x -> begin
#     return [x[i+1] for i in 1:length(x)-1]
# end
# @register "sd1", ["sd1", "sd1_width"], ["geometric"], x -> begin
#     x = function_registry["px"](x)
#     y = function_registry["py"](x)
#     sd1 = sqrt(StatsBase.var((x - y) / sqrt(2)))
# end
# @register "sd2", ["sd2", "sd2_length"], ["geometric"], x -> begin
#     x = function_registry["px"](x)
#     y = function_registry["py"](x)
#     sd2 = sqrt(StatsBase.var((x + y) / sqrt(2)))
# end
# @register "sd2_sd1", ["sd2_sd1_ratio", "csi", "cardiac_sympathetic_index"], ["geometric"], x -> begin
#     return function_registry["sd2"](x) / function_registry["sd1"](x)
# end
# @register "sd1_sd2_area", ["poincare_area"], ["geometric"], x -> begin
#     return π * function_registry["sd1"](x) * function_registry["sd2"](x)
# end
# @register "cvi", ["cardiac_vagal_index"], ["geometric"], x -> begin
#     return log10(function_registry["sd2"](x) * function_registry["sd1"](x) * 16)
# end
# @register "ccsi", ["corrected_cardiac_sympathetic_index", "corrected_csi"], ["geometric"], x -> begin
#     return (4 * function_registry["sd2"](x) ^ 2) / function_registry["sd1"](x)
# end
# @register_representation "histogram", ["histogram"], ["geometric"], x -> begin
#     h = StatsBase.fit(StatsBase.Histogram, x, range(300, 2000, step=8))
#     return h
# end
# @register "triangular_index", ["triangular_index"], ["geometric"], x -> begin
#     histogram_weights = function_registry["histogram"](x).weights
#     return function_registry["length"](x) / maximum(histogram_weights)
# end
# #=
# This function calculates the TINN index of the HRV: The width of the RR interval histogram.
# [Read more](https://www.ahajournals.org/doi/full/10.1161/01.CIR.93.5.1043)[^1]
# [^1]: Heart Rate Variability | Circulation. (n.d.). Retrieved December 17, 2024, from https://www.ahajournals.org/doi/full/10.1161/01.CIR.93.5.1043
# :param n: the array that contains the NN-intervals
# =#
# @register "tinn", ["triangular_interpolation_of_nn_intervals"], ["geometric"], x -> begin
#     h = function_registry["histogram"](x)
#     iX = argmax(h.weights)
#     X = [h.edges[1];][iX]
#     Y = maximum(h.weights)
#     N_range = X<=300 ? [300] : range(300, X, step=8)
#     M_range = X>=2000 ? [2000] : range(X, 2000, step=8)
#     min_sse = 1e10
#     vars = []
#     for (i,n) in enumerate(N_range)
#         for (j,m) in enumerate(M_range)
#             D_edges = h.edges[1]
#             D_weights = h.weights
#             # @assert length(D_edges) == length(D_weights)
#             iN = findfirst(x->x==n, D_edges)
#             iM = findfirst(x->x==m, D_edges)
#             @assert iM <= length(D_edges)

#             Q_weights = zeros(length(D_weights))
#             a = iX - iN
#             b = iM - iX
#             a == 0 && (redg = [])
#             a == 1 && (Q_weights[iX] = Y)
#             a >= 2 && (Q_weights[iN:iX] = [i for i in LinRange(0, Y, iX-iN+1)])

#             b == 0 && (fedg = [])
#             b == 1 && (Q_weights[iX] = Y)
#             b >= 2 && (Q_weights[iX:iM-1] = [i for i in LinRange(Y, 0, iM-iX)])
#             Q_edges = D_edges
#             @assert length(D_weights) == length(Q_weights)
#             # Catch Float overflow
#             sse = Inf
#             try
#                 sse = sum((Q_weights .- D_weights) .^ 2)
#             catch
#                 @debug "Overflow, M: $m, N: $n"
#             end
#             if sse < min_sse
#                 min_sse = sse
#                 vars = [n, m, i, j]
#             end
#         end
#     end
#     N, M = vars[1], vars[2]
#     return M - N
# end # tinn

# Nonlinear features

function extract_feature_set(
    n::Array{Float64,1};
    features::Base.KeySet=keys(feature_registry),
    config::Dict{String,Any}=config,
)
    n = HRMeasurement(n)
    # Extract the features
    println("Extracting features: ", feature_registry)

    result = Dict{String,Any}()
    for f in features # TODO: parallel processing
        f ∈ keys(feature_registry) || throw(ArgumentError("Invalid feature: $f"))
        println("Extracting feature: ", f)
        feature = function_registry[f](n)
        result[f] = feature
    end
    # # Convert the result to a DataFrame
    cols = Symbol.(keys(result))
    println("Columns: ", cols)
    println("Result: ", result)
    result = DataFrame(result)

    return result # Result is a DataFrame with the features as columns, one single row
end

end
