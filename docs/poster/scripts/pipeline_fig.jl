#!/usr/bin/env julia
# Pipeline "chain of sausages" from one real P1 recording. No step numbers.
# Step 1 = STEMS. Step "Features" = 2x2 montage across domains (Poincaré/geometric,
# Spectrum/frequency, Histogram/time, Δ-series/time), NOT just the spectrum. Palette
# colours: domain accents (Time #7c53c9, Freq #2f8a44, Geometric #c07d1e) + brand.
ENV["GKSwstype"]="100"
using HeartRateLab
using HeartRateLab: read_txt, replace_zeros, replace_bio_outliers, interpolate_nans
using HeartRateLab.Frequency: lomb_scargle, get_power
using Distributions, Plots, Statistics, StatsBase
const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))  # repo root
const PDIR=joinpath(ROOT,"test/testdata/export/Resonant_Breathing")
const OUT=joinpath(ROOT,"docs/poster/figs"); const W=360
prep(x)=interpolate_nans(replace_bio_outliers(replace_zeros(x)))
# palette
TIME="#7c53c9"; FREQ="#2f8a44"; GEOM="#c07d1e"; RAW=RGB(0.20,0.22,0.32)
CLEAN="#389826"; WIN=RGBA(0.25,0.39,0.85,0.20); PRIOR="#CB3C33"; GOLD=RGBA(0.88,0.66,0.23,0.35); HFB=RGBA(0.25,0.45,0.85,0.20)

files=sort(filter(f->endswith(f,".txt"),readdir(PDIR;join=true)))
raw=Float64.(read_txt(files[findfirst(f->length(read_txt(f))>=450,files)]))
for f in files; r=try Float64.(read_txt(f)) catch; Float64[] end; length(r)>=450 && (global raw=r; break); end
clean=prep(copy(raw)); nchg=count(i->abs(raw[i]-clean[i])>1e-6,1:length(raw))
# representative window = median LF/HF
starts=1:120:(length(clean)-W); lfhf=Float64[]
for s in starts; w=clean[s:s+W-1]; pg=lomb_scargle(w)
    lf=get_power(pg,0.04,0.15); hf=get_power(pg,0.15,0.4); push!(lfhf,(isfinite(lf)&&isfinite(hf)&&hf>0) ? lf/hf : NaN) end
wi=starts[argmin(abs.(lfhf .- median(filter(isfinite,lfhf))))]
win=clean[wi:wi+W-1]; pg=lomb_scargle(win)
LF=get_power(pg,0.04,0.15); HF=get_power(pg,0.15,0.4); ratio=LF/HF
prior=LogNormal(0.8582761105281326,0.8567129798742524)
pct=cdf(prior,ratio); z=quantile(Normal(),clamp(pct,1e-6,1-1e-6))
println("rec=",basename(files[1]),"  window@",wi,"  LF/HF=",round(ratio,digits=2),"  z=",round(z,digits=2))

default(fontfamily="sans-serif",grid=false,framestyle=:box,tickfontsize=10,guidefontsize=12,titlefontsize=15,legend=false)
b=eachindex(raw)
# ── main steps ──
seg=1:min(55,length(raw))
rseg=raw[seg]; rlo,rhi=extrema(rseg); rpad=0.10*(rhi-rlo)
p_read=plot(seg,rseg;seriestype=:sticks,color=RAW,lw=1.8,title="Read IBIs  →",ylabel="IBI (ms)",
    xlabel="beat (zoom)",ylims=(rlo-rpad,rhi+rpad))
scatter!(p_read,seg,rseg;color=RAW,ms=3.4,msw=0)
p_prep=plot(b,clean;color=CLEAN,lw=1.6,title="Preprocess  →",xlabel="beat")
annotate!(p_prep,length(clean)*0.5,minimum(clean)+0.1*(maximum(clean)-minimum(clean)),text("$(nchg)/$(length(raw))\ncorrected",10,:center,CLEAN))
p_win=plot(b,clean;color=CLEAN,lw=1.0,title="Window 360  →",xlabel="beat")
vspan!(p_win,[wi,wi+W-1];color=WIN,label="")
# ── features montage (2x2) ──
mt_poin=scatter(win[1:end-1],win[2:end];color=GEOM,ms=2.4,msw=0,title="Poincaré",titlefontsize=13,tickfontsize=8)
mt_spec=plot(pg.freq,pg.power;color=FREQ,lw=1.8,title="Spectrum",titlefontsize=13,tickfontsize=8,xlims=(0,0.4))
vspan!(mt_spec,[0.04,0.15];color=GOLD,label=""); vspan!(mt_spec,[0.15,0.4];color=HFB,label="")
mt_hist=histogram(win;bins=22,color=TIME,linecolor=:white,title="Histogram",titlefontsize=13,tickfontsize=8)
mt_diff=plot(2:length(win),diff(win);seriestype=:sticks,color=TIME,lw=0.7,title="Δ IBI",titlefontsize=13,tickfontsize=8)
# ── prior + score ──
xs=range(0.01,30;length=400)
p_prior=plot(xs,pdf.(prior,xs);color=PRIOR,lw=3,title="Normative prior  →",xlabel="LF/HF",ylabel="density",xlims=(0,30))
xl=range(0.01,ratio;length=120); plot!(p_prior,xl,pdf.(prior,xl);fillrange=0,fillalpha=0.25,fillcolor=PRIOR,lw=0,label="")
vline!(p_prior,[ratio];color=:black,lw=3,label=""); annotate!(p_prior,ratio+0.8,maximum(pdf.(prior,xs))*0.7,text("this\nwindow",10,:left,:black))
zs=range(-3.5,3.5;length=400); zc = z>0 ? PRIOR : CLEAN
p_score=plot(zs,pdf.(Normal(),zs);color=:black,lw=2.4,title="Score → z",xlabel="z-equivalent",yticks=false,xlims=(-3.5,3.5))
vline!(p_score,[z];color=zc,lw=4,label=""); annotate!(p_score,0,0.30,text(string(z>=0 ? "+" : "",round(z,digits=2),"σ"),18,zc))
annotate!(p_score,0,0.20,text("$(round(Int,pct*100))th pct",11,:black))

lay=@layout [a b c [m1 m2; m3 m4] d e]
fig=plot(p_read,p_prep,p_win,mt_poin,mt_spec,mt_hist,mt_diff,p_prior,p_score;
    layout=lay,size=(3500,720),dpi=190,left_margin=6Plots.mm,bottom_margin=9Plots.mm,top_margin=3Plots.mm)
savefig(fig,joinpath(OUT,"pipeline_chain.png")); println("wrote pipeline_chain.png")
