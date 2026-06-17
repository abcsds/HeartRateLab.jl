# DMD variants for RR-interval (IBI) modeling — experimental scratch module.
#
# Implements the shipped (weak) DMD plus three better-founded variants, all
# behind the AbstractHRVModel interface so the Evaluation information-criteria
# utilities can score them. See docs/dmd-rr-modeling-research.md.
#
# All variants are deterministic given the data; RNG seeds only matter for the
# ensemble noise layer in Evaluation (we set seeds in the runner).

module DMDVariants

using LinearAlgebra
using Statistics
using HeartRateLab
const M = HeartRateLab.Models

import HeartRateLab.Models: simulate, fit, AbstractHRVModel, ModelFitResult

# ─────────────────────────────────────────────────────────────────────────────
# Shared helpers
# ─────────────────────────────────────────────────────────────────────────────

"""Build a Hankel (delay-embedding) matrix with `d` rows (delays) from `data`.
Column j is data[j : j+d-1]; result is d × (n-d+1)."""
function hankel(data::AbstractVector{<:Real}, d::Int)
    n = length(data)
    d >= n && error("delay dimension d=$d too large for n=$n")
    ncol = n - d + 1
    H = Matrix{Float64}(undef, d, ncol)
    @inbounds for j in 1:ncol
        H[:, j] = data[j:j+d-1]
    end
    return H
end

"""Energy-threshold rank: smallest r capturing `energy` fraction of squared
singular values, capped at `rmax`."""
function energy_rank(Σ::AbstractVector, energy::Float64, rmax::Int)
    e = cumsum(Σ .^ 2) ./ sum(Σ .^ 2)
    r = findfirst(>=(energy), e)
    r = r === nothing ? length(Σ) : r
    return clamp(r, 1, min(rmax, length(Σ)))
end

# ─────────────────────────────────────────────────────────────────────────────
# Variant 1: Centered exact Hankel-DMD (mean subtraction + add-back)
#
# Fix for the documented mean-drop: subtract the data mean BEFORE embedding,
# run exact DMD on the centered Hankel matrix, reconstruct the centered signal,
# then ADD THE MEAN BACK. This is the "affine DMD" / constant-mode handling from
# Hirsh et al. 2019 (Centering Data Improves DMD) and Brunton/Kutz. Rank chosen
# by energy threshold. Reconstruction uses the first row of the Hankel state.
# ─────────────────────────────────────────────────────────────────────────────

mutable struct CenteredDMD <: AbstractHRVModel
    d::Int                 # delay / embedding dimension
    energy::Float64        # SVD energy fraction for rank
    rmax::Int              # rank cap
    # fitted state:
    μ::Float64
    Φ::Matrix{ComplexF64}  # DMD modes (d × r)
    λ::Vector{ComplexF64}  # eigenvalues
    b::Vector{ComplexF64}  # amplitudes (initial-condition projection)
    r::Int
end

CenteredDMD(; d::Int=50, energy::Float64=0.99, rmax::Int=20) =
    CenteredDMD(d, energy, rmax, 0.0, zeros(ComplexF64, 0, 0), ComplexF64[], ComplexF64[], 0)

function fit(model::CenteredDMD, data::Vector{Float64}; kwargs...)
    μ = mean(data)
    xc = data .- μ
    d = min(model.d, length(data) ÷ 2)
    H = hankel(xc, d)
    X1 = H[:, 1:end-1]
    X2 = H[:, 2:end]
    U, Σ, V = svd(X1)
    r = energy_rank(Σ, model.energy, model.rmax)
    Ur = U[:, 1:r]; Σr = Diagonal(Σ[1:r]); Vr = V[:, 1:r]
    Atil = Ur' * X2 * Vr / Σr
    F = eigen(Atil)
    λ = F.values
    W = F.vectors
    Φ = X2 * Vr / Σr * W                      # exact-DMD modes
    b = Φ \ ComplexF64.(X1[:, 1])             # project initial Hankel column
    fitted = CenteredDMD(d, model.energy, model.rmax, μ, Φ, λ, b, r)
    diagnostics = Dict(
        "variant" => "CenteredDMD",
        "rank" => r, "embedding_dimension" => d, "mean" => μ,
        "max_abs_eval" => maximum(abs.(λ)),
    )
    return ModelFitResult(fitted, :gradient, NamedTuple(), nothing, diagnostics, data)
end

function simulate(model::CenteredDMD, ::Union{NamedTuple,Nothing}, n_beats::Int)::Vector{Float64}
    isempty(model.Φ) && error("CenteredDMD must be fitted first")
    # Reconstruct centered signal via first Hankel row: x_c(t) = Re(Σ φ_{1,j} λ_j^t b_j).
    # We advance the full Hankel state and read its first coordinate each step.
    φ1 = model.Φ[1, :]                        # first row of modes (length r)
    out = Vector{Float64}(undef, n_beats)
    @inbounds for t in 1:n_beats
        acc = 0.0 + 0.0im
        for j in 1:model.r
            acc += φ1[j] * (model.λ[j]^(t - 1)) * model.b[j]
        end
        out[t] = real(acc) + model.μ
    end
    return out
