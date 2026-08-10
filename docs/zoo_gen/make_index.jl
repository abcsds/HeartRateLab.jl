#!/usr/bin/env julia
# ─────────────────────────────────────────────────────────────────────────────
# make_index.jl — build the HRV "variable zoo" landing page (docs/src/zoo/index.md).
#
# Reads the merged inventory (docstring metadata + fitted priors) and the measured
# resource ranks, and emits one table per domain (time / frequency / geometric /
# nonlinear) with a link to each dex entry, its declared distribution family, and
# its measured resource tier. Reproducible: re-run after make_entry.jl.
#
#     julia --project=. docs/zoo_gen/make_index.jl
# ─────────────────────────────────────────────────────────────────────────────

const HERE    = @__DIR__
const REPO    = normpath(joinpath(HERE, "..", ".."))
const ZOO_DIR = joinpath(REPO, "docs", "src", "zoo")

include(joinpath(HERE, "inventory.jl"))    # -> INVENTORY

const RESOURCE_RANK_FILE = joinpath(HERE, "resource_rank.jl")
if isfile(RESOURCE_RANK_FILE)
    include(RESOURCE_RANK_FILE)            # -> RESOURCE_RANK_BY_FEATURE
else
    const RESOURCE_RANK_BY_FEATURE = Dict{String,NamedTuple}()
end

const DOMAIN_FALLBACK = Dict(
    "time" => "◍◍◌◌◌  low", "frequency" => "◍◍◍◌◌  moderate",
    "geometric" => "◍◍◌◌◌  low", "nonlinear" => "◍◍◍◍◌  high",
)
rank_for(e) = haskey(RESOURCE_RANK_BY_FEATURE, e.name) ?
    RESOURCE_RANK_BY_FEATURE[e.name].rank : get(DOMAIN_FALLBACK, e.primary_domain, "◍◍◌◌◌  low")

# `hurst` declares `Beta` in its Features.jl docstring (theoretically bounded to
# (0,1)) but its empirical 360-beat-window fit leaves that interval, so the
# empirically-fitted family (`Normal`) is shown here instead, flagged with a
# footnote — see docs/zoo_gen/make_entry.jl's FAMILY_RECONCILE_NOTE and the
# hurst dex page itself for the one-line reconciliation.
const DIST_FAMILY_DISPLAY_OVERRIDE = Dict("hurst" => "Normal*")
family_for(e) = get(DIST_FAMILY_DISPLAY_OVERRIDE, e.name, e.family)

const DOMAINS = [
    ("time",      "Time domain",      "Statistics of the NN/RR intervals and their successive differences — the classic, cheapest, most-reported HRV panel."),
    ("frequency", "Frequency domain", "Power in the ULF/VLF/LF/HF bands of the RR power spectrum — Welch periodogram on the resampled series by default (`config[\"freq_method\"] == :welch`), with Lomb–Scargle on the raw unevenly-sampled series available as an alternative — plus band ratios and peak frequencies."),
    ("geometric", "Geometric",        "Shape descriptors of the Poincaré / Lorenz return map and the RR histogram — robust to occasional artifacts."),
    ("nonlinear", "Nonlinear",        "Entropy, complexity and fractal-scaling measures probing the nonlinear structure of cardiac control (need adequate record length)."),
]

io = IOBuffer()
println(io, "# The HRV Variable Zoo")
println(io)
println(io, "A browsable **\"Pokédex\"** of every heart-rate-variability feature HeartRateLab")
println(io, "computes: **53 registered measures** across four domains. Each entry answers the")
println(io, "same three questions:")
println(io)
println(io, "1. **What is it?** — definition, equation, aliases, and declared distribution family.")
println(io, "2. **What does *normal* look like?** — the empirical distribution over the pooled")
println(io, "   [nsrdb](https://physionet.org/content/nsrdb/) + [nsr2db](https://physionet.org/content/nsr2db/)")
println(io, "   normal-sinus-rhythm cohorts (360-beat windows, n up to 56 472), overlaid with a")
println(io, "   fitted normative prior, plus a normal-range table.")
println(io, "3. **What does it cost, and who introduced it?** — a *measured* wall-clock + allocation")
println(io, "   resource tier, curated use-cases, and the seminal citation.")
println(io)
println(io, "Priors and normal-range statistics are descriptive references from a healthy cohort,")
println(io, "**not** clinical thresholds. See the [References](references.md) page for the full")
println(io, "bibliography. Resource tiers are measured on synthetic realistic RR at a 360-beat")
println(io, "window (`docs/zoo_gen/bench_resources.jl`).")
println(io)
println(io, "**Resource tiers:** `◍◌◌◌◌` very low · `◍◍◌◌◌` low · `◍◍◍◌◌` moderate · `◍◍◍◍◌` high · `◍◍◍◍◍` very high.")
println(io)

for (dom, title, blurb) in DOMAINS
    feats = filter(e -> e.primary_domain == dom, INVENTORY)
    println(io, "## $title ($(length(feats)))")
    println(io)
    println(io, blurb)
    println(io)
    println(io, "| Feature | Definition | Dist. family | Resource tier |")
    println(io, "|---------|------------|--------------|---------------|")
    for e in feats
        defn = rstrip(e.definition)
        endswith(defn, ".") && (defn = defn[1:end-1])
        length(defn) > 70 && (defn = defn[1:67] * "…")
        println(io, "| [`$(e.name)`]($(e.name).md) | $defn | `$(family_for(e))` | $(rank_for(e)) |")
    end
    println(io)
    if dom == "nonlinear"
        println(io, "\\* `hurst` declares `Beta` (theoretically bounded to (0,1)); the table shows",
                    " the empirically-fitted `Normal` family instead, since observed values leave",
                    " that interval — see [`hurst`](hurst.md#What-does-*normal*-look-like?).")
        println(io)
    end
end

println(io, "## All entries")
println(io)
println(io, "The reference dex entry is [`rmssd`](rmssd.md). Full per-feature detail — figure,")
println(io, "normal-range table, resource benchmark, and citation — lives on each entry page")
println(io, "linked above.")

open(joinpath(ZOO_DIR, "index.md"), "w") do f
    write(f, String(take!(io)))
end
println("wrote ", joinpath(ZOO_DIR, "index.md"), " (", length(INVENTORY), " features)")
