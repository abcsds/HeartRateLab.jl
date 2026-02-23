module Visualization

using Statistics

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

end