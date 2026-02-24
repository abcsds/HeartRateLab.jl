module Visualization

using Statistics
using DataFrames

# Import Models module for accessing simulate_lorenz_trajectory and types
# This is safe because Models is included in the parent module before Visualization
import ..Models
using ..Models: ModelFitResult

# Import Features module for extract_feature_set and valid_features
import ..Features
using ..Features: extract_feature_set, valid_features

function getellipsepoints(cx, cy, rx, ry, θ; length=100)
	t = range(0, 2*pi, length=length)
	ellipse_x_r = @. rx * cos(t)
	ellipse_y_r = @. ry * sin(t)
	R = [cos(θ) sin(θ); -sin(θ) cos(θ)]
	r_ellipse = [ellipse_x_r ellipse_y_r] * R
	x = @. cx + r_ellipse[:,1]
	y = @. cy + r_ellipse[:,2]
	(x,y)
end

function default()
    include("default.jl")
end

function bpm()
    include("heart_rate.jl")
end

function bpm_tt()
    include("heart_rate_tt.jl")
end

function geometric()
    include("geometric.jl")
end

"""
    plot_flagship(data::Vector, fit_result; title::String="Flagship Visualization")

Create a comprehensive visualization of HRV analysis results.
Requires Plots.jl to be loaded in the calling environment.
"""
function plot_flagship(data::Vector, fit_result; title::String="Flagship Visualization")
    # Check if Plots is available
    if !isdefined(Main, :plot)
        println("Visualization requires Plots.jl. Please run: using Plots")
        return nothing
    end

    # Access Plots functions through Main
    plot = Main.plot
    plot! = Main.plot!
    scatter! = Main.scatter!
    histogram! = Main.histogram!

    # Create 2x2 subplot layout
    fig = plot(layout=(2, 2), size=(1000, 800), plot_title=title)

    # Panel 1: IBI time series
    plot!(fig[1], data, label="IBI", xlabel="Beat", ylabel="Interval (ms)", title="Inter-Beat Intervals")

    # Panel 2: IBI histogram
    histogram!(fig[2], data, label="IBI Distribution", xlabel="Interval (ms)", ylabel="Count", title="Distribution")

    # Panel 3: Poincaré plot
    if length(data) > 1
        scatter!(fig[3], data[1:end-1], data[2:end], label="Poincaré", xlabel="IBIₙ (ms)", ylabel="IBIₙ₊₁ (ms)", title="Poincaré Plot", markersize=3, alpha=0.6)
    end

    # Panel 4: Cumulative time
    plot!(fig[4], cumsum(data), label="Cumulative Time", xlabel="Beat", ylabel="Cumulative Time (ms)", title="Cumulative Duration")

    return fig
end

"""
    plot_ibi_series(data::Vector{Float64}; title="IBI Time Series", show_grid=true) → Figure

Create a simple line plot of inter-beat-interval values over beat index.

# Arguments
- `data::Vector{Float64}` — IBI series in milliseconds
- `title::String` — plot title
- `show_grid::Bool` — whether to show grid lines

# Returns
- Figure with X-axis=beat index, Y-axis=IBI (ms)
- Physiological bounds marked as horizontal lines (300-2000 ms typical range)

# Requirements
Requires Plots.jl to be loaded in the calling environment.
"""
function plot_ibi_series(data::Vector{Float64}; title="IBI Time Series", show_grid=true)
    # Check if Plots is available
    if !isdefined(Main, :plot)
        println("Visualization requires Plots.jl. Please run: using Plots")
        return nothing
    end

    # Access Plots functions through Main
    plot = Main.plot
    plot! = Main.plot!
    hline! = Main.hline!

    # Create the plot
    fig = plot(data,
               label="IBI",
               xlabel="Beat Index",
               ylabel="IBI (ms)",
               title=title,
               legend=:topright,
               size=(900, 500))

    # Add physiological bounds as horizontal lines
    hline!(fig, [300], label="Min bound (300 ms)", line=:dash, color=:red, alpha=0.5)
    hline!(fig, [2000], label="Max bound (2000 ms)", line=:dash, color=:red, alpha=0.5)

    # Control grid visibility
    if show_grid
        plot!(grid=true)
    end

    return fig
end

