# Flagship Visualization: Testing & Viewing Guide

## Quick Start: How to See the Visualization

### Option 1: Run the Demo Notebook

**Best for:** See the complete pipeline end-to-end

```bash
# In the repository root:
quarto render docs/flagship_demo.qmd --to html
open docs/flagship_demo.html
```

This shows:
- Real data loading
- Feature extraction
- Bayesian model fitting
- Ensemble generation
- Statistical validation
- Flagship visualization
- Full interpretation

### Option 2: Run the Test Script

**Best for:** Quick validation of visualization function

```bash
cd /path/to/HeartRateLab
julia --project=. test/test_flagship_visualization.jl
```

Expected output:
```
======================================================================
           Flagship Visualization Test
======================================================================

1. Generating test data...
   ✓ Created 200 IBI samples
   Range: 543—1143 ms
   Mean: 806.4 ms, Std: 122.5 ms

2. Fitting Van der Pol model (gradient method for fast testing)...
   ✓ Model fitted successfully
   Method: gradient
   Fitted μ: 1.527
   Fitted heart_rate: 73.2 BPM

3. Testing plot_flagship() function...
   ✓ Function is defined

4. Creating flagship visualization...
   ✓ Visualization created successfully
   Type: GLMakie.Figure

5. Testing with model-generated data...
   ✓ Visualization works with synthetic data

6. Verifying visualization structure...
   The plot_flagship() function creates a 4-panel figure...

======================================================================
                    Test Complete
======================================================================
```

### Option 3: Interactive REPL Session

**Best for:** Explore and experiment

```julia
using HeartRateLab
using GLMakie  # Enables visualization extension
using Random

Random.seed!(42)

# Create test data
true_ibi = 800 .+ 100 .* sin.(range(0, 4π, length=200))
real_data = true_ibi .+ randn(200) .* 25
real_data = max.(real_data, 300)

# Fit model
vdp = VanDerPol()
fit_result = fit(vdp, real_data; method=:gradient)

# Create and display visualization
fig = plot_flagship(real_data, fit_result)
display(fig)

# Explore the structure
println("Fit method: $(fit_result.method)")
println("Parameters: $(fit_result.params)")
println("Diagnostics: $(fit_result.diagnostics)")
```

## Understanding the Output

### Expected Visualization Components

The `plot_flagship()` function returns a GLMakie figure with 4 panels:

```
┌─────────────────────────┬──────────────────────────┐
│                         │                          │
│  Phase Portrait         │  Signal + Beat Detection │
│  (Poincaré Plot)        │  (Time Series)           │
│                         │                          │
│  Blue: Real data        │  Orange: Synthetic IBIs  │
│  Orange: Synthetic      │  Red ◇: Beat markers     │
│  Gray ▒: ±1σ posterior  │  Text: IBI annotations   │
│                         │                          │
├─────────────────────────┼──────────────────────────┤
│              Posterior Parameter Distribution       │
│            (Histogram + Mean ± 1σ overlay)         │
└─────────────────────────┴──────────────────────────┘
```

### What Each Panel Tells You

| Panel | What It Shows | Good Fit Looks Like | Poor Fit Looks Like |
|-------|---------------|-------------------|-------------------|
| **Phase Portrait** | Poincaré plot (IBI[n] vs IBI[n+1]) | Synthetic points overlap with real | Separate clusters |
| **Signal** | Time series with beats | Orange line follows blue roughly | Orange consistently off |
| **Posterior** | Parameter uncertainty | Sharp peak, narrow width | Wide flat distribution |

## Troubleshooting

### "Function not found" Error

**Problem**: `plot_flagship` not recognized

**Solution**: Import both the main module and visualization extension
```julia
using HeartRateLab  # Main module
using GLMakie       # Triggers visualization extension
```

### "Figure creation failed" Error

**Common causes**:
1. **Missing GLMakie**: `] add GLMakie`
2. **No display available**: Expected in headless/SSH environments
3. **Model fitting failed**: Check `fit_result` is valid

**Debug**:
```julia
@show fit_result.model
@show fit_result.params
@show fit_result.diagnostics
```

### Visualization Doesn't Display

**In Jupyter/Pluto**: Use explicit display
```julia
using GLMakie
fig = plot_flagship(real_data, fit_result)
display(fig)
```

**In SSH/headless**: Save to file
```julia
save("flagship.png", fig)
# Then download the file
```

### Empty Posterior Distribution Panel

**Possible cause**: Gradient fitting returns `nothing` for posterior

