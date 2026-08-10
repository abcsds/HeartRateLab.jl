# Phase-0 FULL STUDY: argued RR-forecasting model-selection.
# Runs in-container against --project=. (uses Optim; no new deps, no image rebuild).
# Dependency-free model implementations; every model emits Monte-Carlo predictive
# samples so CRPS / PICP / MPIW are computed uniformly. Per-subject output enables
# subject-level bootstrap ranking downstream.
#
# Usage (in container):
#   julia --project=. test/tools/forecasting/study.jl [--quick]
# --quick = 2 subjects, small grid (smoke test before the full background run).

using HeartRateLab
using Statistics, LinearAlgebra, Random
import Optim

const QUICK = "--quick" in ARGS

const H       = 10      # forecast horizon (beats)
const NSAMP   = 300     # Monte-Carlo predictive paths
const SEGLEN  = 500     # controlled segment length (beats)
const NSEG    = QUICK ? 2 : 3       # segments per subject
const ORIGIN0 = 150     # first forecast origin within a segment
const OSTRIDE = 80      # stride between forecast origins
const WFIT    = 250     # cap the fit window to the most recent WFIT beats (live-realistic + bounds GP)
const PMAX    = QUICK ? 4 : 12
const OUTDIR  = "test/tools/forecasting/out"
const GP_ORIGIN_STRIDE = 2   # GP is O(W^3): evaluate on every k-th origin, report coverage

Random.seed!(20260708)
mkpath(OUTDIR)

# ------------------------------------------------------------------ datasets
const DATASETS = QUICK ?
    [("nsrdb", "atr", ["16265", "16272"])] :
    [("nsrdb", "atr", ["16265","16272","16273","16420","16483","16539","16773","16786",
                       "16795","17052","17453","18177","18184","19088","19090","19093","19140","19830"]),
     ("nsr2db","ecg", ["nsr" * lpad(i,3,'0') for i in 1:54])]

dl_dir(ds) = "test/testdata/$ds/_downloads"

function load_rr(ds, ann, subj)
    rr = read_wfdb(joinpath(dl_dir(ds), subj), ann)
    rr = replace_zeros(rr); rr = replace_bio_outliers(rr); rr = interpolate_nans(rr)
    return Float64.(rr)
end

function segments(rr)
    n = length(rr)
    n < SEGLEN && return Vector{Vector{Float64}}()
    starts = unique(round.(Int, range(1, n - SEGLEN + 1; length = NSEG)))
    return [rr[s:s+SEGLEN-1] for s in starts]
end

fitwin(hist) = length(hist) > WFIT ? @view(hist[end-WFIT+1:end]) : hist

# ================================================================== models
# ---- AR(p) via Yule-Walker ----------------------------------------------
function fit_ar(x, p)
    n = length(x); n <= p + 5 && return nothing
    mu = mean(x); xc = x .- mu
    r = [sum(@view(xc[1:n-k]) .* @view(xc[1+k:n]))/n for k in 0:p]
    r[1] <= 0 && return nothing
    p == 0 && return (Float64[], mu, sqrt(r[1]))
    R = [r[abs(i-j)+1] for i in 1:p, j in 1:p]
    phi = try; R \ r[2:p+1]; catch; return nothing; end
    s2 = r[1] - sum(phi .* r[2:p+1]); s2 <= 0 && (s2 = r[1]*1e-3)
    return (phi, mu, sqrt(s2))
end

function ar_sim(last_vals, phi, mu, sigma)
    p = length(phi); S = Matrix{Float64}(undef, NSAMP, H)
    for s in 1:NSAMP
        buf = collect(last_vals)
        for h in 1:H
            pred = mu; @inbounds for j in 1:p; pred += phi[j]*(buf[end-j+1]-mu); end
            pred += sigma*randn(); S[s,h] = pred
            push!(buf, pred); popfirst!(buf)
        end
    end
    return S
end

