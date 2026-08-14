#!/usr/bin/env julia
# Result figures: (1) stability-selection bar, (2) clustered correlation heatmap,
# (3) 3-way comparison (healthy vs meditators vs P1) on the selected features.
ENV["GKSwstype"]="100"
using CSV, DataFrames, Statistics, LinearAlgebra, StatsPlots, Plots

const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))  # repo root
const OUT=joinpath(ROOT,"docs/poster/figs"); mkpath(OUT)
const CACHE=joinpath(@__DIR__, "pdf_all_cache.csv")
const CGREY=RGB(0.45,0.45,0.45); const CMED=RGB(0.22,0.60,0.15); const CP1=RGB(0.24,0.30,0.85); const CUP=RGB(0.80,0.24,0.20); const CDN=RGB(0.25,0.40,0.75)
default(fontfamily="sans-serif")

# ── (1) stability-selection bar ──
res=CSV.read(joinpath(ROOT,"docs/poster/model_results.csv"),DataFrame)
res=res[res.stability .>= 0.15, :]; sort!(res,:stability)   # ascending → biggest on top
n=nrow(res); cols=[b>0 ? CUP : CDN for b in res.mean_beta]
sp=bar(res.stability.*100; orientation=:h, yticks=(1:n, res.label), color=cols,
    linecolor=:white, lw=1, legend=false, xlabel="selection stability  (% of 200 resamples)",
    xlims=(0,100), ylims=(0.3,n+0.7), size=(1760,700), dpi=200,
    tickfontsize=16, guidefontsize=20, left_margin=36Plots.mm, bottom_margin=10Plots.mm,
    right_margin=6Plots.mm, grid=:x, gridalpha=0.25)
vline!(sp,[60]; color=:black, ls=:dash, lw=2.5, label="")
annotate!(sp, 63, n-0.5, text("stable ≥60%", 15, :left, :black))
# direction legend
annotate!(sp, 88, 2.4, text("↑ higher in\nmeditation", 14, :left, CUP))
annotate!(sp, 88, 0.9, text("↓ lower", 14, :left, CDN))
savefig(sp, joinpath(OUT,"stability_selection.png")); println("wrote stability_selection.png")

# ── (2) clustered correlation heatmap ──
FEATS=["mean","median","sdnn","rmssd","sdsd","cvsd","sd1","sd2","sd2_sd1","sd1_sd2_area",
  "ccsi","cvi","pnn20","pnn50","rRR","tinn","triangular_index","lf","hf","tp","lf_hf_ratio",
  "lf_relative","hf_relative","lf_percentage","hf_percentage","lf_peak","hf_peak","mean_hr",
  "std_hr","min_hr","max_hr","min","max","range"]
LAB=Dict(r.feature=>r.label for r in eachrow(CSV.read(joinpath(ROOT,"docs/poster/model_results.csv"),DataFrame)))
ref=vcat(CSV.read(joinpath(ROOT,"test/testdata/nsrdb/windowed_w360_s120_features.csv"),DataFrame),
         CSV.read(joinpath(ROOT,"test/testdata/nsr2db/windowed_w360_s120_features.csv"),DataFrame);cols=:union)
good=[f for f in FEATS if f in names(ref)]
M=hcat([Float64.(coalesce.(ref[!,f],NaN)) for f in good]...); M=M[vec(all(isfinite,M;dims=2)),:]
C=cor(M)
# greedy seriation: chain each feature to its most-correlated unused neighbour
function seriate(C)
    np=size(C,1); ord=[1]; used=Set(1)
    while length(ord)<np
        l=ord[end]; cand=collect(setdiff(1:np,used))
        nxt=cand[argmax([abs(C[l,c]) for c in cand])]; push!(ord,nxt); push!(used,nxt)
    end
    ord
end
ord=seriate(C)
lab=[get(LAB,good[i],good[i]) for i in ord]
hm=heatmap(lab,lab,C[ord,ord]; c=:RdBu, clims=(-1,1), size=(1550,1450), dpi=170,
    xrotation=55, tickfontsize=13, colorbar_tickfontsize=14,
    title="Feature correlation on the healthy reference (clustered)", titlefontsize=20,
    left_margin=6Plots.mm, bottom_margin=24Plots.mm, top_margin=2Plots.mm)
savefig(hm, joinpath(OUT,"feature_correlation.png")); println("wrote feature_correlation.png (clustered)")

# ── (3) 3-way comparison on selected features ──
med=CSV.read(joinpath(ROOT,"test/testdata/meditation/windowed_w360_s120_features.csv"),DataFrame)
med=filter(r->endswith(String(r.participant_id),"med"),med)
p1=CSV.read(CACHE,DataFrame)
col(df,f)=filter(isfinite,Float64.(coalesce.(df[!,f],NaN)))
SEL=[("lf_hf_ratio","LF/HF ratio",30.0),("lf_percentage","LF power (%)",60.0),
     ("lf_peak","LF peak (Hz)",0.16),("pnn20","pNN20",0.6),
     ("tp","Total power (ms²)",8000.0),("sdnn","SDNN (ms) — contrast",180.0)]
panels=Plots.Plot[]
for (f,lab,xhi) in SEL
    r=col(ref,f); m=col(med,f); p=f in names(p1) ? col(p1,f) : Float64[]
    pl=plot(xlims=(0,xhi),yticks=false,xlabel=lab,legend=false,grid=false,framestyle=:box,
            tickfontsize=15,guidefontsize=18)
    density!(pl,r;color=CGREY,lw=4,fillrange=0,fillalpha=0.18,fillcolor=CGREY,label="",trim=true)
    density!(pl,m;color=CMED,lw=5,linestyle=:solid,label="",trim=true)
    isempty(p) || density!(pl,p;color=CP1,lw=5,linestyle=:dashdot,label="",trim=true)
    push!(panels,pl)
end
fig=plot(panels...;layout=(2,3),size=(2450,960),dpi=200,
    plot_title="Healthy reference (grey)   ·   Meditators (green)   ·   Participant P1 (blue)",
    plot_titlefontsize=24,left_margin=6Plots.mm,bottom_margin=11Plots.mm,top_margin=3Plots.mm)
savefig(fig,joinpath(OUT,"three_way_comparison.png")); println("wrote three_way_comparison.png")
println("DONE")
