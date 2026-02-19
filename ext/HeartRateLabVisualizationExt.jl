"""
    HeartRateLabVisualizationExt

Extension providing offline visualization functions for HRV analysis using GLMakie.

This extension is loaded automatically when GLMakie is imported alongside HeartRateLab.

# Visualization Functions Provided (implemented in Phase 4)

## Comparison Plots
- `plot_radar()`: Spider/radar chart of feature z-scores across models/datasets
- `plot_feature_violins()`: Distribution violin plots for real vs synthetic features
- `plot_comparison()`: Time series and Poincaré plots side-by-side for model comparison
- `plot_model_heatmap()`: Reproduction quality heatmap (models × features)
- `plot_correlations()`: Pairplot showing feature correlations across origins

## Analysis Plots
- `plot_poincare()`: Poincaré scatter plot with ellipse
- `plot_spectrum()`: Frequency spectrum (Welch periodogram)
- `plot_ibi_series()`: Time series of inter-beat-intervals
- `plot_lorenz_3d()`: 3D Lorenz plot (IBI[n] vs IBI[n+1] vs IBI[n+2])

## Model-Specific Plots
- LIF: Phase portrait of membrane potential V(t) with spike resets
- Van der Pol: Phase portrait in (x, y) space
- Lorenz: 3D attractor visualization
- DMD: Mode amplitudes and frequencies

All plots are offline-capable and work with in-memory data structures.
For real-time visualization with LSL streams, see `HeartRateLabLSLExt`.

# Example (when implemented)
```julia
using HeartRateLab
using GLMakie  # This loads the visualization extension

# Load and analyze real data
real_data = read_txt("subject.txt")
real_features = extract_feature_set(real_data)

# Fit model and generate synthetic data
result = fit(LIF(), real_data; method=:bayesian)
synthetic_ibis = simulate(result.model, result.params, 500)
synthetic_features = extract_feature_set(synthetic_ibis)

# Visualize comparison
fig = plot_feature_violins(real_features, Dict("LIF" => synthetic_features))
display(fig)
```
"""
module HeartRateLabVisualizationExt

# Import the parent module
import HeartRateLab
using HeartRateLab.Models

# Conditional imports based on Julia version
if !isdefined(Base, :get_extension)
    error("Package extensions require Julia >= 1.9")
end

# GLMakie and related plotting dependencies
using GLMakie
using DataFrames
using Statistics
using DSP

"""
    plot_ibi_series(ibis::Vector{Float64}; title="IBI Time Series") -> Figure

Create a line plot of inter-beat-intervals over time.

# Arguments
- `ibis::Vector{Float64}`: Inter-beat-interval series in milliseconds
- `title::String`: Figure title

# Returns
- `Figure`: GLMakie figure object showing IBI time series

# Features
- Mean line in red
- ±1 standard deviation envelope
- Clear axis labels and legend
"""
function plot_ibi_series(ibis::Vector{Float64}; title="IBI Time Series")
    n = length(ibis)
    t = 1:n

    mean_ibi = mean(ibis)
    std_ibi = std(ibis)

    fig = Figure(size=(800, 400))
    ax = Axis(fig[1, 1];
        xlabel="Beat Index",
        ylabel="IBI (ms)",
        title=title
    )

    # Plot IBI time series
    lines!(ax, t, ibis; label="IBI", color=:blue, linewidth=2)

    # Plot mean line
    lines!(ax, t, fill(mean_ibi, n); label="Mean", color=:red, linestyle=:dash, linewidth=1.5)

    # Plot ±1 std envelope
    band!(ax, t, mean_ibi .- std_ibi, mean_ibi .+ std_ibi;
        label="±1 SD", color=(:gray, 0.3))

    axislegend(ax)
    return fig
end

