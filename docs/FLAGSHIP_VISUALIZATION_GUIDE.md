# Flagship Visualization Guide

## Overview

The `plot_flagship()` function creates a comprehensive 4-panel scientific figure showcasing the complete HeartRateLab pipeline. This document describes what you see and how to interpret it.

## Function Signature

```julia
fig = plot_flagship(real_data::Vector{Float64}, fit_result::ModelFitResult;
                    title="HeartRateLab Pipeline Demo")
```

## Visual Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 HeartRateLab Pipeline: Van der Pol Bayesian Fitting         │
├──────────────────────────────────────┬──────────────────────────────────────┤
│                                      │                                      │
│       PHASE PORTRAIT                 │     SIGNAL WITH BEAT DETECTION       │
│       (Poincaré Plot)                │                                      │
│                                      │    ╱‾‾╲        ╱‾‾╲     ╱‾‾╲        │
│                                      │   ╱    ╲      ╱    ╲   ╱    ╲      │
│       Real (blue ●)        2000 ─── ├──────────────────────────────────   │
│       Synthetic (◆)               │  │    ◆        ◆      ◆ Beats      │
│       ±1σ (▒ band)                 │  │  800ms   795ms   810ms             │
│                                      │    │ ──────────── │       │       │
│                ●●      ▒▒   ●      │  600 ─┴──────────┴─┴───────┴─────  │
│          ●●  ▒▒   ▒▒▒  ●●          │      │                              │
│        ●  ▒▒▒  ◆◆   ▒▒▒●  ●●       │  Time: Beat #1 → #2 → #3 → #4     │
│       ●▒▒▒  ●  ▒▒  ◆  ▒▒▒  ●      │                                      │
│      ●▒▒    ◆   ▒▒▒▒▒▒  ▒▒▒●●●    │                                      │
│      ●▒    ◆◆    ▒▒▒▒▒  ▒▒▒▒  ●   │                                      │
│      ●●▒▒▒●●  ●●▒▒▒▒▒▒▒▒▒▒▒▒▒●   │                                      │
│       ●▒▒▒  ●●  ▒▒▒▒▒▒▒▒▒▒  ▒▒●  │                                      │
│        ●▒▒▒▒  ◆ ▒▒▒▒▒▒▒▒▒▒▒▒ ●   │                                      │
│         ●▒▒▒  ◆◆ ▒▒▒▒▒▒▒▒▒▒  ●    │                                      │
│          ●●▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒●●    │                                      │
│          ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒   │                                      │
│                                      │                                      │
│    300 ─────────────────────────    │  400 ─────────────────────────     │
│        300      800      1300         │       0      50      100      150    │
│        IBI[n] (ms)                    │       Beat Index                   │
├──────────────────────────────────────┴──────────────────────────────────────┤
│                       POSTERIOR PARAMETER DISTRIBUTION                      │
│                                                                             │
│   μ (Non-linearity)                                                        │
│   │                                                                        │
│   │        ╭────╮                                                         │
│   │        │    │                                                         │
│ D │   ╭────┤    ├────╮                                                    │
│ e │   │    │    │    │                    Mean: 1.527 ± 0.084           │
│ n │   │    │    │    │                                                   │
│ s │ ──┴────┴────┴────┴──────────  (normalized μ)                         │
│ i │  0.5  1.0  1.5  2.0  2.5                                            │
│ t │     ▲                                                                │
│ y │  +1σ │ -1σ                                                           │
│   │                                                                        │
└───────────────────────────────────────────────────────────────────────────┘
```

## Panel Descriptions

### Panel 1: Phase Portrait (Left)

**What it shows:** How the model's oscillations compare to real data in phase space.

- **Blue dots (●)**: Real data Poincaré plot (IBI[n] vs IBI[n+1])
- **Orange diamonds (◆)**: Synthetic data from fitted model
- **Gray shaded region (▒)**: Bayesian posterior uncertainty (±1σ)

**How to interpret:**
- **Good fit**: Synthetic points overlap with real points → model captures dynamics
- **Poor fit**: Points separate → model missing key features
- **Uncertainty band**: Wider band = less confident in parameters, narrower = more confident
- **Attractor shape**: Shows whether oscillations are regular (ellipse) or chaotic (cloud)

### Panel 2: Signal Generation (Right Top)

**What it shows:** Time series of IBIs with beat detection markers and physiological annotations.

- **Blue dashed line (- - -)**: Real data for reference
- **Orange solid line (—)**: Synthetic IBIs from model
- **Red diamonds (◇)**: Detected beat peaks
- **Text annotations**: IBI duration in milliseconds

**How to interpret:**
- **Amplitude match**: Real and synthetic should have similar height (similar variability)
- **Peak coincidence**: Beats should occur at realistic intervals
- **IBI annotations**: Should be in physiological range (300-2000 ms)
  - Normal resting: 800-1000 ms
  - Exercise: 400-600 ms
  - Sleep: 1000-1200 ms

### Panel 3: Posterior Distribution (Right Bottom)

**What it shows:** Parameter estimates from Bayesian MCMC sampling.

- **Histogram bars**: Frequency of each parameter value from posterior samples
- **Red vertical line**: Mean of posterior distribution
- **Dashed red lines**: ±1 standard deviation boundaries

**How to interpret:**
- **Tall narrow peak**: Confident parameter estimate, tight posterior
- **Broad flat histogram**: Uncertain estimate, wide posterior
- **Mean position**: Best point estimate of parameter
- **Range**: Credible interval (68% of samples within ±1σ)

## Example Interpretation

### Good Model Fit Shows:

1. **Phase Portrait**: Synthetic points (◆) scattered among real points (●)
   - → Model captures the attractor structure

2. **Signal**: Orange and blue lines track together reasonably well
   - → Model generates realistic IBIs

3. **Posterior**: Sharp peaks with reasonable width
   - → Parameters confidently estimated, but with honest uncertainty

### Poor Model Fit Shows:

1. **Phase Portrait**: Synthetic points far from real points
   - → Model dynamics don't match reality

2. **Signal**: Orange line consistently too high or too low
   - → Model systematic bias

3. **Posterior**: Very wide distributions
   - → Parameters poorly constrained by data

## Usage Example

```julia
using HeartRateLab
using GLMakie  # Enables visualization

