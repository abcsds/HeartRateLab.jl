# Tutorials and Examples

## Tutorial 1: Feature Extraction Deep Dive

Learn to extract, filter, and analyze HRV features.

### Extract Features by Domain

```julia
using HeartRateLab

ibis = read_txt("data.txt")

# Extract specific domains
time_features = extract_feature_set(ibis; domains=[:time])
freq_features = extract_feature_set(ibis; domains=[:frequency])
nonlinear_features = extract_feature_set(ibis; domains=[:nonlinear])
fractal_features = extract_feature_set(ibis; domains=[:fractal])

println("Time domain features: $(length(time_features))")
println("Frequency domain features: $(length(freq_features))")
println("Nonlinear features: $(length(nonlinear_features))")
println("Fractal features: $(length(fractal_features))")
```

### Handle Signal Length Constraints

```julia
# Not all features work with short signals
short_ibis = ibis[1:20]
long_ibis = ibis

# Check valid features
valid_short = valid_features(length(short_ibis))  # ~11 features
valid_long = valid_features(length(long_ibis))   # ~53 features

println("Features for $(length(short_ibis)) beats: $(length(valid_short))")
println("Features for $(length(long_ibis)) beats: $(length(valid_long))")

# Compute only valid features
features_short = extract_feature_set(short_ibis)
features_long = extract_feature_set(long_ibis)
```

### Windowed Analysis

```julia
# Compute features in sliding windows
window_size = 100
overlap = 50
n_windows = div(length(ibis) - window_size, window_size - overlap) + 1

all_window_features = []

for i in 1:n_windows
    start_idx = 1 + (i-1) * (window_size - overlap)
    end_idx = start_idx + window_size - 1

    if end_idx <= length(ibis)
        window_ibis = ibis[start_idx:end_idx]
        features = extract_feature_set(window_ibis)
        features["window"] = i
        features["time_start"] = start_idx / 1000  # Convert to seconds
        push!(all_window_features, features)
    end
end

println("Analyzed $n_windows windows of $window_size beats")

# Plot feature evolution
using GLMakie
windows = [f["window"] for f in all_window_features]
rmssd = [f["rmssd"] for f in all_window_features]
lines(windows, rmssd; title="RMSSD Evolution")
```

## Tutorial 2: Model Fitting and Comparison

Learn to fit mechanistic models and evaluate reproduction quality.

### Fit Multiple Models

```julia
using HeartRateLab, DifferentialEquations, GLMakie

ibis = read_txt("data.txt")

# Create models
lif = LIF()
vdp = VanDerPol()
lorenz = Lorenz()

# Fit each model (gradient-based optimization)
println("Fitting models...")
t1 = time()

lif_result = fit(lif, ibis; method=:gradient, max_iter=500)
vdp_result = fit(vdp, ibis; method=:gradient, max_iter=500)
lorenz_result = fit(lorenz, ibis; method=:gradient, max_iter=500)

elapsed = time() - t1
println("Fitting complete: $(round(elapsed, digits=2))s")

# Check convergence
for (name, result) in [("LIF", lif_result), ("Van der Pol", vdp_result), ("Lorenz", lorenz_result)]
    conv = result.diagnostics["converged"]
    loss = result.diagnostics["loss_final"]
    iters = result.diagnostics["iterations"]
    println("$name: converged=$conv, loss=$loss, iters=$iters")
end
```

### Evaluate Reproduction Quality

```julia
# Generate synthetic data from each model
lif_synth = simulate(lif_result.model, lif_result.params, length(ibis))
vdp_synth = simulate(vdp_result.model, vdp_result.params, length(ibis))
lorenz_synth = simulate(lorenz_result.model, lorenz_result.params, length(ibis))

# Extract features for comparison
real_features = extract_feature_set(ibis)
lif_features = extract_feature_set(lif_synth)
vdp_features = extract_feature_set(vdp_synth)
lorenz_features = extract_feature_set(lorenz_synth)

# Compute errors (relative L2 norm)
function feature_error(real::Dict, synth::Dict)
    errors = []
    for key in keys(real)
        if !isnan(real[key]) && !isnan(synth[key])
            rel_error = abs(real[key] - synth[key]) / (abs(real[key]) + 1e-8)
            push!(errors, rel_error)
        end
    end
    return mean(errors)
end

errors = Dict(
    "LIF" => feature_error(real_features, lif_features),
    "Van der Pol" => feature_error(real_features, vdp_features),
    "Lorenz" => feature_error(real_features, lorenz_features)
)

println("\nFeature Reproduction Errors:")
for (name, error) in errors
    quality = max(0, 1 - error)
    println("$name: $(round(quality; digits=3))")
end
```