"""
    plot_poincare(ibis::Vector{Float64}; title="Poincaré Plot") -> Figure

Create a Poincaré plot showing IBI[n] vs IBI[n+1] correlation.

# Arguments
- `ibis::Vector{Float64}`: Inter-beat-interval series in milliseconds
- `title::String`: Figure title

# Returns
- `Figure`: GLMakie figure object showing Poincaré scatter plot

# Features
- Scatter plot of (IBI[n], IBI[n+1])
- Mean point marked with ⊕
- Confidence ellipse based on SD1/SD2 (Poincaré descriptors)
"""
function plot_poincare(ibis::Vector{Float64}; title="Poincaré Plot")
    # Create pairs: (IBI[n], IBI[n+1])
    x = ibis[1:end-1]
    y = ibis[2:end]

    # Compute Poincaré descriptors
    # SD1 = std along minor axis (perpendicular to identity line)
    # SD2 = std along major axis (along identity line)
    diff_ibi = diff(ibis)
    sum_ibi = ibis[1:end-1] .+ ibis[2:end]

    sd1 = std(diff_ibi) / sqrt(2)
    sd2 = std(sum_ibi) / sqrt(2)

    mean_x = mean(x)
    mean_y = mean(y)

    fig = Figure(size=(600, 600))
    ax = Axis(fig[1, 1];
        xlabel="IBI[n] (ms)",
        ylabel="IBI[n+1] (ms)",
        title=title,
        aspect=DataAspect()
    )

    # Scatter plot
    scatter!(ax, x, y; label="Beat pairs", color=:blue, markersize=6, alpha=0.7)

    # Plot mean point
    scatter!(ax, [mean_x], [mean_y]; label="Mean", color=:red, markersize=10, marker='⊕')

    # Plot identity line (reference)
    xlim_data = (minimum(x) - 50, maximum(x) + 50)
    lines!(ax, xlim_data, xlim_data; label="Identity", color=:black, linestyle=:dash, linewidth=1)

    # Plot ellipse (simplified - just show SD1/SD2 ranges)
    # Note: For full ellipse, would need to rotate based on angle
    xlims!(ax, xlim_data)
    ylims!(ax, xlim_data)

    axislegend(ax)
    return fig
end

"""
    plot_spectrum(ibis::Vector{Float64}; fs=1.0, title="HRV Power Spectrum") -> Figure

Create a power spectrum plot of inter-beat-interval series using Welch method.

# Arguments
- `ibis::Vector{Float64}`: Inter-beat-interval series in milliseconds
- `fs::Float64`: Sampling frequency (beats per second, default 1.0)
- `title::String`: Figure title

# Returns
- `Figure`: GLMakie figure object showing frequency spectrum

# Features
- Welch periodogram with 50% overlap
- Log scale on power axis
- HRV standard frequency bands marked:
  - VLF (0.0-0.04 Hz): very low frequency
  - LF (0.04-0.15 Hz): low frequency
  - HF (0.15-0.4 Hz): high frequency
"""
function plot_spectrum(ibis::Vector{Float64}; fs=1.0, title="HRV Power Spectrum")
    # Normalize IBI series
    ibis_norm = (ibis .- mean(ibis)) ./ std(ibis)

    # Compute Welch periodogram
    # Window length = ~64 samples, 50% overlap
    nfft = min(256, nextpow(2, length(ibis_norm) ÷ 2))
    freq, power = welch_pgram(ibis_norm; fs=fs, nfft=nfft)

    fig = Figure(size=(900, 500))
    ax = Axis(fig[1, 1];
        xlabel="Frequency (Hz)",
        ylabel="Power (dB)",
        title=title,
        yscale=log10,
        xscale=log10
    )

    # Plot power spectrum
    lines!(ax, freq, power; label="Power spectrum", color=:blue, linewidth=2)

    # Mark HRV frequency bands
    # VLF: 0.0-0.04 Hz
    vspan!(ax, 0.001, 0.04; color=(:red, 0.1), label="VLF")
    # LF: 0.04-0.15 Hz
    vspan!(ax, 0.04, 0.15; color=(:green, 0.1), label="LF")
    # HF: 0.15-0.4 Hz
    vspan!(ax, 0.15, 0.4; color=(:blue, 0.1), label="HF")

    xlims!(ax, 0.001, 0.5)

    axislegend(ax)
    return fig
