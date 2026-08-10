"""
    HeartRateLabVisualizationExt

Extension providing interactive GLMakie renderings of the HRV visualization API.

Loaded automatically when GLMakie is imported alongside HeartRateLab. Rather than
defining new functions, it adds **methods** to the package's internal
`HeartRateLab.Visualization._glmakie_plot_*` generics and flips the default
backend to `:glmakie` in `__init__`. The public names (`plot_ibi_series`,
`plot_poincare`, `plot_spectrum`, `plot_comparison`, `plot_model_heatmap`,
`plot_lorenz_3d`, `plot_radar`, `plot_correlations`, `plot_flagship`,
`plot_feature_violins`) therefore return GLMakie figures once GLMakie is loaded,
without the caller changing anything. Pass `backend=:plots` to force the static
Plots.jl figure even with GLMakie loaded.

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
using HeartRateLab: ModelFitResult

# The Visualization submodule owns the public `plot_*` generics. This extension
# adds GLMakie *methods* to its internal `_glmakie_plot_*` generics, so the
# public names (`plot_ibi_series`, …) reach the GLMakie figures when GLMakie is
# loaded. See the dispatch docstring in src/Visualization/Visualization.jl.
const Viz = HeartRateLab.Visualization

# Conditional imports based on Julia version
if !isdefined(Base, :get_extension)
    error("Package extensions require Julia >= 1.9")
end

# GLMakie and related plotting dependencies
using GLMakie
using DataFrames
using Statistics
using DSP
import Random
using HeartRateLab.Frequency: lomb_scargle, welch, get_power, find_peak

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
function Viz._glmakie_plot_ibi_series(ibis::Vector{Float64}; title="IBI Time Series")
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

    # Plot ±1 std envelope. Makie's band! wants per-x vectors for the bounds.
    band!(ax, collect(t), fill(mean_ibi - std_ibi, n), fill(mean_ibi + std_ibi, n);
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
function Viz._glmakie_plot_poincare(ibis::Vector{Float64}; title="Poincaré Plot")
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

    # Plot identity line (reference). Makie's lines! needs coordinate vectors,
    # not a tuple of endpoints.
    xlim_data = (minimum(x) - 50, maximum(x) + 50)
    lines!(ax, [xlim_data[1], xlim_data[2]], [xlim_data[1], xlim_data[2]];
        label="Identity", color=:black, linestyle=:dash, linewidth=1)

    # Plot ellipse (simplified - just show SD1/SD2 ranges)
    # Note: For full ellipse, would need to rotate based on angle
    xlims!(ax, xlim_data)
    ylims!(ax, xlim_data)

    axislegend(ax)
    return fig
end

"""
    plot_spectrum(ibis::Vector{Float64}; method=:lomb, title="HRV Power Spectrum") -> Figure

Create a power spectrum plot of inter-beat-interval series with frequency bands.

# Arguments
- `ibis::Vector{Float64}`: Inter-beat-interval series in milliseconds
- `method::Symbol`: Spectrum method - :lomb (default), :welch, or :periodogram
- `title::String`: Figure title

# Returns
- `Figure`: GLMakie figure object showing frequency spectrum

# Features
- Multiple spectrum methods: Lomb-Scargle, Welch, or DSP Periodogram
- Log scale on power axis
- HRV standard frequency bands marked with vertical lines and shaded regions:
  - VLF (0.003-0.04 Hz): very low frequency
  - LF (0.04-0.15 Hz): low frequency
  - HF (0.15-0.4 Hz): high frequency
