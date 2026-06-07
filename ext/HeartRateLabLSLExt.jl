"""
    HeartRateLabLSLExt

Extension providing real-time HRV analysis and visualization via Lab Streaming Layer (LSL).

This extension is loaded automatically when LSL is imported alongside HeartRateLab.

# Real-Time Capabilities

## Online Processing
- Stream heart rate data from wearable devices or acquisition software via LSL
- Compute HRV features on a sliding window basis
- Update visualizations in real-time as new beats arrive

## Streaming Sources
- Wearable HR monitors (Polar, Garmin, Whoop, etc.)
- EEG systems with cardiac channel
- ECG amplifiers with R-peak detection
- Custom applications sending IBI over LSL

## Visualization Functions (to be implemented)
- `plot_live_rr()`: Real-time RR-interval time series
- `plot_live_heart_rate()`: Heart rate evolution
- `plot_live_poincare()`: Dynamic Poincaré plot with trailing history
- `plot_live_spectrum()`: Updating frequency spectrum
- `plot_live_features()`: Feature evolution over time

## Biofeedback Features (to be implemented)
- `breathing_pacer()`: Visual breathing pace guidance
- `hrv_gauge()`: Real-time HRV metric display
- `resonance_training()`: Interactive HRV optimization feedback

All real-time functions integrate with GLMakie for visualization.
For offline analysis of recorded data, see `HeartRateLabVisualizationExt`.

# LSL Protocol

Expects an LSL stream with:
- Stream name: "RR" or "IBI" (or configurable)
- Data type: Float64 (inter-beat-intervals in milliseconds)
- Sampling rate: Variable (beat-based, not clock-based)
- Channel count: 1

# Example (when implemented)
```julia
using HeartRateLab
using LSL  # This loads the LSL extension

# Connect to a live heart rate stream
stream = open_stream("RR")

# Create a real-time display
fig = plot_live_poincare(stream; window_size=100)
display(fig)

# Stream will continuously update the plot as new data arrives
```

# References
- Lab Streaming Layer: https://github.com/sccn/labstreaminglayer
- Julia LSL binding: https://github.com/abcsds/LSL.jl
"""
module HeartRateLabLSLExt

# Import the parent module
import HeartRateLab
using HeartRateLab.Models

# Conditional imports based on Julia version
if !isdefined(Base, :get_extension)
    error("Package extensions require Julia >= 1.9")
end

# LSL and async/concurrent processing
using LSL

# TODO: Phase 4+ - Real-time LSL implementations will be added here:
# - Stream connection management
# - Online windowing and buffering
# - Real-time feature computation
# - plot_live_rr()
# - plot_live_heart_rate()
# - plot_live_poincare()
# - plot_live_spectrum()
# - plot_live_features()
# - Biofeedback visualizations

"""
    rr_source(; pattern=r"^(RR|PP)", timeout=1.0) -> Function

Resolve a live LSL RR/PP stream (int32 beat intervals in milliseconds, e.g. from
HRBand-LSL or RRStreamer), open an inlet, and return a zero-argument function that
pulls and returns the next RR interval in ms (or `NaN` when no sample is available
this tick). Blocks until at least one stream is present, then selects the first whose
`source_id` matches `pattern` (falling back to the first available stream).

Refactored from the former global-state `src/Visualization/heart_rate_tt.jl` script
so it can drive `HeartRateLab.Visualization.live(source=:lsl)`.
"""
function rr_source(; pattern::Regex=r"^(RR|PP)", timeout::Real=1.0)
    streams = LSL.resolve_streams(timeout=timeout)
    while isempty(streams)
        @info "No LSL streams found — retrying (start HRBand-LSL or RRStreamer)…"
        streams = LSL.resolve_streams(timeout=timeout)
    end
    names = [LSL.source_id(s) for s in streams]
    idx = findfirst(n -> occursin(pattern, n), names)
    idx === nothing && (idx = 1)  # fall back to the first stream
    stream = streams[idx]
    @info "Connected to LSL stream: $(LSL.source_id(stream))"
    inlet = LSL.StreamInlet(stream)
    LSL.open_stream(inlet)
    return function ()
        timestamp, sample = LSL.pull_sample(inlet, timeout=timeout)
        (timestamp == 0.0 || isempty(sample) || sample[1] <= 0) && return NaN
        return Float64(sample[1])
    end
end

"""
    __init__()

Initialize the LSL extension. Called automatically when LSL is loaded.
"""
function __init__()
    # This function is called automatically when the extension is loaded
end

end  # HeartRateLabLSLExt