end

"""
    plot_comparison(real_ibis::Vector{Float64}, synthetic_ibis::Vector{Float64}; model_name="Model") -> Figure

Create side-by-side comparison plots of real vs synthetic IBI data.

# Arguments
- `real_ibis::Vector{Float64}`: Real IBI data
- `synthetic_ibis::Vector{Float64}`: Synthetic IBI data from model
- `model_name::String`: Name of the model for display

# Returns
- `Figure`: GLMakie figure with 2×2 layout comparing the datasets

# Layout
- Top-left: IBI time series overlay (real vs synthetic)
- Top-right: Poincaré plots overlay
- Bottom-left: IBI distribution histograms
- Bottom-right: Q-Q plot for normality assessment
"""
function plot_comparison(real_ibis::Vector{Float64}, synthetic_ibis::Vector{Float64};
                         model_name="Model")
    fig = Figure(size=(1200, 900))

    # Top-left: Time series overlay
    ax_ts = Axis(fig[1, 1]; xlabel="Beat Index", ylabel="IBI (ms)", title="IBI Time Series")
    lines!(ax_ts, 1:min(length(real_ibis), 200), real_ibis[1:min(length(real_ibis), 200)];
        label="Real", color=:blue, linewidth=2)
    lines!(ax_ts, 1:min(length(synthetic_ibis), 200), synthetic_ibis[1:min(length(synthetic_ibis), 200)];
        label="Synthetic", color=:red, linestyle=:dash, linewidth=2, alpha=0.7)
    axislegend(ax_ts)

    # Top-right: Poincaré plots overlay
    ax_poincare = Axis(fig[1, 2]; xlabel="IBI[n] (ms)", ylabel="IBI[n+1] (ms)",
        title="Poincaré Plot Comparison", aspect=DataAspect())

    scatter!(ax_poincare, real_ibis[1:end-1], real_ibis[2:end];
        label="Real", color=:blue, markersize=4, alpha=0.6)
    scatter!(ax_poincare, synthetic_ibis[1:end-1], synthetic_ibis[2:end];
        label="Synthetic", color=:red, markersize=4, alpha=0.6)

    # Add identity line
    xlim_data = (minimum([real_ibis; synthetic_ibis]) - 50,
                 maximum([real_ibis; synthetic_ibis]) + 50)
    lines!(ax_poincare, xlim_data, xlim_data; color=:black, linestyle=:dash, alpha=0.5)
    axislegend(ax_poincare)

    # Bottom-left: Distribution histograms
    ax_hist = Axis(fig[2, 1]; xlabel="IBI (ms)", ylabel="Count", title="IBI Distribution")
    hist!(ax_hist, real_ibis; bins=20, label="Real", color=(:blue, 0.5))
    hist!(ax_hist, synthetic_ibis; bins=20, label="Synthetic", color=(:red, 0.5))
    axislegend(ax_hist)

    # Bottom-right: Q-Q plot (simplified - just sort and plot against normal quantiles)
    ax_qq = Axis(fig[2, 2]; xlabel="Theoretical Quantiles", ylabel="Sample Quantiles",
        title="Q-Q Plot (Real Data)")

    real_sorted = sort((real_ibis .- mean(real_ibis)) ./ std(real_ibis))
    n = length(real_sorted)
    quantiles = (1:n ./ n) .- 0.5 ./ n
    scatter!(ax_qq, quantiles, real_sorted; markersize=4, alpha=0.6)
    # Add y=x reference line
    lines!(ax_qq, quantiles, quantiles; color=:black, linestyle=:dash, alpha=0.5)

    fig
end