- Peak frequency marked with coral cross
- Band power values displayed in title
"""
function Viz._glmakie_plot_spectrum(ibis::Vector{Float64}; method=:lomb, title="HRV Power Spectrum")
    # Validate method
    method in [:lomb, :welch, :periodogram] ||
        throw(ArgumentError("method must be :lomb, :welch, or :periodogram"))

    # Get spectrum based on method
    if method == :lomb
        pgram = lomb_scargle(Float64.(ibis))
    elseif method == :welch
        pgram = welch(Float64.(ibis))
    else  # :periodogram
        # Use DSP.periodogram with normalization
        ibis_norm = (Float64.(ibis) .- mean(ibis)) ./ std(ibis)
        # nfft must be >= length of signal
        nfft = nextpow(2, length(ibis_norm))
        pgram = DSP.periodogram(ibis_norm; fs=1.0, nfft=nfft)
    end

    freq = pgram.freq
    power = pgram.power

    # Calculate band powers using get_power
    vlf = get_power(pgram, 0.003, 0.04)
    lf = get_power(pgram, 0.04, 0.15)
    hf = get_power(pgram, 0.15, 0.4)
    tp = vlf + lf + hf

    # Find peak frequency
    peak_freq = find_peak(pgram, 0.003, 0.4)
    if isnan(peak_freq)
        _, peak_idx = findmax(power)
        peak_freq = freq[peak_idx]
    end
    peak_idx = argmin(abs.(freq .- peak_freq))
    peak_power = power[peak_idx]

    # Create figure with teal line and band markers
    fig = Figure(size=(1000, 600))
    ax = Axis(fig[1, 1];
        xlabel="Frequency (Hz)",
        ylabel="Power (ms²/Hz)",
        title=title,
        yscale=log10
    )

    # Shaded regions for frequency bands (light background)
    vspan!(ax, 0.003, 0.04; color=(:red, 0.1), label="VLF (0.003-0.04 Hz)")
    vspan!(ax, 0.04, 0.15; color=(:green, 0.1), label="LF (0.04-0.15 Hz)")
    vspan!(ax, 0.15, 0.4; color=(:blue, 0.1), label="HF (0.15-0.4 Hz)")

    # Plot power spectrum line in teal
    lines!(ax, freq, power; label="Power spectrum", color=:teal, linewidth=2.5)

    # Vertical band markers at boundaries
    vlines!(ax, [0.003, 0.04, 0.15, 0.4];
            color=:black, linestyle=:dash, linewidth=1.5, label="Band boundaries")

    # Peak marker with coral cross
    scatter!(ax, [peak_freq], [peak_power];
            marker=:xcross, markersize=15, color=:coral, label="Peak ($(round(peak_freq, digits=3)) Hz)")

    # Set axis limits
    xlims!(ax, 0.003, 0.4)
    ylims!(ax, minimum(power[freq .>= 0.003]) / 10, maximum(power) * 2)

    # Add legend with power values
    Legend(fig[1, 2], ax,
           title="Band Powers (ms²):\nVLF: $(round(vlf, digits=1))\nLF: $(round(lf, digits=1))\nHF: $(round(hf, digits=1))\nTP: $(round(tp, digits=1))",
           labelsize=11, titlesize=12)

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
function Viz._glmakie_plot_comparison(real_ibis::Vector{Float64}, synthetic_ibis::Vector{Float64};
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

    # Add identity line (lines! needs coordinate vectors, not an endpoint tuple).
    lo = minimum([real_ibis; synthetic_ibis]) - 50
    hi = maximum([real_ibis; synthetic_ibis]) + 50
    lines!(ax_poincare, [lo, hi], [lo, hi]; color=:black, linestyle=:dash, alpha=0.5)
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
    # Plotting positions (i - 0.5)/n, one per sorted value. Parenthesised so the
    # range divides elementwise — `1:n ./ n` would parse as `1:(n/n)` = `1:1.0`.
    quantiles = ((1:n) ./ n) .- 0.5 / n
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
function Viz._glmakie_plot_model_heatmap(errors::Dict{String, Vector{Float64}}, features::Vector{String})
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
function Viz._glmakie_plot_lorenz_3d(ibis::Vector{Float64}; title="Lorenz Plot 3D")
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
    _glmakie_plot_radar(datasets::Dict{String, Vector{Float64}};
                        features=nothing, title="Feature Comparison") -> Figure

GLMakie radar/spider chart of per-dataset HRV features. Signature mirrors the
public `plot_radar`; reached via `plot_radar(datasets; ...)` when GLMakie is
loaded. Features are z-scored across datasets and drawn on a `PolarAxis`.
"""
function Viz._glmakie_plot_radar(datasets::Dict{String, Vector{Float64}};
                                 features=nothing, title="Feature Comparison")
    isempty(datasets) && error("plot_radar: no datasets provided")

    # Determine feature names exactly like the Plots version.
    if features === nothing
        features = HeartRateLab.Features.valid_features(length(first(values(datasets))))
        isempty(features) && error("plot_radar: no valid features for this dataset length")
    end

    # Extract feature values per dataset.
    feature_matrix = Dict{String, Vector{Float64}}()
    for (name, data) in datasets
        row = HeartRateLab.Features.extract_feature_set(data)
        feature_matrix[name] = Float64[
            hasproperty(row, Symbol(f)) ? getproperty(row, Symbol(f))[1] : 0.0
            for f in features
        ]
    end

    # z-score across all datasets/features.
    all_vals = vcat(values(feature_matrix)...)
    μ = mean(all_vals); σ = std(all_vals); σ = σ > 1e-10 ? σ : 1e-10
    normalized = Dict(k => (v .- μ) ./ σ for (k, v) in feature_matrix)

    keys_list = sort(collect(keys(datasets)))
    n_dims = length(features)
    angles = collect(range(0, 2π, length=n_dims + 1))

    fig = Figure(size=(800, 800))
    ax = PolarAxis(fig[1, 1]; title=title, rticklabelsize=12)
    colors_map = Dict(k => HSL(i * 360 / length(keys_list), 0.7, 0.5)
                      for (i, k) in enumerate(keys_list))

    for key in keys_list
        vals = normalized[key]
        lines!(ax, angles, vcat(vals, vals[1]);
            label=key, color=colors_map[key], linewidth=3)
        scatter!(ax, angles[1:end-1], vals; color=colors_map[key], markersize=8)
    end
    ax.thetaticklabels = features
    axislegend(ax; position=:right)
    fig
