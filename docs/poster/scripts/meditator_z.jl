#!/usr/bin/env julia
# Meditation cohort scored against the NORMAL (healthy) population, per feature.
# Same quantile method as the P1 scoring: z = Φ⁻¹(F_healthy_prior(median of the
# meditation-state windows)).  This is the REFERENCE-GROUP characterisation — how far
# the meditators (n=11, during-meditation) sit from the general population — NOT P1.
# Writes docs/poster/meditator_z.csv (feature,label,med_median,z_vs_normal), sorted desc.
ENV["GKSwstype"]="100"
using CSV, DataFrames, Distributions, Statistics
const ROOT=normpath(joinpath(@__DIR__, "..", "..", ".."))
pri=Dict(r.feature=>r for r in eachrow(CSV.read(joinpath(ROOT,"docs/normative_priors.csv"),DataFrame)))
LAB=Dict(String(r.feature)=>r.label for r in eachrow(CSV.read(joinpath(ROOT,"docs/poster/model_results.csv"),DataFrame)))
med=CSV.read(joinpath(ROOT,"test/testdata/meditation/windowed_w360_s120_features.csv"),DataFrame)
med=filter(r->endswith(String(r.participant_id),"med"),med)          # during-meditation, 11 practitioners
col(df,f)=filter(isfinite,Float64.(coalesce.(df[!,f],NaN)))
# restrict to exactly the features P1 was scored on (docs/poster/zscores.csv) so the
# meditator-vs-normal table lines up with the P1 table; excludes the broken vlf prior.
scored=Set(String.(CSV.read(joinpath(ROOT,"docs/poster/zscores.csv"),DataFrame).feature))

healthy_prior(f)=(r=pri[f]; r.family=="Normal" ? Normal(r.param1_value,r.param2_value) :
  r.family=="LogNormal" ? LogNormal(r.param1_value,r.param2_value) :
  r.family=="Gamma" ? Gamma(r.param1_value,r.param2_value) : Beta(r.param1_value,r.param2_value))
zof(prior,x)=quantile(Normal(),clamp(cdf(prior,x),1e-6,1-1e-6))
validfam(f)= haskey(pri,f) && !ismissing(pri[f].family) && String(pri[f].family) in ("Normal","LogNormal","Gamma","Beta")

rows=DataFrame(feature=String[],label=String[],med_median=Float64[],z_vs_normal=Float64[])
for f in names(med)
    (f in scored && validfam(f) && length(col(med,f))>=8) || continue
    try
        m=median(col(med,f)); z=zof(healthy_prior(f),m)
        isfinite(z) && push!(rows,(f,get(LAB,f,f),m,z))
    catch; end
end
sort!(rows,:z_vs_normal,rev=true)
CSV.write(joinpath(ROOT,"docs/poster/meditator_z.csv"),rows)
println("wrote meditator_z.csv  (",nrow(rows)," features)")
for r in eachrow(rows); println(rpad(r.label,16),lpad(string(round(r.z_vs_normal,digits=2)),7)); end