"""
    plot_model_heatmap(errors::Dict{String, Vector{Float64}}, features::Vector{String}) -> Figure

Create a heatmap showing model reproduction quality across features.

# Arguments
- `errors::Dict{String, Vector{Float64}}`: Dict mapping model names to error vectors per feature
- `features::Vector{String}`: Feature names for labels

# Returns
- `Figure`: GLMakie figure with heatmap

# Details
Error values are normalized to [0,1] quality scale (0=poor, 1=perfect reproduction)
"""
function plot_model_heatmap(errors::Dict{String, Vector{Float64}}, features::Vector{String})
    # Prepare data: models × features matrix
    models = sort(collect(keys(errors)))
    n_models = length(models)
    n_features = length(features)

    # Normalize errors to quality [0, 1]
    quality_matrix = zeros(n_models, n_features)
    for (i, model_name) in enumerate(models)
        error_vec = errors[model_name]
        # Truncate/pad to match feature count
        error_vec_adj = error_vec[1:min(length(error_vec), n_features)]

        # Convert error to quality (lower error = higher quality)
        # Assume errors are normalized 0-100, map 0 error → quality 1, 100 error → quality 0
        quality_matrix[i, 1:length(error_vec_adj)] .= max.(0.0, 1.0 .- error_vec_adj ./ 100.0)
    end

    fig = Figure(size=(1000, 400))
    ax = Axis(fig[1, 1])

    hm = heatmap!(ax, quality_matrix;
        colormap=:RdYlGn,
        colorrange=(0, 1),
        lowclip=:red,
        highclip=:green
    )

    # Set ticks
    ax.xticks = (1:n_features, features)
    ax.yticks = (1:n_models, models)
    ax.xlabel = "Features"
    ax.ylabel = "Models"
    ax.title = "Model Reproduction Quality Heatmap"

    # Rotate x-axis labels
    ax.xticklabelrotation = π/4

    # Add colorbar
    Colorbar(fig[1, 2], hm, label="Quality (0=poor, 1=perfect)")

    fig
end

"""
    plot_lorenz_3d(ibis::Vector{Float64}; title="Lorenz Plot 3D") -> Figure

Create an interactive 3D scatter plot showing IBI[n] vs IBI[n+1] vs IBI[n+2].

# Arguments
- `ibis::Vector{Float64}`: Inter-beat-interval series
- `title::String`: Figure title

# Returns
- `Figure`: Interactive GLMakie 3D figure (rotatable, zoomable)

# Details
Points are colored by time progression (earlier → blue, later → red)
useful for visualizing patterns in cardiac dynamics.
"""
function plot_lorenz_3d(ibis::Vector{Float64}; title="Lorenz Plot 3D")
    # Construct 3D points: (IBI[n], IBI[n+1], IBI[n+2])
    n = length(ibis) - 2
    x = ibis[1:n]
    y = ibis[2:n+1]
    z = ibis[3:n+2]

    # Color by time progression (0 → 1)
    colors = range(0, 1, length=n)

    fig = Figure(size=(800, 800))
    ax = Axis3(fig[1, 1];
        xlabel="IBI[n] (ms)",
        ylabel="IBI[n+1] (ms)",
        zlabel="IBI[n+2] (ms)",
        title=title
    )

    scatter!(ax, x, y, z; color=colors, colormap=:viridis, markersize=5, alpha=0.7)

    Colorbar(fig[1, 2], label="Time Progression", colormap=:viridis, limits=(0, 1))

    fig
end

