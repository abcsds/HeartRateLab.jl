#!/usr/bin/env julia
# L1-logistic STABILITY SELECTION: meditation-state vs healthy reference.
# Honest design: subject-grouped resampling (windows within a record never leak),
# balanced classes each round, L1 picks among collinear features. Reports which
# features are selected + how often (stability), grouped-CV AUC, and the feature
# correlation structure that explains the collapses. Pure Julia, no ML deps.
ENV["GKSwstype"]="100"
using CSV, DataFrames, Statistics, LinearAlgebra, Random, Plots

const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))  # repo root
const OUT=joinpath(ROOT,"docs/poster/figs"); mkpath(OUT)

# ── candidate feature panel (interpretable, fitted; entropy/fractal excluded) ──
FEATS = ["mean","median","sdnn","rmssd","sdsd","cvsd","sd1","sd2","sd2_sd1",
  "sd1_sd2_area","ccsi","cvi","pnn20","pnn50","rRR","tinn","triangular_index",
  "lf","hf","vlf","tp","lf_hf_ratio","lf_relative","hf_relative","lf_percentage",
  "hf_percentage","lf_peak","hf_peak","mean_hr","std_hr","min_hr","max_hr",
  "min","max","range"]
LAB = Dict("mean"=>"Mean IBI","median"=>"Median IBI","sdnn"=>"SDNN","rmssd"=>"RMSSD",
  "sdsd"=>"SDSD","cvsd"=>"CVSD","sd1"=>"SD1","sd2"=>"SD2","sd2_sd1"=>"SD2/SD1",
  "sd1_sd2_area"=>"SD1·SD2 area","ccsi"=>"cCSI","cvi"=>"CVI","pnn20"=>"pNN20","pnn50"=>"pNN50",
  "rRR"=>"rRR","tinn"=>"TINN","triangular_index"=>"HRV tri-index","lf"=>"LF power",
  "hf"=>"HF power","vlf"=>"VLF power","tp"=>"Total power","lf_hf_ratio"=>"LF/HF",
  "lf_relative"=>"LF rel","hf_relative"=>"HF rel","lf_percentage"=>"LF %","hf_percentage"=>"HF %",
  "lf_peak"=>"LF peak","hf_peak"=>"HF peak","mean_hr"=>"Mean HR","std_hr"=>"SD HR",
  "min_hr"=>"Min HR","max_hr"=>"Max HR","min"=>"Min IBI","max"=>"Max IBI","range"=>"IBI range")

# ── load ──
med = CSV.read(joinpath(ROOT,"test/testdata/meditation/windowed_w360_s120_features.csv"),DataFrame)
med = filter(r->endswith(String(r.participant_id),"med"), med)     # meditation-state only
ref = vcat(CSV.read(joinpath(ROOT,"test/testdata/nsrdb/windowed_w360_s120_features.csv"),DataFrame),
           CSV.read(joinpath(ROOT,"test/testdata/nsr2db/windowed_w360_s120_features.csv"),DataFrame);cols=:union)

# keep features finite in ≥98% of both classes
good=String[]
for f in FEATS
    (f in names(med) && f in names(ref)) || continue
    fm=mean(isfinite.(Float64.(coalesce.(med[!,f],NaN)))); fr=mean(isfinite.(Float64.(coalesce.(ref[!,f],NaN))))
    (fm>0.98 && fr>0.98) && push!(good,f)
end
println("candidate features kept: ", length(good), " / ", length(FEATS),
        "  (dropped: ", join(setdiff(FEATS,good),", "), ")")

getmat(df)=begin
    M=Matrix{Float64}(undef,nrow(df),length(good))
    for (j,f) in enumerate(good); M[:,j]=Float64.(coalesce.(df[!,f],NaN)); end
    M
end
Xm=getmat(med); Xr=getmat(ref)
gm=string.(med.participant_id); gr=string.(ref.participant_id)
km=vec(all(isfinite,Xm;dims=2)); kr=vec(all(isfinite,Xr;dims=2))
Xm,gm=Xm[km,:],gm[km]; Xr,gr=Xr[kr,:],gr[kr]
println("med windows=",size(Xm,1)," (",length(unique(gm))," records)   healthy windows=",size(Xr,1)," (",length(unique(gr))," subjects)")

