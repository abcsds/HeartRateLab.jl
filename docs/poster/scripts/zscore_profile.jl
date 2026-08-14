#!/usr/bin/env julia
# Participant P1 z-score PROFILE (the wired poster figure, figs/zopt_vlolli.png):
# all scored features across x (sorted by z vs healthy, descending L->R), z-equivalent
# on y; blue = vs healthy population, green = vs meditators. Wide-and-short — fills the card.
ENV["GKSwstype"]="100"
using CSV, DataFrames, Plots, Statistics
const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))
z=CSV.read(joinpath(ROOT,"docs/poster/zscores.csv"),DataFrame)
sort!(z,:z_healthy,rev=true)           # highest z on the left
n=nrow(z); x=1:n
BLUE="#4063D8"; GREEN="#389826"
G1=RGB(0.90,0.90,0.92); G2=RGB(0.95,0.95,0.96)
default(fontfamily="sans-serif",grid=false,framestyle=:box)

p=plot(size=(3320,1060),dpi=170,legend=false,xlims=(0.3,n+0.7),ylims=(-2.75,3.05),
    xticks=(x,z.label), xrotation=60, xtickfont=font(16,"Helvetica Bold"),    # bold (GKS base font), bigger feature names
    yticks=(-2:1:3, string.(-2:1:3)), ytickfont=font(17,"sans-serif"),       # visible y ticks
    ylabel="z-equivalent  (σ from the group's median)", guidefontsize=20,
    left_margin=22Plots.mm,right_margin=5Plots.mm,bottom_margin=32Plots.mm,top_margin=8Plots.mm)
# reference bands: ±1σ (darker), ±2σ (lighter)
hspan!(p,[-2,-1];color=G2,label=""); hspan!(p,[1,2];color=G2,label=""); hspan!(p,[-1,1];color=G1,label="")
for t in [-2,-1,1,2]; hline!(p,[t];color=:white,lw=1.6,label=""); end
hline!(p,[0];color=RGB(0.5,0.5,0.55),lw=2.2,label="")
# lollipops: line from meditator z to healthy z, a dot at each
for (i,r) in enumerate(eachrow(z))
    plot!(p,[i,i],[r.z_meditators,r.z_healthy];color=RGB(0.62,0.62,0.68),lw=2.6,label="")
    scatter!(p,[i],[r.z_healthy];color=BLUE,ms=13,msw=1.3,msc=:white,label="")
    scatter!(p,[i],[r.z_meditators];color=GREEN,ms=13,msw=1.3,msc=:white,label="")
end
# legend TOP-RIGHT (the right-hand features have low z, so the upper-right is empty)
scatter!(p,[n-0.4],[2.78];color=BLUE,ms=13,msw=1.3,msc=:white,label="")
annotate!(p,n-0.9,2.78,text("vs healthy population",17,BLUE,:right))
scatter!(p,[n-0.4],[2.30];color=GREEN,ms=13,msw=1.3,msc=:white,label="")
annotate!(p,n-0.9,2.30,text("vs meditators",17,GREEN,:right))
savefig(p,joinpath(ROOT,"docs/poster/figs/zopt_vlolli.png"))
println("wrote zopt_vlolli.png (",n," features)")
