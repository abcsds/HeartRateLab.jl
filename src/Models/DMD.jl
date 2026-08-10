"""
    DMD <: AbstractHRVModel

Dynamic Mode Decomposition model for RR-interval (IBI) dynamics.

This is the **V2 / UnitCircleDMD** formulation validated in
`docs/dmd-rr-modeling-research.md`: a **mean-centered, unit-circle-projected,
time-delay (Hankel) DMD** with a **global least-squares amplitude solve**. It
replaces the earlier intentionally-weak model that forced the mean to ~800 ms
and collapsed the variance.

The pipeline:

1. **Center.** Subtract the temporal mean `μ` of the data *before* the
   embedding (affine / constant-mode handling, Hirsh et al. 2019). The mean is
   added back at reconstruction — it is *never* rescaled.
2. **Embed.** Build a `d`-delay Hankel matrix of the centered signal so DMD has
   a state space to act on (Takens / Hankel-DMD, Brunton et al. 2017).
3. **Decompose.** Exact DMD on the Hankel snapshots; retain `r` modes by an SVD
   energy threshold (default 0.99) capped at `rmax`.
4. **Stabilize.** Project every retained eigenvalue onto the unit circle
   (`λ → λ/|λ|`), preserving each mode's frequency while making the free run
   marginally stable (sustained, neither decaying nor exploding) — the
   mean-subtraction≈DFT regime (Chen/Tu/Rowley 2012).
5. **Global amplitudes.** Fit the mode amplitudes `b` by least squares against
   the *full* first-row Hankel trajectory (the optDMD-style global amplitude
   step), so reconstruction variance matches the data instead of being pinned by
   a single initial column.

The physiological 300–2000 ms clip is applied **only as an output guard** in
`simulate` — never as a mean rescale (that was the core bug of the old model).

# Honest limit
RR tachograms are broadband / aperiodic. A low-rank linear model recovers the
mean and the dominant LF oscillation but **cannot reproduce the full broadband
variance** without over-shooting. DMD is a strong *short-horizon forecaster*
(see [`forecast`](@ref)) and a *fair* generative model for RR.

# Parameters / fields
- `rank`  : rank cap `rmax` (kept as the public knob; `DMD(rank=…)` works).
- `d`     : delay / embedding dimension (default 50; ≈100 for faster-mean
            records, e.g. NSRDB 16265 at ~620 ms).
- `energy`: SVD energy fraction used to pick the retained rank `r` (default 0.99).
- `μ`     : fitted temporal mean (0 until fitted).
- `modes` : exact-DMD modes `Φ` (`d × r`, empty until fitted).
- `evals` : retained, unit-circle-projected eigenvalues `λ` (empty until fitted).
- `b`     : global least-squares amplitudes (empty until fitted).
- `r`     : number of retained modes actually used (0 until fitted).
"""
mutable struct DMD <: AbstractHRVModel
    rank::Int                  # rank cap (rmax); public knob
    d::Int                     # delay / embedding dimension
    energy::Float64            # SVD energy fraction for rank selection
    μ::Float64                 # fitted temporal mean (added back at reconstruction)
    modes::Matrix{ComplexF64}  # exact-DMD modes Φ (d × r)
    evals::Vector{ComplexF64}  # retained, unit-circle-projected eigenvalues λ
    b::Vector{ComplexF64}      # global least-squares amplitudes
    r::Int                     # number of retained modes used
end

DMD(; rank::Int=20, d::Int=50, energy::Float64=0.99) =
    DMD(rank, d, energy, 0.0, Matrix{ComplexF64}(undef, 0, 0), ComplexF64[], ComplexF64[], 0)

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

"""
    _hankel(data, d) -> Matrix{Float64}

Build a Hankel (delay-embedding) matrix with `d` rows (delays). Column `j` is
`data[j : j+d-1]`; the result is `d × (n-d+1)`.
"""
function _hankel(data::AbstractVector{<:Real}, d::Int)
    n = length(data)
    d >= n && error("DMD: delay dimension d=$d too large for n=$n")
    ncol = n - d + 1
    H = Matrix{Float64}(undef, d, ncol)
    @inbounds for j in 1:ncol
        H[:, j] = @view data[j:(j + d - 1)]
    end
    return H
end

