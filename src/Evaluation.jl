"""
    Evaluation

Evaluation pipeline for comparing HRV data and model outputs.

This module provides functions for sliding-window analysis and feature comparison
across different data modes (continuous, windowed, ensemble).
"""
module Evaluation

using DataFrames, Random
using ..Features: extract_feature_set, valid_features
using ..Models: AbstractHRVModel

"""
    windowed_feature_set(data::Vector{Float64}; window_size::Int=300, overlap::Int=150) -> DataFrame

Extract HRV features from overlapping time windows of IBI data.

This enables **Mode 2 (Time Windows)** analysis: convert one continuous timeseries
into a distribution of feature vectors, one per window.

# Arguments
- `data::Vector{Float64}`: IBI timeseries (milliseconds)
- `window_size::Int=300`: Number of beats per window (default 300 beats ≈ 4-5 minutes)
- `overlap::Int=150`: Number of overlapping beats between windows (default 150 = 50% overlap)

# Returns
- `DataFrame`: One row per window, columns are valid features for `window_size`

# Details

**Window Computation:**
- First window: `data[1:window_size]`
- Second window: `data[(1 + window_size - overlap):(1 + window_size - overlap + window_size - 1)]`
- Continue until insufficient beats remain for a complete window

**Feature Selection:**
- Only features valid for `window_size` beats are included (via `valid_features()`)
- If a window has features that fail to compute, they are marked as `NaN`

**Edge Cases:**
- If `data` is shorter than `window_size`, returns empty DataFrame
- If `overlap >= window_size`, returns single window (or empty if too short)

# Examples

```julia
# Load HRV data
data = read_txt("subject.txt")  # 1000 beats

# Extract features from 5-minute windows with 50% overlap
windows = windowed_feature_set(data; window_size=300, overlap=150)
# Returns DataFrame with ~7 rows (windows) × ~40 columns (features)

# Use in evaluation
model_features = extract_ensemble_features(ensemble)  # 100 rows
eval_distributional(windows, model_features; test=:ks)  # Compare
```

# Performance

- Parallelizable: each window is independent
- Current implementation is sequential
- For large datasets (>10k beats), consider `Distributed.pmap()` wrapper
"""
function windowed_feature_set(
    data::Vector{Float64};
    window_size::Int=300,
    overlap::Int=150
)::DataFrame

    # Input validation
    if window_size <= 0
        throw(ArgumentError("window_size must be positive, got $window_size"))
    end
    if overlap < 0 || overlap >= window_size
        throw(ArgumentError("overlap must be in [0, window_size), got $overlap"))
    end

    # Calculate window positions
    step = window_size - overlap
    n_data = length(data)

    # Check if we have enough data for even one window
    if n_data < window_size
        # Return empty DataFrame with correct column structure
        valid_feats = valid_features(window_size)
        return DataFrame(Dict(f => Float64[] for f in valid_feats))
    end

    # Calculate number of complete windows
    # Formula: positions where window_start + window_size <= n_data + 1
    # window_start = 1 + (i-1)*step for i = 1, 2, 3, ...
    # => 1 + (i-1)*step + window_size <= n_data + 1
    # => (i-1)*step <= n_data - window_size
    # => i <= (n_data - window_size) / step + 1
    n_windows = div(n_data - window_size, step) + 1

    # Pre-compute valid features for this window size (efficiency)
    valid_feats = valid_features(window_size)

    # Extract features for each window
    windows_features = []

    for i in 1:n_windows
        # Calculate window indices
        start_idx = 1 + (i - 1) * step
        end_idx = start_idx + window_size - 1

        # Ensure we don't go past the end
        if end_idx > n_data
            break
        end

        window_data = @view data[start_idx:end_idx]

        # Extract features for this window (only valid ones)
        try
            window_feats = extract_feature_set(window_data)
            # Filter to only valid features for this window size
            filtered_feats = Dict(
                k => get(window_feats, k, NaN)
                for k in valid_feats
            )
            push!(windows_features, filtered_feats)
        catch e
            # If feature extraction fails, return NaN for all features
            failed_feats = Dict(f => NaN for f in valid_feats)
            push!(windows_features, failed_feats)
        end
    end

    # Convert to DataFrame
    if isempty(windows_features)
        valid_feats = valid_features(window_size)
        return DataFrame(Dict(f => Float64[] for f in valid_feats))
    end

    return DataFrame(windows_features)
end

"""
    simulate_ensemble(model::AbstractHRVModel, params::NamedTuple, n_beats::Int; n_sim::Int=100, rng=Random.default_rng()) -> Vector{Vector{Float64}}

Generate an ensemble of N independent synthetic IBI series from a model.

This enables **Mode 3 (Sampled Windows)** analysis: create a distribution of
synthetic timeseries, then extract features from each to get an empirical feature distribution.

# Arguments
- `model::AbstractHRVModel`: The HRV model to simulate from (LIF, VanDerPol, Lorenz, DMD, etc.)
- `params::NamedTuple`: Model parameters (typically from `fit()` result)
- `n_beats::Int`: Number of beats per simulated series
- `n_sim::Int=100`: Number of independent simulations to generate
- `rng=Random.default_rng()`: Random number generator for reproducibility

# Returns
- `Vector{Vector{Float64}}`: Ensemble of n_sim series, each is a Vector{Float64} of length ≈ n_beats

# Details

**Independence:**
- Each series is generated independently from the same model and parameters
- Series will differ due to stochastic components in the model (noise, MCMC, etc.)
- With fixed RNG seed, results are reproducible

**Stochastic vs Deterministic Models:**
- Stochastic models (LIF, VDP with noise) will produce different series each run
- Deterministic models (Lorenz, DMD) may produce identical series without perturbation

# Examples

```julia
# Fit model to data
lif = LIF()
result = fit(lif, data; method=:bayesian)

# Generate synthetic ensemble
ensemble = simulate_ensemble(lif, result.params, length(data); n_sim=100)
# Returns: Vector{Vector{Float64}} with 100 synthetic IBI series

# Extract features and compare
ensemble_features = extract_ensemble_features(ensemble)
eval_distributional(real_windows, ensemble_features; test=:ks)
```
"""
function simulate_ensemble(
    model::AbstractHRVModel,
    params::NamedTuple,
    n_beats::Int;
    n_sim::Int=100,
    rng=Random.default_rng()
)::Vector{Vector{Float64}}

    # Input validation
    if n_beats <= 0
        throw(ArgumentError("n_beats must be positive, got $n_beats"))
    end
    if n_sim <= 0
        throw(ArgumentError("n_sim must be positive, got $n_sim"))
    end

    # Generate n_sim independent series
    ensemble = Vector{Vector{Float64}}()

    for i in 1:n_sim
        # Simulate one series from the model
        # Note: RNG state automatically advances with each call
        series = simulate(model, params, n_beats)

        # Store the series
        push!(ensemble, series)
    end

    return ensemble
end

end  # Evaluation
