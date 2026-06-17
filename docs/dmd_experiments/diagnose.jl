# Diagnostics: SVD spectrum, eigenvalue magnitudes, and how reconstruction
# variance depends on rank/embedding. Establishes WHY low-rank DMD captures the
# mean but little variance on RR tachograms, and probes high-rank regimes.

using LinearAlgebra, Statistics, HeartRateLab
include("dmd_variants.jl"); using .DMDVariants

data = HeartRateLab.read_txt("test/testdata/example.txt")
n = length(data); μ = mean(data); σ = std(data)
xc = data .- μ

io = open("docs/dmd_experiments/diagnose.txt", "w")
println(io, "n=$n mean=$(round(μ,digits=2)) std=$(round(σ,digits=2))")

# AR(1)-style autocorrelation: how predictable is the next beat?
function autocorr(x, k)
    x0 = x[1:end-k]; x1 = x[1+k:end]
    m0 = mean(x0); m1 = mean(x1)
    sum((x0 .- m0) .* (x1 .- m1)) / sqrt(sum((x0 .- m0).^2) * sum((x1 .- m1).^2))
end
println(io, "lag-1 autocorr=$(round(autocorr(data,1),digits=3)) lag-2=$(round(autocorr(data,2),digits=3)) lag-5=$(round(autocorr(data,5),digits=3)) lag-10=$(round(autocorr(data,10),digits=3))")

# SVD spectrum of the centered Hankel matrix for a few embedding dims
for d in (20, 50, 100, 200)
    H = DMDVariants.hankel(xc, d)
    X1 = H[:, 1:end-1]
    s = svd(X1).S
    e = cumsum(s.^2) ./ sum(s.^2)
    r90 = findfirst(>=(0.90), e); r99 = findfirst(>=(0.99), e)
    println(io, "d=$d  rank@90%E=$r90  rank@99%E=$r99  top5 σ=", round.(s[1:5]./s[1], digits=3))
end

# Eigenvalue magnitudes for exact DMD at several ranks (centered)
println(io, "\nExact centered DMD eigenvalue |λ| distribution (d=50):")
H = DMDVariants.hankel(xc, 50); X1 = H[:,1:end-1]; X2 = H[:,2:end]
U,S,V = svd(X1)
for r in (5, 10, 20, 40)
    Ur=U[:,1:r]; Sr=Diagonal(S[1:r]); Vr=V[:,1:r]
    Atil = Ur'*X2*Vr/Sr
    λ = eigen(Atil).values
    println(io, "  r=$r  |λ| range=[$(round(minimum(abs.(λ)),digits=3)), $(round(maximum(abs.(λ)),digits=3))]  #|λ|>1.0=$(count(>(1.0), abs.(λ)))  #|λ|>0.99=$(count(>(0.99), abs.(λ)))")
end

# Key test: variance captured by FULL Hankel reconstruction (one-step prediction)
# vs free-running simulation. One-step prediction = A applied to true states.
println(io, "\nOne-step-ahead prediction NRMSE (uses TRUE history, like a forecast) vs free-run:")
for r in (5, 10, 20, 40, 60)
    rr = min(r, length(S))
    Ur=U[:,1:rr]; Sr=Diagonal(S[1:rr]); Vr=V[:,1:rr]
    Atil = Ur'*X2*Vr/Sr
    # one-step: project columns of X1 to reduced coords, advance, lift, read first row
    Xproj = Ur' * X1                 # rr × (ncol-1) reduced states
    Xnext_red = Atil * Xproj         # predicted next reduced state
    Xnext = Ur * Xnext_red           # lift back to d-dim
    pred_first = real.(Xnext[1, :])  # predicted first Hankel coord (= xc at shifted index)
    true_first = X2[1, :]
    nr = sqrt(mean((true_first .- pred_first).^2)) / σ
    println(io, "  r=$rr  one-step NRMSE(first coord)=$(round(nr,digits=4))")
end

close(io)
println("DONE")
