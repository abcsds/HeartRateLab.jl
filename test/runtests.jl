using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

# Include all independent test files
@testset "HeartRateLab.jl" begin
    include("test_input.jl")
    include("test_preprocessing.jl")
    include("test_features.jl")
    include("test_priors.jl")
    include("test_frequency.jl")
    include("test_models.jl")
    include("test_evaluation.jl")
    include("test_visualization.jl")
end
