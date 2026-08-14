#!/usr/bin/env julia
# Participant P1 z-scores vs TWO reference priors: healthy population and meditators.
# z_group = Φ⁻¹(F_group_prior(median of P1's windows)).  Same quantile method as the
# poster; healthy prior from the canonical CSV, meditator prior fit (same family) to the
# 263 during-meditation windows.
ENV["GKSwstype"]="100"
using CSV, DataFrames, Distributions, Statistics
const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))  # repo root
const CACHE=joinpath(@__DIR__, "pdf_all_cache.csv")

pri=Dict(r.feature=>r for r in eachrow(CSV.read(joinpath(ROOT,"docs/normative_priors.csv"),DataFrame)))
p1=CSV.read(CACHE,DataFrame)
med=CSV.read(joinpath(ROOT,"test/testdata/meditation/windowed_w360_s120_features.csv"),DataFrame)
med=filter(r->endswith(String(r.participant_id),"med"),med)
col(df,f)=filter(isfinite,Float64.(coalesce.(df[!,f],NaN)))

healthy_prior(f)=(r=pri[f]; r.family=="Normal" ? Normal(r.param1_value,r.param2_value) :
  r.family=="LogNormal" ? LogNormal(r.param1_value,r.param2_value) :
  r.family=="Gamma" ? Gamma(r.param1_value,r.param2_value) : Beta(r.param1_value,r.param2_value))

function fit_prior(fam,x)
    x=filter(v->isfinite(v),x)
    if fam=="Normal"; return Normal(mean(x),std(x))
    elseif fam=="LogNormal"; lx=log.(filter(>(0),x)); return LogNormal(mean(lx),std(lx))
    elseif fam=="Gamma"; try; return fit_mle(Gamma,x) catch; m=mean(x);v=var(x); return Gamma(m^2/v, v/m) end
    elseif fam=="Beta"; m=mean(x);v=var(x); c=m*(1-m)/v-1; return Beta(max(m*c,1e-3),max((1-m)*c,1e-3))
    end
end
zof(prior,x)=quantile(Normal(),clamp(cdf(prior,x),1e-6,1-1e-6))

# Score P1 on EVERY feature that has a fitted prior AND P1 data AND meditation data —
# no hand-picked list (that would be the cherry-picking this project opposes).
LAB=Dict(String(r.feature)=>r.label for r in eachrow(CSV.read(joinpath(ROOT,"docs/poster/model_results.csv"),DataFrame)))
validfam(f)= haskey(pri,f) && !ismissing(pri[f].family) && String(pri[f].family) in ("Normal","LogNormal","Gamma","Beta")
good = String[f for f in names(p1) if validfam(f) && (f in names(med)) &&
              length(col(p1,f))>0 && length(col(med,f))>=8]
rows=DataFrame(feature=String[],label=String[],p1_median=Float64[],z_healthy=Float64[],z_meditators=Float64[])
println(rpad("feature",16),rpad("P1 median",12),rpad("z|healthy",11),"z|meditators")
skipped=String[]
for f in good
    try
        p1med=median(col(p1,f))
        zh=zof(healthy_prior(f), p1med)
        mp=fit_prior(String(pri[f].family), col(med,f))
        (mp===nothing || any(!isfinite,params(mp))) && error("meditator prior undefined")
        zm=zof(mp, p1med)
        (isfinite(zh) && isfinite(zm)) || error("non-finite z")
        push!(rows,(f,get(LAB,f,f),p1med,zh,zm))
    catch e
        push!(skipped,f)
    end
end
isempty(skipped) || println("skipped (prior undefined on meditator data): ",join(skipped,", "))
sort!(rows,:z_healthy,rev=true)
for r in eachrow(rows)
    println(rpad(r.label,16),rpad(string(round(r.p1_median,digits=3)),12),
            rpad(string(round(r.z_healthy,digits=2)),11),round(r.z_meditators,digits=2))
end
CSV.write(joinpath(ROOT,"docs/poster/zscores.csv"),rows)
println("\nwrote docs/poster/zscores.csv  (",nrow(rows)," features scored)")
