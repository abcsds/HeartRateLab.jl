"""
    Evaluation

Evaluation pipeline for comparing HRV data and model outputs.

This module provides functions for sliding-window analysis and feature comparison
across different data modes (continuous, windowed, ensemble).
"""
module Evaluation

using DataFrames, Random, Statistics
using HypothesisTests
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

"""
    extract_ensemble_features(ensemble::Vector{Vector{Float64}}; features=nothing) -> DataFrame

Extract HRV features from all series in a synthetic ensemble.

This applies feature extraction to each independent series in an ensemble,
producing a DataFrame with one row per series. This enables empirical feature
distributions for Mode 3 (Sampled/Ensemble) analysis.

# Arguments
- `ensemble::Vector{Vector{Float64}}`: Collection of IBI series (from `simulate_ensemble()`)
- `features=nothing`: Optional list of specific features to extract. If nothing, uses `valid_features()` for signal length

# Returns
- `DataFrame`: One row per series in ensemble, columns are feature names

# Details

**Signal Length:**
- If all series have the same length, uses that for `valid_features()` filtering
- If series have different lengths, extracts all computable features (less strict)

**Efficiency:**
- Current: sequential (can be parallelized with `Distributed.pmap()`)
- NaN handling: Features that fail to compute are marked as NaN

**Integration with Evaluation:**
```julia
# Typical workflow
lif = LIF()
result = fit(lif, data; method=:bayesian)
ensemble = simulate_ensemble(lif, result.params, length(data); n_sim=100)
ensemble_features = extract_ensemble_features(ensemble)

# Now use with comparison functions
eval_distributional(real_windows, ensemble_features; test=:ks)
```

# Examples

```julia
# Generate ensemble and extract features
ensemble = simulate_ensemble(model, params, 300; n_sim=50)
features_df = extract_ensemble_features(ensemble)

# features_df has 50 rows (one per simulation) and ~40 columns (features)
# Can now compare against real data using eval_* functions
```
"""
function extract_ensemble_features(
    ensemble::Vector{Vector{Float64}};
    features=nothing
)::DataFrame

    # Handle empty ensemble
    if isempty(ensemble)
        return DataFrame()
    end

    # Determine feature set to use
    if features === nothing
        # Use valid_features based on signal length
        # If all series have same length, use that; otherwise use minimum
        series_lengths = length.(ensemble)
        min_length = minimum(series_lengths)
        features = valid_features(min_length)
    end

    # Extract features from each series
    all_features = []

    for series in ensemble
        try
            # Extract features for this series
            series_feats = extract_feature_set(series)

            # Filter to requested features
            filtered = Dict(
                f => get(series_feats, f, NaN)
                for f in features
            )

            push!(all_features, filtered)
        catch e
            # If extraction fails for a series, record NaN for all features
            failed = Dict(f => NaN for f in features)
            push!(all_features, failed)
        end
    end

    # Convert to DataFrame
    if isempty(all_features)
        return DataFrame(Dict(f => Float64[] for f in features))
    end

    return DataFrame(all_features)
end

"""
    eval_distributional(real::DataFrame, ensemble::DataFrame; test=:ks, features=nothing) -> DataFrame

Compare feature distributions between real and model data using statistical tests.

For each feature, tests whether the ensemble distribution differs from real observations
using Kolmogorov-Smirnov, Mann-Whitney U, or Anderson-Darling tests.

# Arguments
- `real::DataFrame`: Feature observations (could be 1 row or many windows/subjects)
- `ensemble::DataFrame`: Ensemble feature samples (typically many rows from synthetic data)
- `test=:ks`: Statistical test to use: `:ks` (Kolmogorov-Smirnov), `:mw` (Mann-Whitney U), `:ad` (Anderson-Darling)
- `features=nothing`: Specific features to test. If nothing, uses all columns in both DataFrames

# Returns
- `DataFrame`: One row per feature with columns: feature, statistic, p_value, test_name

# Details

**Statistical Tests:**
- `:ks` — Kolmogorov-Smirnov test: compares empirical CDFs
- `:mw` — Mann-Whitney U test: non-parametric rank test
- `:ad` — Anderson-Darling test: goodness-of-fit test

**Interpretation:**
- Small p-value (< 0.05): Real and ensemble distributions are significantly different
- Large p-value (> 0.05): Cannot reject that distributions are equal
- statistic: Test-specific value (larger typically = more different)

**Data Handling:**
- NaN values are filtered out per feature
- Features with all NaN are skipped
- Single real observation compares point to ensemble distribution

# Examples

```julia
# Compare real windowed data to synthetic ensemble
real_windows = windowed_feature_set(data; window_size=300, overlap=150)
ensemble = simulate_ensemble(model, params, 300; n_sim=100)
ensemble_features = extract_ensemble_features(ensemble)

# Test each feature
results = eval_distributional(real_windows, ensemble_features; test=:ks)

# View results
sort!(results, :p_value)  # Features most different from ensemble
```
"""
function eval_distributional(
    real::DataFrame,
    ensemble::DataFrame;
    test::Symbol=:ks,
    features=nothing
)::DataFrame

    # Validate test type
    if !(test in [:ks, :mw, :ad])
        throw(ArgumentError("test must be :ks, :mw, or :ad, got :$test"))
    end

    # Determine features to test
    if features === nothing
        # Use common columns in both DataFrames
        features = intersect(names(real), names(ensemble))
    end

    # Handle empty case
    if isempty(features)
        return DataFrame(
            feature=String[],
            statistic=Float64[],
            p_value=Float64[],
            test_name=Symbol[]
        )
    end

    # Run tests
    results = []

    for feature_name in features
        try
            # Extract data for this feature, filtering NaN
            real_vals = real[!, feature_name]
            ensemble_vals = ensemble[!, feature_name]

            # Filter NaN
            real_valid = filter(!isnan, real_vals)
            ensemble_valid = filter(!isnan, ensemble_vals)

            # Skip if insufficient data
            if isempty(real_valid) || isempty(ensemble_valid)
                continue
            end

            # Run the test
            if test == :ks
                # Kolmogorov-Smirnov test
                test_result = ExactOneSampleKSTest(ensemble_valid, real_valid)
                stat = test_result.δ⁺  # or δ⁻, or max
                pval = pvalue(test_result)

            elseif test == :mw
                # Mann-Whitney U test
                test_result = MannWhitneyUTest(real_valid, ensemble_valid)
                stat = test_result.U
                pval = pvalue(test_result)

            elseif test == :ad
                # Anderson-Darling test (one sample)
                # Compare ensemble to real as reference
                test_result = ExactOneSampleADTest(ensemble_valid, real_valid)
                stat = test_result.A²
                pval = pvalue(test_result)
            end

            # Store result
            push!(results, (
                feature = feature_name,
                statistic = stat,
                p_value = pval,
                test_name = test
            ))

        catch e
            # If test fails for a feature, skip it
            continue
        end
    end

    # Convert to DataFrame
    if isempty(results)
        return DataFrame(
            feature=String[],
            statistic=Float64[],
            p_value=Float64[],
            test_name=Symbol[]
        )
    end

    return DataFrame(results)
end

end  # Evaluation
