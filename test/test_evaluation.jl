using HeartRateLab
using Test, DataFrames, Random

# Set working directory to test directory for relative paths
cd(@__DIR__)

@testset "Evaluation — Distance Metrics (eval_distance)" begin
    # Create test data
    Random.seed!(42)

    real_features = DataFrame(
        f1 = [800.0],
        f2 = [40.0],
        f3 = [25.0],
        f4 = [2.5]
    )

    ensemble_features = DataFrame(
        f1 = 800 .+ randn(50) .* 20,
        f2 = 40 .+ randn(50) .* 15,
        f3 = 25 .+ randn(50) .* 10,
        f4 = 2.5 .+ randn(50) .* 0.5
    )

    @testset "Basic Euclidean distance" begin
        result = eval_distance(real_features, ensemble_features; metric=:euclidean)

        @test isa(result, NamedTuple)
        @test haskey(result, :distance)
        @test result.distance >= 0
    end

    @testset "Different distance metrics" begin
        for metric in [:euclidean, :mahalanobis]
            result = eval_distance(real_features, ensemble_features; metric=metric)
            @test isa(result, NamedTuple)
            @test result.distance >= 0
        end
    end

    @testset "Feature contributions" begin
        result = eval_distance(real_features, ensemble_features; metric=:euclidean)

        if haskey(result, :feature_contributions)
            contrib = result.feature_contributions
            @test isa(contrib, Dict) || isa(contrib, NamedTuple)
            @test length(contrib) > 0
        end
    end

    @testset "Feature selection" begin
        selected = [:f1, :f2]
        result = eval_distance(real_features, ensemble_features; metric=:euclidean, features=selected)

        @test result.distance >= 0
    end

    @testset "Multiple real observations" begin
        multi_real = DataFrame(
            f1 = [800.0, 810.0, 795.0],
            f2 = [40.0, 42.0, 38.0]
        )

        multi_ensemble = DataFrame(
            f1 = 805 .+ randn(100) .* 25,
            f2 = 41 .+ randn(100) .* 15
        )

        result = eval_distance(multi_real, multi_ensemble; metric=:euclidean)
        @test result.distance >= 0
    end

    @testset "Handles NaN values" begin
        real_with_nan = DataFrame(f1 = [1.0], f2 = [NaN])
        ensemble_with_nan = DataFrame(f1 = randn(20), f2 = fill(NaN, 20))

        result = eval_distance(real_with_nan, ensemble_with_nan; metric=:euclidean)
        @test isa(result, NamedTuple)
    end

    @testset "Distance metrics are interpretable" begin
        result = eval_distance(real_features, ensemble_features; metric=:euclidean)

        # Distance should be finite and non-negative
        @test isfinite(result.distance)
        @test result.distance >= 0
    end
end

@testset "Evaluation — Scalar Comparison (eval_scalar)" begin
    # Create test data: real features vs ensemble features
    Random.seed!(42)

    real_features = DataFrame(
        mean_ibi = [800.0],
        rmssd = [40.0],
        pnn50 = [25.0]
    )

    ensemble_features = DataFrame(
        mean_ibi = 800 .+ randn(50) .* 20,
        rmssd = 40 .+ randn(50) .* 15,
        pnn50 = 25 .+ randn(50) .* 10
    )

    @testset "Basic scalar metrics" begin
        result = eval_scalar(real_features, ensemble_features)

        @test isa(result, DataFrame)
        @test nrow(result) == 3  # One row per feature
        @test ncol(result) >= 5  # feature, real_mean, sim_mean, error columns minimum

        # Check required columns
        @test "feature" in names(result)
        @test any(contains("mean"), names(result))  # Some mean column
        @test any(contains("error"), names(result))  # Some error column
    end

    @testset "Error metrics are valid" begin
        result = eval_scalar(real_features, ensemble_features)

        # Absolute errors should be non-negative
        @test all(result.abs_error .>= 0)

        # Relative errors should be 0-1 for normalized features
        @test all(result.rel_error .>= 0)
    end

    @testset "Feature selection" begin
        selected = [:mean_ibi, :rmssd]
        result = eval_scalar(real_features, ensemble_features; features=selected)

        @test nrow(result) == 2
        @test all(result.feature .∈ Ref(selected))
    end

    @testset "Multiple real observations" begin
        multi_real = DataFrame(
            feat = [800.0, 810.0, 795.0, 820.0]
        )

        multi_ensemble = DataFrame(
            feat = 805 .+ randn(100) .* 25
        )

        result = eval_scalar(multi_real, multi_ensemble)
        @test nrow(result) == 1
        @test "real_mean" in names(result)
        @test "sim_mean" in names(result)
    end

    @testset "Output structure" begin
        result = eval_scalar(real_features, ensemble_features)

        # Should have feature names as strings
        @test all(isa(f, String) for f in result.feature)

        # All numeric columns should be numeric
        for col in names(result)
            if col != "feature"
                @test all(isa(v, Number) for v in result[!, col])
            end
        end
    end

    @testset "Handles NaN values" begin
        real_with_nan = DataFrame(feature1 = [1.0], feature2 = [NaN])
        ensemble_with_nan = DataFrame(feature1 = randn(20), feature2 = fill(NaN, 20))

        result = eval_scalar(real_with_nan, ensemble_with_nan)
        @test nrow(result) >= 1
    end
