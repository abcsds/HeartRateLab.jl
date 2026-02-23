module Visualization

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

end