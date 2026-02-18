"""
    HeartRateLabDeepExt

Extension providing neural network-based HRV models using Flux.

This extension is loaded automatically when Flux is imported alongside HeartRateLab.

# Deep Learning Models (to be implemented in Phase 3+)

## Generative Models
- **Neural ODE**: Continuous-time neural network that generates IBI series
  - Architecture: RNN-like dynamics with ODE solver backend
  - Fitting: Gradient-based via Flux + DiffEqFlux
  - Use case: Flexible, data-driven HRV synthesis

- **VAE (Variational Autoencoder)**: For ectopic beat detection and anomaly detection
  - Architecture: Encoder-decoder with latent space
  - Variant: Koopman eigenfunction approach for non-linear feature extraction
  - Use case: Identify abnormal beat patterns

## Hybrid Models
- Combinations of mechanistic (ODE) and learned (neural) components

All deep models conform to the `AbstractHRVModel` interface.

# Dependencies
- `Flux.jl`: Neural network definitions and training
- `DiffEqFlux.jl`: Integration with ODE solvers for continuous models

# Example (when implemented)
```julia
using HeartRateLab
using Flux  # This loads the deep learning extension

# Create a neural ODE model
model = NeuralODE(neural_net, tspan)

# Fit to data
result = fit(model, real_data; method=:gradient, epochs=100)

# Generate synthetic data
synthetic_ibis = simulate(result.model, result.params, n_beats=500)

# Use learned features from VAE encoder for anomaly detection
anomalies = detect_ectopic_beats(ecg_data; method=:vae_learned)
```
"""
module HeartRateLabDeepExt

# Import the parent module
import HeartRateLab
using HeartRateLab.Models

# Conditional imports based on Julia version
if !isdefined(Base, :get_extension)
    error("Package extensions require Julia >= 1.9")
end

# Deep learning dependencies
using Flux
using DiffEqFlux

# TODO: Phase 3+ - Deep learning model implementations will be added here:
# - NeuralODE struct and methods
# - Neural network architecture definitions
# - VAE for ectopic detection
# - fit() implementations for deep models
# - Training loops and loss functions

"""
    __init__()

Initialize the deep learning extension. Called automatically when Flux is loaded.
"""
function __init__()
    # This function is called automatically when the extension is loaded
end

end  # HeartRateLabDeepExt
