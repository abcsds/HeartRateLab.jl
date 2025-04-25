import HeartRateLab
using Test

@testset "HeartRateLab.jl" begin
    @testset "Input" begin
        # Test the Input module
        @testset "read_xdf" begin
            # Test reading XDF files
            # infile = "./data/minimal.xdf")
            # infile = "~/Everything/code/example-files/twochannel_string_marker.xdf")
            # infile = "~/Documents/HRV/sub-P001/ses-S001/eeg/sub-P001_ses-S001_task-Default_run-001_eeg.xdf")

            infile = "testdata/example.xdf"
            println("Reading XDF file: $infile")
            println("Current working directory: $(pwd())")
            data = HeartRateLab.Input.read_xdf(infile)
            # data = read_xdf(infile)
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
            # record = "testdata/100"
            # data = HeartRateLab.Input.read_wfdb(record, "atr")
            # @test length(data) == 0
            # record = "testdata/16265"
            # data = HeartRateLab.Input.read_wfdb(record, "atr")
            # @test length(data) == 0
        end
    end
end
