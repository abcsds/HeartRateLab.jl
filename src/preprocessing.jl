using DataInterpolations: DataInterpolations
using StatsBase: StatsBase

"""
    replace_zeros(n::Array{T,1}) where T<:Real

Turns any zero value into a NaN value.

Arguments:
    n: the array that contains the RR-intervals

Returns:
    the array without the zero values
"""
function replace_zeros(n::Array{T,1}) where {T<:Real}
    return Float64[e==0 ? NaN : e for e in n]
end

"""
    replace_bio_outliers(n::Array{T,1}) where T<:Real

Turns any rr-interval outside biologically plausible limits, i.e., less than 300 ms or greater than 2000 ms, into a NaN value.

Arguments:
    n: the array that contains the RR-intervals

Returns:
    the array without the intervals that are less than 300 ms or greater than 2000 ms
"""
function replace_bio_outliers(n::Array{T,1}; min=300, max=2000) where {T<:Real}
    return Float64[e<min || e>max ? NaN : e for e in n]
end

"""
    replace_statistical_outliers(n::Array{T,1}) where T<:Real

Turns any rr-interval outside the 2.5th and 97.5th percentiles into a NaN value.

Arguments:
    n: the array that contains the RR-intervals

Returns:
    the array without the intervals outside the 2.5th and 97.5th percentiles
"""
function replace_statistical_outliers(
    n::Array{T,1}; low::Float64=0.025, high::Float64=0.975
) where {T<:Real}
    l = StatsBase.quantile(n, low)
    h = StatsBase.quantile(n, high)
    return Float64[e<l || e>h ? NaN : e for e in n]
end

"""
    replace_ectopic_beats!(n::Array{T,1}; method::Symbol=:malik, threshold::Float64=0.2) where T<:Real

Replaces ectopic beats with NaN values.

Arguments:
    n: the array that contains the RR-intervals
    method: the method to replace the ectopic beats, default=:malik (options: :malik, :kamath, :acar, :karlsson, :custom)
    threshold: the threshold to replace the ectopic beats, default=0.2

Returns:
    the array without the ectopic beats
"""
function replace_ectopic_beats!(
    n::Array{Float64,1}; method::Symbol=:malik, threshold::Float64=0.2
)
    method ∉ [:malik, :kamath, :acar, :karlsson, :custom] &&
        throw(ArgumentError("Unsupported method: $method"))
    if method == :acar
        n_outliers = 0
        for i in 9:length(n)
            μ_acar = StatsBase.mean(filter(!isnan, n[(i - 8):i]))
            abs(μ_acar - n[i]) >= threshold * μ_acar && (n[i]=NaN; n_outliers += 1)
        end
    elseif method == :karlsson
        n_outliers = 0
        for i in 1:(length(n) - 2)
            μ_pn = n[i] + n[i + 2] / 2
            abs(μ_pn - n[i + 1]) >= threshold * μ_pn && (n[i + 1]=NaN; n_outliers += 1)
        end
    else
        n_outliers = 0
        last_outlier = false
        for i in 2:(length(n) - 1)
            # last_outlier && last_outlier = false && continue
            if last_outlier
                last_outlier = false
                continue
            end
            if method == :malik
                abs(n[i] - n[i + 1]) <= 0.2 * n[i] ||
                    (n[i]=NaN; last_outlier=true; n_outliers += 1)
            elseif method == :kamath
                0 <= (n[i + 1] - n[i]) <= 0.325 * n[i] ||
                    0 <= (n[i] - n[i + 1]) <= 0.245 * n[i] ||
                    (n[i]=NaN; last_outlier=true; n_outliers += 1)
            elseif method == :custom
                abs(n[i] - n[i + 1]) <= threshold * n[i] ||
                    (n[i]=NaN; last_outlier=true; n_outliers += 1)
            end
        end
    end
    @debug "Number of outliers: $n_outliers"
    return n
end
function replace_ectopic_beats(
    n::Array{Float64,1}; method::Symbol=:malik, threshold::Float64=0.2
)
    replace_ectopic_beats!(copy(n); method=method, threshold=threshold)
end

"""
    strip_extremes(n::Array{Float64,1})

Strips any NaN values from the extremes of the array of RR-intervals.

Arguments:
    n: the array that contains the RR-intervals

Returns:
    the array without the NaN values at the extremes
"""
function strip_extremes(n::Array{Float64,1})
    return n[findfirst(!isnan, n):findlast(!isnan, n)]
end

