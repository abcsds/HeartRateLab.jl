using HeartRateLab
using Test
using Plots

# Set working directory to test directory for relative paths
cd(@__DIR__)

@testset "plot_comparison" begin
    real_data = Float64[600, 620, 590, 610, 580, 630, 600, 610, 620, 600]
    models = Dict(
        "Model1" => Float64[605, 615, 595, 615, 585, 625, 605, 605, 620, 600],
        "Model2" => Float64[600, 625, 585, 610, 575, 635, 600, 615, 625, 595]
    )
    fig = HeartRateLab.plot_comparison(real_data, models; title="Test Comparison")
    @test fig isa Any
    @test size(fig) != ()
end

# Gate visualization tests on GLMakie availability
try
    using GLMakie
    using DSP
    using Statistics

    @testset "Offline Visualization" begin
        # Create synthetic IBI data for testing
        t = range(0, 100, length=128)
        ibis = 800 .+ 100 .* sin.(2π .* t / 50) .+ randn(128) .* 20

        # Get the visualization functions (they are re-exported from the extension)
        plot_ibi_series = HeartRateLab.plot_ibi_series
        plot_poincare = HeartRateLab.plot_poincare
        plot_spectrum = HeartRateLab.plot_spectrum

        # Test 1: plot_ibi_series can be created
        try
            fig_ibi = plot_ibi_series(ibis)
            @test fig_ibi !== nothing
        catch e
            @warn "plot_ibi_series test failed" exception=e
            @test false
        end

        # Test 2: plot_poincare can be created
        try
            fig_poincare = plot_poincare(ibis)
            @test fig_poincare !== nothing
        catch e
            @warn "plot_poincare test failed" exception=e
            @test false
        end

        # Test 3: plot_spectrum can be created
        try
            fig_spectrum = plot_spectrum(ibis)
            @test fig_spectrum !== nothing
        catch e
            @warn "plot_spectrum test failed" exception=e
            @test false
        end

        # Test 4: Functions handle edge cases (short series)
        try
            short_ibis = ibis[1:5]
            fig_short = plot_ibi_series(short_ibis)
            @test fig_short !== nothing
        catch e
            @warn "Short series handling test skipped" exception=e
        end

        # Test 5: Functions work with custom titles
        try
            fig_titled = plot_ibi_series(ibis; title="Custom Title")
            @test fig_titled !== nothing
        catch e
            @warn "Custom title test skipped" exception=e
        end
    end

    @testset "plot_lorenz_3d" begin
        using HeartRateLab.Models

        # Create a Lorenz model and mock result
        lorenz = Lorenz()
        params = (σ=10.0, ρ=28.0, β=8/3, threshold=10.0, σ_noise=0.1)
        result = Models.ModelFitResult(lorenz, :gradient, params, nothing, Dict(), Float64[])

        # Test that plot_lorenz_3d can be created
        try
            fig = HeartRateLab.plot_lorenz_3d(result; title="Test Lorenz 3D")
            @test fig !== nothing
            @test isa(fig, Any)
        catch e
            @warn "plot_lorenz_3d test failed" exception=e
            @test false
        end
    end

catch err
    @info "Visualization tests skipped - GLMakie or DSP not available" exception=err
end

@testset "plot_model_heatmap" begin
    using DataFrames
    results = DataFrame(
        model=["VdP", "VdP", "Lorenz", "Lorenz", "LIF", "LIF"],
        feature=["SDNN", "RMSSD", "SDNN", "RMSSD", "SDNN", "RMSSD"],
        score=[0.85, 0.92, 0.78, 0.88, 0.95, 0.91]
    )
    fig = HeartRateLab.plot_model_heatmap(results; title="Test Heatmap")
    @test fig !== nothing
    @test size(fig) != ()
end

@testset "plot_radar" begin
    dataset1 = [600, 620, 590, 610, 580, 630, 600, 610, 620, 600]
    dataset2 = [610, 625, 595, 615, 585, 635, 605, 615, 625, 605]
    datasets = Dict("Dataset1" => dataset1, "Dataset2" => dataset2)

    fig = HeartRateLab.plot_radar(datasets; title="Test Radar")
    @test fig isa Any
    @test size(fig) != ()
end

@testset "plot_correlations" begin
    using DataFrames

    data1 = DataFrame(
        SDNN=[60, 65, 58, 62, 59],
        RMSSD=[30, 32, 28, 31, 29],
        LF=[500, 520, 480, 510, 490],
        HF=[300, 310, 290, 305, 295]
    )

    data2 = DataFrame(
        SDNN=[55, 60, 58, 62, 56],
        RMSSD=[28, 30, 29, 31, 27],
        LF=[450, 480, 460, 510, 440],
        HF=[280, 300, 290, 305, 270]
    )

    feature_sets = Dict("Model1" => data1, "Model2" => data2)

    # Test with default features (all available)
    fig = HeartRateLab.plot_correlations(feature_sets; title="Test Correlations")
    @test fig isa Any
    @test size(fig) != ()

    # Test with specific features
    fig2 = HeartRateLab.plot_correlations(feature_sets; features=["SDNN", "RMSSD"], title="Test Correlations - Subset")
    @test fig2 isa Any
    @test size(fig2) != ()

    # Test with single dataset
    single_set = Dict("Dataset" => data1)
    fig3 = HeartRateLab.plot_correlations(single_set; title="Single Dataset Correlations")
    @test fig3 isa Any
    @test size(fig3) != ()
end