# standardize by HEALTHY mean/sd (the normative frame)
mu=vec(mean(Xr;dims=1)); sd=vec(std(Xr;dims=1))
Zm=(Xm.-mu')./sd'; Zr=(Xr.-mu')./sd'
p=length(good)

# ── correlation heatmap (on healthy) ──
C=cor(Zr)
ord=sortperm(good)  # alphabetical stable; could cluster
hlab=[LAB[good[i]] for i in ord]
hm=heatmap(hlab,hlab,C[ord,ord];c=:RdBu,clims=(-1,1),size=(1500,1400),dpi=150,
    xrotation=60,tickfontsize=9,title="Feature correlation (healthy reference)",titlefontsize=16,
    left_margin=8Plots.mm,bottom_margin=18Plots.mm)
savefig(hm,joinpath(OUT,"feature_correlation.png"))
# report worst collinear pairs
pairs=[(abs(C[i,j]),good[i],good[j]) for i in 1:p for j in i+1:p]
sort!(pairs;rev=true)
println("\nMost collinear feature pairs (|r|):")
for (r,a,b) in pairs[1:10]; println("  ",round(r,digits=3),"  ",LAB[a]," ~ ",LAB[b]); end

# ── L1 logistic via FISTA (intercept unpenalized) ──
σ(z)=1/(1+exp(-z))
function fit_l1(X,y,λ;iters=400)
    n,d=size(X); A=hcat(ones(n),X)               # col1=intercept
    L=0.25*opnorm(A)^2/n
    w=zeros(d+1); v=copy(w); t=1.0
    for _ in 1:iters
        z=A*v; g=A'*(σ.(z).-y)./n
        wn=v .- g./L
        @inbounds for j in 2:d+1                   # soft-threshold, skip intercept
            wn[j]=sign(wn[j])*max(abs(wn[j])-λ/L,0.0)
        end
        tn=(1+sqrt(1+4t^2))/2; v=wn .+ ((t-1)/tn).*(wn.-w); w=wn; t=tn
    end
    w   # [b; β]
end
auc(s,y)=begin
    o=sortperm(s); r=zeros(length(s)); r[o]=1:length(s)
    np=sum(y.==1); nn=sum(y.==0)
    (sum(r[y.==1])-np*(np+1)/2)/(np*nn)
end

# choose λ targeting moderate sparsity on the full balanced set
Random.seed!(1)
function balanced(Zr,gr,nmed;seed=0)
    Random.seed!(seed)
    subs=unique(gr)
    idx=Int[]
    while length(idx)<nmed
        s=rand(subs); si=findall(==(s),gr); append!(idx,si)
    end
    idx[1:nmed]
end
# λ grid → pick where ~12 features enter on the pooled balanced set
ridx=balanced(Zr,gr,size(Zm,1);seed=99)
Xall=vcat(Zm,Zr[ridx,:]); yall=vcat(ones(size(Zm,1)),zeros(length(ridx)))
λs=exp10.(range(-3.2,-0.4;length=25)); nsel=Int[]
for λ in λs; w=fit_l1(Xall,yall,λ); push!(nsel,count(!=(0.0),w[2:end])); end
λ=λs[argmin(abs.(nsel .- 12))]
println("\nchosen λ=",round(λ,digits=4)," (≈",nsel[argmin(abs.(nsel.-12))]," features enter)")

# ── STABILITY SELECTION: B rounds, grouped-balanced resample ──
B=200; freq=zeros(p); coefsum=zeros(p)
medsubs=unique(gm); refsubs=unique(gr)
for b in 1:B
    Random.seed!(1000+b)
    # bootstrap med records; balanced healthy subjects
    mrec=rand(medsubs,length(medsubs)); mi=vcat([findall(==(s),gm) for s in mrec]...)
    hsub=rand(refsubs, length(medsubs)); hi=vcat([findall(==(s),gr) for s in hsub]...)
    nb=min(length(mi),length(hi)); mi=mi[1:nb]; hi=hi[1:nb]
    Xb=vcat(Zm[mi,:],Zr[hi,:]); yb=vcat(ones(nb),zeros(nb))
    w=fit_l1(Xb,yb,λ); β=w[2:end]
    freq .+= (β .!= 0.0); coefsum .+= β
end
freq ./= B; coefmean=coefsum ./ B

# ── grouped 5-fold CV AUC at chosen λ ──
allsub=vcat([(s,:m) for s in medsubs],[(s,:h) for s in refsubs]); Random.seed!(7); shuffle!(allsub)
K=5; folds=[allsub[i:K:end] for i in 1:K]; aucs=Float64[]
for k in 1:K
    test=Set(folds[k])
    tr_m=[i for i in 1:size(Zm,1) if (gm[i],:m) ∉ test]; te_m=[i for i in 1:size(Zm,1) if (gm[i],:m) ∈ test]
    tr_h=[i for i in 1:size(Zr,1) if (gr[i],:h) ∉ test]; te_h=[i for i in 1:size(Zr,1) if (gr[i],:h) ∈ test]
    (isempty(te_m)||isempty(te_h)) && continue
    Random.seed!(500+k); tr_h=tr_h[randperm(length(tr_h))[1:min(length(tr_h),length(tr_m))]]
    Xtr=vcat(Zm[tr_m,:],Zr[tr_h,:]); ytr=vcat(ones(length(tr_m)),zeros(length(tr_h)))
    w=fit_l1(Xtr,ytr,λ)
    Xte=vcat(Zm[te_m,:],Zr[te_h,:]); yte=vcat(ones(length(te_m)),zeros(length(te_h)))
    push!(aucs, auc(hcat(ones(size(Xte,1)),Xte)*w, yte))
end
println("\nGrouped 5-fold CV AUC (meditation-state vs healthy): ",
        round(mean(aucs),digits=3)," ± ",round(std(aucs),digits=3))

# ── results table ──
ordr=sortperm(freq;rev=true)
println("\n══ STABILITY-SELECTION RESULTS (", B, " grouped resamples, λ=",round(λ,digits=4)," ) ══")
println(rpad("feature",16),rpad("stability",11),rpad("mean β",10),"direction")
for i in ordr
    freq[i]<0.05 && continue
    dir = coefmean[i]>0 ? "↑ higher in meditation" : "↓ lower in meditation"
    println(rpad(LAB[good[i]],16),rpad(string(round(freq[i]*100,digits=0),"%"),11),
            rpad(string(round(coefmean[i],digits=3)),10), abs(coefmean[i])<1e-3 ? "" : dir)
end

# save stability + coefs to CSV for the notes handout + poster figure
res=DataFrame(feature=good, label=[LAB[f] for f in good], stability=freq, mean_beta=coefmean)
sort!(res,:stability,rev=true)
CSV.write(joinpath(ROOT,"docs/poster/model_results.csv"),res)
println("\nwrote docs/poster/model_results.csv  +  figs/feature_correlation.png")
