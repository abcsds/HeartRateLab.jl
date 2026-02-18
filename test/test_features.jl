using HeartRateLab: HeartRateLab
using Test
using DataFrames
using CSV

# Set working directory to test directory for relative paths
cd(@__DIR__)

@testset "Features" begin
    # Test the Features module
    if isfile("testdata/example.txt")
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

        @testset "Features.Windowed" begin
            # Test windowed feature extraction
            ds_windowed = HeartRateLab.Features.windowed_feature_set(
                data, features=String.(keys(feature_registry)), window_size=60, stride=10
            )
            # CSV.write("target/example_windowed_60_10.csv", ds_windowed)
            @test ds_windowed isa DataFrames.DataFrame
            @test size(ds_windowed) == (414, 44)
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
    else
        @warn "Features test skipped: testdata/example.txt not found"
    end
end