"""
    _energy_rank(Σ, energy, rmax) -> Int

Smallest rank capturing `energy` fraction of the squared singular values,
clamped to `[1, min(rmax, length(Σ))]`.
"""
function _energy_rank(Σ::AbstractVector, energy::Float64, rmax::Int)
    e = cumsum(Σ .^ 2) ./ sum(Σ .^ 2)
    r = findfirst(>=(energy), e)
    r = r === nothing ? length(Σ) : r
    return clamp(r, 1, min(rmax, length(Σ)))
end

"""
    _fit_dmd(data, d, energy, rmax) -> (μ, Φ, λs, b, r)

Core V2 fit: center, Hankel-embed, exact DMD, energy-rank truncation,
unit-circle projection, and a global least-squares amplitude solve against the
full first-row trajectory. Returns the fitted pieces; shared by [`fit`] and
[`forecast`].
"""
function _fit_dmd(data::AbstractVector{<:Real}, d::Int, energy::Float64, rmax::Int)
    μ = mean(data)
    xc = collect(Float64.(data)) .- μ
    d = clamp(d, 2, length(data) ÷ 2)
    H = _hankel(xc, d)
    X1 = H[:, 1:(end - 1)]
    X2 = H[:, 2:end]
    U, Σ, V = svd(X1)
    r = _energy_rank(Σ, energy, rmax)
    Ur = U[:, 1:r]
    Σr = Diagonal(Σ[1:r])
    Vr = V[:, 1:r]
    Atil = Ur' * X2 * Vr / Σr
    F = eigen(Atil)
    λ = F.values
    W = F.vectors
    Φ = X2 * Vr / Σr * W                       # exact-DMD modes (d × r)
    # Project retained eigenvalues onto the unit circle: keep frequency arg(λ),
    # force |λ|=1 so the free run is marginally stable.
    λs = ComplexF64[l == 0 ? complex(1.0) : l / abs(l) for l in λ]
    # Global least-squares amplitudes: fit the first Hankel coordinate against the
    # unit-circle modal time basis Ψ[t,j] = φ1_j · λs_j^{t-1} over ALL snapshots.
    φ1 = Φ[1, :]
    nT = size(H, 2)
    Ψ = Matrix{ComplexF64}(undef, nT, r)
    @inbounds for t in 1:nT, j in 1:r
        Ψ[t, j] = φ1[j] * (λs[j]^(t - 1))
    end
    b = Ψ \ ComplexF64.(H[1, :])
    return μ, Φ, λs, b, r
end

# ─────────────────────────────────────────────────────────────────────────────
# fit / simulate
# ─────────────────────────────────────────────────────────────────────────────

"""
    fit(model::DMD, data::Vector{Float64}; kwargs...) -> ModelFitResult

Fit the V2 Hankel-DMD operator to IBI data: center on the data mean, build the
`model.d`-delay Hankel matrix, run exact DMD, retain `r` modes by the energy
threshold (`model.energy`, capped at `model.rank`), project the eigenvalues onto
the unit circle, and solve for global least-squares amplitudes.

Returns a `ModelFitResult` whose `model` is a fitted `DMD` carrying the temporal
mean, modes, unit-circle eigenvalues and amplitudes. DMD stores no continuous
`params`, so `params` is an empty `NamedTuple` and the method is reported as
`:gradient` (deterministic, like the other data-driven fits).
"""
function fit(model::DMD, data::Vector{Float64}; kwargs...)
    length(data) < 5 && error("DMD: data too short for decomposition (need ≥ 5 points).")
    μ, Φ, λs, b, r = _fit_dmd(data, model.d, model.energy, model.rank)
    d = clamp(model.d, 2, length(data) ÷ 2)
    fitted = DMD(model.rank, d, model.energy, μ, Φ, λs, b, r)
    diagnostics = Dict(
        "method" => "UnitCircleDMD (V2)",
        "rank" => r,
        "embedding_dimension" => d,
        "mean" => μ,
        "max_abs_eval" => isempty(λs) ? NaN : maximum(abs.(λs)),
    )
    return ModelFitResult(fitted, :gradient, NamedTuple(), nothing, diagnostics, data)
end

