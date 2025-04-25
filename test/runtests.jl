using HeartRateLab: HeartRateLab
using Test
using Statistics

@testset "HeartRateLab.jl" begin
    @testset "Input" begin
        # Test the Input module
        @testset "read_xdf" begin
            # Test reading XDF files
            # infile = "/home/beto/.julia/dev/HeartRateLab/data/minimal.xdf")
            # infile = "/run/media/beto/Everything/code/example-files/twochannel_string_marker.xdf")
            # infile = "/home/beto/Documents/HRV/sub-P001/ses-S001/eeg/sub-P001_ses-S001_task-Default_run-001_eeg.xdf")

            infile = "testdata/example.xdf"
            data = HeartRateLab.Input.read_xdf(infile)
            @test length(data) == 4193
        end

        @testset "read_txt" begin
            # Test reading text files
            infile = "testdata/example.txt"
            data = HeartRateLab.Input.read_txt(infile)
            @test length(data) == 4193
        end

        @testset "read_wfdb" begin
            # Test reading WFDB files
            @testset "testdata/e1304" begin
                record = "testdata/e1304"
                data = HeartRateLab.Input.read_wfdb(record, "atr")
                @test length(data) == 7749
            end
            @testset "testdata/100" begin
                record = "testdata/100"
                data = HeartRateLab.Input.read_wfdb(record, "atr")
                @test length(data) == 2272
            end
            @testset "testdata/16265" begin
                record = "testdata/16265"
                data = HeartRateLab.Input.read_wfdb(record, "atr")
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
                    HeartRateLab.Preprocessing.replace_zeros([1, 2, 0, 4, 5, 0, 7]),
                    Float64[1.0, 2.0, NaN, 4.0, 5.0, NaN, 7.0],
                )
            end
        end

        @testset "replace_bio_outliers" begin
            # Test replacing biological outliers with NaN
            @testset "synthetic" begin
                @test isequal(
                    HeartRateLab.Preprocessing.replace_bio_outliers([
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
                    HeartRateLab.Preprocessing.replace_statistical_outliers(
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
                hrv = HeartRateLab.Input.read_txt("testdata/example.txt")
                n = hrv[1:1000]
                @test sum(isnan.(n))==0
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(n; method=:malik)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(n; method=:kamath)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(
                            n; method=:acar, threshold=0.2
                        ),
                    ),
                )==3
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(
                            n; method=:karlsson, threshold=0.2
                        ),
                    ),
                )==499
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(
                            n; method=:custom, threshold=0.2
                        ),
                    ),
                )==0

                n = hrv[1000:2000]
                @test sum(isnan.(n))==0
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(n; method=:malik)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(n; method=:kamath)
                    ),
                )==0
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(
                            n; method=:acar, threshold=0.2
                        ),
                    ),
                )==8
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(
                            n; method=:karlsson, threshold=0.2
                        ),
                    ),
                )==500
                @test sum(
                    isnan.(
                        HeartRateLab.Preprocessing.replace_ectopic_beats(
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
                result = HeartRateLab.Preprocessing.strip_extremes(n)
                @test length(result) == length(n) - count(iszero.(n))
            end
        end

        @testset "interpolate_nans" begin
            # Test interpolating NaN values
            @testset "synthetic" begin
                @test isequal(
                    HeartRateLab.Preprocessing.interpolate_nans(
                        Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:constant
                    ),
                    Float64[1.0, 2.0, 2.0, 4.0, 5.0, 5.0, 7.0],
                )
                @test isequal(
                    HeartRateLab.Preprocessing.interpolate_nans(
                        Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:linear
                    ),
                    Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
                )
                @test isequal(
                    HeartRateLab.Preprocessing.interpolate_nans(
                        Float64[1, 2, NaN, 4, 5, NaN, 7.0]; method=:quadratic
                    ),
                    Float64[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0],
                )
                @test isequal(
                    HeartRateLab.Preprocessing.interpolate_nans(
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
                    HeartRateLab.Preprocessing.windowed(v; window_size=3),
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
                    HeartRateLab.Preprocessing.windowed(v; window_size=3, stride=3),
                    [[1.0, 2.0, 3.0], [4.0, 5.0, 6.0], [7.0, 8.0, 9.0]],
                )
                @test isequal(
                    HeartRateLab.Preprocessing.windowed(
                        v; window_size=3, stride=3, f=Statistics.mean
                    ),
                    [2.0, 5.0, 8.0],
                )
            end
        end
    end
end
