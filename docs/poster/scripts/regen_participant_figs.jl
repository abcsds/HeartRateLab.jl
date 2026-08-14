#!/usr/bin/env julia
# Poster participant figures — A0 legibility redesign.
#   hero: full-width 2x3 of SIX story features via HRL's own plot_normative_kde_comparison
#         (correct skewed-range handling) but with LARGE fonts + P1 label.
#   over-time: LF/HF & RMSSD, big fonts, few ticks, inline band labels, no legend box.
ENV["GKSwstype"] = "100"
using HeartRateLab
using HeartRateLab: windowed_feature_set, read_txt,
                    replace_zeros, replace_bio_outliers, interpolate_nans,
                    plot_normative_kde_comparison
using Plots, StatsPlots, Distributions, CSV, DataFrames, Statistics, Dates
using Memoization: empty_all_caches!

const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))  # repo root
const PDIR=joinpath(ROOT,"test/testdata/export/Resonant_Breathing")
const FIGS=joinpath(ROOT,"docs/poster/figs"); const W,S=360,120
const PLABEL="Participant P1"
const G_OUT=RGB(0.90,0.90,0.90); const G_IN=RGB(0.72,0.72,0.72)
const LAB=Dict("rmssd"=>"RMSSD (ms)","mean"=>"Mean IBI (ms)","sdnn"=>"SDNN (ms)",
  "lf"=>"LF Power (ms²)","hf"=>"HF Power (ms²)","sd1"=>"SD1 (ms)","sd2"=>"SD2 (ms)",
  "pnn50"=>"pNN50","lf_hf_ratio"=>"LF/HF ratio")
priors=CSV.read(joinpath(ROOT,"docs/normative_priors.csv"),DataFrame)
pdist(f)=(r=first(filter(x->x.feature==f,priors)); r.family=="Normal" ? Normal(r.param1_value,r.param2_value) :
  r.family=="LogNormal" ? LogNormal(r.param1_value,r.param2_value) :
  r.family=="Gamma" ? Gamma(r.param1_value,r.param2_value) : Beta(r.param1_value,r.param2_value))
parse_dt(fn)=try DateTime(splitext(basename(fn))[1],"yyyy-mm-dd HH-MM-SS") catch;
  try DateTime(Date(splitext(basename(fn))[1][1:10],"yyyy-mm-dd")) catch; nothing end end
prep(x)=interpolate_nans(replace_bio_outliers(replace_zeros(x)))

const CACHE=joinpath(dirname(@__FILE__),"pdf_all_cache.csv")
local pdf_all
if isfile(CACHE)
    pdf_all=CSV.read(CACHE,DataFrame); pdf_all.recording_date=Date.(pdf_all.recording_date)
else
    rows=DataFrame[]
    for fp in sort(filter(f->endswith(f,".txt"),readdir(PDIR;join=true)))
        dt=parse_dt(fp); dt===nothing && continue
        try; raw=read_txt(fp); length(raw)<W && continue; empty_all_caches!()
            df=windowed_feature_set(prep(Vector{Float64}(raw));window_size=W,stride=S,time=:beats,features=:default)
            df[!,:recording_date].=Date(dt); push!(rows,df); catch; end
    end
    pdf_all=vcat(rows...;cols=:union)
    for c in names(pdf_all); eltype(pdf_all[!,c])>:Missing && (pdf_all[!,c]=coalesce.(pdf_all[!,c],NaN)); end
    CSV.write(CACHE,pdf_all)
end
refparts=DataFrame[]
for ds in ["nsrdb","nsr2db"]
    p=joinpath(ROOT,"test/testdata",ds,"windowed_w$(W)_s$(S)_features.csv"); isfile(p) && push!(refparts,CSV.read(p,DataFrame;silencewarnings=true))
end
refdf=vcat(refparts...;cols=:union)
println("windows=$(nrow(pdf_all)) dates=$(length(unique(pdf_all.recording_date))) ref=$(nrow(refdf))")

# ── HERO: reuse HRL comparison (correct ranges) with LARGE fonts, 6 features, 2x3 ──
default(fontfamily="sans-serif", tickfontsize=16, guidefontsize=20, legendfontsize=17,
        titlefontsize=22, grid=false)
HERO6=["lf","lf_hf_ratio","sd2","sdnn","rmssd","hf"]
hero=plot_normative_kde_comparison(Dict("All Normal"=>refdf, PLABEL=>pdf_all), HERO6;
        reference_key="All Normal", feat_labels=LAB, ncols=3, title="")
Plots.plot!(hero; size=(2500,740), dpi=200,
        left_margin=13Plots.mm, bottom_margin=15Plots.mm, top_margin=2Plots.mm)
savefig(hero,joinpath(FIGS,"hero_participant_vs_normative.png")); println("wrote hero 2x3")

# ── OVER-TIME (big fonts, inline band labels, no legend box) ──
function overtime(feat,fname)
    g=combine(groupby(pdf_all,:recording_date),feat=>(v->mean(filter(!isnan,v)))=>:m); sort!(g,:recording_date)
    dates=g.recording_date; y=g.m; x=1:length(dates); D=pdist(feat)
    loc=median(D);lo1=quantile(D,0.1587);hi1=quantile(D,0.8413);lo2=quantile(D,0.0228);hi2=quantile(D,0.9772)
    ymin=min(minimum(y),lo2);ymax=max(maximum(y),hi2);pad=(ymax-ymin)*0.10;ymin-=pad;ymax+=pad
    yrs=year.(dates);tp=Int[];tl=String[];mg=max(1,round(Int,length(dates)*0.05))
    for i in eachindex(yrs); (i==1||yrs[i]!=yrs[i-1]) && (isempty(tp)||(i-tp[end])>=mg) && (push!(tp,i);push!(tl,string(yrs[i]))); end
    p=plot(xlabel="Recording date (year)",ylabel=LAB[feat],title="",ylims=(ymin,ymax),legend=false,
           xticks=(tp,tl),xrotation=0,size=(1500,560),dpi=200,grid=false,framestyle=:box,
           tickfontsize=20,guidefontsize=23,left_margin=12Plots.mm,bottom_margin=15Plots.mm,right_margin=22Plots.mm,top_margin=4Plots.mm)
    n=length(dates)
    plot!(p,[1,n],[lo2,lo2];fillrange=[hi2,hi2],fillalpha=1,fillcolor=G_OUT,linewidth=0,label="")
    plot!(p,[1,n],[lo1,lo1];fillrange=[hi1,hi1],fillalpha=1,fillcolor=G_IN,linewidth=0,label="")
    hline!(p,[loc];color=:black,lw=2.5,linestyle=:dash,label="")
    xf=Float64.(collect(x));xm=mean(xf);ym=mean(y);b=sum((xf.-xm).*(y.-ym))/sum((xf.-xm).^2);a=ym-b*xm
    plot!(p,x,a.+b.*xf;color=RGB(0.35,0.35,0.35),lw=3,linestyle=:dot,label="")
    scatter!(p,x,y;color=:darkorange,markersize=7.5,markerstrokewidth=1.2,markerstrokecolor=:white,label="")
    annotate!(p, n+0.6, hi2, text("+2σ",17,:left,RGB(0.45,0.45,0.45)))
    annotate!(p, n+0.6, hi1, text("+1σ",17,:left,RGB(0.25,0.25,0.25)))
    annotate!(p, n+0.6, loc, text("median",16,:left,:black))
    savefig(p,joinpath(FIGS,fname)); println("wrote ",fname)
end
overtime("lf_hf_ratio","lfhf_over_time.png")
overtime("rmssd","rmssd_over_time.png")
println("DONE")
