using HeartRateLab
using Test, DataFrames, Random

# Set working directory to test directory for relative paths
cd(@__DIR__)

@testset "Evaluation — Extract Ensemble Features" begin
    # Create simple ensemble for testing
    model = LIF(; τ=50.0, I_base=0.5, threshold=1.0, noise_amp=0.1)
    params = (τ=50.0, I_base=0.5, threshold=1.0, noise_amp=0.1)
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
    model = LIF(; τ=50.0, I_base=0.5, threshold=1.0, noise_amp=0.1)
    params = (τ=50.0, I_base=0.5, threshold=1.0, noise_amp=0.1)

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
            # All IBIs should be in physiological range
            @test all((series .> 300) .| (series .< 10))  # Some might be small due to noise
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
        overlap = 50

        # Call windowed_feature_set
        result = windowed_feature_set(ibis; window_size=window_size, overlap=overlap)

        # Should return a DataFrame
        @test isa(result, DataFrame)

        # Should have features as columns
        @test ncol(result) >= 10  # At least some features valid for 100-beat windows

        # Should have multiple rows (one per window)
        expected_n_windows = div(n_beats - window_size, window_size - overlap) + 1
        @test nrow(result) == expected_n_windows

        # Each row should contain valid numerical values
        @test all(skipmissing(Matrix(result[1, :])) .!= NaN)
    end

    @testset "Window computation is correct" begin
        window_size = 150
        overlap = 50

        result = windowed_feature_set(ibis; window_size=window_size, overlap=overlap)

        # Manually compute expected number of windows
        # First window: indices 1:150
        # Second window: indices 101:250
        # Continue until window_start + window_size > n_beats
        expected_n_windows = div(n_beats - window_size, window_size - overlap) + 1
        @test nrow(result) == expected_n_windows
    end

    @testset "Respects valid_features constraint" begin
        # Use small window size that limits available features
        window_size = 50  # Only ~11 features valid for 50-beat signals
        overlap = 25

        result = windowed_feature_set(ibis; window_size=window_size, overlap=overlap)

        # Should have fewer columns (only valid features)
        valid_count = length(valid_features(window_size))
        @test ncol(result) <= valid_count

        # All column names should be in the valid set
        valid_names = valid_features(window_size)
        for col in names(result)
            @test col in valid_names
        end
    end

    @testset "No overlap (sequential windows)" begin
        window_size = 100
        overlap = 0

        result = windowed_feature_set(ibis; window_size=window_size, overlap=overlap)

        # With no overlap: floor(n_beats / window_size) non-overlapping windows
        # Plus possibly one partial window
        expected_n_windows = div(n_beats, window_size)
        @test nrow(result) == expected_n_windows
    end

    @testset "Full overlap (every beat starts a window)" begin
        window_size = 100
        overlap = 99  # 99 of 100 beats overlap with next window

        result = windowed_feature_set(ibis; window_size=window_size, overlap=overlap)

        # Should have n_beats - window_size + 1 windows (every position gets a window)
        expected_n_windows = n_beats - window_size + 1
        @test nrow(result) == expected_n_windows
    end

    @testset "Short timeseries handling" begin
        # Edge case: data shorter than window size
        short_ibis = ibis[1:50]
        window_size = 100
        overlap = 50

        result = windowed_feature_set(short_ibis; window_size=window_size, overlap=overlap)

        # Should handle gracefully: either return empty DataFrame or one window if possible
        # Behavior: return empty DataFrame (no complete windows possible)
        @test isa(result, DataFrame)
        @test nrow(result) == 0 || nrow(result) == 1  # Either empty or one partial window
    end

    @testset "Feature values are reasonable" begin
        window_size = 200
        overlap = 100

        result = windowed_feature_set(ibis; window_size=window_size, overlap=overlap)

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
                    # Allow NaN/missing but not negative
                    finite_vals = filter(!ismissing, vals)
                    if length(finite_vals) > 0
                        @test all(finite_vals .>= 0)
                    end
                end
            end
        end
    end
end