**Solution**: Use Bayesian fitting to get posterior samples
```julia
fit_result = fit(vdp, real_data;
    method=:bayesian,
    chains=4,
    samples=1000
)
```

## Testing Different Models

### Van der Pol (Recommended)
```julia
vdp = VanDerPol()
fit_result = fit(vdp, real_data; method=:gradient)
fig = plot_flagship(real_data, fit_result)
```

### Lorenz (Chaotic)
```julia
lorenz = Lorenz()
fit_result = fit(lorenz, real_data; method=:bayesian)  # Requires Turing.jl
fig = plot_flagship(real_data, fit_result)
```

### LIF (Stochastic)
```julia
lif = LIF()
fit_result = fit(lif, real_data; method=:gradient)
fig = plot_flagship(real_data, fit_result)
```

## Making Publication-Quality Figures

### Save to High-Resolution Image

```julia
# Save as PNG (1200 DPI equivalent)
save("flagship_fitting.png", fig;
    px_per_unit=2)

# Save as PDF (for papers)
save("flagship_fitting.pdf", fig)
```

### Customize Title and Labels

```julia
fig = plot_flagship(real_data, fit_result;
    title="Subject 001: Van der Pol Bayesian Fit (n=200 beats)"
)
```

### Change Figure Size

Edit in `src/Visualization/HeartRateLabVisualizationExt.jl`:
```julia
fig = Figure(size=(1600, 900))  # Wider for presentations
# or
fig = Figure(size=(1200, 700))  # Narrower for papers
```

## Complete Example Workflow

```julia
using HeartRateLab
using Statistics
using Random
using GLMakie

# 1. LOAD DATA
Random.seed!(42)
true_ibi = 800 .+ 100 .* sin.(range(0, 4π, length=300))
real_data = true_ibi .+ randn(300) .* 30
real_data = max.(real_data, 300)

# 2. FIT MODEL
vdp = VanDerPol()
println("Fitting Van der Pol...")
fit_result = fit(vdp, real_data; method=:gradient)

println("Fitted parameters:")
println("  μ = $(round(fit_result.params.μ; digits=3))")
println("  heart_rate = $(round(fit_result.params.heart_rate; digits=1)) BPM")
println("  Converged: $(fit_result.diagnostics["converged"])")

# 3. GENERATE ENSEMBLE
println("\nGenerating synthetic ensemble...")
ensemble = simulate_ensemble(vdp, fit_result.params, 300; n_sim=100)
ensemble_features = extract_ensemble_features(ensemble)

# 4. VALIDATE
println("Validating against real data...")
real_features = extract_feature_set(real_data)
real_df = DataFrame([real_features])
ks_results = eval_distributional(real_df, ensemble_features; test=:ks)
matching = sum(ks_results.p_value .>= 0.05)
println("Features matching: $(matching)/$(nrow(ks_results))")

# 5. VISUALIZE
println("\nCreating flagship visualization...")
fig = plot_flagship(real_data, fit_result;
    title="Complete HRV Analysis Pipeline"
)
display(fig)

# 6. ANALYZE POSTERIOR (if using Bayesian fit)
if !isnothing(fit_result.posterior)
    μ_samples = fit_result.posterior["μ"]
    println("\nPosterior analysis:")
    println("  μ = $(round(mean(μ_samples); digits=3)) ± $(round(std(μ_samples); digits=3))")
end
```

## Next Steps

### For Users
- Read `FLAGSHIP_VISUALIZATION_GUIDE.md` for interpretation details
- Run `flagship_demo.qmd` for complete end-to-end example
- Try with your own real HRV data

### For Developers
- Modify `plot_flagship()` in `ext/HeartRateLabVisualizationExt.jl`
- Add custom overlays or annotations
- Integrate with publication workflows

### For Researchers
- Use as template for your own mechanistic modeling
- Cite HeartRateLab in methods section
- Contribute improvements back to the project

## References

- **GLMakie Documentation**: https://makie.juliaplots.org/stable/
- **Bayesian Inference**: Gelman et al. (2013). Bayesian Data Analysis
- **HRV Standards**: Task Force (1996). Heart rate variability: standards
- **Van der Pol Model**: Lopez-Chamorro et al. (2018). Cardiac pulse modeling

## Support

**Issues or questions?**
- Check `FLAGSHIP_VISUALIZATION_GUIDE.md` for interpretation help
- Review test script: `test/test_flagship_visualization.jl`
- Run demo notebook: `docs/flagship_demo.qmd`
- File issue on GitHub with your code and error message