# ---- ARMA(p,q) via Hannan-Rissanen ---------------------------------------
function fit_arma_hr(x, p, q)
    n = length(x); n <= p + q + 20 && return nothing
    mu = mean(x); y = x .- mu
    m = min(max(2p, 2q, 8), n ÷ 3)                 # long AR order for stage 1
    ar1 = fit_ar(x, m); ar1 === nothing && return nothing
    phi1, _, _ = ar1
    eps = zeros(n)                                  # in-sample residuals
    for t in (m+1):n
        pred = 0.0; @inbounds for j in 1:m; pred += phi1[j]*y[t-j]; end
        eps[t] = y[t] - pred
    end
    start = m + 1
    rows = (start+max(p,q)):n
    isempty(rows) && return nothing
    X = Matrix{Float64}(undef, length(rows), p + q)
    Y = Vector{Float64}(undef, length(rows))
    for (i,t) in enumerate(rows)
        for j in 1:p; X[i,j]      = y[t-j];   end
        for j in 1:q; X[i,p+j]    = eps[t-j]; end
        Y[i] = y[t]
    end
    coef = try; X \ Y; catch; return nothing; end
    phi = coef[1:p]; theta = coef[p+1:p+q]
    resid = Y .- X*coef; sigma = std(resid)
    return (phi, theta, mu, sigma, y[end-p+1:end], eps[end-q+1:end])
end

function arma_sim(fit)
    phi, theta, mu, sigma, ylast, epslast = fit
    p = length(phi); q = length(theta)
    S = Matrix{Float64}(undef, NSAMP, H)
    for s in 1:NSAMP
        yb = collect(ylast); eb = collect(epslast)
        for h in 1:H
            e = sigma*randn()
            pred = 0.0
            @inbounds for j in 1:p; pred += phi[j]*yb[end-j+1]; end
            @inbounds for j in 1:q; pred += theta[j]*eb[end-j+1]; end
            pred += e
            S[s,h] = pred + mu
            push!(yb, pred); popfirst!(yb)
            push!(eb, e);    popfirst!(eb)
        end
    end
    return S
end

# ---- ARIMA(p,1,0): AR(p) on first differences, integrated back -----------
function ari_sim(hist, p)
    d = diff(hist); f = fit_ar(d, p); f === nothing && return nothing
    phi, mu, sigma = f
    Sd = ar_sim(d[end-p+1:end], phi, mu, sigma)     # sampled differences
    S = similar(Sd)
    for s in 1:NSAMP
        acc = hist[end]
        for h in 1:H; acc += Sd[s,h]; S[s,h] = acc; end
    end
    return S
end

# ---- ETS: Holt linear / damped trend, residual-bootstrap predictive ------
function ets_fit(x; damped=false)
    # coarse grid over smoothing params; returns level, trend, phi, residuals
    best = nothing; bestsse = Inf
    phis = damped ? (0.8:0.05:0.98) : (1.0,)
    for α in 0.1:0.2:0.9, β in 0.05:0.2:0.65, ϕ in phis
        l = x[1]; b = x[2]-x[1]; sse = 0.0; res = Float64[]
        for t in 2:length(x)
            f = l + ϕ*b
            e = x[t] - f; sse += e^2; push!(res, e)
            l = f + α*e; b = ϕ*b + β*e
        end
        if sse < bestsse; bestsse = sse; best = (l, b, ϕ, res); end
    end
    return best
end

function ets_sim(hist; damped=false)
    length(hist) < 10 && return nothing
    f = ets_fit(hist; damped=damped); f === nothing && return nothing
    l0, b0, ϕ, res = f
    isempty(res) && return nothing
    S = Matrix{Float64}(undef, NSAMP, H)
    for s in 1:NSAMP
        l = l0; b = b0
        for h in 1:H
            fpred = l + ϕ*b
            e = rand(res)                # bootstrap innovation
            yv = fpred + e
            S[s,h] = yv
            l = fpred + 0.3*e; b = ϕ*b   # propagate level with a mild update
        end
    end
    return S
end