# Load real data
real_data = read_txt("subject_001.txt")

# Fit Van der Pol model with Bayesian inference
vdp = VanDerPol()
fit_result = fit(vdp, real_data;
    method=:bayesian,
    chains=4,      # MCMC chains
    samples=1000   # Samples per chain
)

# Create flagship visualization
fig = plot_flagship(real_data, fit_result;
    title="Subject 001: Van der Pol Bayesian Fit"
)

display(fig)

# Access posterior for analysis
μ_posterior = fit_result.posterior["μ"]
μ_mean = mean(μ_posterior)
μ_std = std(μ_posterior)
println("μ = $μ_mean ± $μ_std")
```

## What Each Panel Tells You

| Panel | Shows | Key Questions | Green Flags | Red Flags |
|-------|-------|---------------|------------|-----------|
| **Phase Portrait** | Model attractor vs real data | Does model capture dynamics? | Overlapping clusters | Separated groups |
| **Signal** | Time series + beats | Do generated IBIs look realistic? | Realistic durations, clear beats | Outliers, missed beats |
| **Posterior** | Parameter certainty | How confident are we? | Sharp peaks | Flat distributions |

## Advanced Interpretation

### Understanding Posterior Width

**Narrow posterior** (small ±1σ)
- Pro: Parameters are well-constrained
- Con: May indicate overfitting or insufficient uncertainty
- Interpretation: This data strongly supports these parameter values

**Wide posterior** (large ±1σ)
- Pro: Honest uncertainty representation
- Con: May indicate underfitting or parameter non-identifiability
- Interpretation: Multiple parameter sets could explain this data

### Reading Posterior Multimodality

**Single peak posterior**
→ Unique best-fit parameters

**Multiple peaks**
→ Model has multiple plausible parameter sets
→ Data doesn't strongly distinguish between them
→ May need more data or different model

### Phase Portrait Ellipticity

**Circular cluster** → Nearly periodic, low variability
**Stretched ellipse** → Periodic with variation (normal HRV)
**Scattered cloud** → Chaotic dynamics

## Common Patterns and Interpretations

### Pattern: Good Van der Pol Fit
```
✓ Phase portrait: Ellipse shape matches
✓ Signal: Smooth oscillations, realistic IBI range
✓ Posterior: Sharp peak for μ ≈ 1.5, tight heart_rate
→ Model is appropriate for this data
```

### Pattern: Poor Van der Pol Fit
```
✗ Phase portrait: Synthetic points don't cluster with real
✗ Signal: Generated IBIs too high or too low
✗ Posterior: Very wide μ posterior
→ Van der Pol may not be ideal; try Lorenz or LIF
```

### Pattern: Over-narrow Posterior
```
⚠ Posterior: Extremely sharp peaks
⚠ Phase portrait: Still some scatter
→ Posterior may be over-confident
→ Check convergence diagnostics (R-hat)
```

## Tips for Presentation

The flagship visualization is publication-quality for:

- **Journal papers**: Model validation section
- **Presentations**: Slide showing complete pipeline
- **Dissertations**: Methods chapter demonstration
- **Talks**: "Here's what we can do" showcase

The figure demonstrates:
✓ Scientific rigor (Bayesian inference)
✓ Mechanistic understanding (ODE modeling)
✓ Uncertainty quantification (posterior distributions)
✓ Physiological realism (beat detection, IBI ranges)
✓ Complete workflow (data → model → validation)

## Technical Notes

### MCMC Diagnostics in Posterior

The fit_result contains:
```julia
fit_result.diagnostics["rhat_mu"]  # Should be < 1.05
fit_result.diagnostics["rhat_heart_rate"]  # Should be < 1.05
```

R-hat < 1.05 indicates MCMC convergence.

### Posterior Samples

Access full posterior for custom analysis:
```julia
μ_samples = fit_result.posterior["μ"]
hr_samples = fit_result.posterior["heart_rate"]

# 95% credible interval
μ_95ci = quantile(μ_samples, [0.025, 0.975])

# Probability μ > 1.5
prob_mu_high = mean(μ_samples .> 1.5)
```

### Parameter Bounds

All parameters enforce physiological bounds:
- μ: [0.5, 3.0] (non-linearity range)
- heart_rate: [40, 150] BPM (physiological range)

## See Also

- `flagship_demo.qmd`: Complete end-to-end example
- `plot_poincare()`: Phase portrait visualization alone
- `eval_distributional()`: Statistical validation of fit
- `simulate_ensemble()`: Generating synthetic data
