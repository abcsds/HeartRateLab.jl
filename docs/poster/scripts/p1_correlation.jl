#!/usr/bin/env julia
# Participant P1's OWN feature correlation — clustered |r| heatmap over P1's 148 windows
# (docs/poster/scripts/pdf_all_cache.csv). Same single-axis dendrogram+heatmap machinery
# as the poster's healthy-reference clustermap (scripts/clustermap.jl), but computed on P1
# so the two structures can be compared: does P1's within-subject collinearity match the
# population's? Writes docs/poster/figs/p1_correlation.png.
ENV["GKSwstype"]="100"
using CSV, DataFrames, Statistics, Plots
const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))
LABc=Dict(r.feature=>r.label for r in eachrow(CSV.read(joinpath(ROOT,"docs/poster/model_results.csv"),DataFrame)))
FEATS=["mean","median","sdnn","rmssd","sdsd","cvsd","sd1","sd2","sd2_sd1","sd1_sd2_area",
  "ccsi","cvi","pnn20","pnn50","rRR","tinn","triangular_index","lf","hf","tp","lf_hf_ratio",
  "lf_relative","hf_relative","lf_percentage","hf_percentage","lf_peak","hf_peak","mean_hr",
  "std_hr","min_hr","max_hr","min","max","range"]
DOM=Dict("time"=>"#7c53c9","freq"=>"#2f8a44","geom"=>"#c07d1e")
featdom=Dict("mean"=>"time","median"=>"time","sdnn"=>"time","rmssd"=>"time","sdsd"=>"time",
  "cvsd"=>"time","mean_hr"=>"time","std_hr"=>"time","min_hr"=>"time","max_hr"=>"time","min"=>"time",
  "max"=>"time","range"=>"time","pnn20"=>"time","pnn50"=>"time","rRR"=>"time",
  "sd1"=>"geom","sd2"=>"geom","sd2_sd1"=>"geom","sd1_sd2_area"=>"geom","ccsi"=>"geom","cvi"=>"geom",
  "tinn"=>"geom","triangular_index"=>"geom",
  "lf"=>"freq","hf"=>"freq","tp"=>"freq","lf_hf_ratio"=>"freq","lf_relative"=>"freq","hf_relative"=>"freq",
  "lf_percentage"=>"freq","hf_percentage"=>"freq","lf_peak"=>"freq","hf_peak"=>"freq")
ref=CSV.read(joinpath(@__DIR__,"pdf_all_cache.csv"),DataFrame)   # P1's own per-window features
good=[f for f in FEATS if f in names(ref)]
M=hcat([Float64.(coalesce.(ref[!,f],NaN)) for f in good]...); M=M[vec(all(isfinite,M;dims=2)),:]
C=cor(M); D0=1 .- abs.(C); n=length(good)

function hcluster(D0,n)
    tree=Dict{Int,Any}(); for i in 1:n; tree[i]=(:leaf,i); end
    Dd=Dict{Tuple{Int,Int},Float64}(); for i in 1:n, j in i+1:n; Dd[(i,j)]=D0[i,j]; end
    dist(a,b)= a<b ? Dd[(a,b)] : Dd[(b,a)]
    sz=Dict(i=>1 for i in 1:n); active=Set(1:n); nid=n
    while length(active)>1
        av=collect(active); best=(Inf,0,0)
        for ii in 1:length(av), jj in ii+1:length(av)
            d=dist(av[ii],av[jj]); d<best[1] && (best=(d,av[ii],av[jj])) end
        d,a,b=best; nid+=1; tree[nid]=(:node,a,b,d); sz[nid]=sz[a]+sz[b]
        for k in active; (k==a||k==b) && continue
            Dd[(min(nid,k),max(nid,k))]=(sz[a]*dist(a,k)+sz[b]*dist(b,k))/(sz[a]+sz[b]) end
        delete!(active,a); delete!(active,b); push!(active,nid)
    end
    return tree, first(active)
end
tree,root=hcluster(D0,n)
leaves=Int[]; function cl(id); t=tree[id]; t[1]==:leaf ? push!(leaves,t[2]) : (cl(t[2]);cl(t[3])); end; cl(root)
ypos=Dict(f=>k for (k,f) in enumerate(leaves)); ord=leaves
hmax=maximum(tree[id][4] for id in n+1:2n-1)
DSPAN=0.34*n; DSCALE=DSPAN/hmax; DW=DSPAN     # thin dendrogram band so the square heatmap dominates a PORTRAIT panel

default(fontfamily="sans-serif",grid=false)
Cord=abs.(C)[ord,ord]
p=plot(size=(1720,1600),dpi=170,legend=false,framestyle=:none,   # near-square: fills a 99mm-wide trifold panel
    xlims=(-DW-0.8, n+0.8), ylims=(-0.2, n+2.0),
    top_margin=4Plots.mm,bottom_margin=26Plots.mm,left_margin=6Plots.mm,right_margin=6Plots.mm)
heatmap!(p, 1:n, 1:n, Cord; c=cgrad(:Blues), clims=(0,1), colorbar=true, colorbar_title="|r|")
function draw!(id)
    t=tree[id]; t[1]==:leaf && return (0.0, Float64(ypos[t[2]]))
    xa,ya=draw!(t[2]); xb,yb=draw!(t[3]); h=-t[4]*DSCALE
    plot!(p,[xa,h],[ya,ya];color=:gray35,lw=2.6,label="")
    plot!(p,[h,h],[ya,yb];color=:gray35,lw=2.6,label="")
    plot!(p,[h,xb],[yb,yb];color=:gray35,lw=2.6,label=""); (h,(ya+yb)/2)
end
draw!(root)
for f in leaves; scatter!(p,[-0.12],[ypos[f]];color=DOM[featdom[good[f]]],ms=8,msw=0,label=""); end
for (j,f) in enumerate(ord)
    annotate!(p, j, 0.10, text(get(LABc,good[f],good[f]), 12, DOM[featdom[good[f]]], :right, rotation=60))
end
for d in 0:0.2:round(hmax,digits=2)
    plot!(p,[-d*DSCALE,-d*DSCALE],[0.6,n+0.4];color=RGB(0.93,0.93,0.94),lw=1,label="")
    annotate!(p,-d*DSCALE,n+0.9,text(string(d),9,:gray50))
end
annotate!(p,-DW/2,n+1.5,text("1−|r|  (avg linkage)",13,:gray40))
for (i,(nm,k)) in enumerate([("Time","time"),("Frequency","freq"),("Geometric","geom")])
    scatter!(p,[n*0.30+i*4.5-4],[n+1.0];color=DOM[k],ms=9,msw=0,label="")
    annotate!(p,n*0.30+i*4.5-3.6,n+1.0,text(nm,12,DOM[k],:left))
end
title!(p,"Feature correlation — clustered |r|, Participant P1 (148 windows)")
savefig(p,joinpath(ROOT,"docs/poster/figs/p1_correlation.png"))
println("wrote p1_correlation.png  (P1 self-correlation, ",size(M,1)," windows)")