# ---- Gaussian Process, quasi-periodic kernel -----------------------------
function estimate_period(y)
    n = length(y); n < 20 && return 8.0
    yc = y .- mean(y)
    ac = [sum(@view(yc[1:n-k]).*@view(yc[1+k:n])) for k in 0:min(40,n-1)]
    ac ./= ac[1]
    # first local max after the first zero crossing
    zc = findfirst(k -> ac[k] < 0, 2:length(ac))
    zc === nothing && return 8.0
    rng = (zc+1):length(ac)
    isempty(rng) && return 8.0
    pk = argmax(@view ac[rng]) + first(rng) - 1
    return clamp(Float64(pk-1), 3.0, 30.0)
end

function gp_qp_sim(hist)
    W = min(length(hist), 180)
    y = collect(hist[end-W+1:end]); x = collect(1.0:W)
    my = mean(y); yc = y .- my
    period = estimate_period(y)
    D = [abs(x[i]-x[j]) for i in 1:W, j in 1:W]
    function nll(θ)
        sf, lp, lse, sn = exp.(θ)
        K = @. sf^2 * exp(-2*sin(pi*D/period)^2/lp^2) * exp(-D^2/(2*lse^2))
        K[diagind(K)] .+= sn^2 + 1e-6
        C = cholesky(Symmetric(K); check=false)
        issuccess(C) || return 1e8
        α = C \ yc
        return 0.5*dot(yc,α) + sum(log.(diag(C.L))) + 0.5*W*log(2pi)
    end
    θ0 = log.([std(yc)+1e-3, 1.0, period, std(yc)/3 + 1e-3])
    res = try
        Optim.optimize(nll, θ0, Optim.NelderMead(), Optim.Options(iterations=60))
    catch; return nothing; end
    sf, lp, lse, sn = exp.(Optim.minimizer(res))
    K = @. sf^2 * exp(-2*sin(pi*D/period)^2/lp^2) * exp(-D^2/(2*lse^2))
    K[diagind(K)] .+= sn^2 + 1e-6
    C = cholesky(Symmetric(K); check=false); issuccess(C) || return nothing
    α = C \ yc
    xs = collect(W+1.0:W+H)
    Ks = [sf^2*exp(-2*sin(pi*abs(xs[a]-x[b])/period)^2/lp^2)*exp(-abs(xs[a]-x[b])^2/(2*lse^2))
          for a in 1:H, b in 1:W]
    mu = Ks*α .+ my
    v = Vector{Float64}(undef, H)
    for a in 1:H
        kss = sf^2 + sn^2
        sol = C \ (@view Ks[a,:])
        v[a] = max(kss - dot(@view(Ks[a,:]), sol), 1e-6)
    end
    S = Matrix{Float64}(undef, NSAMP, H)
    for s in 1:NSAMP, h in 1:H; S[s,h] = mu[h] + sqrt(v[h])*randn(); end
    return S
end

# ------------------------------------------------------------------ registry
struct M; name::String; f::Function; every::Int; end
function build_models()
    ms = M[]
    push!(ms, M("persistence", h->(d=diff(h); s=std(d); [h[end]+s*sqrt(k)*randn() for _ in 1:NSAMP, k in 1:H]), 1))
    push!(ms, M("mean",        h->(mean(h) .+ std(h).*randn(NSAMP,H)), 1))
    push!(ms, M("rw_drift",    h->(d=diff(h); dr=mean(d); s=std(d); [h[end]+dr*k+s*sqrt(k)*randn() for _ in 1:NSAMP, k in 1:H]), 1))
    for p in 1:PMAX
        push!(ms, M("ar_raw_$p", h->(f=fit_ar(fitwin(h),p); f===nothing ? nothing : ar_sim(fitwin(h)[end-p+1:end], f...)), 1))
        push!(ms, M("ar_log_$p", h->(lh=log.(fitwin(h)); f=fit_ar(lh,p); f===nothing ? nothing : exp.(ar_sim(lh[end-p+1:end], f...))), 1))
    end
    for p in 1:(QUICK ? 2 : 6)
        push!(ms, M("ari_$(p)_1", h->ari_sim(fitwin(h), p), 1))
    end
    for p in (1,2,3), q in (1,2)
        push!(ms, M("arma_$(p)_$(q)", h->(f=fit_arma_hr(fitwin(h),p,q); f===nothing ? nothing : arma_sim(f)), 1))
    end
    push!(ms, M("ets_holt",   h->ets_sim(fitwin(h); damped=false), 1))
    push!(ms, M("ets_damped", h->ets_sim(fitwin(h); damped=true), 1))
    push!(ms, M("gp_qp",      h->gp_qp_sim(h), GP_ORIGIN_STRIDE))
    return ms
