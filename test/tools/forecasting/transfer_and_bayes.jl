# Phase-0 follow-ups: (A) transfer test of the NSRDB-selected winner on the
# personal Resonant_Breathing data, and (B) Bayesian AR(8) refit (Turing) vs the
# frequentist AR(8) to check whether the posterior predictive recovers calibration.
# Runs in-container against --project=. . Writes local CSVs (no external publish).

using HeartRateLab
using Statistics, LinearAlgebra, Random
using Turing

const H = 10
const NSAMP = 300
const WFIT = 250
const PWIN = 8                       # winning AR order
const OUTDIR = "test/tools/forecasting/out"
Random.seed!(20260708)
mkpath(OUTDIR)

# ---- shared metric + AR helpers (mirror study.jl) ----
crps(s,y) = (n=length(s); t1=sum(abs.(s.-y))/n; ss=sort(s); acc=0.0;
    (@inbounds for i in 1:n; acc+=(2i-n-1)*ss[i]; end); t1-0.5*(2acc/(n^2)))
qs(sc,q)=(n=length(sc);idx=clamp(q*(n-1)+1,1,n);lo=floor(Int,idx);hi=ceil(Int,idx);f=idx-lo;sc[lo]*(1-f)+sc[hi]*f)
fitwin(h)= length(h)>WFIT ? h[end-WFIT+1:end] : h

function fit_ar(x,p)
    n=length(x); n<=p+5 && return nothing
    mu=mean(x); xc=x.-mu
    r=[sum(@view(xc[1:n-k]).*@view(xc[1+k:n]))/n for k in 0:p]; r[1]<=0 && return nothing
    R=[r[abs(i-j)+1] for i in 1:p, j in 1:p]
    phi=try; R\r[2:p+1]; catch; return nothing; end
    s2=r[1]-sum(phi.*r[2:p+1]); s2<=0 && (s2=r[1]*1e-3)
    (phi,mu,sqrt(s2))
end
function ar_sim(last,phi,mu,sig)
    p=length(phi); S=Matrix{Float64}(undef,NSAMP,H)
    for s in 1:NSAMP
        buf=collect(last)
        for h in 1:H
            pr=mu; @inbounds for j in 1:p; pr+=phi[j]*(buf[end-j+1]-mu); end
            pr+=sig*randn(); S[s,h]=pr; push!(buf,pr); popfirst!(buf)
        end
    end; S
end
persist(h)=(d=diff(h);s=std(d);[h[end]+s*sqrt(k)*randn() for _ in 1:NSAMP,k in 1:H])

score!(acc,key,S,actual)=for h in 1:H
    col=collect(@view S[:,h]); y=actual[h]; pt=mean(col); sc=sort(col)
    a=get!(acc,(key,h),zeros(5))
    a[1]+=(pt-y)^2; a[2]+=crps(col,y); a[3]+=(qs(sc,0.05)<=y<=qs(sc,0.95)); a[4]+=qs(sc,0.95)-qs(sc,0.05); a[5]+=1
end

# ============================================================ (A) transfer on RB
println("=== (A) transfer: Resonant_Breathing ==="); flush(stdout)
rbdir="test/testdata/export/Resonant_Breathing"
files=sort(filter(f->endswith(f,".txt"), readdir(rbdir;join=true)))
accA=Dict{Tuple{String,Int},Vector{Float64}}()
nrec=0
for f in files
    rr=try
        x=read_txt(f); x=replace_zeros(x); x=replace_bio_outliers(x); x=interpolate_nans(x); Float64.(x)
    catch; continue end
    length(rr)<130 && continue
    global nrec+=1
    for origin in 100:40:(length(rr)-H)
        hist=rr[1:origin]; actual=@view rr[origin+1:origin+H]
        score!(accA,"persistence",persist(hist),actual)
        for p in (4,8)
            fw=fitwin(hist); f=fit_ar(fw,p); f===nothing && continue
            score!(accA,"ar_raw_$p",ar_sim(fw[end-p+1:end],f...),actual)
        end
    end
