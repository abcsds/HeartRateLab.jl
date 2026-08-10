# Empirical comparison of DMD variants on RR-interval data.
# Writes a results table to docs/dmd_experiments/results.txt and a JSON-ish dump.

using Random
using Statistics
using LinearAlgebra
using HeartRateLab
const M = HeartRateLab.Models
const E = HeartRateLab.Evaluation

include("dmd_variants.jl")
using .DMDVariants

Random.seed!(20260617)

# ── metrics ──────────────────────────────────────────────────────────────────
rmse(a, b) = sqrt(mean((a .- b) .^ 2))
nrmse(a, b) = rmse(a, b) / std(a)            # normalized by data std

"""Welch-free periodogram power in HRV bands via simple FFT on uniformly-indexed
(beat-indexed) series. We compare band-power *fractions* of recon vs data — a
sampling-rate-free fidelity proxy for the spectral shape."""
function band_fractions(x::AbstractVector)
    n = length(x)
    xc = x .- mean(x)
    X = abs2.(rfft_safe(xc))
    # frequency in cycles/beat: k/n for k=0..n/2
    freqs = (0:length(X)-1) ./ n
    total = sum(X[2:end])                     # drop DC
    total == 0 && return (lf=0.0, hf=0.0, ratio=NaN)
    # crude LF/HF split in cycles-per-beat: LF < 0.15, HF 0.15-0.5
    lf = sum(X[f] for f in 2:length(X) if freqs[f] < 0.15; init=0.0)
    hf = sum(X[f] for f in 2:length(X) if 0.15 <= freqs[f] <= 0.5; init=0.0)
    return (lf=lf / total, hf=hf / total, ratio=(hf == 0 ? NaN : lf / hf))
end

function rfft_safe(x)
    # minimal real FFT via FFTW through DSP if available; else use Base via
    # AbstractFFTs which DifferentialEquations pulls in. Fall back to a DFT.
    try
        return _rfft(x)
    catch
        n = length(x)
        nf = n ÷ 2 + 1
        out = Vector{ComplexF64}(undef, nf)
        for k in 0:nf-1
            s = 0.0 + 0.0im
            @inbounds for t in 0:n-1
                s += x[t+1] * cis(-2π * k * t / n)
            end
            out[k+1] = s
        end
        return out
    end
end
_rfft(x) = error("no fast path")  # force DFT fallback for determinism/portability

# ── load data ────────────────────────────────────────────────────────────────
data = HeartRateLab.read_txt("test/testdata/example.txt")
n = length(data)
dmean, dstd = mean(data), std(data)
dbands = band_fractions(data)

io = open("docs/dmd_experiments/results.txt", "w")
println(io, "RR-interval DMD variant comparison")
println(io, "data: example.txt  n=$n  mean=$(round(dmean,digits=2)) ms  std=$(round(dstd,digits=2)) ms")
println(io, "data band fractions: LF=$(round(dbands.lf,digits=3)) HF=$(round(dbands.hf,digits=3)) LF/HF=$(round(dbands.ratio,digits=3))")
println(io, "="^110)

# (name, model constructor) — existing weak DMD + 3 variants
models = [
    ("ExistingDMD (rank=5)", M.DMD(rank=5)),
    ("CenteredDMD d=50 e=.99 rmax=20", DMDVariants.CenteredDMD(d=50, energy=0.99, rmax=20)),
    ("UnitCircleDMD d=50 e=.99 rmax=20", DMDVariants.StabilizedDMD(d=50, energy=0.99, rmax=20)),
    ("UnitCircleDMD d=100 e=.99 rmax=40", DMDVariants.StabilizedDMD(d=100, energy=0.99, rmax=40)),
    ("HAVOK d=100 r=11", DMDVariants.HAVOKModel(d=100, r=11)),
    ("HAVOK d=200 r=25", DMDVariants.HAVOKModel(d=200, r=25)),
]

hdr = rpad("variant", 36) * rpad("recon_nrmse", 13) * rpad("sim_mean", 11) *
      rpad("sim_std", 10) * rpad("LF", 8) * rpad("HF", 8) * rpad("loglik", 14) *
      rpad("BIC", 14) * "k"
println(io, hdr)
println(io, "-"^110)

results = M.ModelFitResult[]
rows = []

