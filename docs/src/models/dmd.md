```@meta
CurrentModule = HeartRateLab
```

# [Dynamic Mode Decomposition (DMD)](@id dmd-page)

DMD is a purely data-driven spectral method (Schmid, 2010). It decomposes an IBI
time series into dynamic modes and temporal eigenvalues, then uses them to reconstruct
or forecast the signal. No mechanistic model of the heart is assumed.

## Theory

### Hankel Embedding

A scalar IBI series $\mathbf{x} = [x_1, x_2, \ldots, x_n]$ is lifted into a data
matrix via delay embedding (Hankel matrix), where $m = \lfloor n/2 \rfloor$:

```math
X = \begin{bmatrix}
  x_1    & x_2    & \cdots & x_{n-m}   \\
  x_2    & x_3    & \cdots & x_{n-m+1} \\
  \vdots &        &        & \vdots     \\
  x_m    & x_{m+1}& \cdots & x_n
\end{bmatrix}
```

### DMD Decomposition

The data matrix is split into shifted snapshots $X_1 = X[:, 1\!:\!end\!-\!1]$ and
$X_2 = X[:, 2\!:\!end]$. DMD finds the best-fit linear operator $A$ such that
$X_2 \approx A X_1$ using a rank-$r$ SVD of $X_1$:

```math
X_1 \approx U_r \Sigma_r V_r^T
```

The reduced operator $\tilde{A} = U_r^T X_2 V_r \Sigma_r^{-1}$ is then diagonalized to
obtain eigenvalues $\lambda_i$ and eigenvectors $W$. The **dynamic modes** are:

```math
\Phi = X_2 V_r \Sigma_r^{-1} W
```

### Reconstruction

With mode amplitudes $\mathbf{b}$ fitted by least squares, the signal is reconstructed as:

```math
x(t) \approx \sum_{i=1}^{r} b_i \, \phi_i \, \lambda_i^{t-1}
```

The rank $r$ controls how many modes contribute:

| Rank | Captures | Risk |
|------|----------|------|
| 2 – 3 | Dominant trends only | May underfit |
| 5 (default) | Main oscillatory patterns | Balanced |
| 10+ | Fine-grained detail | May overfit short recordings |

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `rank` | 5 | SVD truncation rank. Must be ≤ ⌊n/2⌋ (half the series length). |

DMD has no `parameter_space` — it is entirely data-driven. The decomposition
adapts to the input; `rank` is the only tunable setting.

## Workflow

DMD **must be fitted before simulating**. `fit` decomposes the training data;
`simulate` reconstructs using the learned modes.

```
dmd = DMD(rank=5)   →   result = fit(dmd, ibis)   →   simulate(result.model, nothing, n)
```

Note that `simulate` is called on `result.model` (the fitted DMD with modes filled in),
not on the original `dmd` object.

## Examples

### Fit and Reconstruct

```julia
using HeartRateLab

ibis = read_txt("data.txt")

dmd = DMD(rank=5)
result = fit(dmd, ibis)

println("Rank used:             ", result.diagnostics["rank"])
println("Embedding dimension:   ", result.diagnostics["embedding_dimension"])
println("Reconstruction error:  ", round(result.diagnostics["reconstruction_error"]; digits=2))

# Reconstruct the training signal
reconstructed = simulate(result.model, nothing, length(ibis))
```

### Effect of Rank on Reconstruction Quality

```julia
using HeartRateLab

ibis = read_txt("data.txt")

for r in [2, 5, 10, 20]
    result = fit(DMD(rank=r), ibis)
    recon  = simulate(result.model, nothing, length(ibis))
    rmse   = sqrt(sum((ibis .- recon).^2) / length(ibis))
    println("rank=", r, "  RMSE=", round(rmse; digits=1), " ms")
end
```

## API Reference

```@docs
DMD
fit(::DMD, ::Vector{Float64})
simulate(::DMD, ::Union{NamedTuple, Nothing}, ::Int)
```
