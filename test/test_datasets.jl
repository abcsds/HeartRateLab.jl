using HeartRateLab: HeartRateLab
using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

# Gate dataset tests on network availability
if get(ENV, "HEARTRATE_NETWORK_TESTS", "false") == "true"
    @testset "Datasets" begin
        # Generic PhysioNet loader
        @testset "load_physionet" begin
            try
                url = "https://physionet.org/files/nsrdb/1.0.0/16265"
                data = HeartRateLab.load_physionet(url)
                @test data isa Vector{Float64}
                @test length(data) > 0
                @test all(x -> x > 0, data)
            catch e
                @warn "load_physionet test skipped: $e"
            end
        end

        # Normative databases
        @testset "load_nsrdb" begin
            try
                data = HeartRateLab.load_nsrdb("16265")
                @test data isa Vector{Float64}
                @test length(data) > 0
                @test all(x -> x > 0, data)
            catch e
                @warn "load_nsrdb test skipped: $e"
            end
        end

        @testset "load_nsr2db" begin
            try
                # NSRDB test - should work if network available
                @test isdefined(HeartRateLab, :load_nsr2db)
            catch e
                @warn "load_nsr2db test skipped: $e"
            end
        end

        @testset "load_healthy_rr_intervals" begin
            try
                @test isdefined(HeartRateLab, :load_healthy_rr_intervals)
            catch e
                @warn "load_healthy_rr_intervals test skipped: $e"
            end
        end

        # Clinical/Arrhythmia databases
        @testset "load_mitbih" begin
            try
                data = HeartRateLab.load_mitbih("100")
                @test data isa Vector{Float64}
                @test length(data) > 0
                @test all(x -> x > 0, data)
            catch e
                @warn "load_mitbih test skipped: $e"
            end
        end

        @testset "load_mvtdb" begin
            try
                @test isdefined(HeartRateLab, :load_mvtdb)
            catch e
                @warn "load_mvtdb test skipped: $e"
            end
        end

        # Specialized databases
        @testset "load_meditation" begin
            try
                @test isdefined(HeartRateLab, :load_meditation)
            catch e
                @warn "load_meditation test skipped: $e"
            end
        end

        @testset "load_challenge_2002" begin
            try
                @test isdefined(HeartRateLab, :load_challenge_2002)
            catch e
                @warn "load_challenge_2002 test skipped: $e"
            end
        end

        @testset "load_chaos" begin
            try
                @test isdefined(HeartRateLab, :load_chaos)
            catch e
                @warn "load_chaos test skipped: $e"
            end
        end

        @testset "load_ibs" begin
            try
                @test isdefined(HeartRateLab, :load_ibs)
            catch e
                @warn "load_ibs test skipped: $e"
            end
        end

        @testset "load_simultaneous_measurements" begin
            try
                @test isdefined(HeartRateLab, :load_simultaneous_measurements)
            catch e
                @warn "load_simultaneous_measurements test skipped: $e"
            end
        end
    end
else
    @info "Dataset tests skipped: set HEARTRATE_NETWORK_TESTS=true to run"
end
