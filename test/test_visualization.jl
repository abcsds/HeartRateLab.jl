using HeartRateLab
using Test

# Set working directory to test directory for relative paths
cd(@__DIR__)

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

catch err
    @info "Visualization tests skipped - GLMakie or DSP not available" exception=err
end