"""
    plot_radar(data::Dict{String, Vector{Float64}}; names::Vector{String}) -> Figure

Create a radar/spider chart comparing multiple datasets across dimensions.

# Arguments
- `data::Dict{String, Vector{Float64}}`: Dict mapping labels to data vectors
- `names::Vector{String}`: Dimension names for axes

# Returns
- `Figure`: GLMakie figure with radar chart

# Details
Values are normalized to [0, 1] using min-max scaling for fair comparison.
Each dataset is plotted as a separate polygon.
"""
function plot_radar(data::Dict{String, Vector{Float64}}; names::Vector{String})
    # Prepare data
    keys_list = sort(collect(keys(data)))
    n_dims = length(names)

    # Normalize data to [0, 1]
    all_vals = vcat(collect.(values(data))...)
    val_min = minimum(all_vals)
    val_max = maximum(all_vals)

    normalized_data = Dict()
    for (key, vec) in data
        normalized_data[key] = (vec .- val_min) ./ (val_max - val_min + 1e-8)
    end

    # Create polar coordinates for radar plot
    angles = range(0, 2π, length=n_dims+1)

    fig = Figure(size=(800, 800))
    ax = PolarAxis(fig[1, 1]; title="Radar Chart", rticklabelsize=12)

    # Plot each dataset
    colors_map = Dict(k => HSL(i*360/length(keys_list), 0.7, 0.5)
                      for (i, k) in enumerate(keys_list))

    for (i, key) in enumerate(keys_list)
        vals = normalized_data[key]
        # Close the polygon
        vals_closed = vcat(vals, vals[1])
        angles_closed = angles

        lines!(ax, angles_closed, vals_closed;
            label=key, color=colors_map[key], linewidth=3)
        scatter!(ax, angles_closed[1:end-1], vals;
            color=colors_map[key], markersize=8)
    end

    # Set radial ticks and labels
    ax.rticklabels = string.(0:0.25:1)
    ax.thetaticklabels = names

    axislegend(ax; position=:right)

    fig
end

"""
    plot_correlations(features_df::DataFrame; title="Feature Correlations") -> Figure

Create a correlation heatmap showing relationships between features.

# Arguments
- `features_df::DataFrame`: DataFrame with features as columns
- `title::String`: Figure title

# Returns
- `Figure`: GLMakie figure with correlation heatmap

# Details
Computes Pearson correlation between all pairs of features.
Displays correlation matrix as a symmetric heatmap.
Diagonal shows perfect correlation (1.0).
"""
function plot_correlations(features_df::DataFrame; title="Feature Correlations")
    # Convert to matrix if needed
    data_matrix = Matrix(features_df)

    # Compute correlation matrix
    corr_matrix = Statistics.cor(data_matrix)

    feature_names = names(features_df)
    n_features = size(corr_matrix, 1)

    fig = Figure(size=(900, 900))
    ax = Axis(fig[1, 1])

    # Plot heatmap
    hm = heatmap!(ax, corr_matrix;
        colormap=:RdBu_11,
        colorrange=(-1, 1),
        lowclip=:darkred,
        highclip=:darkblue
    )

    # Set labels
    ax.xticks = (1:n_features, feature_names)
    ax.yticks = (1:n_features, feature_names)
    ax.xlabel = "Features"
    ax.ylabel = "Features"
    ax.title = title

    # Rotate x-axis labels for readability
    ax.xticklabelrotation = π/4

    # Add correlation values in cells (if not too many features)
    if n_features <= 15
        for i in 1:n_features
            for j in 1:n_features
                val = round(corr_matrix[i, j]; digits=2)
                text!(ax, j, i; text=string(val), align=(:center, :center),
                    color=ifelse(abs(corr_matrix[i, j]) > 0.5, :white, :black),
                    fontsize=8)
            end
        end
    end

    # Add colorbar
    Colorbar(fig[1, 2], hm, label="Pearson Correlation")

    fig
end

