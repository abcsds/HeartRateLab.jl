#!/usr/bin/env julia
# Participant P1 z-score dumbbell: deviation from the healthy population (blue) and from
# the meditator group (green), per feature. The connecting line shows how much of P1's
# elevation is "explained" by resembling meditators.
ENV["GKSwstype"]="100"
using CSV, DataFrames, Plots, Statistics
const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))  # repo root
z=CSV.read(joinpath(ROOT,"docs/poster/zscores.csv"),DataFrame)
sort!(z,:z_healthy)                       # ascending → largest on top
n=nrow(z)
BLUE="#4063D8"; GREEN="#389826"; INK=RGB(0.14,0.13,0.25)
G1=RGB(0.90,0.90,0.92); G2=RGB(0.95,0.95,0.96)
default(fontfamily="sans-serif",grid=false,framestyle=:box)
# scale marker/label sizes to the row count (all ~35 features vs the old 9)
ms  = n>18 ? 7.0 : 13.0
vfs = n>18 ? 9   : 13     # value-label font
tfs = n>18 ? 13  : 19     # y-tick (feature name) font
lfs = n>18 ? 12  : 15     # in-plot legend font

xlo,xhi=-2.7,3.1
p=plot(size=(1820, round(Int,150+n*40)),dpi=200,legend=false,
    xlims=(xlo,xhi),ylims=(0.4,n+1.2),yticks=(1:n,z.label),
    xlabel="z-equivalent  (σ from the group's median)",
    tickfontsize=tfs,guidefontsize=22,left_margin=34Plots.mm,bottom_margin=11Plots.mm,
    right_margin=6Plots.mm,top_margin=8Plots.mm)
# reference bands (recessive): ±1σ and ±2σ
vspan!(p,[-2,-1];color=G2,label=""); vspan!(p,[1,2];color=G2,label="")
vspan!(p,[-1,1];color=G1,label="")
for t in [-2,-1,1,2]; vline!(p,[t];color=:white,lw=2,label=""); end
vline!(p,[0];color=RGB(0.5,0.5,0.55),lw=2.5,label="")
# dumbbells
for (i,r) in enumerate(eachrow(z))
    plot!(p,[r.z_meditators,r.z_healthy],[i,i];color=RGB(0.6,0.6,0.65),lw=2.4,label="")
    scatter!(p,[r.z_healthy],[i];color=BLUE,ms=ms,msw=1.2,msc=:white,label="")
    scatter!(p,[r.z_meditators],[i];color=GREEN,ms=ms,msw=1.2,msc=:white,label="")
    dh = r.z_healthy>=r.z_meditators ? 1 : -1
    annotate!(p, r.z_healthy+0.14*dh, i, text(string(round(r.z_healthy,digits=1)),vfs,BLUE, dh>0 ? :left : :right))
    annotate!(p, r.z_meditators-0.14*dh, i, text(string(round(r.z_meditators,digits=1)),vfs,GREEN, dh>0 ? :right : :left))
end
# in-plot legend (top-left, above the tallest rows)
scatter!(p,[xlo+0.5],[n+0.75];color=BLUE,ms=ms,msw=1.2,msc=:white,label=""); annotate!(p,xlo+0.68,n+0.75,text("vs healthy population",lfs,BLUE,:left))
scatter!(p,[xlo+0.5],[n+0.20];color=GREEN,ms=ms,msw=1.2,msc=:white,label=""); annotate!(p,xlo+0.68,n+0.20,text("vs meditators",lfs,GREEN,:left))
savefig(p,joinpath(ROOT,"docs/poster/figs/participant_zscores.png"))
println("wrote participant_zscores.png (",n," features)")
