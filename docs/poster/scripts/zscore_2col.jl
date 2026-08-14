#!/usr/bin/env julia
# Participant P1 z-score dumbbell, TWO-COLUMN layout (figs/zopt_2col.png):
# all scored features split into two half-height columns so every row is tall
# enough to carry its numeric z on both dots. Blue = vs the healthy population,
# green = vs the meditators; the connecting bar shows how much of P1's elevation
# is "explained" by resembling a meditator. No baked-in title — the poster card
# supplies it (avoids a duplicate heading).
ENV["GKSwstype"]="100"
using CSV, DataFrames, Plots, Statistics
const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))
z=CSV.read(joinpath(ROOT,"docs/poster/zscores.csv"),DataFrame)
sort!(z,:z_healthy)                      # ascending; largest on top
n=nrow(z)
BLUE="#4063D8"; GREEN="#389826"
G1=RGB(0.90,0.90,0.92); G2=RGB(0.95,0.95,0.96)
default(fontfamily="sans-serif",grid=false,framestyle=:box)

# one half-column of dumbbells with numeric labels on each dot
function dumbcol(sub)
    m=nrow(sub); xlo,xhi=-2.7,3.1
    p=plot(xlims=(xlo,xhi),ylims=(0.4,m+0.6),yticks=(1:m,sub.label),legend=false,
        tickfontsize=15,xlabel="z-equivalent  (σ from the group's median)",guidefontsize=15,
        left_margin=26Plots.mm,right_margin=3Plots.mm,bottom_margin=8Plots.mm,top_margin=2Plots.mm)
    vspan!(p,[-2,-1];color=G2,label=""); vspan!(p,[1,2];color=G2,label=""); vspan!(p,[-1,1];color=G1,label="")
    for t in [-2,-1,1,2]; vline!(p,[t];color=:white,lw=1.6,label=""); end
    vline!(p,[0];color=RGB(0.5,0.5,0.55),lw=2,label="")
    for (i,r) in enumerate(eachrow(sub))
        plot!(p,[r.z_meditators,r.z_healthy],[i,i];color=RGB(0.6,0.6,0.65),lw=2.6,label="")
        scatter!(p,[r.z_healthy],[i];color=BLUE,ms=9,msw=1.2,msc=:white,label="")
        scatter!(p,[r.z_meditators],[i];color=GREEN,ms=9,msw=1.2,msc=:white,label="")
        dh=r.z_healthy>=r.z_meditators ? 1 : -1
        annotate!(p,r.z_healthy+0.15dh,i,text(string(round(r.z_healthy,digits=1)),10,BLUE,dh>0 ? :left : :right))
        annotate!(p,r.z_meditators-0.15dh,i,text(string(round(r.z_meditators,digits=1)),10,GREEN,dh>0 ? :right : :left))
    end
    p
end

# in-plot legend lives in the left column's empty top-left corner
h=ceil(Int,n/2)
pL=dumbcol(z[h+1:n,:])                    # higher-z half on the left
scatter!(pL,[-2.35],[nrow(z[h+1:n,:])+0.15];color=BLUE,ms=9,msw=1.2,msc=:white,label="")
annotate!(pL,-2.18,nrow(z[h+1:n,:])+0.15,text("vs healthy population",13,BLUE,:left))
scatter!(pL,[-2.35],[nrow(z[h+1:n,:])-0.45];color=GREEN,ms=9,msw=1.2,msc=:white,label="")
annotate!(pL,-2.18,nrow(z[h+1:n,:])-0.45,text("vs meditators",13,GREEN,:left))
pR=dumbcol(z[1:h,:])                      # lower-z half on the right
p=plot(pL,pR; layout=(1,2), size=(3350,1160),dpi=170)   # ~2.9:1 — full card width, short enough to keep the footer on page 1
savefig(p,joinpath(ROOT,"docs/poster/figs/zopt_2col.png"))
println("wrote zopt_2col.png (",n," features)")