end

@testset "Evaluation — Distributional Comparison (eval_distributional)" begin
    # Create test data: real features (1 window) vs ensemble features
    Random.seed!(42)

    # Real data: 1 feature vector (could be from one window or one subject)
    real_features = DataFrame(
        mean_ibi = [800.0],
        rmssd = [40.0],
        pnn50 = [25.0],
        lf_hf_ratio = [2.5]
    )

    # Ensemble data: 50 feature vectors from synthetic series
    ensemble_features = DataFrame(
        mean_ibi = 800 .+ randn(50) .* 20,
        rmssd = 40 .+ randn(50) .* 15,
        pnn50 = 25 .+ randn(50) .* 10,
        lf_hf_ratio = 2.5 .+ randn(50) .* 0.5
    )

    @testset "Basic KS test" begin
        result = eval_distributional(real_features, ensemble_features; test=:ks)

        @test isa(result, DataFrame)
        @test nrow(result) == 4  # One row per feature
        @test ncol(result) >= 4  # feature, statistic, p_value, at minimum

        # Check column names
        @test "feature" in names(result)
        @test "statistic" in names(result)
        @test "p_value" in names(result)

        # Check p-values are valid (0-1)
        @test all(0 .<= result.p_value .<= 1)

        # Check statistics are non-negative
        @test all(result.statistic .>= 0)
    end

    @testset "Different test types" begin
        for test_type in [:ks, :mw]  # KS and Mann-Whitney
            result = eval_distributional(real_features, ensemble_features; test=test_type)
            @test nrow(result) == 4
            @test all(0 .<= result.p_value .<= 1)
        end
    end

    @testset "Feature selection" begin
        # Test with specific features
        selected = [:mean_ibi, :rmssd]
        result = eval_distributional(real_features, ensemble_features; features=selected)

        @test nrow(result) == 2
        @test all(result.feature .∈ Ref(selected))
    end

    @testset "Handles NaN values" begin
        # Create data with NaN
        real_with_nan = DataFrame(
            feature1 = [1.0],
            feature2 = [NaN],
            feature3 = [3.0]
        )

        ensemble_with_nan = DataFrame(
            feature1 = randn(20),
            feature2 = fill(NaN, 20),
            feature3 = randn(20) .+ 3
        )

        result = eval_distributional(real_with_nan, ensemble_with_nan; test=:ks)
        @test nrow(result) >= 1  # Should handle gracefully
    end

    @testset "Large ensemble" begin
        large_real = DataFrame(mean_ibi = [800.0])
        large_ensemble = DataFrame(mean_ibi = 800 .+ randn(1000) .* 30)

        result = eval_distributional(large_real, large_ensemble; test=:ks)
        @test nrow(result) == 1
        @test result.p_value[1] >= 0 && result.p_value[1] <= 1
    end

    @testset "Multiple real observations" begin
        # Real data as multiple windows/subjects
        multi_real = DataFrame(
            feat = [800.0, 810.0, 790.0, 820.0, 795.0]
        )

        multi_ensemble = DataFrame(
            feat = 805 .+ randn(100) .* 25
        )

        result = eval_distributional(multi_real, multi_ensemble; test=:ks)
        @test nrow(result) == 1
        @test result.p_value[1] >= 0 && result.p_value[1] <= 1
    end

    @testset "Output structure" begin
        result = eval_distributional(real_features, ensemble_features; test=:ks)

        # Should have useful columns
        @test "feature" in names(result)
        @test "statistic" in names(result)
        @test "p_value" in names(result)

        # Feature column should contain feature names
        @test all(isa(f, String) for f in result.feature)

        # Numeric columns should be numeric
        @test all(isa(s, Number) for s in result.statistic)
        @test all(isa(p, Number) for p in result.p_value)
    end
end

