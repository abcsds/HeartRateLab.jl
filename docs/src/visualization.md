# Heart Rate Variability Visualization

HeartRateLab provides **9 interactive visualization functions** using GLMakie for analysis and model comparison.

## Analysis Plots

### plot_ibi_series

Time series visualization of inter-beat-intervals with statistical overlays.

```julia
using HeartRateLab, GLMakie

ibis = read_txt("data.txt")
fig = plot_ibi_series(ibis; title="IBI Time Series")
display(fig)
```

**Features:**
- Line plot of IBI values
- Mean line (red dashed)
- ±1 standard deviation envelope (gray band)
- Clear axis labels and legend

**Use cases:**
- Quick visual inspection of IBI trends
- Identify periods of high/low variability
- Detect anomalies or artifacts

### plot_poincare

Poincaré scatter plot showing beat-to-beat correlation and variability structure.

```julia
fig = plot_poincare(ibis; title="Poincaré Plot")
display(fig)
```

**Features:**
- Scatter plot: IBI[n] vs IBI[n+1]
- Mean point marked with ⊕
- Identity line (reference)
- Symmetric aspect ratio for clarity

**Interpretation:**
- Tight cluster → Low HRV (regular beats)
- Wide distribution → High HRV (variable beats)
- Horizontal/vertical spread → Different variability types

### plot_spectrum

Frequency domain power spectral density with HRV frequency bands.

```julia
fig = plot_spectrum(ibis; fs=1.0, title="HRV Power Spectrum")
display(fig)
```

**Features:**
- Welch periodogram with log scales
- VLF band (0.0-0.04 Hz) - Red shading
- LF band (0.04-0.15 Hz) - Green shading
- HF band (0.15-0.4 Hz) - Blue shading

**Interpretation:**
- **VLF Power** - Very low frequency (thermoregulation, long-term variability)
- **LF Power** - Low frequency (sympathetic + parasympathetic)
- **HF Power** - High frequency (parasympathetic/respiratory)
- **LF/HF Ratio** - Sympathovagal balance indicator

## Comparison Plots

### plot_comparison

Multi-panel comparison of real vs synthetic IBI data across multiple perspectives.

```julia
using HeartRateLab, DifferentialEquations, GLMakie

ibis_real = read_txt("data.txt")
lif = LIF()
result = fit(lif, ibis_real; method=:gradient)
ibis_synthetic = simulate(result.model, result.params, length(ibis_real))

fig = plot_comparison(ibis_real, ibis_synthetic; model_name="LIF")
display(fig)
```

**Layout (2×2):**

- **Top-left:** IBI time series overlay
  - Real data (blue line)
  - Synthetic data (red dashed line)
  - First 200 beats for clarity

- **Top-right:** Poincaré plot overlay
  - Real beat pairs (blue scatter)
  - Synthetic beat pairs (red scatter)
  - Identity line (reference)

- **Bottom-left:** IBI distribution histograms
  - Real data histogram (blue)
  - Synthetic data histogram (red)
  - Overlaid for comparison

- **Bottom-right:** Q-Q plot
  - Real data normalized quantiles
  - Theoretical quantiles
  - Diagonal reference line

### plot_model_heatmap

Heatmap showing model reproduction quality across multiple features.

```julia
using HeartRateLab, DifferentialEquations

# Fit multiple models
lif_result = fit(LIF(), ibis; method=:gradient)
vdp_result = fit(VanDerPol(), ibis; method=:gradient)
lorenz_result = fit(Lorenz(), ibis; method=:gradient)

# Compute errors per feature (example)
errors = Dict(
    "LIF" => [5.2, 3.1, 7.8, ...],      # Error for each feature
    "Van der Pol" => [6.1, 2.9, 6.5, ...],
    "Lorenz" => [4.8, 4.2, 8.1, ...]
)

features = ["Mean", "Std", "RMSSD", "pNN50", ...]

fig = plot_model_heatmap(errors, features)
display(fig)
```

**Interpretation:**
- Green = Excellent reproduction (quality near 1.0)
- Yellow = Good reproduction (quality 0.5-0.8)
- Red = Poor reproduction (quality < 0.5)
- Diagonal: Model-feature pairs to prioritize

