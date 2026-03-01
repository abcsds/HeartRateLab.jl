```@meta
CurrentModule = HeartRateLab
```

# [Leaky Integrate-and-Fire (LIF)](@id lif-page)

The LIF model treats the heart's sinoatrial node as a biological pacemaker neuron.
Each heartbeat corresponds to a membrane voltage threshold crossing, producing an
inter-beat interval (IBI) directly in physiological time (milliseconds).

## Theory

The sinoatrial node drives cardiac rhythm by spontaneously depolarizing and then
resetting after each beat. The leaky integrate-and-fire model captures this with a
single first-order ODE:

```math
\tau \frac{dV}{dt} = -(V - V_{rest}) + R \cdot I
```

The membrane potential $V$ rises toward the fixed point $V^* = V_{rest} + R \cdot I$.
When $V$ crosses $V_{threshold}$ (upward), a **spike** (heartbeat) is recorded and
$V$ is immediately reset to $V_{reset}$.

### Analytical Period Formula

For constant current $I$ with $V^* > V_{threshold}$ (a necessary condition for
repetitive firing), the inter-spike period has a closed form:

```math
T = \tau \cdot \ln\!\left(\frac{R \cdot I}{R \cdot I - \Delta V}\right),
\quad \Delta V = V_{threshold} - V_{rest}
```

Inverting for the current that produces a target period $T$:

```math
I(T) = \frac{\Delta V}{R \cdot \left(1 - e^{-T/\tau}\right)}
```

This inverse formula is the basis of the `:analytical` fitting method, which applies
it to each measured IBI individually.

## Parameters

### Fixed Physiological Parameters

These are set at construction and are **not fitted**. They reflect biologically
plausible values for the human sinoatrial node.

| Parameter | Default | Unit | Description |
|-----------|---------|------|-------------|
| `τ` | 200.0 | ms | Membrane time constant |
| `V_rest` | −65.0 | mV | Resting potential |
| `V_reset` | −65.0 | mV | Post-spike reset potential (equals `V_rest`) |
| `V_threshold` | −60.0 | mV | Spike threshold |
| `R` | 10.0 | MΩ | Membrane resistance |

### Fitted Parameter

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| `I` | 1.48 – 1.56 μA | 1.52 | Input current; encodes autonomic drive and heart rate |

The bounds on `I` correspond to physiological heart rate limits:
- `I ≈ 1.48` → very slow rate (~20 bpm)
- `I ≈ 1.52` → resting rate (~75 bpm)
- `I ≈ 1.56` → fast rate (~200 bpm)

## Fitting Methods

| Method | Speed | Output | Notes |
|--------|-------|--------|-------|
| `:analytical` | Instant | Per-beat $I$ series | No simulation needed; exact inversion |
| `:gradient` | Fast | Scalar $I$ | Brent univariate optimization; minimizes RMSE |
| `:bayesian` | Slow | Posterior over $I$ | NUTS MCMC (Turing.jl); provides uncertainty |

## Examples

### Create and Simulate

```julia
using HeartRateLab

# Create model with physiological defaults
lif = LIF()

# Simulate 500 inter-beat intervals
params = (I = 1.52,)
ibis = simulate(lif, params, 500)

using Statistics
println("Mean IBI: ", round(mean(ibis); digits=1), " ms")
println("Heart rate: ", round(60000 / mean(ibis)), " bpm")
```

### Fit with Analytical Method

The analytical method is the fastest option. It returns a per-beat current series
capturing how autonomic drive varies across the recording.

```julia
using HeartRateLab

lif = LIF()
ibis = read_txt("data.txt")

result = fit(lif, ibis; method=:analytical)

println("Mean I:  ", round(result.params.I; digits=4))
println("Std(I):  ", round(result.diagnostics["I_std"]; digits=4))

# Per-beat current series — same length as ibis
I_series = parameter_series(result, :I)
println("I range: ", round.(extrema(I_series); digits=4))

# Simulate from the mean fitted I
synthetic = simulate(result.model, result.params, length(ibis))
```

### Fit with Gradient Method

```julia
using HeartRateLab

lif = LIF()
ibis = read_txt("data.txt")

result = fit(lif, ibis; method=:gradient)

println("Fitted I:    ", round(result.params.I; digits=4))
println("Converged:   ", result.diagnostics["converged"])
println("Final RMSE:  ", round(result.diagnostics["loss_final"]; digits=2), " ms")

# Generate synthetic IBIs
synthetic = simulate(result.model, result.params, length(ibis))
```

## API Reference

```@docs
LIF
parameter_space(::LIF)
simulate(::LIF, ::NamedTuple, ::Int)
fit(::LIF, ::Vector{Float64})
```
