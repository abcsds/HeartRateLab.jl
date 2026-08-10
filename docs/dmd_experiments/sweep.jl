# Parameter sweep for UnitCircleDMD (variance-matching) + validation on a 16265
# NSRDB window. Also forecast-NRMSE sweep over embedding/rank.

using LinearAlgebra, Statistics, HeartRateLab
const M = HeartRateLab.Models
const E = HeartRateLab.Evaluation
include("dmd_variants.jl"); using .DMDVariants

io = open("docs/dmd_experiments/sweep.txt", "w")

function eval_gen(data, d, rmax)
    m = DMDVariants.StabilizedDMD(d=d, energy=0.99, rmax=rmax)
    res = M.fit(m, data)
    sim = M.simulate(res.model, nothing, length(data))
    ic = E.information_criteria(res; n_sim_beats=min(500, length(data)))
    (mean=mean(sim), std=std(sim), bic=ic.bic, loglik=ic.loglik, r=res.model.r)
end

# example.txt sweep
data = HeartRateLab.read_txt("test/testdata/example.txt")
println(io, "example.txt: n=$(length(data)) mean=$(round(mean(data),digits=1)) std=$(round(std(data),digits=1))")
println(io, "UnitCircleDMD variance-matching sweep (target std≈$(round(std(data),digits=1))):")
println(io, rpad("d",6),rpad("rmax",7),rpad("r_used",8),rpad("sim_mean",11),rpad("sim_std",10),rpad("BIC",12),"loglik")
for d in (30,50,80,120), rmax in (10,20,30)
    e = eval_gen(data, d, rmax)
    println(io, rpad(d,6),rpad(rmax,7),rpad(e.r,8),rpad(round(e.mean,digits=1),11),rpad(round(e.std,digits=2),10),rpad(round(e.bic,digits=1),12),round(e.loglik,digits=1))
end
flush(io)

# 16265 NSRDB window validation
println(io, "\n", "="^80)
nsr = try
    HeartRateLab.read_wfdb("test/testdata/16265", "atr")
catch err
    println(io, "read_wfdb failed: $err"); Float64[]
end
if !isempty(nsr)
    # take a clean 4000-beat window from the middle
    w = nsr[20001:24000]
    w = filter(x -> 300 <= x <= 2000, w)  # physiological clip for safety
    println(io, "16265 window: n=$(length(w)) mean=$(round(mean(w),digits=1)) std=$(round(std(w),digits=1))")
    println(io, "UnitCircleDMD sweep on 16265 window:")
    println(io, rpad("d",6),rpad("rmax",7),rpad("r_used",8),rpad("sim_mean",11),rpad("sim_std",10),rpad("BIC",12),"loglik")
    for d in (50,100), rmax in (20,30)
        e = eval_gen(w, d, rmax)
        println(io, rpad(d,6),rpad(rmax,7),rpad(e.r,8),rpad(round(e.mean,digits=1),11),rpad(round(e.std,digits=2),10),rpad(round(e.bic,digits=1),12),round(e.loglik,digits=1))
    end
    # existing DMD on the same window for comparison
    rex = M.fit(M.DMD(rank=5), w)
    icex = E.information_criteria(rex; n_sim_beats=500)
    sex = M.simulate(rex.model, nothing, length(w))
    println(io, "ExistingDMD on window: sim_mean=$(round(mean(sex),digits=1)) sim_std=$(round(std(sex),digits=2)) BIC=$(round(icex.bic,digits=1)) loglik=$(round(icex.loglik,digits=1))")
end

# forecast sweep on example.txt over (d, r)
println(io, "\n", "="^80)
println(io, "Out-of-sample forecast NRMSE (train 70%/test 30%) over (d,r), h=1 and h=5:")
function forecast(data, d, r, h)
    n=length(data); ntr=round(Int,0.7n); σall=std(data); μtr=mean(data[1:ntr])
    xtr=data[1:ntr].-μtr
    H=DMDVariants.hankel(xtr,d); X1=H[:,1:end-1]; X2=H[:,2:end]
    U,S,V=svd(X1); rr=min(r,length(S))
    Ur=U[:,1:rr]; Sr=Diagonal(S[1:rr]); Vr=V[:,1:rr]
    Atil=Ur'*X2*Vr/Sr
    full=data.-μtr; preds=Float64[]; truth=Float64[]
    for t0 in ntr:(n-h)
        t0-d+1<1 && continue
        z=Ur'*full[t0-d+1:t0]
        for _ in 1:h; z=Atil*z; end
        push!(preds, real((Ur*z)[end])+μtr); push!(truth, data[t0+h])
    end
    sqrt(mean((truth.-preds).^2))/σall
end
println(io, rpad("d",6),rpad("r",6),rpad("h=1",10),"h=5")
for d in (30,50,100), r in (10,20,40)
    r>=d && continue
    println(io, rpad(d,6),rpad(r,6),rpad(round(forecast(data,d,r,1),digits=4),10),round(forecast(data,d,r,5),digits=4))
end

close(io)
println("DONE")
