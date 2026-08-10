```@meta
CurrentModule = HeartRateLab
```

# [Dynamic Mode Decomposition (DMD)](@id dmd-page)

DMD is a purely data-driven spectral method [schmid2010](@cite). It decomposes an
IBI time series into dynamic modes and temporal eigenvalues, then uses them to
reconstruct or forecast the signal. No mechanistic model of the heart is assumed.

The implementation is the **mean-centered, unit-circle-projected, time-delay
(Hankel) DMD** with a global least-squares amplitude solve ("V2 /
UnitCircleDMD").

## Theory

The fitting pipeline has five steps:

### 1. Mean centering

The temporal mean $\mu$ of the series is subtracted *before* the embedding
(affine / constant-mode handling) and added back — never rescaled — at
reconstruction.

### 2. Hankel Embedding

The centered scalar IBI series $\mathbf{x} = [x_1, x_2, \ldots, x_n]$ is lifted
into a data matrix via delay embedding with a **fixed delay dimension** $d$
(default 50, clamped to $\lfloor n/2 \rfloor$ for short series):

```math
X = \begin{bmatrix}
  x_1    & x_2    & \cdots & x_{n-d+1} \\
  x_2    & x_3    & \cdots & x_{n-d+2} \\
  \vdots &        &        & \vdots     \\
  x_d    & x_{d+1}& \cdots & x_n
\end{bmatrix}
```

### 3. DMD Decomposition with energy-based rank selection

The data matrix is split into shifted snapshots $X_1 = X[:, 1\!:\!end\!-\!1]$ and
$X_2 = X[:, 2\!:\!end]$. Exact DMD finds the best-fit linear operator $A$ such
that $X_2 \approx A X_1$ via an SVD of $X_1$:

```math
X_1 \approx U_r \Sigma_r V_r^T
```

The retained rank $r$ is **not fixed by hand**: it is the smallest rank whose
squared singular values capture the `energy` fraction (default 0.99) of the total,
**capped at** `rank` (the rank cap $r_{\max}$, default 20). The reduced operator
$\tilde{A} = U_r^T X_2 V_r \Sigma_r^{-1}$ is diagonalized to obtain eigenvalues
$\lambda_i$ and eigenvectors $W$. The **dynamic modes** are:

```math
\Phi = X_2 V_r \Sigma_r^{-1} W
```

### 4. Unit-circle eigenvalue projection

Each retained eigenvalue is projected onto the unit circle
($\lambda \to \lambda / |\lambda|$), preserving its frequency while making the
free run marginally stable — oscillations are sustained rather than decaying or
exploding.

### 5. Global least-squares amplitudes and reconstruction

The mode amplitudes $\mathbf{b}$ are fitted by least squares against the *full*
first-row Hankel trajectory (not a single initial snapshot), so the
reconstruction variance tracks the data. The signal is then reconstructed as:

```math
x(t) \approx \mu + \operatorname{Re}\!\left(\sum_{i=1}^{r} b_i \, \lambda_i^{t-1}\right)
```

The physiological 300–2000 ms clip is applied only as an **output guard** in
`simulate` — the mean is always the data mean $\mu$.

## Honest limit

RR tachograms are broadband / aperiodic. A low-rank linear model recovers the
mean and the dominant LF oscillation, but **cannot reproduce the full broadband
variance** without over-shooting — the corresponding variance check in the test
suite is an explicit `@test_broken`. DMD is deliberately kept as the *weaker
baseline* generative model in HeartRateLab; its real strength for RR is
short-horizon prediction via [`forecast`](@ref).

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `rank` | 20 | Rank cap $r_{\max}$. The retained rank $r$ is chosen by the energy threshold, then clamped to at most `rank`. |
| `d` | 50 | Delay / embedding dimension of the Hankel matrix (clamped to $\lfloor n/2 \rfloor$). Use ≈100 for faster-mean records. |
| `energy` | 0.99 | SVD energy fraction used to pick the retained rank $r$. |

DMD has no `parameter_space` — it is entirely data-driven and has no priors to
sample. `rank`, `d`, and `energy` are structural knobs of the decomposition, not
fitted physiological parameters.

## Workflow

DMD **must be fitted before simulating**. `fit` decomposes the training data;
`simulate` reconstructs using the learned modes.

```
dmd = DMD()   →   result = fit(dmd, ibis)   →   simulate(result.model, nothing, n)
```

Note that `simulate` is called on `result.model` (the fitted DMD with the mean,
modes, eigenvalues, and amplitudes filled in), not on the original `dmd` object.

## Examples

### Fit and Reconstruct

```julia
using HeartRateLab

ibis = read_txt("data.txt")

dmd = DMD()   # rank cap 20, d = 50, energy = 0.99
result = fit(dmd, ibis)

println("Retained rank r:       ", result.diagnostics["rank"])
println("Embedding dimension:   ", result.diagnostics["embedding_dimension"])
println("Fitted mean (ms):      ", round(result.diagnostics["mean"]; digits=1))

# Reconstruct the training signal
reconstructed = simulate(result.model, nothing, length(ibis))
```

### Effect of the Rank Cap on Reconstruction Quality

```julia
using HeartRateLab

ibis = read_txt("data.txt")

for rmax in [2, 5, 10, 20]
    result = fit(DMD(rank=rmax), ibis)
    recon  = simulate(result.model, nothing, length(ibis))
    rmse   = sqrt(sum((ibis .- recon).^2) / length(ibis))
    println("rank cap=", rmax, "  retained r=", result.diagnostics["rank"],
            "  RMSE=", round(rmse; digits=1), " ms")
end
```

### Short-Horizon Forecasting

```julia
using HeartRateLab

hist = read_txt("data.txt")[1:2000]
ŷ = forecast(DMD(d=50), hist, 5)   # next 5 beats (richer rank by default)
```

## API Reference

```@docs
DMD
fit(::DMD, ::Vector{Float64})
simulate(::DMD, ::Union{NamedTuple, Nothing}, ::Int)
forecast(::DMD, ::AbstractVector, ::Int)
```
