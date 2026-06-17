using HeartRateLab
using Test

# NOTE: we deliberately do NOT `using Plots` here. The package imports Plots
# internally (it is a hard `[deps]`), so the exported offline plots must return a
# real `PlotType` out of the box. We reach the type through the package's own
# import to prove that — no user-side `using Plots` required.
const PlotsMod = HeartRateLab.Visualization.Plots
const PlotType = PlotsMod.Plot

# Set working directory to test directory for relative paths
cd(@__DIR__)

@testset "Offline plots work without user `using Plots`" begin
    # `Plots` is not in this test's namespace — prove it.
    @test !isdefined(@__MODULE__, :Plots)
    ibis = Float64[800, 810, 790, 805, 815, 795, 800, 808, 812, 798]
    fig = HeartRateLab.plot_ibi_series(ibis)
    @test fig isa PlotType
    @test !isempty(fig.series_list)
    @test HeartRateLab.Visualization.default_backend() == :plots ||
          HeartRateLab.Visualization.default_backend() == :glmakie
end

@testset "plot_comparison" begin
    real_data = Float64[600, 620, 590, 610, 580, 630, 600, 610, 620, 600]
    models = Dict(
        "Model1" => Float64[605, 615, 595, 615, 585, 625, 605, 605, 620, 600],
        "Model2" => Float64[600, 625, 585, 610, 575, 635, 600, 615, 625, 595]
    )
    fig = HeartRateLab.plot_comparison(real_data, models; title="Test Comparison")
    @test fig isa PlotType
    @test !isempty(fig.series_list)
end

# d-08: headless Plots.jl plots — power spectrum + dedicated LIF/DMD model viz.
# These need only Plots.jl (no GLMakie/display), so they run in the always-on section.
@testset "Offline spectrum & model plots (d-08)" begin
    data = Float64.(HeartRateLab.read_txt("testdata/example.txt"))

    @testset "plot_spectrum (headless, banded)" begin
        fig = HeartRateLab.plot_spectrum(data)
        @test fig isa PlotType
        # bands (4 vspan) + spectrum line + peak marker → ≥ 6 series
        @test length(fig.series_list) >= 6
        @test HeartRateLab.plot_spectrum(data; method=:welch) isa PlotType
    end

    @testset "plot_lif (membrane V(t))" begin
        fig = HeartRateLab.plot_lif(HeartRateLab.Models.LIF(); n_beats=5)
        @test fig isa PlotType
        @test length(fig.series_list) >= 3   # V(t) + threshold + rest lines
    end

    @testset "plot_dmd (modes + reconstruction)" begin
        dmd_fit = HeartRateLab.Models.fit(HeartRateLab.Models.DMD(rank=5), data[1:200])
        fig = HeartRateLab.plot_dmd(dmd_fit)
        @test fig isa PlotType
    end
end

# d-07: branch visualizations for the previously-uncovered computational branches
# (fractal/DFA scaling, entropy/complexity). DMD modes are covered by plot_dmd (d-08).
@testset "Branch plots (d-07)" begin
    data = Float64.(HeartRateLab.read_txt("testdata/example.txt"))

    @testset "plot_dfa (log-log scaling)" begin
        fig = HeartRateLab.plot_dfa(data)
        @test fig isa PlotType
        @test length(fig.series_list) >= 3   # F(n) points + α1 + α2 fit lines
    end

    @testset "plot_complexity (multiscale entropy)" begin
        fig = HeartRateLab.plot_complexity(data; scales=8)
        @test fig isa PlotType
    end
end

# d-22: advanced 3D visualizations (headless GR 3D).
@testset "Advanced 3D plots (d-22)" begin
    data = Float64.(HeartRateLab.read_txt("testdata/example.txt"))

    @testset "plot_time_frequency_3d (waterfall)" begin
        fig = HeartRateLab.plot_time_frequency_3d(data; window_size=120, stride=40)
        @test fig isa PlotType
    end

    @testset "plot_poincare_3d (time-evolving)" begin
        fig = HeartRateLab.plot_poincare_3d(data[1:300])
        @test fig isa PlotType
        @test HeartRateLab.plot_poincare_3d([800.0, 810.0]) === nothing  # <3-IBI guard
    end
end

