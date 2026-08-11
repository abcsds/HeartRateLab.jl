```@meta
CurrentModule = HeartRateLab
```

# [Lorenz Chaotic Attractor](@id lorenz-page)

The Lorenz system is a 3-dimensional ODE exhibiting **deterministic chaos**: bounded,
aperiodic trajectories with sensitive dependence on initial conditions (Lorenz, 1963).
HeartRateLab uses threshold crossings of the z-coordinate to extract inter-beat intervals.

## Theory

The Lorenz equations model atmospheric convection:

```math
\frac{dX}{dt} = \sigma(Y - X)
```

```math
\frac{dY}{dt} = X(\rho - Z) - Y
```

```math
\frac{dZ}{dt} = XY - \beta Z
```

The trajectory traces the **butterfly attractor**: two lobes in 3D phase space with
chaotic switching between them.

### IBI Extraction

Heartbeat events are identified by **upward threshold crossings** of the z-coordinate.
Each time $Z$ rises through `threshold`, a beat is recorded. The IBI is the time between
consecutive crossings, converted to milliseconds:

```math
\text{IBI}_i = (t_{i+1} - t_i) \times 1000 \quad \text{[ms]}
```

### Chaos Regime

The Lorenz system transitions from stable fixed points to chaos as $\rho$ increases:

| $\rho$ | Behavior |
|--------|----------|
| < 1 | Stable fixed point at origin |
| 1 – 24.7 | Two stable fixed points (no oscillation) |
| ≈ 28 (default) | Classical chaotic regime |
| > 40 | High-dimensional chaos |

### Why Bayesian Fitting Only

The Lorenz system is non-differentiable with respect to its parameters in practice:
small parameter changes cause qualitative trajectory reorganization (bifurcations).
Gradient-based methods are therefore ineffective. NUTS MCMC explores the parameter
space stochastically, making it the only supported fitting method.

## Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `σ` | 5 – 15 | 10.0 | Prandtl number (flow structure) |
| `ρ` | 20 – 35 | 28.0 | Rayleigh number (chaos control) |
| `β` | 1 – 4 | 8/3 ≈ 2.667 | Aspect ratio (dissipation) |
| `threshold` | 5 – 15 | 10.0 | Z-value for IBI detection |

`parameter_space(::Lorenz)` also defines a `σ_noise` likelihood parameter used
internally by the Bayesian sampler. It is not an ODE parameter and is not
returned in `result.params`, but its convergence is reported in
`result.diagnostics["rhat_sigma_noise"]`.

## Examples

### Create and Simulate

```julia
using HeartRateLab

# Standard chaotic parameters (defaults)
lorenz = Lorenz()

# Custom threshold
lorenz_custom = Lorenz(σ=10.0, ρ=28.0, β=8/3, threshold=12.0)

params = (σ=10.0, ρ=28.0, β=8/3, threshold=10.0)
ibis = simulate(lorenz, params, 200)

using Statistics
println("Mean IBI: ", round(mean(ibis); digits=1), " ms")
println("SDNN:     ", round(std(ibis); digits=1), " ms")
```

### Visualize the Lorenz Trajectory

The full 3D trajectory (not just IBIs) can be retrieved for visualization using the
`simulate_lorenz_trajectory` helper. This function lives in the `Models` submodule and
is not exported at the top level.

```julia
using HeartRateLab

params = (σ=10.0, ρ=28.0, β=8/3)
sol = HeartRateLab.Models.simulate_lorenz_trajectory(params; duration=50.0)

# sol is a DifferentialEquations solution object
x = sol[1, :]   # x-coordinates
y = sol[2, :]   # y-coordinates
z = sol[3, :]   # z-coordinates

# Plot with Plots.jl or GLMakie (requires separate installation)
# using Plots
# plot(x, y, z, label="", xlabel="X", ylabel="Y", zlabel="Z")
```

### Bayesian Fit

```julia
using HeartRateLab

lorenz = Lorenz()
ibis = read_txt("data.txt")

# Bayesian fitting is the only supported method
result = fit(lorenz, ibis; method=:bayesian, chains=4, samples=500)

println("Fitted σ:         ", round(result.params.σ; digits=2))
println("Fitted ρ:         ", round(result.params.ρ; digits=2))
println("Fitted β:         ", round(result.params.β; digits=3))
println("Fitted threshold: ", round(result.params.threshold; digits=2))

# Check convergence (R-hat < 1.1 indicates good mixing)
println("R-hat σ:         ", round(result.diagnostics["rhat_sigma"]; digits=3))
println("R-hat ρ:         ", round(result.diagnostics["rhat_rho"]; digits=3))
```

## API Reference

```@docs
Lorenz
parameter_space(::Lorenz)
simulate(::Lorenz, ::NamedTuple, ::Int)
fit(::Lorenz, ::Vector{Float64})
```