### Visualize Comparisons

```julia
# Create comparison plots
fig_lif = plot_comparison(ibis, lif_synth; model_name="LIF")
fig_vdp = plot_comparison(ibis, vdp_synth; model_name="Van der Pol")
fig_lorenz = plot_comparison(ibis, lorenz_synth; model_name="Lorenz")

# Create heatmap
fig_heatmap = plot_model_heatmap(errors, collect(keys(real_features)))

# Display all
display(fig_lif)
display(fig_vdp)
display(fig_lorenz)
display(fig_heatmap)
```

## Tutorial 3: Data-Driven Analysis with DMD

Use Dynamic Mode Decomposition for data-driven modeling.

### Fit and Reconstruct

```julia
using HeartRateLab, LinearAlgebra, GLMakie

ibis = read_txt("data.txt")

# Fit DMD with different ranks
dmd_low = DMD(rank=3)
dmd_mid = DMD(rank=5)
dmd_high = DMD(rank=10)

result_low = fit(dmd_low, ibis)
result_mid = fit(dmd_mid, ibis)
result_high = fit(dmd_high, ibis)

# Reconstruct
recon_low = simulate(result_low, nothing, length(ibis))
recon_mid = simulate(result_mid, nothing, length(ibis))
recon_high = simulate(result_high, nothing, length(ibis))

# Compare reconstruction errors
function rmse(real::Vector, synth::Vector)
    return sqrt(mean((real .- synth).^2))
end

println("Reconstruction RMSE:")
println("Rank 3: $(round(rmse(ibis, recon_low); digits=2)) ms")
println("Rank 5: $(round(rmse(ibis, recon_mid); digits=2)) ms")
println("Rank 10: $(round(rmse(ibis, recon_high); digits=2)) ms")
```

### Visualize Modes

```julia
# Higher rank → more accurate reconstruction
fig1 = plot_comparison(ibis, recon_low; model_name="DMD (rank=3)")
fig2 = plot_comparison(ibis, recon_mid; model_name="DMD (rank=5)")
fig3 = plot_comparison(ibis, recon_high; model_name="DMD (rank=10)")

display(fig1)
display(fig2)
display(fig3)
```

## Tutorial 4: Publication-Quality Figures

Create figures suitable for research papers.

### Single Plot

```julia
using HeartRateLab, GLMakie

ibis = read_txt("data.txt")

# Create large figure with custom styling
fig = Figure(size=(1200, 400), figure_padding=50)

# Add plot to figure
ax = Axis(fig[1, 1];
    xlabel="Beat Index",
    ylabel="IBI (ms)",
    title="Heart Rate Variability",
    titlesize=20,
    xlabelsize=16,
    ylabelsize=16)

# Plot data
lines!(ax, 1:min(length(ibis), 500), ibis[1:min(length(ibis), 500)];
    linewidth=2, color=:blue, label="Real data")

axislegend(ax; position=:rt)

# Save publication-quality figure
save("figure_ibi.png", fig; px_per_unit=2)
save("figure_ibi.pdf", fig)
```

### Multi-Panel Figure

