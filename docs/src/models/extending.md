```@meta
CurrentModule = HeartRateLab
```

# Extending: Adding Your Own Model

HeartRateLab's model system is designed for easy extension. Any struct that inherits
from `AbstractHRVModel` and implements `simulate` integrates automatically with
`simulate_ensemble`, `extract_ensemble_features`, and the evaluation pipeline.

## Minimal Implementation

### Step 1: Define a struct

```julia
using HeartRateLab

struct GaussianIBI <: AbstractHRVModel
    mean_ibi::Float64   # Mean IBI in milliseconds
    std_ibi::Float64    # Standard deviation in milliseconds
end

GaussianIBI(; mean_ibi=800.0, std_ibi=50.0) = GaussianIBI(mean_ibi, std_ibi)
```

### Step 2: Implement `simulate`

The only required method. Must return a `Vector{Float64}` of IBIs in milliseconds,
with length equal to `n_beats`.

```julia
using Random

function HeartRateLab.simulate(model::GaussianIBI, params::NamedTuple, n_beats::Int)
    μ = get(params, :mean_ibi, model.mean_ibi)
    σ = get(params, :std_ibi, model.std_ibi)
    ibis = randn(n_beats) .* σ .+ μ
    # Clip to physiological range (300–2000 ms)
    return clamp.(ibis, 300.0, 2000.0)
end
```

### Step 3: Use it

Once `simulate` is defined, the model integrates with the full ecosystem:

```julia
model = GaussianIBI(mean_ibi=820.0, std_ibi=45.0)
params = (mean_ibi=820.0, std_ibi=45.0)

# Simulate 500 IBIs
ibis = simulate(model, params, 500)

# Use with ensemble evaluation
ensemble = simulate_ensemble(model, params, 500; n_sim=100)
features = extract_ensemble_features(ensemble)
```

## Adding Fitting Support

### Optional: `parameter_space`

Required if you want Bayesian fitting to work. Returns bounds and priors for each
parameter:

```julia
using Distributions

function HeartRateLab.parameter_space(model::GaussianIBI)
    return (
        mean_ibi = (
            lower = 300.0,
            upper = 2000.0,
            prior = truncated(Normal(800.0, 100.0), 300.0, 2000.0)
        ),
        std_ibi = (
            lower = 1.0,
            upper = 200.0,
            prior = Exponential(50.0)
        )
    )
end
```

### Optional: `fit`

Implement gradient-based fitting using Optim.jl:

```julia
using Optim, Statistics

function HeartRateLab.fit(model::GaussianIBI, data::Vector{Float64};
                          method::Symbol=:gradient, kwargs...)
    function loss(x)
        params = (mean_ibi=x[1], std_ibi=x[2])
        synthetic = simulate(model, params, length(data))
        # Minimize distance in mean and std
        return (mean(synthetic) - mean(data))^2 + (std(synthetic) - std(data))^2
    end

    x0    = [model.mean_ibi, model.std_ibi]
    lower = [300.0, 1.0]
    upper = [2000.0, 200.0]

    result = optimize(loss, lower, upper, x0, Fminbox(LBFGS()))

    params_map = (mean_ibi=result.minimizer[1], std_ibi=result.minimizer[2])
    diagnostics = Dict(
        "converged"   => Optim.converged(result),
        "loss_final"  => result.minimum
    )

    return ModelFitResult(model, :gradient, params_map, nothing, diagnostics, data)
end
```

## Interface Checklist

| Item | Required? | Notes |
|------|:---------:|-------|
| `struct MyModel <: AbstractHRVModel` | ✓ | Any fields you need |
| `MyModel(; ...)` keyword constructor | Recommended | Makes API ergonomic |
| `simulate(::MyModel, params, n_beats) -> Vector{Float64}` | ✓ | IBIs in ms; length == n_beats |
| `parameter_space(::MyModel) -> NamedTuple` | For `:bayesian` fit | Bounds + Distributions.jl priors |
| `fit(::MyModel, data; method, ...)` | Optional | Return `ModelFitResult` |

## Notes

- **Dispatch namespace:** Define methods as `HeartRateLab.simulate(...)` and
  `HeartRateLab.fit(...)` when working outside the package to avoid method ambiguity.
- **Units:** IBIs must be in **milliseconds**. All features, evaluation functions,
  and model comparisons assume milliseconds.
- **Physiological bounds:** Clip IBIs to 300–2000 ms in `simulate` to prevent
  downstream evaluation failures caused by out-of-range values.
- **Determinism:** Use `Random.seed!` or a seeded RNG if reproducible simulations
  are needed.
