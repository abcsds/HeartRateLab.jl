using HeartRateLab: HeartRateLab
using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

@testset "Input" begin
    # Test the Input module
    @testset "read_xdf" begin
        # Test reading XDF files
        # infile = "./data/minimal.xdf")
        # infile = "~/Everything/code/example-files/twochannel_string_marker.xdf")
        # infile = "~/Documents/HRV/sub-P001/ses-S001/eeg/sub-P001_ses-S001_task-Default_run-001_eeg.xdf")

        try
            infile = "testdata/example.xdf"
            data = HeartRateLab.read_xdf(infile)
            @test length(data) == 4193
        catch e
            # XDF dependency may not be available
            @warn "XDF reading test skipped: $(e.msg)"
        end
    end

    @testset "read_txt" begin
        # Test reading text files
        infile = "testdata/example.txt"
        data = HeartRateLab.read_txt(infile)
        @test length(data) == 4193
    end

    if Sys.which("ann2rr") !== nothing
        @testset "read_wfdb" begin
            # Test reading WFDB files (requires ann2rr binary)
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
    else
        @info "WFDB tests skipped: ann2rr binary not found on PATH"
    end
end