```julia
using HeartRateLab, DifferentialEquations, GLMakie

ibis = read_txt("data.txt")

# Fit model
lif = LIF()
result = fit(lif, ibis; method=:gradient)
synthetic = simulate(result.model, result.params, length(ibis))

# Create 2×2 figure
fig = Figure(size=(1600, 1200))

# Top-left: IBI time series
ax1 = Axis(fig[1, 1]; title="A. IBI Time Series", xlabel="Beat", ylabel="IBI (ms)")
lines!(ax1, 1:min(length(ibis), 500), ibis[1:min(length(ibis), 500)];
    linewidth=2, label="Real", color=:blue)
lines!(ax1, 1:min(length(ibis), 500), synthetic[1:min(length(ibis), 500)];
    linewidth=2, label="LIF", color=:red, linestyle=:dash)
axislegend(ax1)

# Top-right: Poincaré plot
ax2 = Axis(fig[1, 2]; title="B. Poincaré Plot", xlabel="IBI[n]", ylabel="IBI[n+1]",
    aspect=DataAspect())
scatter!(ax2, ibis[1:end-1], ibis[2:end]; label="Real", alpha=0.6, markersize=5)
scatter!(ax2, synthetic[1:end-1], synthetic[2:end]; label="LIF", alpha=0.6, markersize=5)
axislegend(ax2)

# Bottom-left: Distribution
ax3 = Axis(fig[2, 1]; title="C. IBI Distribution", xlabel="IBI (ms)", ylabel="Count")
hist!(ax3, ibis; bins=30, label="Real", alpha=0.5)
hist!(ax3, synthetic; bins=30, label="LIF", alpha=0.5)
axislegend(ax3)

# Bottom-right: Spectrum
ax4 = Axis(fig[2, 2]; title="D. Power Spectrum", xlabel="Frequency (Hz)", ylabel="Power (dB)",
    yscale=log10, xscale=log10)
# Add spectrum plots (simplified)

# Save figure
save("publication_figure.pdf", fig; pt_per_unit=1)
```

## Tutorial 5: Batch Processing and Statistics

Process multiple subjects and compute group statistics.

```julia
using HeartRateLab
using CSV, DataFrames, Statistics

# List of subjects
subjects = [
    ("healthy_001.txt", "healthy"),
    ("healthy_002.txt", "healthy"),
    ("patient_001.txt", "patient"),
    ("patient_002.txt", "patient"),
]

# Extract features for each
results = []

for (filename, group) in subjects
    ibis = read_txt(filename)
    features = extract_feature_set(ibis)
    features["subject"] = split(filename, ".")[1]
    features["group"] = group
    push!(results, features)
    println("✓ $(split(filename, ".")[1]) ($group)")
end

# Convert to DataFrame
df = DataFrame(results)

# Compute group statistics
println("\n=== Group Statistics ===")

healthy_df = filter(:group => ==(healthy), df)
patient_df = filter(:group => ==(patient), df)

println("\nHealthy (n=$(nrow(healthy_df))):")
println("Mean RMSSD: $(round(mean(healthy_df.rmssd); digits=2)) ms")
println("Mean HF Power: $(round(mean(healthy_df.hf_power); digits=2))")

println("\nPatient (n=$(nrow(patient_df))):")
println("Mean RMSSD: $(round(mean(patient_df.rmssd); digits=2)) ms")
println("Mean HF Power: $(round(mean(patient_df.hf_power); digits=2))")

# Statistical test (example: t-test)
using HypothesisTests
t_result = ttest(healthy_df.rmssd, patient_df.rmssd)
println("\nRMSSD t-test p-value: $(round(pvalue(t_result); digits=4))")

# Save results
CSV.write("group_analysis.csv", df)
```

## Common Patterns

### Error Handling

```julia
function safe_extract_features(filename::String)
    try
        ibis = read_txt(filename)

        # Validate data
        if length(ibis) < 20
            return nothing, "Insufficient data ($(length(ibis)) beats)"
        end

        if any(isnan.(ibis)) || any(ibis .<= 0)
            return nothing, "Invalid IBIs detected"
        end

        features = extract_feature_set(ibis)
        return features, "success"

    catch e
        return nothing, "Error: $e"
    end
end

# Use it
features, status = safe_extract_features("data.txt")
if status == "success"
    println("Extracted $(length(features)) features")
else
    println("Error: $status")
end
```

### Parallel Processing

```julia
using Distributed

# Add workers (uses all available cores)
addprocs()

@everywhere using HeartRateLab

files = ["subject_001.txt", "subject_002.txt", ...]

# Process in parallel
results = pmap(files) do file
    try
        ibis = read_txt(file)
        features = extract_feature_set(ibis)
        return (file, "success", features)
    catch e
        return (file, "error", nothing)
    end
end

# Collect results
successful = [r for r in results if r[2] == "success"]
println("Processed $(length(successful))/$(length(files)) files successfully")
```