end

# ─────────────────────────────────────────────────────────────────────────────
# Variant 2: Unit-circle-projected centered Hankel-DMD
#
# Diagnosis (docs/dmd_experiments/diagnose.txt) showed every retained eigenvalue has |λ|<1
# (0.92–0.999), so V1's free-running reconstruction DECAYS to the mean over
# thousands of beats — variance collapses (sim std 13 vs data 90). The fix for a
# *generative* (free-running) model is to project the retained modes ONTO the
# unit circle: λ -> λ/|λ|. This preserves each mode's frequency while making the
# reconstruction marginally stable (sustained oscillation), which is the
# mean-subtraction≈DFT regime (Chen/Tu/Rowley 2012; Hirsh et al. 2019). It keeps
# the oscillation amplitude alive instead of decaying. Energy rank as V1.
# ─────────────────────────────────────────────────────────────────────────────

mutable struct StabilizedDMD <: AbstractHRVModel
    d::Int
    energy::Float64
    rmax::Int
    μ::Float64
    Φ::Matrix{ComplexF64}
    λ::Vector{ComplexF64}
    b::Vector{ComplexF64}
    r::Int
end

StabilizedDMD(; d::Int=50, energy::Float64=0.99, rmax::Int=20) =
    StabilizedDMD(d, energy, rmax, 0.0, zeros(ComplexF64, 0, 0), ComplexF64[], ComplexF64[], 0)

function fit(model::StabilizedDMD, data::Vector{Float64}; kwargs...)
    μ = mean(data)
    xc = data .- μ
    d = min(model.d, length(data) ÷ 2)
    H = hankel(xc, d)
    X1 = H[:, 1:end-1]; X2 = H[:, 2:end]
    U, Σ, V = svd(X1)
    r = energy_rank(Σ, model.energy, model.rmax)
    Ur = U[:, 1:r]; Σr = Diagonal(Σ[1:r]); Vr = V[:, 1:r]
    Atil = Ur' * X2 * Vr / Σr
    F = eigen(Atil); λ = F.values; W = F.vectors
    Φ = X2 * Vr / Σr * W
    # Project ALL retained modes onto the unit circle: preserve frequency
    # arg(λ), force |λ|=1 so the free-run neither grows nor decays.
    λs = [l == 0 ? complex(1.0) : l / abs(l) for l in λ]
    # Amplitudes b: least-squares fit of the FIRST Hankel coordinate against the
    # unit-circle modal time basis over ALL snapshots (the optDMD-style global
    # amplitude step), so the reconstruction's variance matches the data instead
    # of being pinned by a single initial column. Solve min_b || x_c - Ψ b ||
    # where Ψ[t,j] = φ1_j λs_j^{t-1}.
    nT = size(H, 2)
    φ1 = Φ[1, :]
    Ψ = Matrix{ComplexF64}(undef, nT, r)
    @inbounds for t in 1:nT, j in 1:r
        Ψ[t, j] = φ1[j] * (λs[j]^(t - 1))
    end
    b = Ψ \ ComplexF64.(H[1, :])
    fitted = StabilizedDMD(d, model.energy, model.rmax, μ, Φ, λs, b, r)
    diagnostics = Dict(
        "variant" => "StabilizedDMD",
        "rank" => r, "embedding_dimension" => d, "mean" => μ,
        "max_abs_eval_raw" => maximum(abs.(λ)),
        "max_abs_eval_stab" => maximum(abs.(λs)),
    )
    return ModelFitResult(fitted, :gradient, NamedTuple(), nothing, diagnostics, data)
end

function simulate(model::StabilizedDMD, ::Union{NamedTuple,Nothing}, n_beats::Int)::Vector{Float64}
    isempty(model.Φ) && error("StabilizedDMD must be fitted first")
    # b was fit against the basis Ψ[t,j] = φ1_j λ_j^{t-1}, so b already folds in
    # the first-row mode weight φ1; reconstruct x_c(t) = Re(Σ b_j λ_j^{t-1}).
    out = Vector{Float64}(undef, n_beats)
    @inbounds for t in 1:n_beats
        acc = 0.0 + 0.0im
        for j in 1:model.r
            acc += model.b[j] * (model.λ[j]^(t - 1))
        end
        out[t] = real(acc) + model.μ
    end
    return out
end