"""
    plot_poincare(data::Vector; title="Poincaré Plot") → Figure

Create a Poincaré plot of inter-beat-interval variability with SD1/SD2 ellipse overlay.

# Arguments
- `data::Vector` — IBI series in milliseconds (numeric vector)
- `title::String` — plot title

# Returns
- Figure showing:
  - Scatter plot of consecutive IBI pairs (RR[n-1], RR[n]) in purple
  - SD1/SD2 ellipse overlay in limegreen
  - Diagonal reference line
  - SD1, SD2 values in legend

# Details
The Poincaré plot visualizes HRV by plotting each IBI against the next IBI.
SD1 measures short-term variability, SD2 measures long-term variability.

# Requirements
Requires Plots.jl to be loaded in the calling environment.
"""
function plot_poincare(data::Vector; title="Poincaré Plot")
    # Check if Plots is available
    if !isdefined(Main, :plot)
        println("Visualization requires Plots.jl. Please run: using Plots")
        return nothing
    end

    # Access Plots functions through Main
    plot = Main.plot
    scatter! = Main.scatter!
    plot! = Main.plot!

    # Handle edge case: need at least 2 data points
    if length(data) < 2
        println("Poincaré plot requires at least 2 IBI values")
        return nothing
    end

    # Calculate consecutive RR pairs
    pp_x = data[1:end-1]
    pp_y = data[2:end]

    # Calculate SD1 and SD2
    # SD1 = sqrt(var((pp_x - pp_y) / sqrt(2)))
    # SD2 = sqrt(var((pp_x + pp_y) / sqrt(2)))
    sd1 = sqrt(var((pp_x .- pp_y) ./ sqrt(2)))
    sd2 = sqrt(var((pp_x .+ pp_y) ./ sqrt(2)))

    # Calculate ellipse center
    cx = mean(pp_x)
    cy = mean(pp_y)

    # Calculate ellipse points
    ex, ey = getellipsepoints(cx, cy, sd2, sd1, π/4)

    # Create the plot
    fig = plot(legend=:topleft, size=(700, 600), title=title)

    # Add scatter plot of Poincaré points in purple
    scatter!(fig, pp_x, pp_y,
             color=:purple,
             markersize=4,
             alpha=0.6,
             label="IBI Pairs")

    # Add SD1/SD2 ellipse in limegreen
    plot!(fig, ex, ey,
          color=:limegreen,
          linewidth=2,
          label="SD1/SD2 Ellipse")

    # Add diagonal reference line (y = x)
    min_val = min(minimum(pp_x), minimum(pp_y))
    max_val = max(maximum(pp_x), maximum(pp_y))
    plot!(fig, [min_val, max_val], [min_val, max_val],
          color=:gray,
          linestyle=:dash,
          alpha=0.5,
          label="")

    # Add axis labels and SD values to legend label
    plot!(fig,
          xlabel="RR[n-1] (ms)",
          ylabel="RR[n] (ms)",
          grid=true,
          aspect_ratio=:equal)

    # Add text annotation for SD values
    mid_x = cx + (max_val - min_val) * 0.05
    mid_y = cy + (max_val - min_val) * 0.05

    return fig
end

# Placeholder stubs for extension-provided functions
# These will be overridden when GLMakie is loaded

"""
    plot_spectrum(ibis::Vector{Float64}; method=:lomb, title="HRV Power Spectrum") -> Figure

Create a power spectrum plot of inter-beat-interval series with frequency bands.
This function is provided by the HeartRateLabVisualizationExt extension when GLMakie is loaded.
"""
function plot_spectrum(ibis::Vector{Float64}; method=:lomb, title="HRV Power Spectrum")
    # Try to delegate to the extension if it's loaded
    ext = Base.get_extension(parentmodule(parentmodule(@__MODULE__)), :HeartRateLabVisualizationExt)
    if ext !== nothing
        return ext.plot_spectrum(ibis; method=method, title=title)
    end
    error("plot_spectrum requires GLMakie. Please run: using GLMakie")
end