end

"""
    _glmakie_plot_correlations(feature_sets::Dict{String, DataFrame};
                               features=nothing, title="Feature Correlations") -> Figure

GLMakie Pearson-correlation heatmap. Signature mirrors the public
`plot_correlations`; reached via `plot_correlations(feature_sets; ...)` when
GLMakie is loaded. Rows from every dataset are pooled before correlating.
"""
function Viz._glmakie_plot_correlations(feature_sets::Dict{String, DataFrame};
                                        features=nothing, title="Feature Correlations")
    isempty(feature_sets) && error("plot_correlations: no feature sets provided")

    if features === nothing
        features = String.(names(first(values(feature_sets))))
    end
    features = String.(features)

    # Pool rows across datasets into one matrix (columns = features).
    cols = [vcat([Float64.(df[!, Symbol(f)]) for df in values(feature_sets)]...) for f in features]
    data_matrix = reduce(hcat, cols)

    corr_matrix = Statistics.cor(data_matrix)
    feature_names = features
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
function Viz._glmakie_plot_feature_violins(real::DataFrame, ensembles::Dict{String, DataFrame}; features=nothing)
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

"""
    plot_flagship(real_data::Vector{Float64}, fit_result::ModelFitResult; title="HeartRateLab Pipeline Demo") -> Figure

Create a comprehensive flagship visualization showcasing the complete HRV analysis pipeline.

Shows:
1. **Phase Portrait**: Model attractor with Bayesian posterior uncertainty
2. **Signal**: Generated IBIs with beat detection markers and IBI annotations
3. **Posterior**: Distribution of key parameters from MCMC

# Arguments
- `real_data::Vector{Float64}`: Original IBI data used for fitting
- `fit_result::ModelFitResult`: Result from fit() - contains model, params, posterior
- `title::String`: Figure title

# Returns
- `Figure`: Multi-panel GLMakie figure with:
  - Phase portrait (left): Attractor trajectory with posterior contours
  - Signal plot (right top): Generated IBIs with beat markers
  - Posterior plots (right bottom): Parameter distributions from MCMC

# Details
This is the flagship visualization showing:
- Real data (input)
- Fitted model dynamics
- Generated synthetic data
- Parameter uncertainty from Bayesian inference
- Beat detection with physiological annotations

Works with any model supporting both simulation and Bayesian fitting (LIF, VanDerPol, Lorenz).
"""
function Viz._glmakie_plot_flagship(real_data::Vector{Float64}, fit_result::ModelFitResult; title="HeartRateLab Pipeline Demo")
    # Validate inputs
    if isnothing(fit_result.posterior)
        @warn "fit_result has no posterior - using point estimates only"
    end

    # Generate synthetic data from fitted model
    synthetic_data = simulate(fit_result.model, fit_result.params, length(real_data))

    # Create figure layout: 2 columns
    # Left: Phase portrait + posterior
    # Right: Signal analysis
    fig = Figure(size=(1400, 800))

    # ========== LEFT COLUMN: Phase Portrait ==========
    ax_phase = Axis(fig[1, 1];
        xlabel="IBI[n] (ms)",
        ylabel="IBI[n+1] (ms)",
        title="Phase Portrait: Real vs Synthetic"
    )

    # Plot real data Poincaré (X vs X+1)
    x_real = real_data[1:end-1]
    y_real = real_data[2:end]
    scatter!(ax_phase, x_real, y_real; label="Real", color=:blue, markersize=5, alpha=0.5)

    # Plot synthetic data Poincaré
    x_synth = synthetic_data[1:end-1]
    y_synth = synthetic_data[2:end]
    scatter!(ax_phase, x_synth, y_synth; label="Synthetic", color=:orange, markersize=5, alpha=0.5)

    # Add posterior uncertainty visualization if available
    if !isnothing(fit_result.posterior)
        # Extract parameter posterior
        if haskey(fit_result.posterior, "μ")
            # Van der Pol model - show phase portrait for different μ values from posterior
            μ_samples = fit_result.posterior["μ"]
            μ_mean = mean(μ_samples)
            μ_std = std(μ_samples)

            # Create synthetic data with mean and ±1σ parameters
            try
                hr = fit_result.params.heart_rate
                synth_low = simulate(fit_result.model, (μ=max(0.5, μ_mean-μ_std), heart_rate=hr), length(real_data))
                synth_high = simulate(fit_result.model, (μ=min(3.0, μ_mean+μ_std), heart_rate=hr), length(real_data))

                x_low = synth_low[1:end-1]
                y_low = synth_low[2:end]
                x_high = synth_high[1:end-1]
                y_high = synth_high[2:end]

                # Plot uncertainty band as scatter with transparency
                scatter!(ax_phase, x_low, y_low; color=:orange, markersize=3, alpha=0.15, label="-1σ")
                scatter!(ax_phase, x_high, y_high; color=:orange, markersize=3, alpha=0.15, label="+1σ")
            catch
                # If posterior sampling fails, just use mean
            end
        end
    end

    axislegend(ax_phase; position=:rt)
    xlims!(ax_phase, minimum(x_real)-50, maximum(x_real)+50)
    ylims!(ax_phase, minimum(y_real)-50, maximum(y_real)+50)

    # ========== RIGHT COLUMN: Signal Analysis ==========
    # Top right: IBI time series with beat markers
    ax_signal = Axis(fig[1, 2];
        xlabel="Beat Index",
        ylabel="IBI (ms)",
        title="Generated Signal with Beat Detection"
    )

    n_beats = length(synthetic_data)
    beat_indices = 1:n_beats

    # Plot synthetic signal
    lines!(ax_signal, beat_indices, synthetic_data; color=:orange, linewidth=2, label="Synthetic IBIs")

    # Plot real signal for reference
    lines!(ax_signal, beat_indices[1:length(real_data)], real_data; color=:blue, linewidth=1, alpha=0.5, linestyle=:dash, label="Real IBIs")

    # Add beat detection markers (peaks for visualization)
    peak_threshold = mean(synthetic_data) + 0.5 * std(synthetic_data)
    peaks = findall(synthetic_data .> peak_threshold)

    if !isempty(peaks)
        scatter!(ax_signal, peaks, synthetic_data[peaks]; color=:red, markersize=8, marker=:diamond, label="Beat peaks")

        # Annotate some IBIs
        for i in 1:min(5, length(peaks)-1)
            ibi_val = peaks[i+1] - peaks[i]
            mid_x = (peaks[i] + peaks[i+1]) / 2
            mid_y = maximum(synthetic_data) + 50

            text!(ax_signal, mid_x, mid_y;
                text="$(Int(round(ibi_val)))ms",
                fontsize=9,
                align=(:center, :bottom),
                color=:darkred
            )
        end
    end

    axislegend(ax_signal; position=:rt)
    xlims!(ax_signal, 0, n_beats+1)

    # Bottom right: Posterior parameter distributions
    if !isnothing(fit_result.posterior) && !isempty(fit_result.posterior)
        param_names = collect(keys(fit_result.posterior))
        n_params = min(length(param_names), 2)  # Show top 2 parameters

        for (param_idx, param_name) in enumerate(param_names[1:n_params])
            ax_post = Axis(fig[2, 2];
                xlabel=param_name,
                ylabel="Density",
                title="Posterior: $param_name"
            )

            samples = fit_result.posterior[param_name]
            # Create histogram
            hist!(ax_post, samples; bins=30, color=(:teal, 0.6), alpha=0.7)

            # Add mean and std lines
            mean_val = mean(samples)
            std_val = std(samples)
            vlines!(ax_post, [mean_val]; color=:red, linewidth=2, label="Mean: $(round(mean_val; digits=2))")
            vlines!(ax_post, [mean_val - std_val, mean_val + std_val]; color=:darkred, linewidth=1, linestyle=:dash, label="±1σ")

            axislegend(ax_post; position=:rt, fontsize=10)

            # Only show one posterior plot for space
            break
        end
    end

    # Add overall title
    Label(fig[0, :], title, fontsize=20, font=:bold)

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

