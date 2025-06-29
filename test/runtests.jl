using HeartRateLab: HeartRateLab
using Test
using StatsBase
using DataFrames
using CSV

@testset "HeartRateLab.jl" begin
    @testset "Input" begin
        # Test the Input module
        @testset "read_xdf" begin
            # Test reading XDF files
            # infile = "/home/beto/.julia/dev/HeartRateLab/data/minimal.xdf")
            # infile = "/run/media/beto/Everything/code/example-files/twochannel_string_marker.xdf")
            # infile = "/home/beto/Documents/HRV/sub-P001/ses-S001/eeg/sub-P001_ses-S001_task-Default_run-001_eeg.xdf")

            infile = "testdata/example.xdf"
            data = HeartRateLab.read_xdf(infile)
            @test length(data) == 4193
        end

        @testset "read_txt" begin
            # Test reading text files
            infile = "testdata/example.txt"
            data = HeartRateLab.read_txt(infile)
            @test length(data) == 4193
        end

        @testset "read_wfdb" begin  # TODO: broken for v1.6
            # Test reading WFDB files
            @testset "testdata/e1304" begin
                record = "testdata/e1304"
                data = HeartRateLab.read_wfdb(record, "atr")
                @test length(data) == 7749
            end
            @testset "testdata/100" begin
                record = "testdata/100"
                data = HeartRateLab.read_wfdb(record, "atr")
                @test length(data) == 2272
            end
            @testset "testdata/16265" begin
                record = "testdata/16265"
                data = HeartRateLab.read_wfdb(record, "atr")
                @test length(data) == 99819
            end
        end
    end

    # Test the Preprocessing module
    @testset "Preprocessing" begin
        @testset "replace_zeros" begin
            # Test replacing zeros with NaN
            @testset "Synthetic" begin
                @test isequal(
                    HeartRateLab.replace_zeros([1, 2, 0, 4, 5, 0, 7]),
                    Float64[1.0, 2.0, NaN, 4.0, 5.0, NaN, 7.0],
                )
            end
        end

        @testset "replace_bio_outliers" begin
            # Test replacing biological outliers with NaN
            @testset "synthetic" begin
                @test isequal(
                    HeartRateLab.replace_bio_outliers([
                        400, 500, 200, 2000, 1000, 3000, 1500, 100
                    ]),
                    Float64[400.0, 500.0, NaN, 2000, 1000.0, NaN, 1500.0, NaN],
                )
            end
        end

        @testset "replace_statistical_outliers" begin
            # Test replacing statistical outliers with NaN
            @testset "synthetic" begin
                # Generate synthetic data
                N = 100
                a_dist = Float64.(rand(600:1200, N))
                q_high = quantile(a_dist, 0.75)
                q_low = quantile(a_dist, 0.25)
                ridx = [e<q_low || e>q_high for e in a_dist]
                goal = copy(a_dist)
                goal[ridx] .= repeat([NaN], sum(ridx))
                @test isequal(
                    HeartRateLab.replace_statistical_outliers(
                        a_dist; low=0.25, high=0.75
                    ),
                    goal,
                )
            end
        end

        @testset "replace_ectopic_beats" begin
            # Test replacing ectopic beats with NaN
            # TODO
            @testset "rr-interval-healthy-subjects" begin
                hrv = HeartRateLab.read_txt("testdata/example.txt")
                n = hrv[1:1000]
                @test sum(isnan.(n))==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(n; method=:malik)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(n; method=:kamath)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:acar, threshold=0.2
                        ),
                    ),
                )==3
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:karlsson, threshold=0.2
                        ),
                    ),
                )==499
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:custom, threshold=0.2
                        ),
                    ),
                )==0

                n = hrv[1000:2000]
                @test sum(isnan.(n))==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(n; method=:malik)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(n; method=:kamath)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:acar, threshold=0.2
                        ),
                    ),
                )==8
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:karlsson, threshold=0.2
                        ),
                    ),
                )==500
                @test sum(
                    isnan.(
                        HeartRateLab.replace_ectopic_beats(
                            n; method=:custom, threshold=0.2
                        ),
                    ),
                )==0
            end
        end

        @testset "strip_extremes" begin
            # Test stripping extremes from the data
            @testset "synthetic" begin
                n = [1.0e-10; rand(100)]
                result = HeartRateLab.strip_extremes(n)
                @test length(result) == length(n) - count(iszero.(n))
            end
        end

        @testset "interpolate_nans" begin
            # Test interpolating NaN values
            @testset "synthetic" begin
                @test isequal(
                    HeartRateLab.interpolate_nans(
                        Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:constant
                    ),
                    Float64[1.0, 2.0, 2.0, 4.0, 5.0, 5.0, 7.0],
                )
                @test isequal(
                    HeartRateLab.interpolate_nans(
                        Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:linear
                    ),
                    Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
                )
                @test isapprox(
                    HeartRateLab.interpolate_nans(
                        Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:quadratic
                    ),
                    Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
                    atol=1e-6,
                )
                @test isequal(
                    HeartRateLab.interpolate_nans(
                        Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:cubic
                    ),
                    Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
                )
            end
        end

        @testset "Windowed" begin
            # Test windowed function
            @testset "synthetic" begin
                v = Float64[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
                @test isequal(
                    HeartRateLab.windowed(v; window_size=3),
                    [
                        [1.0, 2.0, 3.0],
                        [2.0, 3.0, 4.0],
                        [3.0, 4.0, 5.0],
                        [4.0, 5.0, 6.0],
                        [5.0, 6.0, 7.0],
                        [6.0, 7.0, 8.0],
                        [7.0, 8.0, 9.0],
                        [8.0, 9.0, 10.0],
                    ],
                )
                @test isequal(
                    HeartRateLab.windowed(v; window_size=3, stride=3),
                    [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]],
                )
                @test isequal(
                    HeartRateLab.windowed(
                        v; window_size=3, stride=3, f=StatsBase.mean
                    ),
                    [2.0, 5.0, 8.0],
                )
            end
        end
    end
    @testset "Features" begin
        # Test the Features module
        infile = "testdata/example.txt"
        data = HeartRateLab.read_txt(infile)
        println("Data loaded from: ", infile)
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
        @test isequal(ds, target)

        @testset "Features.Windowed" begin
            # Test windowed feature extraction
            ds_windowed = HeartRateLab.Features.windowed_feature_set(
                data, features=String.(keys(feature_registry)), window_size=60, stride=10
            )
            # CSV.write("target/example_windowed_60_10.csv", ds_windowed)
            @test ds_windowed isa DataFrames.DataFrame
            @test size(ds_windowed) == (414, 44)
            target_windowed = CSV.read("target/example_windowed.csv", DataFrame)
            @test isequal(ds_windowed, target_windowed)
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
end
