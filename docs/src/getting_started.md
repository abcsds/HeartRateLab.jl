# Getting Started with HeartRateLab.jl

This guide will get you from installation to extracting your first HRV features in 5 minutes.

## Installation

### Step 1: Install Julia
Download Julia from [julialang.org](https://julialang.org/downloads/) (version 1.11 or later).

### Step 2: Add HeartRateLab
Open the Julia REPL and type:

```julia
julia> using Pkg
julia> Pkg.add("HeartRateLab")
```

### Step 3: Install Optional Dependencies

For visualization and modeling (optional):

```julia
julia> Pkg.add("GLMakie")           # For interactive plots
julia> Pkg.add("DifferentialEquations")  # For mechanistic models
```

## Your First Analysis (5 minutes)

### Prepare Your Data

Create a text file `data.txt` with inter-beat-intervals (IBIs) in milliseconds, one per line:

```
800
810
795
825
...
```

Or download sample data from the [HeartRateLab repository](https://github.com/abcsds/HeartRateLab.jl/tree/main/data).

### Extract HRV Features

```julia
using HeartRateLab

# Step 1: Load your IBI data
ibis = read_txt("data.txt")
println("Loaded $(length(ibis)) beats")

# Step 2: Extract all HRV features (automatically preprocessed)
features = extract_feature_set(ibis)
println("Extracted $(length(features)) features")

# Step 3: Display results
for (name, value) in pairs(features)
    println("$name: $(round(value; digits=2))")
end
```

**Output:**
```
Loaded 500 beats
Extracted 44 features
mean_ibi: 800.25
std_ibi: 45.32
rmssd: 38.14
pnn50: 22.5
...
```

## Common Workflows

### Workflow 1: Batch Feature Extraction

Extract features from multiple subjects:

```julia
using HeartRateLab
using CSV, DataFrames

# List of data files
files = [
    "subject_001.txt",
    "subject_002.txt",
    "subject_003.txt"
]

# Extract features for each
all_features = []

for file in files
    try
        ibis = read_txt(file)
        features = extract_feature_set(ibis)
        features["subject"] = split(file, ".")[1]  # Add subject ID
        push!(all_features, features)
        println("✓ Processed $file")
    catch e
        println("✗ Error processing $file: $e")
    end
end

# Convert to DataFrame for analysis
df = DataFrame(all_features)

# Save results
CSV.write("hrv_features.csv", df)

# Quick statistics
println("\nFeature Statistics:")
println(describe(df))
```

### Workflow 2: Visualize Your Data

```julia
using HeartRateLab, GLMakie

ibis = read_txt("data.txt")

# Time series
fig1 = plot_ibi_series(ibis; title="Your IBI Data")

# Poincaré plot
fig2 = plot_poincare(ibis)

# Frequency spectrum
fig3 = plot_spectrum(ibis)

# Display
display(fig1)
display(fig2)
display(fig3)
```

### Workflow 3: Fit a Model

```julia
using HeartRateLab, DifferentialEquations

ibis = read_txt("data.txt")

# Fit LIF model to your data
println("Fitting LIF model...")
lif = LIF()
result = fit(lif, ibis; method=:gradient, max_iter=1000)

# Check convergence
println("Converged: $(result.diagnostics["converged"])")
println("Final loss: $(result.diagnostics["loss_final"])")

# Generate synthetic data
synthetic = simulate(result.model, result.params, n_beats=length(ibis))

# Compare with visualization
using GLMakie
fig = plot_comparison(ibis, synthetic; model_name="LIF")
display(fig)
```

## Data Format

### Input Formats

**Text file (.txt)** - One IBI per line, milliseconds:
```
800
810
795
...
```

**CSV file (.csv)** - With header:
```csv
ibi
800
810
795
```

**WFDB format** - If you have WFDB tools installed:
```julia
ibis = read_wfdb("record_name")
```

### Output Formats

```julia
# Write to text file
write_txt("output.txt", ibis)

# Write to CSV
using CSV, DataFrames
df = DataFrame(ibi=ibis)
CSV.write("output.csv", df)
```

## Troubleshooting

### Issue: "Module not found"
**Solution:** Make sure HeartRateLab is installed:
```julia
using Pkg
Pkg.add("HeartRateLab")
```

### Issue: Features return NaN
**Possible causes:**
- IBI series too short (minimum varies by feature, typically 50+ beats)
- IBIs contain zero or negative values (check your data)
- IBIs outside physiological range (should be ~300-2000 ms)

**Solution:**
```julia
# Check your data
println("Length: $(length(ibis))")
println("Range: $(extrema(ibis))")
println("NaN count: $(sum(isnan.(ibis)))")

# Check valid features for your data length
valid = valid_features(length(ibis))
println("Valid features: $(length(valid))")
```

### Issue: Visualization not showing
**Solution:** Make sure GLMakie is installed:
```julia
using Pkg
Pkg.add("GLMakie")
```

On headless systems, save plots instead:
```julia
fig = plot_ibi_series(ibis)
save("my_plot.png", fig)
```

## Next Steps

- **[Feature Documentation](features.md)** - Learn about all 54 HRV features
- **[Modeling Guide](models.md)** - Fit mechanistic models to your data
- **[Visualization Guide](visualization.md)** - Create publication-quality plots
- **[GitHub Repository](https://github.com/abcsds/HeartRateLab.jl)** - Source code and examples

## Getting Help

**Questions or issues?**
- Check the [API documentation](index.md)
- Search [GitHub Issues](https://github.com/abcsds/HeartRateLab.jl/issues)
- Create a new issue with details about your problem

**Contributing?**
- See [CONTRIBUTING.md](https://github.com/abcsds/HeartRateLab.jl/blob/main/CONTRIBUTING.md)
- Fork the repository and submit a pull request