"""
    plot_comparison(real::Vector{Float64}, models::Dict{String, Vector{Float64}}; title="Time Series Comparison") → Figure

Overlay multiple model-generated IBI series against real data for visual inspection and comparison.

# Arguments
- `real::Vector{Float64}` — real IBI data (milliseconds)
- `models::Dict{String, Vector{Float64}}` — Dict mapping model names → synthetic IBI series
- `title::String` — overall plot title

# Returns
- Multi-panel figure with one panel per model, plus real data reference
- Each panel shows time series overlay:
  - Real data in blue
  - Model in red/orange/green (cycle through colors)
- Legend showing real vs model names
- X-axis: beat index, Y-axis: IBI (ms)
- Physiological bounds marked (300-2000 ms)

# Requirements
Requires Plots.jl to be loaded in the calling environment.
"""
function plot_comparison(real::Vector{Float64}, models::Dict{String, Vector{Float64}}; title="Time Series Comparison")
    # Check if Plots is available
    if !isdefined(Main, :plot)
        println("Visualization requires Plots.jl. Please run: using Plots")
        return nothing
    end

    # Access Plots functions through Main
    plot = Main.plot
    plot! = Main.plot!
    hline! = Main.hline!

    # Handle empty models dict
    if isempty(models)
        # Return plot with real data only
        fig = plot(real,
                   label="Real Data",
                   xlabel="Beat Index",
                   ylabel="IBI (ms)",
                   title=title,
                   legend=:topright,
                   size=(900, 500))
        hline!(fig, [300, 2000], label="", line=:dash, color=:gray, alpha=0.5)
        return fig
    end

    # Prepare data
    n_models = length(models)
    model_names = collect(keys(models))
    colors = [:red, :orange, :green, :purple, :cyan]  # Cycle through colors

    # Create subplot layout
    # Total panels = n_models + 1 (for real data as reference in each panel)
    fig = plot(layout=(n_models + 1, 1), size=(900, 150 * (n_models + 1)), plot_title=title)

    # Panel 0: Real data only
    plot!(fig[1], real,
          label="Real Data",
          xlabel="Beat Index",
          ylabel="IBI (ms)",
          title="Real Data",
          legend=:topright,
          color=:blue,
          linewidth=2)
    hline!(fig[1], [300, 2000], label="", line=:dash, color=:gray, alpha=0.5)

    # For each model
    for (i, (name, synthetic)) in enumerate(models)
        # Ensure same length
        min_len = min(length(synthetic), length(real))
        synthetic_truncated = synthetic[1:min_len]
        real_truncated = real[1:min_len]

        # Create subplot
        beat_idx = 1:min_len
        color_idx = (i - 1) % length(colors) + 1
        model_color = colors[color_idx]

        plot!(fig[i + 1], beat_idx, real_truncated,
              label="Real",
              xlabel="Beat Index",
              ylabel="IBI (ms)",
              title=name,
              legend=:topright,
              color=:blue,
              linewidth=2)

        plot!(fig[i + 1], beat_idx, synthetic_truncated,
              label=name,
              color=model_color,
              linewidth=2)

        # Add physiological bounds
        hline!(fig[i + 1], [300, 2000], label="", line=:dash, color=:gray, alpha=0.5)
    end

    return fig
end

"""
    plot_comparison(real_ibis::Vector{Float64}, synthetic_ibis::Vector{Float64}; model_name="Model") -> Figure

Create side-by-side comparison plots of real vs synthetic IBI data.
This function is provided by the HeartRateLabVisualizationExt extension when GLMakie is loaded.
"""
function plot_comparison(real_ibis::Vector{Float64}, synthetic_ibis::Vector{Float64}; model_name="Model")
    error("plot_comparison requires GLMakie. Please run: using GLMakie")
end

"""
    plot_model_heatmap(results::DataFrame; title="Model × Feature Reproduction") → Figure

Create a matrix visualization showing which (model, feature) pairs reproduce well.

# Arguments
- `results::DataFrame` — evaluation results with columns:
  - `:model` (String) — model name (e.g., "VanDerPol", "Lorenz", "DMD")
  - `:feature` (String) — feature name (e.g., "SDNN", "RMSSD", "LF/HF")
  - `:score` (Float64) — 0-1 reproduction quality (0=fail, 1=perfect)
- `title::String` — plot title

# Returns
- Heatmap with:
  - Rows = models
  - Columns = features
  - Color = score (white=0/fail, red=1/perfect)
  - Values displayed in cells
  - Row/column labels visible

# Requirements
Requires Plots.jl to be loaded in the calling environment.
"""
function plot_model_heatmap(results::DataFrame; title="Model × Feature Reproduction")
    # Check if Plots is available
    if !isdefined(Main, :plot)
        println("Visualization requires Plots.jl. Please run: using Plots")
        return nothing
    end

    # Try to access heatmap, handling ambiguity from multiple backends (GLMakie, etc.)
    heatmap = try
        Main.heatmap
    catch err
        if isdefined(Main, :Plots)
            Main.Plots.heatmap
        else
            error("heatmap function not found. Please ensure Plots.jl is imported.")
        end
    end

    # Extract unique models and features, preserving order
    models = unique(results.model)
    features = unique(results.feature)

    # Create matrix where rows=models, cols=features, values=scores
    Z = fill(NaN, length(models), length(features))

    for (i, model) in enumerate(models)
        for (j, feature) in enumerate(features)
            # Find matching row in results
            row_mask = (results.model .== model) .& (results.feature .== feature)
            row_idx = findfirst(row_mask)

            if row_idx !== nothing
                Z[i, j] = results.score[row_idx]
            end
        end
    end

    # Create heatmap with Plots.jl
    fig = heatmap(
        features,  # x-axis (columns)
        models,    # y-axis (rows)
        Z,
        color=:heat,
        xlabel="Features",
        ylabel="Models",
        title=title,
        clims=(0, 1),
        size=(600, 400),
        legend=:right,
        aspect_ratio=:auto
    )

    return fig