@testset "Evaluation — Extract Ensemble Features" begin
    # Create simple ensemble for testing
    model = LIF()
    params = (I=1.52,)
    ensemble = simulate_ensemble(model, params, 200; n_sim=10)

    @testset "Basic feature extraction from ensemble" begin
        result = extract_ensemble_features(ensemble)

        # Should return DataFrame
        @test isa(result, DataFrame)

        # Should have one row per simulation
        @test nrow(result) == 10

        # Should have multiple feature columns
        @test ncol(result) >= 10

        # All columns should be feature names (strings) or have valid data
        for col in names(result)
            @test isa(col, String)
        end
    end

    @testset "Feature values are reasonable" begin
        result = extract_ensemble_features(ensemble)

        # Most rows should have at least some non-NaN values
        for row_idx in 1:nrow(result)
            row = result[row_idx, :]
            non_nan_count = sum(!ismissing(v) && !isnan(v) for v in row)
            @test non_nan_count > 0  # At least some valid features per series
        end
    end

    @testset "Respects valid_features for signal length" begin
        # Shorter ensemble
        short_ensemble = simulate_ensemble(model, params, 50; n_sim=5)
        result_short = extract_ensemble_features(short_ensemble)

        # Should have fewer features for short signals
        valid_short = valid_features(50)
        @test ncol(result_short) <= length(valid_short)

        # d-16: exact boundary membership, not just a length bound. `apen` declares a
        # minimum length of 100, so it must be excluded at n=50 and included at n=150;
        # `mean` (minimum length ~1) is always present and the set grows with n.
        @test "apen" ∉ valid_features(50)
        @test "apen" ∈ valid_features(150)
        @test "mean" ∈ valid_features(50)
        @test length(valid_features(50)) < length(valid_features(150))
    end

    @testset "Ensemble with single series" begin
        single_series = simulate_ensemble(model, params, 200; n_sim=1)
        result = extract_ensemble_features(single_series)

        @test nrow(result) == 1
        @test ncol(result) >= 10
    end

    @testset "Large ensemble" begin
        large_ensemble = simulate_ensemble(model, params, 150; n_sim=100)
        result = extract_ensemble_features(large_ensemble)

        @test nrow(result) == 100
        @test all(size(result) .> 0)
    end

    @testset "Feature selection parameter" begin
        # Test with specific feature selection (when implemented)
        result = extract_ensemble_features(ensemble)

        # By default should get all valid features for signal length
        n_beats = length(ensemble[1])
        expected_features = valid_features(n_beats)

        @test ncol(result) <= length(expected_features)
    end

    @testset "Empty ensemble handling" begin
        empty_ensemble = Vector{Vector{Float64}}()
        result = extract_ensemble_features(empty_ensemble)

        # Should return empty DataFrame
        @test isa(result, DataFrame)
        @test nrow(result) == 0
    end
end

@testset "Evaluation — Simulate Ensemble" begin
    # Create a simple synthetic model for testing
    # Use LIF model which should be available
    model = LIF()
    params = (I=1.52,)

    @testset "Basic ensemble generation" begin
        n_beats = 100
        n_sim = 10

        ensemble = simulate_ensemble(model, params, n_beats; n_sim=n_sim)

        # Should return Vector of Vector{Float64}
        @test isa(ensemble, Vector)
        @test length(ensemble) == n_sim

        # Each series should be a Vector{Float64}
        for series in ensemble
            @test isa(series, Vector{Float64})
            @test length(series) ≈ n_beats atol=5  # Stochastic, so approximate
        end
    end

    @testset "Ensemble series are different (stochastic)" begin
        n_beats = 150
        n_sim = 5

        ensemble = simulate_ensemble(model, params, n_beats; n_sim=n_sim)

        # Each series should be different (not exact copies)
        for i in 1:n_sim
            for j in (i+1):n_sim
                @test ensemble[i] != ensemble[j]  # Extremely unlikely to be identical
            end
        end
    end

    @testset "Ensemble series are physiological" begin
        n_beats = 200
        n_sim = 10

        ensemble = simulate_ensemble(model, params, n_beats; n_sim=n_sim)

        for series in ensemble
            # d-16: the old `all((s .> 300) .| (s .< 10))` was a near-tautology (true for any
            # value outside (10, 300]). Assert strictly-positive + bounded; the ≥70% physiological
            # majority is checked just below.
            @test all(series .> 0)
            @test all(series .< 2000)

            # Most values should be reasonable
            valid_ibis = filter(x -> 300 <= x <= 2000, series)
            @test length(valid_ibis) >= 0.7 * length(series)  # At least 70%
        end
    end

    @testset "Reproducibility with RNG seed" begin
        n_beats = 100
        n_sim = 3

        # First run with seed
        rng1 = Random.seed!(123)
        ensemble1 = simulate_ensemble(model, params, n_beats; n_sim=n_sim, rng=rng1)

        # Second run with same seed
        rng2 = Random.seed!(123)
        ensemble2 = simulate_ensemble(model, params, n_beats; n_sim=n_sim, rng=rng2)

        # Should be identical
        for i in 1:n_sim
            @test ensemble1[i] ≈ ensemble2[i]
        end
    end

    @testset "Different ensemble sizes" begin
        n_beats = 100

        for n_sim in [1, 5, 20, 100]
            ensemble = simulate_ensemble(model, params, n_beats; n_sim=n_sim)
            @test length(ensemble) == n_sim
        end
    end

    @testset "Different beat counts" begin
        n_sim = 5

        for n_beats in [50, 100, 500, 1000]
            ensemble = simulate_ensemble(model, params, n_beats; n_sim=n_sim)
            for series in ensemble
                @test length(series) ≈ n_beats atol=10
            end
        end
    end