# ─────────────────────────────────────────────────────────────────────────────
# Variant 3: HAVOK-style forced linear model (Hankel Alternative View of Koopman)
#
# Brunton et al. 2017 / ultradian-rhythm HRV (arXiv:2505.08953). Build Hankel
# matrix on centered data, take SVD -> time-delay eigen-coordinates V (n × q).
# Model the first r-1 coordinates as a linear system v̇ = A v + B v_r forced by
# the last retained coordinate v_r (the intermittent forcing). For *generative*
# simulation we (a) fit A,B by least squares on discrete differences, and (b)
# replay the empirical forcing signal v_r (resampled / tiled to length), then
# reconstruct x_c from the linear combination of spatial modes U Σ, read first row.
# Adds the mean back. This captures genuine forced oscillatory dynamics.
# ─────────────────────────────────────────────────────────────────────────────

mutable struct HAVOKModel <: AbstractHRVModel
    d::Int            # number of delays q
    r::Int            # number of retained delay coordinates (incl. forcing)
    μ::Float64
    UΣ1::Vector{Float64}   # first row of U*Σ for the r-1 modeled coords (length r-1)
    A::Matrix{Float64}     # (r-1)×(r-1) discrete dynamics
    Bb::Vector{Float64}    # (r-1) forcing input vector
    v0::Vector{Float64}    # initial state (r-1)
    forcing::Vector{Float64}  # empirical forcing time series v_r
end

HAVOKModel(; d::Int=100, r::Int=11) =
    HAVOKModel(d, r, 0.0, Float64[], zeros(0, 0), Float64[], Float64[], Float64[])

function fit(model::HAVOKModel, data::Vector{Float64}; kwargs...)
    μ = mean(data)
    xc = data .- μ
    d = min(model.d, length(data) ÷ 2)
    H = hankel(xc, d)               # d × ncol
    U, Σ, V = svd(H)                 # V: ncol × ncol; columns are delay coords
    r = min(model.r, length(Σ))
    r < 2 && error("HAVOK needs r>=2")
    Vr = V[:, 1:r]                   # ncol × r delay-coordinate time series
    # Linear forced model on first r-1 coords, forced by coord r.
    # Discrete one-step: v[k+1, 1:r-1] = A v[k,1:r-1] + Bb * v[k, r]
    Vm = Vr[1:end-1, 1:r-1]          # states at k     (N-1 × r-1)
    Vp = Vr[2:end, 1:r-1]            # states at k+1
    f  = Vr[1:end-1, r]              # forcing at k     (N-1)
    Θ  = hcat(Vm, f)                 # (N-1) × r        regressors
    # Solve [A Bb] = Vp' * Θ * (Θ'Θ)^{-1}  via least squares (Vp = Θ * [A;Bb]')
    coef = Θ \ Vp                    # r × (r-1):  rows 1:r-1 = A', row r = Bb'
    A = permutedims(coef[1:r-1, :])  # (r-1)×(r-1)
    Bb = vec(coef[r, :])             # (r-1)
    UΣ = U * Diagonal(Σ)             # d × ncol; reconstruct H ≈ UΣ * V'
    UΣ1 = UΣ[1, 1:r]                 # first Hankel row weights for r coords (incl forcing)
    v0 = Vr[1, 1:r-1]
    forcing = Vr[:, r]
    fitted = HAVOKModel(d, r, μ, UΣ1[1:r-1], A, Bb, v0, forcing)
    # store forcing-mode weight for reconstruction (first row, forcing coord)
    fitted = HAVOKModel(d, r, μ, vcat(UΣ1[1:r-1]), A, Bb, v0, forcing)
    diagnostics = Dict(
        "variant" => "HAVOK", "rank" => r, "embedding_dimension" => d, "mean" => μ,
        "forcing_kurtosis" => _kurt(forcing),
        "UΣ1_forcing_weight" => UΣ[1, r],
    )
    # smuggle the forcing-coordinate first-row weight via a closure-free field:
    # we recompute it in simulate from stored arrays, so store it on the struct
    # by appending to UΣ1.
    fitted.UΣ1 = vcat(UΣ1[1:r-1], UΣ[1, r])  # length r: first r-1 = modeled, last = forcing weight
    return ModelFitResult(fitted, :gradient, NamedTuple(), nothing, diagnostics, data)
end

_kurt(x) = (m = mean(x); s = std(x); s == 0 ? NaN : mean(((x .- m) ./ s) .^ 4))

function simulate(model::HAVOKModel, ::Union{NamedTuple,Nothing}, n_beats::Int)::Vector{Float64}
    isempty(model.A) && error("HAVOK must be fitted first")
    r = model.r
    w_modeled = model.UΣ1[1:r-1]      # first-row weights for modeled coords
    w_forcing = model.UΣ1[r]          # first-row weight for forcing coord
    f = model.forcing
    nf = length(f)
    v = copy(model.v0)
    out = Vector{Float64}(undef, n_beats)
    @inbounds for t in 1:n_beats
        fk = f[((t - 1) % nf) + 1]    # replay empirical forcing (tiled)
        out[t] = dot(w_modeled, v) + w_forcing * fk + model.μ
        v = model.A * v + model.Bb * fk
    end
    return out
end

end # module