end

# ------------------------------------------------------------------ metrics
function crps(samples, y)
    n = length(samples); t1 = sum(abs.(samples .- y))/n
    ss = sort(samples); s = 0.0
    @inbounds for i in 1:n; s += (2i-n-1)*ss[i]; end
    return t1 - 0.5*(2s/(n^2))
end
qs(sorted,q) = (n=length(sorted); idx=clamp(q*(n-1)+1,1,n); lo=floor(Int,idx); hi=ceil(Int,idx); f=idx-lo; sorted[lo]*(1-f)+sorted[hi]*f)

# ------------------------------------------------------------------ driver
acc = Dict{Tuple{String,Int,String}, Vector{Float64}}()   # ->[sse,sae,crps,cov90,cov50,w90,n]
fails = Dict{String,Int}()
bump!(k,i,v) = (a=get!(acc,k,zeros(7)); a[i]+=v)

const MODELS = build_models()
println("models = ", length(MODELS), "  quick=", QUICK); flush(stdout)

for (ds, ann, subjs) in DATASETS, subj in subjs
    rr = try; load_rr(ds, ann, subj); catch e; println("  SKIP $ds/$subj ($e)"); continue; end
    sid = "$ds:$subj"
    segs = segments(rr)
    origin_i = 0
    for seg in segs
        L = length(seg)
        for origin in ORIGIN0:OSTRIDE:(L-H)
            origin_i += 1
            hist = seg[1:origin]; actual = @view seg[origin+1:origin+H]
            for m in MODELS
                (origin_i % m.every != 0) && continue
                S = try; m.f(hist); catch; nothing; end
                if S === nothing; fails[m.name] = get(fails,m.name,0)+1; continue; end
                for h in 1:H
                    col = collect(@view S[:,h]); y = actual[h]; pt = mean(col); sc = sort(col)
                    k = (m.name, h, sid)
                    bump!(k,1,(pt-y)^2); bump!(k,2,abs(pt-y)); bump!(k,3,crps(col,y))
                    bump!(k,4, (qs(sc,0.05)<=y<=qs(sc,0.95)) ? 1.0 : 0.0)
                    bump!(k,5, (qs(sc,0.25)<=y<=qs(sc,0.75)) ? 1.0 : 0.0)
                    bump!(k,6, qs(sc,0.95)-qs(sc,0.05)); bump!(k,7,1.0)
                end
            end
        end
    end
    println("done $sid  (segments=$(length(segs)))"); flush(stdout)
end

# ------------------------------------------------------------------ write
out = joinpath(OUTDIR, QUICK ? "results_quick.csv" : "results_full.csv")
open(out,"w") do io
    println(io,"model,horizon,subject,rmse,mae,crps,picp90,picp50,mpiw90,n")
    for (k,a) in sort(collect(acc); by=x->(x[1][1],x[1][2],x[1][3]))
        m,h,sid=k; n=a[7]
        println(io,"$m,$h,$sid,$(sqrt(a[1]/n)),$(a[2]/n),$(a[3]/n),$(a[4]/n),$(a[5]/n),$(a[6]/n),$(Int(n))")
    end
end
println("\nwrote $out  ($(length(acc)) rows)")
!isempty(fails) && println("fit failures (numeric-guard, counted): ", fails)

# console ranking
agg = Dict{String,Vector{Float64}}()
for (k,a) in acc; push!(get!(agg,k[1],Float64[]), a[3]/a[7]); end
println("\n--- ranking by mean CRPS ---")
for (m,v) in sort(collect(agg); by=x->mean(x[2]))
    println(rpad(m,14),"  CRPS=",round(mean(v),digits=2))
end
