# Headless figure: data vs reconstructions (first 600 beats) + forecast panel.
ENV["GKSwstype"] = "100"
using Plots; gr()
using LinearAlgebra, Statistics, HeartRateLab
const M = HeartRateLab.Models
include("dmd_variants.jl"); using .DMDVariants

data = HeartRateLab.read_txt("test/testdata/example.txt")
N = 600
seg = data[1:N]

ex = M.fit(M.DMD(rank=5), data); ex_s = M.simulate(ex.model, nothing, N)
uc = M.fit(DMDVariants.StabilizedDMD(d=50, energy=0.99, rmax=10), data); uc_s = M.simulate(uc.model, nothing, N)
hv = M.fit(DMDVariants.HAVOKModel(d=100, r=11), data); hv_s = M.simulate(hv.model, nothing, N)

p1 = plot(1:N, seg, label="data (RR)", lw=2, color=:black,
    title="Generative reconstruction (first $N beats)", xlabel="beat", ylabel="RR (ms)", legend=:topright)
plot!(p1, 1:N, ex_s, label="ExistingDMD (mean→800, var collapse)", lw=1.2, color=:red, ls=:dash)
plot!(p1, 1:N, uc_s, label="UnitCircleDMD d=50 r=10", lw=1.2, color=:dodgerblue)
plot!(p1, 1:N, hv_s, label="HAVOK d=100 r=11", lw=1.2, color=:green)

# forecast panel: out-of-sample h=1 closed-loop on the test tail
n=length(data); ntr=round(Int,0.7n); μtr=mean(data[1:ntr]); xtr=data[1:ntr].-μtr
d=50; H=DMDVariants.hankel(xtr,d); X1=H[:,1:end-1]; X2=H[:,2:end]
U,S,V=svd(X1); r=40; Ur=U[:,1:r]; Sr=Diagonal(S[1:r]); Vr=V[:,1:r]; Atil=Ur'*X2*Vr/Sr
full=data.-μtr; preds=Float64[]; truth=Float64[]; idx=Int[]
for t0 in ntr:(n-1)
    t0-d+1<1 && continue
    z=Ur'*full[t0-d+1:t0]; z=Atil*z
    push!(preds, real((Ur*z)[end])+μtr); push!(truth, data[t0+1]); push!(idx, t0+1)
end
rng = 1:min(400,length(idx))
p2 = plot(idx[rng], truth[rng], label="data (held-out)", lw=2, color=:black,
    title="Out-of-sample 1-step forecast (test tail)", xlabel="beat", ylabel="RR (ms)", legend=:topright)
plot!(p2, idx[rng], preds[rng], label="DMD forecast (d=50,r=40)", lw=1.3, color=:dodgerblue)

plt = plot(p1, p2, layout=(2,1), size=(1000,700))
savefig(plt, "docs/dmd-rr-figure.png")
println("SAVED docs/dmd-rr-figure.png")