end
open(joinpath(OUTDIR,"transfer_rb.csv"),"w") do io
    println(io,"model,horizon,rmse,crps,picp90,mpiw90,n")
    for (k,a) in sort(collect(accA);by=x->(x[1][1],x[1][2]))
        m,h=k; n=a[5]; println(io,"$m,$h,$(sqrt(a[1]/n)),$(a[2]/n),$(a[3]/n),$(a[4]/n),$(Int(n))")
    end
end
println("RB recordings used = $nrec ; wrote transfer_rb.csv"); flush(stdout)

# ============================================================ (B) Bayesian AR(8)
@model function bayes_ar(y, p)
    n=length(y); mu~Normal(mean(y),200); sigma~Exponential(50)
    phi~filldist(Normal(0,0.5),p)
    for t in (p+1):n
        m=mu; for j in 1:p; m+=phi[j]*(y[t-j]-mu); end
        y[t]~Normal(m,sigma)
    end
end
function bayes_sim(hist,p)
    fw=fitwin(hist)
    ch=sample(bayes_ar(fw,p), NUTS(0.65), 250; progress=false)
    mus=vec(Array(ch[:mu])); sigs=vec(Array(ch[:sigma]))
    phis=Array(ch[:,[Symbol("phi[$j]") for j in 1:p],1])  # draws×p
    ndraw=length(mus); S=Matrix{Float64}(undef,NSAMP,H)
    for s in 1:NSAMP
        d=rand(1:ndraw); mu=mus[d]; sig=sigs[d]; ph=@view phis[d,:]
        buf=collect(fw[end-p+1:end])
        for h in 1:H
            pr=mu; @inbounds for j in 1:p; pr+=ph[j]*(buf[end-j+1]-mu); end
            pr+=sig*randn(); S[s,h]=pr; push!(buf,pr); popfirst!(buf)
        end
    end; S
end

println("\n=== (B) Bayesian vs frequentist AR($PWIN) calibration ==="); flush(stdout)
accB=Dict{Tuple{String,Int},Vector{Float64}}()
# subsample: a few NSRDB + a few RB origins to keep MCMC cost bounded
bnsr=[("nsrdb","atr",s) for s in ("16265","16273","16483","17052","19090")]
count=0
for (ds,ann,subj) in bnsr
    rr=try; x=read_wfdb(joinpath("test/testdata/$ds/_downloads",subj),ann);
        x=replace_zeros(x);x=replace_bio_outliers(x);x=interpolate_nans(x);Float64.(x)
    catch; continue end
    for origin in (400,900,1500,2200)
        origin+H>length(rr) && continue
        hist=rr[1:origin]; actual=@view rr[origin+1:origin+H]
        fw=fitwin(hist); f=fit_ar(fw,PWIN); f===nothing && continue
        score!(accB,"freq_ar$PWIN",ar_sim(fw[end-PWIN+1:end],f...),actual)
        score!(accB,"bayes_ar$PWIN",bayes_sim(hist,PWIN),actual)
        global count+=1
    end
    println("  bayes done $subj (cum origins=$count)"); flush(stdout)
end
open(joinpath(OUTDIR,"bayes_compare.csv"),"w") do io
    println(io,"model,horizon,rmse,crps,picp90,mpiw90,n")
    for (k,a) in sort(collect(accB);by=x->(x[1][1],x[1][2]))
        m,h=k; n=a[5]; println(io,"$m,$h,$(sqrt(a[1]/n)),$(a[2]/n),$(a[3]/n),$(a[4]/n),$(Int(n))")
    end
end
println("bayes origins = $count ; wrote bayes_compare.csv")

# console summary
for (nm,acc) in (("TRANSFER-RB",accA),("BAYES",accB))
    agg=Dict{String,Vector{Vector{Float64}}}()
    for (k,a) in acc; push!(get!(agg,k[1],Vector{Float64}[]),a); end
    println("\n--- $nm (mean over horizons) ---")
    for (m,as) in sort(collect(agg);by=x->sum(v[2] for v in x[2])/sum(v[5] for v in x[2]))
        n=sum(v[5] for v in as); cr=sum(v[2] for v in as)/n; p=sum(v[3] for v in as)/n; w=sum(v[4] for v in as)/n
        println(rpad(m,16)," CRPS=",round(cr,digits=2)," PICP90=",round(p,digits=3)," MPIW90=",round(w,digits=1))
    end
end