end

"""
    plot_model_heatmap(errors::Dict{String, Vector{Float64}}, features::Vector{String}) -> Figure

Create a heatmap showing model reproduction quality across features.
This function is provided by the HeartRateLabVisualizationExt extension when GLMakie is loaded.
"""
function plot_model_heatmap(errors::Dict{String, Vector{Float64}}, features::Vector{String})
    error("plot_model_heatmap requires GLMakie. Please run: using GLMakie")
end

"""
    plot_lorenz_3d(lorenz_result::ModelFitResult; title="Lorenz Phase Space") -> Figure

Create a 3D visualization of the Lorenz system phase space trajectory from fitted parameters.

# Arguments
- `lorenz_result::ModelFitResult`: Result from fit(Lorenz(), data) containing fitted parameters
- `title::String`: Plot title (default "Lorenz Phase Space")

# Returns
3D line plot showing:
- Teal trajectory line representing the system evolution
- Color gradient along the trajectory indicating time flow
- Green marker at trajectory start
- Red marker at trajectory end
- XYZ axes labeled

# Details
Solves the Lorenz ODE system using the fitted parameters (σ, ρ, β) and plots the full
(x, y, z) trajectory in 3D space. This shows the characteristic butterfly-shaped
strange attractor behavior of the Lorenz system.

# Requirements
Requires Plots.jl to be loaded in the calling environment.
Requires DifferentialEquations.jl (included in dependency chain).
"""
function plot_lorenz_3d(lorenz_result::ModelFitResult; title="Lorenz Phase Space")
    # Check if Plots is available
    if !isdefined(Main, :plot)
        println("Visualization requires Plots.jl. Please run: using Plots")
        return nothing
    end

    # Access Plots functions through Main
    plot = Main.plot
    scatter! = Main.scatter!

    # Extract parameters from ModelFitResult
    params = lorenz_result.params

    # Solve ODE to get full trajectory using the helper function from Models
    sol = Models.simulate_lorenz_trajectory(params; duration=100.0)

    # Extract (x, y, z) points from solution
    x = [sol.u[i][1] for i in 1:length(sol.u)]
    y = [sol.u[i][2] for i in 1:length(sol.u)]
    z = [sol.u[i][3] for i in 1:length(sol.u)]

    # Create 3D plot with teal trajectory
    fig = plot(x, y, z,
               color=:teal,
               linewidth=2.5,
               label="Trajectory",
               xlabel="x",
               ylabel="y",
               zlabel="z",
               title=title,
               legend=:topright,
               size=(800, 700),
               aspectratio=:equal)

    # Mark start point in green
    scatter!(fig, [x[1]], [y[1]], [z[1]],
             color=:green,
             markersize=8,
             label="Start",
             markerstrokewidth=0)

    # Mark end point in red
    scatter!(fig, [x[end]], [y[end]], [z[end]],
             color=:red,
             markersize=8,
             label="End",
             markerstrokewidth=0)

    return fig
end

"""
    plot_lorenz_3d(ibis::Vector{Float64}; title="IBI 3D Phase Space") -> Figure

Create an interactive 3D scatter plot showing IBI[n] vs IBI[n+1] vs IBI[n+2].
This function is provided by the HeartRateLabVisualizationExt extension when GLMakie is loaded.
"""
function plot_lorenz_3d(ibis::Vector{Float64}; title="IBI 3D Phase Space")
    error("plot_lorenz_3d(::Vector) requires GLMakie. Please run: using GLMakie")