"""
    interpolate_nans!(n::Array{Float64,1}; method::Symbol=:linear)

Interpolates nan values in a time series.

Arguments:
    n: the array that contains the RR-intervals
    method: the interpolation method, default=:linear (options: :constant, :linear, :quadratic, :cubic)

Returns:
    the array with the interpolated values
"""
function interpolate_nans!(n::Array{Float64,1}; method::Symbol=:linear)
    n = strip_extremes(n)
    # Check if the number of missing values is valid
    n_nan = count(isnan, n)
    n_nan > length(n) / 2 &&
        throw(ArgumentError("Too many missing values: $n_nan out of $(length(n))"))

    # Identify indices of valid values and NaN values
    valid_indices = findall(!isnan, n)
    NaN_idx = findall(isnan, n)

    # Extract valid values
    valid_values = n[valid_indices]
    x = Float64.(collect(1:length(n)))
    # Select interpolation method
    if method == :constant
        itp = DataInterpolations.ConstantInterpolation(x[valid_indices], valid_values)
    elseif method == :linear
        itp = DataInterpolations.LinearInterpolation(x[valid_indices], valid_values)
    elseif method == :quadratic
        itp = DataInterpolations.QuadraticInterpolation(x[valid_indices], valid_values)
    elseif method == :cubic
        itp = DataInterpolations.CubicSpline(x[valid_indices], valid_values)
    else
        throw(ArgumentError("Unsupported interpolation method: $method"))
    end
    # Replace missing values with interpolated values
    n[NaN_idx] .= itp(NaN_idx)
    return n
end
function interpolate_nans(n::Array{Float64,1}; method::Symbol=:linear)
    interpolate_nans!(copy(n); method=method)
end

"""
    interpolate(n::Array{Float64,1}; method::Symbol=:linear, fs::Int=10)

Interpolates the RR-intervals to fit a given sampling rate.

Arguments:
    n: the array that contains the RR-intervals
    method: the interpolation method, default=:linear (options: :constant, :linear, :quadratic, :cubic)
    fs: the sampling rate, default=10 Hz

Returns:
    the array with the interpolated values
"""
function interpolate(n::Array{Float64,1}; method::Symbol=:linear, fs::Int=10)
    sum(isnan.(n)) > 0 &&
        throw(ArgumentError("The array contains $(sum(isnan.(n))) NaN values."))
    t = cumsum(n) .- n[1]
    if method == :constant
        itp = DataInterpolations.ConstantInterpolation(n, t)
    elseif method == :linear
        itp = DataInterpolations.LinearInterpolation(n, t)
    elseif method == :quadratic
        itp = DataInterpolations.QuadraticInterpolation(n, t)
    elseif method == :cubic
        itp = DataInterpolations.CubicSpline(n, t)
    else
        throw(ArgumentError("Unsupported interpolation method: $method"))
    end
    # Create a new time vector with the desired sampling rate
    return itp.(0:(1000 / fs):t[end])
end

"""
    windowed(n::Array{Float64,1}; window_size::Int=60, stride::Int=1, time::Symbol=:beats, f::Function=identity)

This function returns views of the array of RR-intervals in a sliding window. The sliding window can be defined in beats or milliseconds.

Arguments:
    n: the array that contains the RR-intervals
    window_size: the size of the window, default=60 (beats)
    stride: the step size of the sliding window, default=1 (beat)
    time: the time unit of the window, default=:beats (options: :beats, :ms)
    f: reducing function to apply to the window, default=identity

Returns:
    the views of the array in a sliding window, with the reducing function applied to each window
"""
function windowed(
    n::Array{Float64,1};
    window_size::Int=60,
    stride::Int=1,
    time::Symbol=:beats,
    f::Function=identity,
)
    if time == :beats
        return [
            f(view(n, i:(i + window_size - 1))) for
            i in 1:stride:(length(n) - window_size + 1)
        ]
    elseif time == :ms
        t = cumsum(n) .- n[1]
        max_t = t[end] # Record duration in ms
    else
        throw(ArgumentError("Unsupported time unit: $time"))
    end
    window_starts = 1:stride:max_t
    window_ends = window_starts .+ window_size
    views = Vector{Any}(undef, length(window_starts))
    for (i, (start, stop)) in enumerate(zip(window_starts, window_ends))
        idx = findall(x -> x >= start && x < stop, t)
        if !isempty(idx)
            views[i] = f(view(n, idx))
        end
    end
    return views
end
"""
    ms2bpm(n::Array{Float64,1})

Converts milliseconds to beats per minute (BPM).

Arguments:
    n: the array of RR-intervals in milliseconds

Returns:
    the array of RR-intervals in BPM
"""
ms2bpm(n::Float64) = 60000 / n
# ms2bpm(n::Array{Float64,1}) = 60000 ./ n
