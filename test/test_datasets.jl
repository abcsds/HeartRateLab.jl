using HeartRateLab: HeartRateLab
using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

# Gate dataset tests on network availability
if get(ENV, "HEARTRATE_NETWORK_TESTS", "false") == "true"
    @testset "Datasets" begin
        # TODO: Dataset loading and benchmarking tests will be added in Phase 4
        # Currently just a placeholder for future dataset testing
        @test true
    end
else
    @info "Dataset tests skipped: set HEARTRATE_NETWORK_TESTS=true to run"
end