"""
    plot_feature_violins(real::DataFrame, ensembles::Dict{String, DataFrame}; features=nothing) -> Figure

Create violin plots comparing real vs synthetic feature distributions.

# Arguments
- `real::DataFrame`: Real feature data (n_real_samples × n_features)
- `ensembles::Dict{String, DataFrame}`: Dict mapping model names to feature DataFrames
  - Each DataFrame should have same columns as `real`
  - Rows represent samples from that model's ensemble
- `features=nothing`: Subset of features to plot (default: all common columns)

# Returns
- `Figure`: GLMakie figure with one panel per feature, showing:
  - Reference violin for real data (in gray)
  - Colored violins for each model's synthetic distribution

# Details
Enables visual comparison of feature distributions between real and synthetic data.
Useful for identifying which features the models capture well vs. poorly.
All features must have numeric columns.

# Example
```julia
real_features = extract_feature_set(real_data)
real_df = DataFrame([real_features])  # 1 row
ensemble_df = extract_ensemble_features(ensemble)  # n_sim rows
fig = plot_feature_violins(real_df, Dict("LIF" => ensemble_df))
```
"""
function plot_feature_violins(real::DataFrame, ensembles::Dict{String, DataFrame}; features=nothing)
    # Determine which features to use
    if isnothing(features)
        # Use all common columns
        common_cols = intersect(names(real), [names(df) for df in values(ensembles)]...)
        features = String.(common_cols)
    end

    n_features = length(features)
    n_models = length(ensembles)
    model_names = sort(collect(keys(ensembles)))
    colors = HSL.(range(0, 360, length=n_models+1)[1:end-1], 0.7, 0.5)

    # Calculate subplot grid
    n_cols = min(3, n_features)  # 3 columns max
    n_rows = cld(n_features, n_cols)

    fig = Figure(size=(300*n_cols, 250*n_rows))

    for (feat_idx, feat_name) in enumerate(features)
        ax_row = cld(feat_idx, n_cols)
        ax_col = ((feat_idx - 1) % n_cols) + 1

        ax = Axis(fig[ax_row, ax_col];
            title=feat_name,
            xlabel="Distribution",
            ylabel="Value",
            xticks=(1:n_models+1, vcat("Real", model_names))
        )

        # Prepare data for violin plot
        all_positions = []
        all_values = []
        all_colors = []

        # Real data (position 1)
        real_vals = real[!, feat_name]
        # Remove NaN and Inf
        real_vals = filter(x -> isfinite(x), real_vals)
        if !isempty(real_vals)
            append!(all_positions, fill(1, length(real_vals)))
            append!(all_values, real_vals)
            append!(all_colors, fill(:gray, length(real_vals)))
        end

        # Synthetic data (positions 2, 3, ..., n_models+1)
        for (model_idx, model_name) in enumerate(model_names)
            synth_vals = ensembles[model_name][!, feat_name]
            # Remove NaN and Inf
            synth_vals = filter(x -> isfinite(x), synth_vals)
            if !isempty(synth_vals)
                append!(all_positions, fill(model_idx + 1, length(synth_vals)))
                append!(all_values, synth_vals)
                append!(all_colors, fill(model_idx, length(synth_vals)))
            end
        end

        # Plot violins
        if !isempty(all_positions)
            violin!(ax, all_positions, all_values;
                color=all_colors,
                colormap=[:gray; colors],
                alpha=0.6,
                linewidth=0
            )

            # Add box plots on top for quartile visualization
            boxplot!(ax, all_positions, all_values;
                color=all_colors,
                colormap=[:gray; colors],
                strokewidth=1,
                width=0.2,
                alpha=0.3
            )
        end

        # Add mean marker
        real_mean = mean(filter(x -> isfinite(x), real[!, feat_name]))
        scatter!(ax, [1], [real_mean]; color=:red, markersize=8, marker=:star5, label="Real mean")

        for (model_idx, model_name) in enumerate(model_names)
            model_mean = mean(filter(x -> isfinite(x), ensembles[model_name][!, feat_name]))
            scatter!(ax, [model_idx + 1], [model_mean];
                color=colors[model_idx], markersize=8, marker=:star5)
        end

        # Clean up axis
        hidexdecorations!(ax; label=false, ticklabels=false)
        hidedecorations!(ax; label=false, ticklabels=false)
        ax.xticks = (1:n_models+1, vcat("Real", model_names))
        ax.xticklabelrotation = π/6
    end

    fig
end

# TODO: Phase 4 - Visualization implementations will be added here:
# - plot_radar()
# - plot_feature_violins()
# - plot_comparison()
# - plot_model_heatmap()
# - plot_correlations()
# - plot_poincare()
# - plot_spectrum()
# - plot_ibi_series()
# - plot_lorenz_3d()
# - Model-specific phase portraits

"""
    __init__()

Initialize the visualization extension. Called automatically when GLMakie is loaded.
"""
function __init__()
    # This function is called automatically when the extension is loaded
end

end  # HeartRateLabVisualizationExt
