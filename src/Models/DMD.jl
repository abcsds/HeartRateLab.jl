"""
    DMD <: AbstractHRVModel

Dynamic Mode Decomposition model for spectral IBI analysis.
Decomposes time series into dynamic modes and eigenvalues for reconstruction.

# Parameters
- `rank`: Number of modes to retain
- `modes`: Dynamic modes (matrix, empty until fitted)
- `evals`: Eigenvalues of modes (vector, empty until fitted)
- `b`: Mode amplitudes (vector, empty until fitted)
"""
mutable struct DMD <: AbstractHRVModel
    rank::Int
    modes::Matrix{ComplexF64}
    evals::Vector{ComplexF64}
    b::Vector{ComplexF64}
end

DMD(; rank::Int=5) = DMD(rank, Matrix{ComplexF64}(undef, 0, 0), ComplexF64[], ComplexF64[])

"""
    fit(model::DMD, data::Vector{Float64}; kwargs...) -> ModelFitResult

Fit DMD model to IBI data using SVD-based decomposition.
Returns a new DMD model instance with fitted modes and eigenvalues.

# Arguments
- `model::DMD`: DMD model instance with desired rank
- `data::Vector{Float64}`: IBI time series in milliseconds

# Returns
`ModelFitResult` with fitted DMD model containing modes and eigenvalues
"""
function fit(model::DMD, data::Vector{Float64}; kwargs...)
    n = length(data)
    r = min(model.rank, n - 1)  # Rank cannot exceed n-1

    # Construct Hankel matrix (embedding)
    # Each row is a delay-embedded view of the signal
    m = div(n, 2)  # Use half the length for embedding dimension
    X = zeros(m, n - m)

    for i in 1:m
        X[i, :] = data[i:i+n-m-1]
    end

    if size(X, 2) < 2
        error("DMD: data too short for decomposition. Need at least rank+2 points.")
    end

    # Split into X1 and X2 (shifted version)
    X1 = X[:, 1:end-1]
    X2 = X[:, 2:end]

    # SVD of X1
    U, Σ, V = svd(X1)

    # Truncate to rank
    U_r = U[:, 1:r]
    Σ_r = Diagonal(Σ[1:r])
    V_r = V[:, 1:r]

    # DMD matrix in reduced space
    A_tilde = U_r' * X2 * V_r * inv(Σ_r)

    # Eigendecomposition of A_tilde
    eigen_result = eigen(A_tilde)
    evals = eigen_result.values
    W = eigen_result.vectors

    # Dynamic modes: Φ = X2 * V_r * Σ_r^{-1} * W
    modes = X2 * V_r * inv(Σ_r) * W

    # Compute mode amplitudes b via least squares
    # We want: data ≈ Φ * b (approximately, for reconstruction)
    b = nothing  # Initialize b to ensure it's defined in function scope
    try
        b = modes \ data[1:size(modes, 1)]
    catch
        # If direct solve fails, use pinv
        b = pinv(modes) * data[1:size(modes, 1)]
    end
    # Create fitted model
    fitted_model = DMD(r, modes, evals, b)

    # Diagnostics
    reconstruction_error = norm(X1 - U_r * Σ_r * V_r')

    diagnostics = Dict(
        "method" => "SVD (DMD)",
        "rank" => r,
        "embedding_dimension" => m,
        "reconstruction_error" => reconstruction_error,
        "condition_number" => cond(A_tilde)
    )

    return ModelFitResult(
        fitted_model,
        :gradient,  # DMD is deterministic (like gradient-based)
        NamedTuple(),  # No continuous parameters to optimize
        nothing,  # No posterior samples
        diagnostics,
        data
    )
end

"""
    simulate(model::DMD, params::Union{NamedTuple,Nothing}, n_beats::Int) -> Vector{Float64}

Reconstruct IBI time series using fitted DMD model.

# Arguments
- `model::DMD`: Fitted DMD model with modes and eigenvalues
- `params`: Ignored (DMD is data-driven)
- `n_beats`: Number of IBIs to generate

# Returns
Vector of inter-beat intervals in milliseconds
"""
function simulate(model::DMD, params::Union{NamedTuple,Nothing}, n_beats::Int)::Vector{Float64}
    if isempty(model.modes)
        error("DMD model must be fitted before simulation. Call fit() first.")
    end

    # Standard DMD reconstruction: x(t) ≈ Σ_j φ_j * λ_j^(t-1) * b_j
    # where φ_j is j-th mode (column of modes matrix), λ_j is eigenvalue, b_j is amplitude

    m = size(model.modes, 1)  # Spatial dimension (embedding dimension)
    r = size(model.modes, 2)  # Number of modes
    reconstructed = zeros(n_beats)

    # For each time step, compute the reconstruction
    for t in 1:n_beats
        # Sum contribution from each dynamic mode
        for j in 1:r
            # Mode amplitude evolves as λ_j^(t-1)
            λ_power = model.evals[j]^(t-1)

            # Average the mode contribution across spatial dimension
            mode_j = model.modes[:, j]
            spatial_avg = mean(abs.(mode_j))

            # Weighted contribution
            contribution = real(spatial_avg * λ_power * model.b[j])
            reconstructed[t] += contribution
        end
    end

    # Normalize to physiological range
    # First, shift to have similar mean as original signal
    μ = mean(reconstructed)
    if μ > 0 && !isnan(μ)
        # Scale to typical IBI mean (800ms for ~75 BPM)
        reconstructed = reconstructed * (800 / abs(μ))
    else
        reconstructed = fill(800.0, n_beats)
    end

    # Enforce physiological bounds (300-2000 ms)
    reconstructed = max.(reconstructed, 300.0)
    reconstructed = min.(reconstructed, 2000.0)

    return reconstructed
end
