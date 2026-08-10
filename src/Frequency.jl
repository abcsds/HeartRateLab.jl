"""This module provides functions for calculating frequency domain features from NN-interval data.
It includes methods for Lomb-Scargle periodograms, Welch periodograms, and power calculations
for specific frequency bands.
It also provides functions for finding peaks in the frequency domain."""
module Frequency

using LombScargle: LombScargle
using Trapz: Trapz
using DSP: DSP
using StatsBase: StatsBase
import ..interpolate

"""
    lomb_scargle(n::Array{Float64,1})

Calculates a Lomb-Scargle periodogram for the given array of NN-intervals.
Arguments:
    n: the array that contains the NN-intervals
Returns:
    the Lomb-Scargle periodogram object
"""
function lomb_scargle(n::AbstractArray{Float64,1})
    t=cumsum(n) .- n[1]
    t=t ./ 1000
    plan=LombScargle.plan(
        t, n; normalization=:psd, minimum_frequency=0.003, maximum_frequency=0.4
    )
    return LombScargle.lombscargle(plan)
end

"""
    welch(n::AbstractArray{Float64,1}; method::Symbol=:linear, fs::Int=4, kwargs...)
Calculates a Welch periodogram for the given array of NN-intervals.
Arguments:
    n: the array that contains the NN-intervals
    method: the interpolation method, default=:linear (options: :constant, :linear, :quadratic, :cubic)
    fs: the sampling rate, default=4 Hz
    kwargs: additional keyword arguments for the `DSP.welch_pgram` function
Returns:
    the Welch periodogram object
"""
function welch(n::AbstractArray{Float64,1}; method::Symbol=:linear, fs::Int=4, kwargs...)
    method in [:constant, :linear, :quadratic, :cubic] ||
        throw(ArgumentError("Unsupported interpolation method: $method"))
    s = interpolate(n; method=method, fs=fs)
    s = s .- StatsBase.mean(s)
    # Default call:
    # welch_pgram(s::AbstractVector, n=div(length(s), 8), noverlap=div(n, 2); onesided=eltype(s)<:Real, nfft=nextfastfft(n), fs=1, window)
    return DSP.welch_pgram(s; fs=fs, kwargs...)
end

"""
    get_power(pgram::LombScargle.LombScargle, min, max)
    get_power(pgram::DSP.Periodograms.Periodogram, min, max)
Calculates the power of a frequency band between two given frequencies.
Arguments:
    pgram: The periodogram object containing frequency and power data
    min: The minimum value of the frequency band to be calculated
    max: The maximum value of the frequency band to be calculated
Returns:
    p: The power of the frequency band
"""
function get_power(
    pgram::T, min, max
) where {T<:Union{LombScargle.LombScargle.Periodogram,DSP.Periodograms.Periodogram}}
    freq = pgram.freq
    power = pgram.power
    index = findall(x -> x >= min && x < max, freq)
    isempty(index) && return NaN
    return Trapz.trapz(freq[index[1]:index[end]], power[index[1]:index[end]])
end

"""
    find_peak(pgram::T, min, max)
Finds the peak frequency in a given range from a periodogram.
Arguments:
    pgram: The periodogram object containing frequency and power data
    min: The minimum value of the frequency range to be searched
    max: The maximum value of the frequency range to be searched
Returns:
    The frequency of the peak within the specified range, or NaN if no peak is found
"""
function find_peak(pgram::T, min, max) where {T<:Union{LombScargle.LombScargle.Periodogram,DSP.Periodograms.Periodogram}}
    freq = pgram.freq
    power = pgram.power
    index = findall(x->x>=min && x<max, freq)
    isempty(index) && return NaN
    # index[argmax(power[index])] gives the correct index in the original arrays
    peak_idx = index[argmax(power[index])]
    return freq[peak_idx]
end
end # Frequency
