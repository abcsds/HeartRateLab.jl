# Getting Started with HeartRateLab.jl

This guide will get you from installation to extracting your first HRV features in 5 minutes.

## Installation

### Step 1: Install Julia
Download Julia from [julialang.org](https://julialang.org/downloads/) (version 1.11 or later).

### Step 2: Add HeartRateLab
Open the Julia REPL and type:

```julia
julia> using Pkg
julia> Pkg.add(url="https://github.com/abcsds/HeartRateLab.jl")
```

!!! note
    HeartRateLab is not yet registered in the Julia General registry (registration is planned), so it is installed directly from the GitHub URL.

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

Or use the sample recording that ships with the package: [`test/testdata/example.txt`](https://github.com/abcsds/HeartRateLab.jl/blob/main/test/testdata/example.txt) (an anonymized slow-breathing session).

### Extract HRV Features

```julia
using HeartRateLab
using DataFrames

# Step 1: Load your IBI data
ibis = read_txt("data.txt")
println("Loaded $(length(ibis)) beats")

# Step 2: Extract all 53 HRV features (returns a one-row DataFrame)
features = extract_feature_set(ibis; features=:all)
println("Extracted $(ncol(features)) features")

# Step 3: Display results
for name in names(features)
    println("$name: $(round(features[1, name]; digits=2))")
end
```

**Output:**
```
Loaded 500 beats
Extracted 53 features
mean: 800.25
sdnn: 45.32
rmssd: 38.14
pnn50: 0.23
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

# Extract features for each (extract_feature_set returns a one-row DataFrame)
all_features = DataFrame[]

for file in files
    try
        ibis = read_txt(file)
        features = extract_feature_set(ibis)
        features.subject .= split(file, ".")[1]  # Add subject ID column
        push!(all_features, features)
        println("✓ Processed $file")
    catch e
        println("✗ Error processing $file: $e")
    end
end

# Stack into one DataFrame (one row per subject) for analysis
df = reduce(vcat, all_features)

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
result = fit(lif, ibis; method=:gradient)

# Check convergence
println("Converged: $(result.diagnostics["converged"])")
println("Final loss: $(result.diagnostics["loss_final"])")

# Generate synthetic data
synthetic = simulate(result.model, result.params, length(ibis))

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

**WFDB format** - If you have WFDB tools installed, pass the record name and the annotator extension:
```julia
ibis = read_wfdb("16265", "atr")   # record "16265" with the "atr" annotation file
```

### Output Formats

```julia
# Write to CSV
using CSV, DataFrames
df = DataFrame(ibi=ibis)
CSV.write("output.csv", df)
```

## Troubleshooting

### Issue: "Module not found"
**Solution:** Make sure HeartRateLab is installed (from the GitHub URL — the package is not yet in the General registry):
```julia
using Pkg
Pkg.add(url="https://github.com/abcsds/HeartRateLab.jl")
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

- **[Feature Documentation](features.md)** - Learn about all 53 HRV features
- **[Modeling Guide](models/index.md)** - Fit mechanistic models to your data
- **[Visualization Guide](visualization.md)** - Create publication-quality plots
- **[GitHub Repository](https://github.com/abcsds/HeartRateLab.jl)** - Source code and examples

## Getting Help

**Questions or issues?**
- Check the [API documentation](index.md)
- Search [GitHub Issues](https://github.com/abcsds/HeartRateLab.jl/issues)
- Create a new issue with details about your problem

**Contributing?**
- Open or comment on a [GitHub issue](https://github.com/abcsds/HeartRateLab.jl/issues) to discuss your idea
- Fork the repository and submit a pull request