"""
    simulate(model::DMD, params::Union{NamedTuple,Nothing}, n_beats::Int) -> Vector{Float64}

Free-running reconstruction from a fitted V2 DMD model:

    x_c(t) = Re( Σ_j b_j · λ_j^{t-1} ),    x(t) = x_c(t) + μ.

The amplitudes `b` were fit against the basis `Ψ[t,j] = φ1_j · λ_j^{t-1}`, so
they already fold in the first-row mode weight `φ1`. `params` is ignored (DMD is
data-driven). The physiological 300–2000 ms clip is applied as an **output
guard only**; the mean is the data mean `μ`, not a forced constant.
"""
function simulate(model::DMD, params::Union{NamedTuple,Nothing}, n_beats::Int)::Vector{Float64}
    isempty(model.modes) && error("DMD model must be fitted before simulation. Call fit() first.")
    out = Vector{Float64}(undef, n_beats)
    @inbounds for t in 1:n_beats
        acc = 0.0 + 0.0im
        for j in 1:model.r
            acc += model.b[j] * (model.evals[j]^(t - 1))
        end
        out[t] = real(acc) + model.μ
    end
    # Output guard only: clip to the physiological band without rescaling the mean.
    @inbounds for t in 1:n_beats
        out[t] = clamp(out[t], 300.0, 2000.0)
    end
    return out
end

# ─────────────────────────────────────────────────────────────────────────────
# forecast
# ─────────────────────────────────────────────────────────────────────────────

"""
    forecast(model::DMD, history::AbstractVector, h::Int; d=model.d, rank=max(model.rank, 40), energy=1.0) -> Vector{Float64}

`h`-step-ahead forecast of an IBI series from its `history`.

This is DMD's real strength for RR: with a richer rank, the one-step
out-of-sample NRMSE ≈ 0.19, beating both the persistence (≈0.35) and mean
(≈1.04) baselines at every horizon (see `docs/dmd-rr-modeling-research.md` §5).
A fresh DMD operator is fit on `history` (centered + Hankel-embedded). Unlike
the *generative* `simulate` path, the eigenvalues are kept at their **raw**
magnitudes — predictive accuracy, not free-running stability, is the goal.

The most recent `d`-beat delay vector seeds the rank-`r` Hankel state; the
exact-DMD propagator `A = Uᵣ Ã Uᵣ'` is applied `h` times and the newest Hankel
coordinate (`z[end] + μ`) is read off at each step, giving the closed-loop
multi-step prediction. The mean used is `history`'s mean (added back).

For forecasting the report recommends a *richer* rank than for generation
(`r ≈ 20–40`), so this defaults to `energy=1.0` (use the full `rank` cap, ≥ 40)
rather than the 0.99 energy threshold that the generative model uses.

Returns the `h` predicted beats following `history` (length `h`). Forecasting
does not mutate `model`.

# Example
```julia
hist = read_txt("example.txt")[1:2000]
ŷ = forecast(DMD(d=50), hist, 5)   # next 5 beats, richer rank by default
```
"""
function forecast(
    model::DMD,
    history::AbstractVector,
    h::Int;
    d::Int=model.d,
    rank::Int=max(model.rank, 40),
    energy::Float64=1.0,
)::Vector{Float64}
    h < 1 && return Float64[]
    x = collect(Float64.(history))
    n = length(x)
    n < 5 && error("DMD forecast: history too short (need ≥ 5 points).")
    μ = mean(x)
    xc = x .- μ
    d = clamp(d, 2, n ÷ 2)
    H = _hankel(xc, d)
    X1 = H[:, 1:(end - 1)]
    X2 = H[:, 2:end]
    U, Σ, V = svd(X1)
    r = _energy_rank(Σ, energy, rank)
    Ur = U[:, 1:r]
    Σr = Diagonal(Σ[1:r])
    Vr = V[:, 1:r]
    Atil = Ur' * X2 * Vr / Σr                  # reduced one-step operator
    # Full-state one-step propagator on the d-dimensional Hankel coordinate:
    #   z_{k+1} = A z_k,  A = Ur * Atil * Ur'  (projection of the exact operator).
    A = Ur * Atil * Ur'
    z = ComplexF64.(xc[(n - d + 1):n])         # most recent delay vector (length d)
    preds = Vector{Float64}(undef, h)
    @inbounds for k in 1:h
        z = A * z
        # newest beat is the last Hankel coordinate; clip is an output guard only.
        preds[k] = clamp(real(z[end]) + μ, 300.0, 2000.0)
    end
    return preds
end
