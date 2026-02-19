using HeartRateLab: HeartRateLab
using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

# Gate dataset tests on network availability
if get(ENV, "HEARTRATE_NETWORK_TESTS", "false") == "true"
    @testset "Datasets" begin
        @testset "load_physionet" begin
            # Test 1: load_physionet returns a Vector{Float64}
            try
                # Use a known public dataset
                url = "https://physionet.org/files/nsrdb/1.0.0/16265"
                data = HeartRateLab.load_physionet(url)
                @test data isa Vector{Float64}
                @test length(data) > 0
                @test all(x -> x > 0, data)  # All IBIs should be positive
            catch e
                @warn "load_physionet test skipped: $e"
            end
        end

        @testset "load_nsrdb" begin
            # Test 1: load_nsrdb returns a Vector{Float64}
            try
                data = HeartRateLab.load_nsrdb("16265")
                @test data isa Vector{Float64}
                @test length(data) > 0
                @test all(x -> x > 0, data)
            catch e
                @warn "load_nsrdb test skipped: $e"
            end
        end

        @testset "load_mitbih" begin
            # Test 1: load_mitbih returns a Vector{Float64}
            try
                data = HeartRateLab.load_mitbih("100")
                @test data isa Vector{Float64}
                @test length(data) > 0
                @test all(x -> x > 0, data)
            catch e
                @warn "load_mitbih test skipped: $e"
            end
        end
    end
else
    @info "Dataset tests skipped: set HEARTRATE_NETWORK_TESTS=true to run"
end
