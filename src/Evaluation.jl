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
using ..Models: AbstractHRVModel, simulate, ModelFitResult, DMD

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
    rng=Random.default_rng(),
    noise::Float64=0.02
)::Vector{Vector{Float64}}

    # Input validation
    if n_beats <= 0
        throw(ArgumentError("n_beats must be positive, got $n_beats"))
    end
    if n_sim <= 0
        throw(ArgumentError("n_sim must be positive, got $n_sim"))
    end
    if noise < 0
        throw(ArgumentError("noise must be non-negative, got $noise"))
    end

    # Generate n_sim independent series.
    #
    # Deterministic models (e.g. LIF) produce an identical IBI series on every
    # call for fixed params, which would make the ensemble degenerate (zero
    # variance, identical members). To obtain a genuine empirical distribution
    # we add a small amount of multiplicative observation noise to each beat,
    # drawn from `rng`. This keeps the ensemble reproducible under a seeded
    # `rng` while making the members independent. Stochastic models also
    # benefit from this measurement-noise layer; set `noise=0.0` to disable.
    ensemble = Vector{Vector{Float64}}()

    for i in 1:n_sim
        # Simulate one base series from the model
        series = simulate(model, params, n_beats)

        # Apply per-beat observation noise (multiplicative, mean-preserving)
        if noise > 0
            series = series .* (1.0 .+ noise .* randn(rng, length(series)))
        end

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

    # `extract_feature_set` accepts a list of String feature names.
    feat_names = collect(String, features)

    # Extract features from each series. `extract_feature_set` returns a
    # one-row DataFrame; we read that row into a NamedTuple-friendly Dict.
    all_features = Vector{Dict{String,Any}}()

    for series in ensemble
        try
            # Extract requested features for this series (one-row DataFrame)
            series_feats = extract_feature_set(series; features=feat_names)

            row = Dict{String,Any}(
                f => (f in names(series_feats) ? series_feats[1, f] : NaN)
                for f in feat_names
            )
            push!(all_features, row)
        catch e
            # If extraction fails for a series, record NaN for all features
            push!(all_features, Dict{String,Any}(f => NaN for f in feat_names))
        end
    end

    # Convert to DataFrame (always a DataFrame, even when empty)
    if isempty(all_features)
        return DataFrame([f => Float64[] for f in feat_names])
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

            # Run the test. All three are two-sample comparisons between the
            # real observations and the ensemble samples (both are empirical
            # samples, so one-sample-vs-distribution tests do not apply).
            if test == :ks
                # Two-sample Kolmogorov-Smirnov test (compares empirical CDFs)
                test_result = ApproximateTwoSampleKSTest(
                    Float64.(real_valid), Float64.(ensemble_valid)
                )
                stat = test_result.δ  # max CDF distance, always >= 0
                pval = pvalue(test_result)

            elseif test == :mw
                # Mann-Whitney U test (non-parametric rank test)
                test_result = MannWhitneyUTest(
                    Float64.(real_valid), Float64.(ensemble_valid)
                )
                stat = Float64(test_result.U)
                pval = pvalue(test_result)

            elseif test == :ad
                # k-sample Anderson-Darling test (goodness-of-fit)
                test_result = KSampleADTest(
                    Float64.(real_valid), Float64.(ensemble_valid)
                )
                stat = test_result.A²k
                pval = pvalue(test_result)
            end

            # Store result. `feature_name` is kept as-is (String when derived
            # from column names, Symbol when the caller passed a `features`
            # Symbol list) so downstream membership checks against the caller's
            # `features` argument behave consistently.
            push!(results, (
                feature = feature_name,
                statistic = Float64(stat),
                p_value = Float64(pval),
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

"""
    eval_scalar(real::DataFrame, ensemble::DataFrame; features=nothing) -> DataFrame

Compare scalar statistics (means and errors) between real and ensemble data.

For each feature, computes mean of real observations and ensemble samples,
then calculates absolute and relative errors.

# Arguments
- `real::DataFrame`: Real feature observations (one or more rows)
- `ensemble::DataFrame`: Ensemble feature samples (typically many rows)
- `features=nothing`: Specific features to compare. If nothing, uses common columns

# Returns
- `DataFrame`: One row per feature with columns: feature, real_mean, sim_mean, abs_error, rel_error

# Details

**Metrics:**
- `real_mean`: Mean of real feature observations
- `sim_mean`: Mean of ensemble feature samples
- `abs_error`: |real_mean - sim_mean| (absolute difference)
- `rel_error`: abs_error / (abs(real_mean) + 1e-8) (relative error, epsilon-normalized)

**Interpretation:**
- Small errors (< 0.05) indicate excellent model fit
- Medium errors (0.05-0.15) indicate good model fit
- Large errors (> 0.15) indicate model needs improvement

**Use Cases:**
- Quick overall quality metric (complement to p-values)
- Identifying which features are biased
- Benchmarking against baseline models

# Examples

```julia
real_windows = windowed_feature_set(data; window_size=300, overlap=150)
ensemble_features = extract_ensemble_features(ensemble)

errors = eval_scalar(real_windows, ensemble_features)

# Find most biased features
sort!(errors, :rel_error)
println(errors[1:5, :])  # Top 5 most biased
```
"""
function eval_scalar(
    real::DataFrame,
    ensemble::DataFrame;
    features=nothing
)::DataFrame

    # Determine features to compare
    if features === nothing
        features = intersect(names(real), names(ensemble))
    end

    # Handle empty case
    if isempty(features)
        return DataFrame(
            feature=String[],
            real_mean=Float64[],
            sim_mean=Float64[],
            abs_error=Float64[],
            rel_error=Float64[]
        )
    end

    # Compute metrics
    results = []

    for feature_name in features
        try
            # Get values
            real_vals = real[!, feature_name]
            ensemble_vals = ensemble[!, feature_name]

            # Filter NaN
            real_valid = filter(!isnan, real_vals)
            ensemble_valid = filter(!isnan, ensemble_vals)

            # Skip if insufficient data
            if isempty(real_valid) || isempty(ensemble_valid)
                continue
            end

            # Compute means
            real_mean = mean(real_valid)
            sim_mean = mean(ensemble_valid)

            # Compute errors
            abs_error = abs(real_mean - sim_mean)
            rel_error = abs_error / (abs(real_mean) + 1e-8)

            # Store result
            push!(results, (
                feature = feature_name,
                real_mean = real_mean,
                sim_mean = sim_mean,
                abs_error = abs_error,
                rel_error = rel_error
            ))

        catch e
            # Skip features that fail
            continue
        end
    end

    # Convert to DataFrame
    if isempty(results)
        return DataFrame(
            feature=String[],
            real_mean=Float64[],
            sim_mean=Float64[],
            abs_error=Float64[],
            rel_error=Float64[]
        )
    end

    return DataFrame(results)
end

"""
    eval_distance(real::DataFrame, ensemble::DataFrame; metric=:mahalanobis, features=nothing) -> NamedTuple

Compute feature-space distance between real and ensemble data.

Measures how far apart real observations and ensemble samples are in
multi-dimensional feature space using different distance metrics.

# Arguments
- `real::DataFrame`: Real feature observations (one or more rows)
- `ensemble::DataFrame`: Ensemble feature samples (typically many rows)
- `metric=:mahalanobis`: Distance metric: `:mahalanobis`, `:euclidean`
- `features=nothing`: Specific features to use. If nothing, uses common columns

# Returns
- `NamedTuple`: (distance=Float64, metric=Symbol, feature_contributions=Dict)

# Details

**Distance Metrics:**
- `:euclidean` — Standard L2 distance: √(Σ(x-y)²)
  - Simple, interpretable
  - Sensitive to scale differences

- `:mahalanobis` — Accounts for covariance structure: √((x-y)ᵀΣ⁻¹(x-y))
  - Accounts for feature correlations
  - Scale-invariant
  - More robust

**Feature Contributions:**
- Each feature's contribution to total distance
- Identifies which features drive the difference
- Useful for debugging model misspecification

**Interpretation:**
- Small distance (0-1) = good model fit
- Medium distance (1-5) = acceptable fit
- Large distance (>5) = poor model fit
- Depends on feature scaling and number of features

# Examples

```julia
result = eval_distance(real_features, ensemble_features; metric=:mahalanobis)

println("Distance: \$(result.distance)")
println("Metric: \$(result.metric)")
sort!(result.feature_contributions, rev=true) |> display  # Top contributors
```
"""
function eval_distance(
    real::DataFrame,
    ensemble::DataFrame;
    metric::Symbol=:mahalanobis,
    features=nothing
)::NamedTuple

    # Validate metric
    if !(metric in [:euclidean, :mahalanobis])
        throw(ArgumentError("metric must be :euclidean or :mahalanobis, got :$metric"))
    end

    # Determine features
    if features === nothing
        features = intersect(names(real), names(ensemble))
    end

    # Extract and prepare data
    real_vals = Matrix(real[:, features])
    ensemble_vals = Matrix(ensemble[:, features])

    # Filter rows with all NaN
    real_valid_rows = [any(!isnan, row) for row in eachrow(real_vals)]
    ensemble_valid_rows = [any(!isnan, row) for row in eachrow(ensemble_vals)]

    real_vals = real_vals[real_valid_rows, :]
    ensemble_vals = ensemble_vals[ensemble_valid_rows, :]

    if isempty(real_vals) || isempty(ensemble_vals)
        return (distance=NaN, metric=metric, feature_contributions=Dict())
    end

    # Replace remaining NaN with column mean
    for j in 1:size(real_vals, 2)
        real_col = real_vals[:, j]
        valid_real = real_col[.!isnan.(real_col)]
        if !isempty(valid_real)
            real_mean = mean(valid_real)
            for i in 1:size(real_vals, 1)
                if isnan(real_vals[i, j])
                    real_vals[i, j] = real_mean
                end
            end
        end

        ens_col = ensemble_vals[:, j]
        valid_ens = ens_col[.!isnan.(ens_col)]
        if !isempty(valid_ens)
            ens_mean = mean(valid_ens)
            for i in 1:size(ensemble_vals, 1)
                if isnan(ensemble_vals[i, j])
                    ensemble_vals[i, j] = ens_mean
                end
            end
        end
    end

    # Compute real mean vector
    real_mean = vec(mean(real_vals; dims=1))

    # Compute ensemble mean vector
    ensemble_mean = vec(mean(ensemble_vals; dims=1))

    # Compute difference vector
    diff = real_mean .- ensemble_mean

    # Compute distance based on metric
    if metric == :euclidean
        # Standard Euclidean distance
        distance = sqrt(sum(diff .^ 2))

        # Feature contributions: squared differences
        contributions = Dict(
            features[i] => diff[i]^2
            for i in 1:length(features)
        )

    elseif metric == :mahalanobis
        # Mahalanobis distance
        try
            # Compute covariance from ensemble
            centered = ensemble_vals .- ensemble_mean'
            cov_matrix = (centered' * centered) / (size(ensemble_vals, 1) - 1)

            # Add small regularization for numerical stability
            cov_matrix += I(size(cov_matrix, 1)) * 1e-6

            # Compute inverse
            cov_inv = inv(cov_matrix)

            # Mahalanobis distance
            distance = sqrt(diff' * cov_inv * diff)[1]

            # Feature contributions: weighted squared differences
            weighted_diff = cov_inv * diff
            contributions = Dict(
                features[i] => (diff[i] * weighted_diff[i])
                for i in 1:length(features)
            )

        catch e
            # If covariance inversion fails, fall back to Euclidean
            distance = sqrt(sum(diff .^ 2))
            contributions = Dict(
                features[i] => diff[i]^2
                for i in 1:length(features)
            )
        end
    end

    return (
        distance=Float64(distance),
        metric=metric,
        feature_contributions=contributions
    )
end

# ─── Information-criterion model ranking (d-20) ───────────────────────────────
#
# Given a set of fitted HRV models, rank them on an RR series by an information
# criterion (AIC/BIC). The purpose is to demonstrate *why* some models beat
# others — in particular why DMD is weaker (its mean-normalised, decaying
# reconstruction yields a too-narrow / mislocated IBI distribution, so it earns
# a low likelihood and is penalised further by its rank-r parameter count).

"""
    model_n_params(model::AbstractHRVModel, params::NamedTuple) -> Int

Effective number of free parameters of a fitted model, the `k` in AIC/BIC.

For the mechanistic models the continuous fitted parameters live in `params`
(LIF `I` ⇒ 1; VanDerPol `μ,heart_rate` ⇒ 2; Lorenz `σ,ρ,β,threshold` ⇒ 4), so
the default counts the `NamedTuple` fields. DMD is special-cased: it stores no
continuous parameters in `params` (it is data-driven) — its complexity is the
number of retained dynamic modes (the truncation rank `r`), which is what must
enter the criterion for an honest comparison.
"""
model_n_params(::AbstractHRVModel, params::NamedTuple) = length(params)
model_n_params(model::DMD, ::NamedTuple) = max(length(model.evals), 1)

"""
    model_loglikelihood(model, params, data; n_sim_beats) -> Float64

Gaussian log-likelihood of the observed IBI series `data` under a model. The
model contributes the mean `μ_sim` and variance `σ²_sim` of a simulated series;
the predictive variance is `σ² = max((1/n)·Σ(dataᵢ − μ_sim)², σ²_sim)` and

    logL = −½·(n·log 2π + n·log σ² + Σ(dataᵢ − μ_sim)² / σ²).

The `max(·)` combines two failure modes into one robust criterion:
- If the model under-predicts spread (`σ²_sim` too small — the near-deterministic
  mechanistic models), `σ²` falls back to the MLE residual variance
  `Var(data) + (mean(data) − μ_sim)²`, which rewards matching the data's mean.
- If the model over-predicts spread (`σ²_sim` larger than the residual variance),
  `σ²` uses `σ²_sim` and the likelihood is penalised for being too wide.

Why this rather than a beat-indexed-residual or a raw marginal `Normal(μ, σ)`
likelihood:
- Generative HRV models produce trajectories with their own phase, so
  `dataᵢ − simᵢ` residuals are meaningless even for a well-fitted model.
- A raw `Normal(μ_sim, σ_sim)` density is numerically ill-conditioned: the
  mechanistic models are near-deterministic, so `σ_sim → 0` (dominated by solver
  noise), which makes `logpdf` diverge for reasons unrelated to fit quality.
This form is robust (`σ² ≥ Var(data) > 0` for real data) and surfaces DMD's
documented weakness — its reconstruction forces the mean toward a fixed ~800 ms,
away from a typical recording's mean.

`n_sim_beats` controls the simulation length used to estimate `μ_sim`/`σ²_sim`;
the default (500) gives stable moment estimates and is independent of the data
length (some models — e.g. LIF's ODE solver — cannot cheaply produce tens of
thousands of beats). If the model cannot simulate the given parameters at all,
the likelihood is `-Inf` so that model ranks last rather than crashing a
comparison.
"""
function model_loglikelihood(
    model::AbstractHRVModel,
    params::NamedTuple,
    data::AbstractVector{<:Real};
    n_sim_beats::Int=500
)::Float64
    sim = try
        simulate(model, params, n_sim_beats)
    catch
        return -Inf
    end
    (isempty(sim) || !all(isfinite, sim)) && return -Inf

    μ = mean(sim)
    n = length(data)
    residual_mse = sum(abs2, data .- μ) / n      # = Var(data) + (mean(data) − μ)²
    var_sim = length(sim) > 1 ? var(sim) : 0.0
    σ2 = max(residual_mse, var_sim, eps())
    return -0.5 * (n * log(2π) + n * log(σ2) + residual_mse * n / σ2)
end

"""    aic(loglik, k) -> Float64

Akaike Information Criterion: `2k - 2·loglik`. Lower is better."""
aic(loglik::Real, k::Integer) = 2 * k - 2 * loglik

"""    bic(loglik, k, n) -> Float64

Bayesian (Schwarz) Information Criterion: `k·ln(n) - 2·loglik`, where `n` is the
number of observations. Lower is better; penalises parameters more than AIC."""
bic(loglik::Real, k::Integer, n::Integer) = k * log(n) - 2 * loglik

"""
    information_criteria(model, params, data; kwargs...) -> NamedTuple
    information_criteria(result::ModelFitResult; kwargs...) -> NamedTuple

Compute the information-criterion summary for a single fitted model on `data`.
Returns `(model, n_params, n_obs, loglik, aic, bic)`. `kwargs` are forwarded to
[`model_loglikelihood`](@ref) (e.g. `n_sim_beats`).
"""
function information_criteria(
    model::AbstractHRVModel,
    params::NamedTuple,
    data::AbstractVector{<:Real};
    kwargs...
)
    k = model_n_params(model, params)
    n = length(data)
    ll = model_loglikelihood(model, params, data; kwargs...)
    return (
        model = string(nameof(typeof(model))),
        n_params = k,
        n_obs = n,
        loglik = ll,
        aic = aic(ll, k),
        bic = bic(ll, k, n),
    )
end

information_criteria(result::ModelFitResult; kwargs...) =
    information_criteria(result.model, result.params, result.data; kwargs...)

"""
    rank_models(results::AbstractVector{ModelFitResult}; criterion=:bic, kwargs...) -> DataFrame

Rank a set of fitted models on their respective data by an information criterion.

Each `ModelFitResult` carries the fitted model, its parameters, and the data it
was fitted to. The returned `DataFrame` is sorted best-first (lowest `criterion`)
with columns:

- `model`     — model type name
- `n_params`  — effective free-parameter count `k` ([`model_n_params`](@ref))
- `n_obs`     — number of observed beats
- `loglik`    — Gaussian-residual log-likelihood ([`model_loglikelihood`](@ref))
- `aic`, `bic`— the two criteria
- `delta`     — `criterion - min(criterion)` (0 for the best model)
- `weight`    — Akaike/Schwarz weight `exp(-Δ/2) / Σ exp(-Δ/2)` (relative support)
- `rank`      — 1 = best

`criterion` must be `:aic` or `:bic` (default `:bic`). `kwargs` are forwarded to
[`model_loglikelihood`](@ref).
"""
function rank_models(
    results::AbstractVector{ModelFitResult};
    criterion::Symbol=:bic,
    kwargs...
)::DataFrame
    if !(criterion in (:aic, :bic))
        throw(ArgumentError("criterion must be :aic or :bic, got :$criterion"))
    end

    cols = (model=String[], n_params=Int[], n_obs=Int[], loglik=Float64[],
            aic=Float64[], bic=Float64[], delta=Float64[], weight=Float64[],
            rank=Int[])
    isempty(results) && return DataFrame(cols)

    df = DataFrame([information_criteria(r; kwargs...) for r in results])

    # Sort best-first by the chosen criterion (NaN, from models that failed to
    # simulate, sorts last under Julia's default ordering).
    sort!(df, criterion)

    crit = df[!, criterion]
    df.delta = crit .- minimum(crit)
    rel = exp.(-0.5 .* df.delta)               # unnormalised relative likelihoods
    df.weight = rel ./ sum(rel)
    df.rank = collect(1:nrow(df))
    return df
end

end  # Evaluation