# ============================================================================
# Real-time live view (backs HeartRateLab.Visualization.live / `nix run .#viz`)
# ============================================================================

# A synthetic RR generator (ms): ~850 ms baseline with respiratory sinus
# arrhythmia plus small noise. Used by `source=:simulate` for demos/testing the
# render pipeline with no hardware or LSL.
function _simulate_source()
    rng = Random.MersenneTwister(1)
    i = Ref(0)
    return function ()
        i[] += 1
        return 850.0 + 60.0 * sin(2π * i[] / 12) + 15.0 * Random.randn(rng)
    end
end

# Render loop, decoupled from the data source. `next_rr` is a zero-arg callable
# returning the next RR interval in ms, NaN to skip a tick, or `nothing` to stop.
function _live_view(next_rr; sample_size::Int=100, frames::Int=typemax(Int),
                    title::AbstractString="Heart Rate")
    rr  = Observable(fill(NaN, sample_size))
    bpm = Observable(fill(NaN, sample_size))
    x   = Observable(collect(1:sample_size))
    avg = Observable(0.0)
    ttl = Observable(String(title))
    fig = Figure(size=(1280, 720))
    ax  = Axis(fig[1, 1], title=ttl, xlabel="beat (rolling window)", ylabel="Heart rate (BPM)")
    lines!(ax, x, bpm, color=:teal)
    hlines!(ax, avg, color=:coral, linestyle=:dash)
    display(fig)
    frame = 0
    while frame < frames
        v = next_rr()
        v === nothing && break
        (isnan(v) || v <= 0) && continue
        rr[]  = [rr[][2:end]; Float64(v)]
        b     = 60000.0 ./ rr[]
        bpm[] = b
        fin   = filter(isfinite, b)
        avg[] = isempty(fin) ? 0.0 : mean(fin)
        ttl[] = isempty(fin) ? String(title) : "$(title) — BPM ≈ $(round(avg[], digits=1))"
        autolimits!(ax)
        frame += 1
    end
    return fig
end

# Entry point delegated to from HeartRateLab.Visualization.live.
function live_impl(; source=:lsl, sample_size::Int=100, frames::Int=typemax(Int),
                   title::AbstractString="Heart Rate", kwargs...)
    next_rr = if source === :simulate
        _simulate_source()
    elseif source isa Function
        source
    elseif source === :lsl
        lslext = Base.get_extension(HeartRateLab, :HeartRateLabLSLExt)
        lslext === nothing && error("source=:lsl requires LSL. Please run: using LSL")
        lslext.rr_source(; kwargs...)
    else
        error("Unknown live source: $source (use :lsl, :simulate, or a zero-arg Function)")
    end
    return _live_view(next_rr; sample_size=sample_size, frames=frames, title=title)
end

"""
    __init__()

Initialize the visualization extension. Called automatically when GLMakie is
loaded. Flips the package's default plotting backend to `:glmakie` so the public
`plot_*` names dispatch to the interactive GLMakie methods added above.
"""
function __init__()
    Viz._GLMAKIE_LOADED[] = true
end

end  # HeartRateLabVisualizationExt