end

"""
    plot_radar(datasets::Dict{String, Vector{Float64}}; features=nothing, title="Feature Comparison") → Figure

Create a spider/radar chart of normalized feature values for multi-dataset comparison.

# Arguments
- `datasets::Dict{String, Vector{Float64}}` — Dict mapping dataset names → IBI series
- `features::Union{Nothing, Vector{String}}` — which features to include
  - `nothing` (default): use valid_features() for all available features
- `title::String` — plot title

# Returns
- Radar/spider chart with:
  - One polygon per dataset (color-coded)
  - Each axis = one feature (z-scored across datasets)
  - Axes labeled with feature names
  - Values normalized (z-scored) across datasets
  - Legend showing dataset names

# Requirements
Requires Plots.jl to be loaded in the calling environment.
"""
function plot_radar(datasets::Dict{String, Vector{Float64}}; features=nothing, title="Feature Comparison")
    # Check if Plots is available
    if !isdefined(Main, :plot)
        println("Visualization requires Plots.jl. Please run: using Plots")
        return nothing
    end

    # Access Plots functions through Main
    plot = Main.plot
    plot! = Main.plot!

    # Handle empty datasets
    if isempty(datasets)
        println("No datasets provided for radar plot")
        return nothing
    end

    # Determine features to plot
    if features === nothing
        # Use first dataset to determine available features
        first_data = first(values(datasets))
        valid_len = length(first_data)
        features = valid_features(valid_len)

        # Handle case where no features are valid for this length
        if isempty(features)
            println("No valid features available for dataset length $(valid_len)")
            return nothing
        end
    end

    # Extract feature values for each dataset
    feature_matrix = Dict()
    for (name, data) in datasets
        feature_row = extract_feature_set(data)
        # Convert DataFrame row to vector of values for requested features
        feature_vec = Float64[]
        for f in features
            if hasproperty(feature_row, Symbol(f))
                val = getproperty(feature_row, Symbol(f))[1]
                push!(feature_vec, val)
            else
                push!(feature_vec, 0.0)  # Default to 0 if feature not found
            end
        end
        feature_matrix[name] = feature_vec
    end

    # Normalize features (z-score across all datasets and features)
    all_values = vcat([feature_matrix[k] for k in keys(datasets)]...)
    μ = mean(all_values)
    σ = std(all_values)

    # Avoid division by zero
    σ = σ > 1e-10 ? σ : 1e-10

    # Normalize each dataset
    normalized = Dict()
    for (name, values) in feature_matrix
        normalized[name] = (values .- μ) ./ σ
    end

    # Create angles for each feature axis
    n_features = length(features)
    angles = range(0, 2π, length=n_features+1)[1:end-1]

    # Create radar plot with polar projection
    p = plot([], [], projection=:polar, title=title, legend=true, size=(800, 800))

    # Plot each dataset
    colors = [:blue, :red, :green, :purple, :orange, :brown, :pink, :gray]
    for (idx, (name, values)) in enumerate(normalized)
        # Close the polygon by repeating first point
        plot_angles = vcat(angles, angles[1])
        plot_values = vcat(values, values[1])

        # Cycle through colors
        color_idx = ((idx - 1) % length(colors)) + 1
        color = colors[color_idx]

        plot!(p, plot_angles, plot_values,
            label=name,
            color=color,
            linewidth=2,
            fillalpha=0.15)
    end

    # Set radial axis limits (based on z-scores, typically -3 to +3)
    plot!(p, ylims=(-3, 3))

    return p
end

"""
    plot_correlations(features_df::DataFrame; title="Feature Correlations") -> Figure

Create a correlation heatmap showing relationships between features.
This function is provided by the HeartRateLabVisualizationExt extension when GLMakie is loaded.
"""
function plot_correlations(features_df)
    error("plot_correlations requires GLMakie. Please run: using GLMakie")
end

"""
    plot_feature_violins(real::DataFrame, ensembles::Dict{String, DataFrame}; features=nothing) -> Figure

Create violin plots comparing real vs synthetic feature distributions.
This function is provided by the HeartRateLabVisualizationExt extension when GLMakie is loaded.
"""
function plot_feature_violins(real, ensembles; features=nothing)
    error("plot_feature_violins requires GLMakie. Please run: using GLMakie")
end

end