## Advanced Plots

### plot_lorenz_3d

Interactive 3D scatter plot of Lorenz coordinates from IBI data.

```julia
fig = plot_lorenz_3d(ibis; title="3D Lorenz Plot")
display(fig)
```

**Coordinates:**
- X-axis: IBI[n]
- Y-axis: IBI[n+1]
- Z-axis: IBI[n+2]
- Color: Time progression (blue → red)

**Interaction:**
- Rotate with mouse drag
- Zoom with mouse scroll
- Hover for coordinates

**Use cases:**
- Visualize three-beat patterns
- Identify nonlinear structure
- Compare healthy vs pathological patterns

### plot_radar

Radar/spider chart for multi-dimensional feature comparison.

```julia
using HeartRateLab, GLMakie

# Prepare data (normalized to [0,1])
data = Dict(
    "Subject A" => [0.7, 0.8, 0.6, 0.9, 0.5],
    "Subject B" => [0.5, 0.6, 0.8, 0.7, 0.6],
    "Subject C" => [0.9, 0.7, 0.5, 0.6, 0.8]
)

features = ["HRV", "Complexity", "Chaos", "Stability", "Entropy"]

fig = plot_radar(data; names=features)
display(fig)
```

**Features:**
- Polygon for each dataset
- Normalized [0,1] scale
- Color-coded legend
- Clear radius grid

**Use cases:**
- Compare multiple subjects/conditions
- Visualize HRV profile
- Identify strengths/weaknesses

### plot_correlations

Correlation heatmap showing relationships between HRV features.

```julia
using HeartRateLab, GLMakie, DataFrames

# Load data and extract features
ibis = read_txt("data.txt")
features_df = extract_feature_set(ibis) |> DataFrame

# Create correlation heatmap
fig = plot_correlations(features_df; title="HRV Feature Correlations")
display(fig)
```

**Features:**
- Pearson correlation matrix
- Symmetric heatmap
- Red = Negative correlation (-1)
- Blue = Positive correlation (+1)
- White = No correlation (0)
- Optional: Correlation values in cells

**Use cases:**
- Identify redundant features
- Understand feature relationships
- Guide feature selection

## Visualization Workflow

```julia
using HeartRateLab
using DifferentialEquations
using GLMakie

# Load real data
ibis_real = read_txt("subject.txt")

# 1. Analyze real data
fig1 = plot_ibi_series(ibis_real)
fig2 = plot_poincare(ibis_real)
fig3 = plot_spectrum(ibis_real)

# 2. Fit models
lif = fit(LIF(), ibis_real; method=:gradient)
vdp = fit(VanDerPol(), ibis_real; method=:gradient)
lorenz = fit(Lorenz(), ibis_real; method=:gradient)

# 3. Generate synthetic data
ibis_lif = simulate(lif.model, lif.params, length(ibis_real))
ibis_vdp = simulate(vdp.model, vdp.params, length(ibis_real))
ibis_lorenz = simulate(lorenz.model, lorenz.params, length(ibis_real))

# 4. Compare models
fig_lif = plot_comparison(ibis_real, ibis_lif; model_name="LIF")
fig_vdp = plot_comparison(ibis_real, ibis_vdp; model_name="Van der Pol")
fig_lorenz = plot_comparison(ibis_real, ibis_lorenz; model_name="Lorenz")

# 5. Advanced analysis
fig_3d = plot_lorenz_3d(ibis_real)
fig_radar = plot_radar(real_features_dict; names=feature_names)
```

## API Reference

```@autodocs
Modules = [HeartRateLab.Visualization]
Private = false
```

## GLMakie Tips

**Saving Plots:**
```julia
save("my_plot.png", fig)
```

**Customizing Figure Size:**
```julia
fig = Figure(size=(1200, 800))
```

**Controlling Display:**
```julia
# Interactive display
display(fig)

# Save without display
save("my_plot.svg", fig)
```

**Keyboard Shortcuts:**
- `q` - Quit 3D view
- `s` - Screenshot
- `h` - Help menu