for (name, model) in models
    local res, recon, sim
    try
        res = M.fit(model, data)
    catch err
        println(io, rpad(name, 36) * "FIT ERROR: $err")
        continue
    end
    # in-sample reconstruction of the same length as data, from t=1
    recon = M.simulate(res.model, nothing, n)
    rec_nrmse = nrmse(data, recon)
    smean = mean(recon); sstd = std(recon)
    rb = band_fractions(recon)
    # information criteria (uses model_loglikelihood w/ default n_sim_beats=500)
    ic = E.information_criteria(res; n_sim_beats=min(500, n))
    push!(results, res)
    push!(rows, (name=name, nrmse=rec_nrmse, smean=smean, sstd=sstd,
                 lf=rb.lf, hf=rb.hf, loglik=ic.loglik, bic=ic.bic, k=ic.n_params))
    println(io, rpad(name, 36) *
        rpad(string(round(rec_nrmse, digits=4)), 13) *
        rpad(string(round(smean, digits=1)), 11) *
        rpad(string(round(sstd, digits=2)), 10) *
        rpad(string(round(rb.lf, digits=3)), 8) *
        rpad(string(round(rb.hf, digits=3)), 8) *
        rpad(string(round(ic.loglik, digits=1)), 14) *
        rpad(string(round(ic.bic, digits=1)), 14) *
        string(ic.n_params))
    flush(io)
end

println(io, "="^110)

# rank_models via Evaluation (BIC) — note each carries its own .data (same here)
ranked = E.rank_models(results; criterion=:bic, n_sim_beats=min(500, n))
println(io, "\nrank_models (BIC) via Evaluation:")
println(io, ranked)

# Also: how well does in-sample reconstruction track the data over the first 300 beats?
println(io, "\nIn-sample recon NRMSE (first 300 beats), data-tracking fidelity:")
for r in rows
    println(io, "  ", rpad(r.name, 36), " nrmse=", round(r.nrmse, digits=4))
end

# ── Forecasting evaluation (the regime where DMD genuinely excels for RR) ──────
# Train the centered Hankel-DMD operator on the first 70% of beats, then do
# h-step-ahead closed-loop forecasting on the held-out 30%, reporting NRMSE vs a
# persistence baseline (predict last value) and a mean baseline.
println(io, "\n", "="^110)
println(io, "FORECASTING (out-of-sample, train=70% / test=30%): closed-loop h-step NRMSE")
ntr = round(Int, 0.7n)
train = data[1:ntr]; test = data[ntr+1:end]
μtr = mean(train); σall = std(data)
xtr = train .- μtr
d = 50
H = DMDVariants.hankel(xtr, d); X1 = H[:,1:end-1]; X2 = H[:,2:end]
U,S,V = svd(X1); r = 20
Ur=U[:,1:r]; Sr=Diagonal(S[1:r]); Vr=V[:,1:r]
Atil = Ur'*X2*Vr/Sr                    # reduced operator
# Full-state operator action via lift/project: state z_red, advance, lift first coord.
function forecast_nrmse(h)
    # walk through test set; at each anchor, seed reduced state from last d true
    # (centered) beats, roll forward h steps, compare h-th prediction to truth.
    preds = Float64[]; truth = Float64[]
    full = data .- μtr
    for t0 in ntr:(length(data)-h)
        t0 - d + 1 < 1 && continue
        seed = full[t0-d+1:t0]          # length d centered window
        z = Ur' * seed                  # reduced coords
        for _ in 1:h
            z = Atil * z
        end
        lift = Ur * z
        push!(preds, real(lift[end]) + μtr)   # predicted beat at t0+h (last Hankel coord)
        push!(truth, data[t0+h])
    end
    nr = sqrt(mean((truth .- preds).^2)) / σall
    # baselines
    pers = [data[t0] for t0 in ntr:(length(data)-h) if t0-d+1>=1]
    np = sqrt(mean((truth .- pers).^2)) / σall
    nm = sqrt(mean((truth .- mean(data)).^2)) / σall
    return (dmd=nr, persistence=np, meanbase=nm)
end
for h in (1, 2, 5, 10)
    f = forecast_nrmse(h)
    println(io, "  h=$h  DMD NRMSE=$(round(f.dmd,digits=4))   persistence=$(round(f.persistence,digits=4))   mean-baseline=$(round(f.meanbase,digits=4))")
end

close(io)

# dump rows for plotting
open("docs/dmd_experiments/rows.csv", "w") do f
    println(f, "name,nrmse,sim_mean,sim_std,lf,hf,loglik,bic,k")
    for r in rows
        println(f, join((r.name, r.nrmse, r.smean, r.sstd, r.lf, r.hf, r.loglik, r.bic, r.k), ","))
    end
end

# dump first 600 beats of data + each recon for the figure
open("docs/dmd_experiments/traces.csv", "w") do f
    hdr = ["data"]
    traces = Dict{String,Vector{Float64}}()
    for (name, model) in models
        try
            res = M.fit(model, data)
            traces[name] = M.simulate(res.model, nothing, 600)
            push!(hdr, name)
        catch
        end
    end
    println(f, join(hdr, "|"))
    for t in 1:600
        vals = [string(data[t])]
        for name in hdr[2:end]
            push!(vals, string(round(traces[name][t], digits=3)))
        end
        println(f, join(vals, "|"))
    end
end

println("DONE")