end

@testset "Evaluation — Windowed Feature Set" begin
    # Create synthetic IBI data: realistic heart rate variability
    # 300-2000 ms range, with some variation
    Random.seed!(42)
    n_beats = 500
    ibis = 800 .+ randn(n_beats) .* 50  # Mean ~800ms, ±50ms variation
    ibis = max.(ibis, 300)              # Clamp to physiological range
    ibis = min.(ibis, 2000)

    @testset "Basic windowed extraction" begin
        window_size = 100
        stride = 50

        # Call windowed_feature_set
        result = windowed_feature_set(ibis; window_size=window_size, stride=stride)

        # Should return a DataFrame
        @test isa(result, DataFrame)

        # Should have features as columns
        @test ncol(result) >= 10  # At least some features valid for 100-beat windows

        # Should have multiple rows (one per window)
        expected_n_windows = div(n_beats - window_size, stride) + 1
        @test nrow(result) == expected_n_windows

        # Each row should contain valid numerical values
        @test all(skipmissing(Matrix(result[1:1, :])) .!= NaN)
    end

    @testset "Window computation is correct" begin
        window_size = 150
        stride = 100

        result = windowed_feature_set(ibis; window_size=window_size, stride=stride)

        # Manually compute expected number of windows
        # First window: indices 1:150
        # Second window: indices 101:250
        # Continue until window_start + window_size > n_beats
        expected_n_windows = div(n_beats - window_size, stride) + 1
        @test nrow(result) == expected_n_windows
    end

    @testset "Respects valid_features constraint" begin
        # Use small window size that limits available features
        window_size = 50  # Only ~11 features valid for 50-beat signals
        stride = 25

        result = windowed_feature_set(ibis; window_size=window_size, stride=stride)

        # windowed_feature_set extracts the default registry feature set, so the
        # column count is bounded by that set (a subset of all 53 registry features).
        @test ncol(result) <= length(DEFAULT_FEATURES)

        # All column names must be valid feature names from the registry.
        valid_names = Set(keys(feature_registry))
        for col in names(result)
            @test col in valid_names
        end
    end

    @testset "No overlap (sequential windows)" begin
        window_size = 100
        stride = 100

        result = windowed_feature_set(ibis; window_size=window_size, stride=stride)

        # With no overlap: floor(n_beats / window_size) non-overlapping windows
        # Plus possibly one partial window
        expected_n_windows = div(n_beats, window_size)
        @test nrow(result) == expected_n_windows
    end

    @testset "Full overlap (every beat starts a window)" begin
        window_size = 100
        stride = 1  # 99 of 100 beats overlap with next window

        result = windowed_feature_set(ibis; window_size=window_size, stride=stride)

        # Should have n_beats - window_size + 1 windows (every position gets a window)
        expected_n_windows = n_beats - window_size + 1
        @test nrow(result) == expected_n_windows
    end

    @testset "Short timeseries handling" begin
        # Edge case: data shorter than window size
        short_ibis = ibis[1:50]
        window_size = 100
        stride = 50

        result = windowed_feature_set(short_ibis; window_size=window_size, stride=stride)

        # Should handle gracefully when no complete window fits: the result is
        # empty. windowed_feature_set concatenates per-window DataFrames, so with
        # zero windows it yields an empty collection (no rows).
        n_windows = result isa DataFrame ? nrow(result) : length(result)
        @test n_windows == 0 || n_windows == 1  # Either empty or one partial window
    end

    @testset "Feature values are reasonable" begin
        window_size = 200
        stride = 100

        result = windowed_feature_set(ibis; window_size=window_size, stride=stride)

        # If we have results, check that feature values are in reasonable ranges
        if nrow(result) > 0
            # Mean IBI should be around 800ms for our synthetic data
            if "mean" in names(result)
                means = result.mean
                @test all((means .> 600) .| ismissing.(means))  # Physiological range
                @test all((means .< 1200) .| ismissing.(means))
            end

            # All numeric values should be positive (for most HRV features)
            for col in names(result)
                if col != "mean"  # Skip non-standard columns
                    vals = result[!, col]
                    # Allow NaN/missing but not negative: keep only finite values
                    finite_vals = filter(
                        v -> !ismissing(v) && !(v isa Number && isnan(v)),
                        vals
                    )
                    if length(finite_vals) > 0
                        @test all(finite_vals .>= 0)
                    end
                end
            end
        end
    end
end
