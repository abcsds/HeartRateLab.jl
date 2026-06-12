using HeartRateLab: HeartRateLab
using Test
using DataFrames
using CSV

# Set working directory to test directory for relative paths
cd(@__DIR__)

@testset "Features" begin
    # Test the Features module
    infile = "testdata/example.txt"
    println("Data loaded from: ", infile)
    data = HeartRateLab.read_txt(infile)
    println("Data length: ", length(data))
    println("Type of data: ", typeof(data))

    feature_registry = HeartRateLab.Features.feature_registry
    names = String[keys(feature_registry)...]
    println("Full Feature set: ", names)

    ds = HeartRateLab.Features.extract_feature_set(
        data, features=String.(keys(feature_registry))
    )
    @test ds isa DataFrames.DataFrame
    # Write ds to target file
    # CSV.write("target/example.csv", ds)
    # Test against target
    target = CSV.read("target/example.csv", DataFrame)
    @test isapprox(Matrix(ds), Matrix(target); rtol=1e-10)

    @testset "Registry completeness" begin
        # SPEC-F1/F2: the feature registry is the single source of truth for the
        # scalar HRV features. There are 53 registered features (44 original + 9 added
        # in d-19: cvnni, median_hr, range_hr, shan_en, svd_en, fuzzyen, spec_en,
        # perm_en, mse). Representations such as `diff`, `pgram`, `dfa`, `dfa1`, `px`,
        # `py`, `histogram`, `renyi`, `length`, `duration`, `max_t` live in
        # `representation_registry`, not here.
        feat_names = sort(String[keys(feature_registry)...])
        @test length(feat_names) == 53

        # Every registered feature must be a column in the comparison matrix, i.e.
        # the matrix-vs-target test above actually exercises ALL of them, not a
        # default subset. `ds` was built from `keys(feature_registry)`.
        @test sort(DataFrames.names(ds)) == feat_names
        @test sort(DataFrames.names(target)) == feat_names

        n = HeartRateLab.Features.HRMeasurement(data)
        @testset "Finiteness: $f" for f in feat_names
            # SPEC-F4: every registered feature must produce a finite (non-NaN,
            # non-Inf) value on the 4193-IBI example recording.
            v = HeartRateLab.Features.function_registry[f](n)
            ok = v isa Number ? isfinite(v) : all(isfinite, v)
            @test ok
        end

        @testset "Distribution family: $f" for f in feat_names
            # SPEC-F1: every scalar feature declares a valid analytical
            # distribution family (Normal/Gamma/Beta/LogNormal) in its docstring,
            # parsed by @register into the HRFeature.distribution field.
            valid = (HeartRateLab.Features.DISTRIBUTION_MAP |> values |> collect)
            d = feature_registry[f].distribution
            @test d !== nothing
            @test d in valid
        end
    end

    @testset "Features.Windowed" begin
        # Test windowed feature extraction
        ds_windowed = HeartRateLab.Features.windowed_feature_set(
            data, features=String.(keys(feature_registry)), window_size=60, stride=10
        )
        # CSV.write("target/example_windowed_60_10.csv", ds_windowed)
        @test ds_windowed isa DataFrames.DataFrame
        @test size(ds_windowed) == (414, 53)
        target_windowed = CSV.read("target/example_windowed_60_10.csv", DataFrame)
        # Compare allowing for floating-point precision and NaN equality
        m_ds = Matrix(ds_windowed)
        m_target = Matrix(target_windowed)
        @test all((isnan.(m_ds) .== isnan.(m_target)) .| isapprox.(m_ds, m_target; nans=true, rtol=1e-10))
    end

    @testset "Frequency" begin
        n = HeartRateLab.read_txt("testdata/example.txt")[1:50]
        @testset "lomb_scargle" begin
            # Test Lomb-Scargle transformation
            pgram = HeartRateLab.Frequency.lomb_scargle(n)
            @test pgram.freq ≈ 0.003:0.004360243301576228:0.39978214044343674
            @test sum(abs.(pgram.power)) ≈ 1.0143225764346281e6
        end

        @testset "get_power" begin
            # Test power calculation in frequency bands
            pgram = HeartRateLab.Frequency.lomb_scargle(n)
            @test HeartRateLab.Frequency.get_power(pgram, 0.003, 0.4) ≈ 4401.271945010022
        end
        @testset "welch" begin
            # Test Welch's method for spectral density estimation
            pgram = HeartRateLab.Frequency.welch(n; method=:linear, fs=4)
            @test HeartRateLab.Frequency.get_power(pgram, 0.003, 0.4) ≈ 1025.5980988017122
            pgram = HeartRateLab.Frequency.welch(n; method=:quadratic, fs=4)
            @test HeartRateLab.Frequency.get_power(pgram, 0.003, 0.4) ≈ 1041.7463216769288
            pgram = HeartRateLab.Frequency.welch(n; method=:cubic, fs=4)
            @test HeartRateLab.Frequency.get_power(pgram, 0.003, 0.4) ≈ 1043.3374467399701
            pgram = HeartRateLab.Frequency.welch(n; method=:constant, fs=4)
            @test HeartRateLab.Frequency.get_power(pgram, 0.003, 0.4) ≈ 1046.5361627009815
        end
        @testset "get_power_welch" begin
            pgram = HeartRateLab.Frequency.welch(n; method=:quadratic)
            @test HeartRateLab.Frequency.get_power(pgram, 0.003, 0.4) ≈ 1041.7463216769288
        end
    end
end
