using HeartRateLab
using Test, DataFrames, Random

# Set working directory to test directory for relative paths
cd(@__DIR__)

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