# d-17/task-11: the offline plots are Plots.jl (no GLMakie/display) — test directly with
# structural assertions; NO try/catch sham-skips that hide failures.
@testset "Offline plots (Plots.jl)" begin
    t = range(0, 100, length=128)
    ibis = 800 .+ 100 .* sin.(2π .* t ./ 50) .+ randn(128) .* 20

    @testset "plot_ibi_series" begin
        fig = HeartRateLab.plot_ibi_series(ibis)
        @test fig isa PlotType
        @test !isempty(fig.series_list)
        @test HeartRateLab.plot_ibi_series(ibis; title="Custom Title") isa PlotType
        @test HeartRateLab.plot_ibi_series(ibis[1:5]) isa PlotType   # short series
    end

    @testset "plot_poincare" begin
        fig = HeartRateLab.plot_poincare(ibis)
        @test fig isa PlotType
        @test length(fig.series_list) >= 3   # scatter + SD1/SD2 ellipse + diagonal
    end

    @testset "plot_lorenz_3d (from fitted result)" begin
        lorenz = HeartRateLab.Models.Lorenz()
        params = (σ=10.0, ρ=28.0, β=8/3, threshold=10.0, σ_noise=0.1)
        result = HeartRateLab.Models.ModelFitResult(
            lorenz, :gradient, params, nothing, Dict{String,Any}(), Float64[])
        @test HeartRateLab.plot_lorenz_3d(result; title="Test Lorenz 3D") isa PlotType
    end
end

@testset "plot_model_heatmap" begin
    using DataFrames
    results = DataFrame(
        model=["VdP", "VdP", "Lorenz", "Lorenz", "LIF", "LIF"],
        feature=["SDNN", "RMSSD", "SDNN", "RMSSD", "SDNN", "RMSSD"],
        score=[0.85, 0.92, 0.78, 0.88, 0.95, 0.91]
    )
    # The DataFrame method always renders with Plots (the GLMakie variant is a
    # separate (Dict, Vector) signature), so this is deterministic.
    fig = HeartRateLab.plot_model_heatmap(results; title="Test Heatmap")
    @test fig isa PlotType
    @test !isempty(fig.series_list)
end

@testset "plot_radar" begin
    dataset1 = Float64[600, 620, 590, 610, 580, 630, 600, 610, 620, 600]
    dataset2 = Float64[610, 625, 595, 615, 585, 635, 605, 615, 625, 605]
    datasets = Dict("Dataset1" => dataset1, "Dataset2" => dataset2)

    fig = HeartRateLab.plot_radar(datasets; backend=:plots, title="Test Radar")
    @test fig isa PlotType
    @test !isempty(fig.series_list)
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
    fig = HeartRateLab.plot_correlations(feature_sets; backend=:plots, title="Test Correlations")
    @test fig isa PlotType
    @test !isempty(fig.series_list)

    # Test with specific features
    fig2 = HeartRateLab.plot_correlations(feature_sets; backend=:plots, features=["SDNN", "RMSSD"], title="Test Correlations - Subset")
    @test fig2 isa PlotType
    @test size(fig2) != ()

    # Test with single dataset
    single_set = Dict("Dataset" => data1)
    fig3 = HeartRateLab.plot_correlations(single_set; backend=:plots, title="Single Dataset Correlations")
    @test fig3 isa PlotType
    @test size(fig3) != ()
end

# GLMakie-dependent paths (run LAST so loading GLMakie can't flip the default
# backend out from under the Plots-asserting testsets above). The launcher API
# is always checked; the GLMakie ext load is gated and SKIPS CLEANLY when
# headless (no crash, no sham).
@testset "Live launchers & GLMakie extension" begin
    V = HeartRateLab.Visualization
    for fn in (:default, :bpm, :bpm_tt, :geometric, :vdp_field, :live)
        @test isdefined(V, fn)
    end

    # Forcing :plots always returns a Plots figure regardless of GLMakie.
    pibis = Float64[800, 810, 790, 805, 815, 795, 800, 808, 812, 798]
    @test HeartRateLab.plot_ibi_series(pibis; backend=:plots) isa PlotType

    if (try; @eval(Main, using GLMakie); true; catch; false; end)
        ext = Base.get_extension(HeartRateLab, :HeartRateLabVisualizationExt)
        @test ext !== nothing
        # Loading GLMakie flips the default backend and registers GLMakie methods
        # on the SAME public generics — prove dispatch reaches a GLMakie Figure.
        @test V.default_backend() == :glmakie
        gibis = 800 .+ 40 .* sin.(2π .* (1:200) ./ 25) .+ randn(200) .* 12
        gfig = HeartRateLab.plot_ibi_series(gibis)        # default → GLMakie now
        @test gfig isa GLMakie.Figure
        @test HeartRateLab.plot_poincare(gibis) isa GLMakie.Figure
        @test HeartRateLab.plot_spectrum(gibis) isa GLMakie.Figure
        # The two-vector comparison method is a GLMakie-only signature.
        @test HeartRateLab.plot_comparison(gibis, gibis) isa GLMakie.Figure
        # backend=:plots still escapes to a Plots figure even with GLMakie loaded.
        @test HeartRateLab.plot_ibi_series(pibis; backend=:plots) isa PlotType
    else
        @test_skip "GLMakie unavailable (headless): ext load + GLMakie dispatch not exercised"
    end
end
