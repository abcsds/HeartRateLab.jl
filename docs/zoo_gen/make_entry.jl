#!/usr/bin/env julia
# ─────────────────────────────────────────────────────────────────────────────
# make_entry.jl — HRV feature "Pokédex" dex-entry generator (PILOT)
#
# For a given feature name it:
#   1. loads the merged inventory (docstring metadata + fitted normative prior),
#   2. reads the empirical distribution of that feature over the NSR2DB normative
#      windows (test/testdata/nsr2db/windowed_w360_s120_features.csv),
#   3. renders a headless PNG ("what does normal look like": empirical histogram
#      overlaid with the fitted prior density + median/IQR markers),
#   4. writes a Documenter-markdown dex entry (docs/src/zoo/<name>.md).
#
# Headless & dependency-light: uses Plots+GR with GKSwstype=100 (NO GLMakie), reads
# only CSVs (no WFDB, no display). Run under the package project:
#
#     ENV["GKSwstype"]="100"
#     julia --project=. docs/zoo_gen/make_entry.jl rmssd
#     julia --project=. docs/zoo_gen/make_entry.jl            # -> all plottable features
#
# NB: since the full 53-feature re-extraction (commit 472c970) every feature has
# a fitted prior + a column in the pooled windowed tables; `ulf` alone falls back
# to the long-window extended extraction (no ULF-band power in 360-beat windows).
# ─────────────────────────────────────────────────────────────────────────────

ENV["GKSwstype"] = get(ENV, "GKSwstype", "100")  # headless GR — no window server

using CSV, DataFrames, StatsBase, Distributions, Printf
import Plots

const HERE      = @__DIR__
const REPO      = normpath(joinpath(HERE, "..", ".."))
const ZOO_DIR   = joinpath(REPO, "docs", "src", "zoo")
const FIG_DIR   = joinpath(ZOO_DIR, "figs")
const NSR2DB    = joinpath(REPO, "test", "testdata", "nsr2db", "windowed_w360_s120_features.csv")
# The fitted priors for the 36 "pooled" (non-extended) features are fit on BOTH
# normal-sinus-rhythm cohorts pooled together (n=61 715: 47 890 nsr2db + 13 825
# nsrdb windows, docs/src/usecases/normative.md). The empirical histogram/summary
# shown on each dex page must match that same population, not nsr2db alone
# (~42 647) — see docs/zoo_gen/gen_inventory.py / docs/normative_priors.csv.
const NSRDB_W360 = joinpath(REPO, "test", "testdata", "nsrdb", "windowed_w360_s120_features.csv")
function load_pooled_df()
    a = CSV.read(NSR2DB, DataFrame)
    b = CSV.read(NSRDB_W360, DataFrame)
    vcat(a, b; cols=:union)
end
# Extended normative data (test/tools/collect_extended_features.jl). Since the
# full 53-feature re-extraction this is only the *fallback* for features whose
# pooled fit is not ok — in practice `ulf` (long-window NSRDB-only extraction).
const EXTENDED     = joinpath(REPO, "test", "testdata", "nsr2db", "windowed_w360_s120_features_extended.csv")
const EXT_PRIORS_F = joinpath(REPO, "docs", "normative_priors_extended.csv")
# Optional cross-dataset comparison (healthy vs. other cohorts)
const XDATASETS = Dict(
    "nsr2db"       => NSR2DB,
    "nsrdb"        => joinpath(REPO, "test", "testdata", "nsrdb",        "windowed_w360_s120_features.csv"),
    "mitbih"       => joinpath(REPO, "test", "testdata", "mitbih",       "windowed_w360_s120_features.csv"),
    "challenge2002"=> joinpath(REPO, "test", "testdata", "challenge2002","windowed_w360_s120_features.csv"),
)

include(joinpath(HERE, "inventory.jl"))     # -> INVENTORY, INVENTORY_BY_NAME
include(joinpath(HERE, "citations.jl"))     # -> CITATION_KEYS, CITATION_BLURB, USE_CASES
include(joinpath(HERE, "applications.jl"))  # -> FAMILY_APPLICATIONS, VARIABLE_FAMILY, VARIABLE_NOTES, applications_for

# ── Citation rendering mode ───────────────────────────────────────────────────
# "documentercitations" -> emit DocumenterCitations `[key](@cite)` links, resolved
#                          at build time against docs/references.bib (wired in
#                          docs/make.jl via CitationBibliography) + a References page.
# "markdown"            -> emit a self-contained, formatted inline citation
#                          (Authors, Year. Venue. doi-link) parsed from the .bib,
#                          with no build-time dependency on DocumenterCitations.
# Override with ENV["ZOO_CITATION_MODE"]. The default is DocumenterCitations; the
# markdown path is the robustness fallback and is fully baked in here so that a
# plain `make_entry.jl` run reproduces citations either way.
const CITATION_MODE = get(ENV, "ZOO_CITATION_MODE", "documentercitations")
const BIBFILE       = joinpath(REPO, "docs", "references.bib")

# ── Minimal BibTeX parser (only what the markdown fallback needs) ─────────────
# key => (authors, year, journal, doi) with light LaTeX de-escaping.
function parse_bib(path)
    db = Dict{String,NamedTuple}()
    isfile(path) || return db
    txt = read(path, String)
    # split on @type{ ... } entries at top level (entries are non-nested here)
    for m in eachmatch(r"@\w+\{([^,]+),(.*?)\n\}"s, txt)
        key = strip(m.captures[1])
        body = m.captures[2]
        field(name) = begin
            fm = match(Regex("$(name)\\s*=\\s*\\{(.*?)\\}", "s"), body)
            fm === nothing ? "" : strip(replace(fm.captures[1], r"\s+" => " "))
        end
        deTeX(s) = replace(s,
            r"[{}]" => "",
            "\\&" => "&", "\\\"a" => "ä", "\\\"o" => "ö", "\\\"u" => "ü",
            "\\'a" => "á", "\\'e" => "é", "\\'i" => "í", "\\'o" => "ó",
            "\\`a" => "à", "\\~n" => "ñ")
        db[key] = (
            authors = deTeX(field("author")),
            year    = field("year"),
            journal = deTeX(field("journal") == "" ? field("booktitle") : field("journal")),
            doi     = field("doi"),
        )
    end
    db
end

const BIB = parse_bib(BIBFILE)

# Turn a BibTeX author list ("Last, First and Last2, First2 and ...") into a
# compact "Last et al." / "Last & Last2" citation string.
function short_authors(authors)
    isempty(authors) && return ""
    people = split(authors, r"\s+and\s+")
    last(p) = strip(first(split(p, ",")))
    ppl = last.(people)
    length(ppl) == 1 && return ppl[1]
    length(ppl) == 2 && return "$(ppl[1]) & $(ppl[2])"
    return "$(ppl[1]) et al."
end

# Render the citation block for one feature according to CITATION_MODE.
function citation_block(entry)
    keys = get(CITATION_KEYS, entry.name, String[])
    blurb = get(CITATION_BLURB, entry.name, "")
    isempty(keys) && return "_No seminal reference on file for `$(entry.name)`._"
    if CITATION_MODE == "markdown"
        parts = String[]
        for k in keys
            b = get(BIB, k, nothing)
            if b === nothing
                push!(parts, "`$k`")
            else
                sa = short_authors(b.authors)
                doi = isempty(b.doi) ? "" : " [doi:$(b.doi)](https://doi.org/$(b.doi))"
                ven = isempty(b.journal) ? "" : " *$(b.journal)*."
                push!(parts, "$sa ($(b.year)).$ven$doi")
            end
        end
        cites = join(parts, "  \n")
        return (isempty(blurb) ? "" : "$blurb\n\n") * cites
    else
        cites = join(["[$k](@cite)" for k in keys], "; ")
        return (isempty(blurb) ? "" : "$blurb\n\n") * "**Seminal reference(s):** $cites."
    end
end

# Rewrite literal "[key](@cite)" spans in `text` to a self-contained inline
# citation when CITATION_MODE == "markdown" (mirrors citation_block's fallback
# path); a no-op under the default "documentercitations" mode, where the
# `[key](@cite)` link is resolved at Documenter build time instead.
function render_citerefs(text::AbstractString)
    CITATION_MODE == "documentercitations" && return text
    out = text
    for m in eachmatch(r"\[([A-Za-z0-9_]+)\]\(@cite\)", text)
        k = m.captures[1]
        b = get(BIB, k, nothing)
        rep = b === nothing ? "`$k`" : "$(short_authors(b.authors)) ($(b.year))"
        out = replace(out, m.match => rep)
    end
    return out
end

# The three *application* fields of the consolidated HRV knowledge base
# (docs/references.bib). The KB's fourth field, "methods & foundations", is not
# an application area — it is where each entry's seminal lineage lives, rendered
# in the "## Citation" section instead. Field names follow the KB labeling
# scheme (2026-08 citation-expansion run): clinical · sports & peak-performance
# · contemplative practice · methods & foundations.
const APPLICATION_DOMAINS = (:clinical, :sports, :meditation)
const APPLICATION_DOMAIN_TITLE = Dict(
    :clinical   => "Clinical",
    :sports     => "Sports & peak performance",
    :meditation => "Contemplative practice",
)
const APPLICATION_COVERAGE_LABEL = Dict(
    "statistics"        => "**Coverage: statistics** — a large/pooled literature (reviews or meta-analyses exist)",
    "individual-papers" => "**Coverage: individual papers** — a small, scattered literature (no pooled meta-analysis)",
    "sparse-or-none"    => "**Coverage: sparse-or-none** — essentially no dedicated application literature found",
)

# Render the "## Applications by area" section for one dex entry, from the
# per-variable data in docs/zoo_gen/applications.jl (`applications_for`).
function applications_block(entry)
    info = applications_for(entry.name)
    io = IOBuffer()
    if info.apps === nothing
        println(io, "No applications literature was harvested for `$(entry.name)` in the 2026-07",
                    " clinical / sports-&-peak-performance / contemplative-practice literature sweep",
                    " (`hrv-applications-bibliography`",
                    " workflow) — treat this measure as **sparse-or-none** on real-world application",
                    " evidence until a dedicated search is done. Its aliases and closest relatives may",
                    " have their own applications; see the [HRV Variable Zoo](index.md) overview.")
        println(io)
    else
        for dom in APPLICATION_DOMAINS
            d = getfield(info.apps, dom)
            println(io, "### $(APPLICATION_DOMAIN_TITLE[dom])")
            println(io)
            println(io, "$(APPLICATION_COVERAGE_LABEL[d.coverage]).")
            println(io)
            println(io, render_citerefs(d.summary))
            println(io)
            println(io, "*Dominant reported direction:* $(d.direction).")
            if !isempty(d.refs)
                refs = render_citerefs(join(["[$r](@cite)" for r in d.refs], "; "))
                println(io)
                println(io, "**Key references:** $refs.")
            end
            println(io)
        end
    end
    for note in info.notes
        println(io, "!!! note")
        println(io, "    ", render_citerefs(note))
        println(io)
    end
    println(io, "See the",
                " [effect-distribution meta-analysis](../usecases/effect-distributions.md) page for the",
                " harvested per-study effect sizes/p-values behind these domain summaries",
                " (`docs/zoo_gen/effect_stats.csv`).")
    return String(take!(io))
end

# ── Extended normative priors (17 features absent from the original tables) ───
# Loaded from docs/normative_priors_extended.csv into a name→NamedTuple map.
const EXT_PRIORS = let d = Dict{String,NamedTuple}()
    if isfile(EXT_PRIORS_F)
        for r in eachrow(CSV.read(EXT_PRIORS_F, DataFrame))
            d[String(r.feature)] = (
                family   = String(r.family),
                p1n      = String(r.param1_name), p1 = Float64(r.param1_value),
                p2n      = String(r.param2_name), p2 = Float64(r.param2_value),
                ksp      = Float64(r.ks_pvalue),  n  = Int(r.n_valid),
                datasets = String(r.datasets),
                wsize    = Int(r.window_size),    stride = Int(r.stride),
            )
        end
    end
    d
end

# ── Coarse resource-intensity fallback (computational-graph depth) ────────────
# Domain-level stand-in used only when a feature has no MEASURED rank. Ranks from
# the computational-graph depth in docs/slides/computational-graph.mmd: Level-1
# base stats are cheapest; frequency/nonlinear features that first build a
# periodogram or do template matching are the most expensive.
const RESOURCE_RANK = Dict(
    "time"      => (rank = "◍◌◌◌◌  very low", note = "O(N) reduction over successive differences"),
    "frequency" => (rank = "◍◍◍◌◌  moderate", note = "requires a Lomb–Scargle/Welch periodogram first"),
    "geometric" => (rank = "◍◍◌◌◌  low",      note = "O(N) Poincaré coordinates + reductions"),
    "nonlinear" => (rank = "◍◍◍◍◌  high",      note = "template matching / embedding — O(N²) worst case"),
)

# ── Measured per-feature resource ranks (docs/zoo_gen/bench_resources.jl) ──────
# feature → (rank, tier, median_ms_360, allocs, warm_ms_360, note). When present
# these OVERRIDE the coarse domain fallback above (report §D7).
const RESOURCE_RANK_FILE = joinpath(HERE, "resource_rank.jl")
if isfile(RESOURCE_RANK_FILE)
    include(RESOURCE_RANK_FILE)  # -> RESOURCE_RANK_BY_FEATURE
else
    const RESOURCE_RANK_BY_FEATURE = Dict{String,NamedTuple}()
end
resource_for(entry) = get(RESOURCE_RANK_BY_FEATURE, entry.name,
                          get(RESOURCE_RANK, entry.primary_domain, (rank = "◍◍◌◌◌  low", note = "")))
is_measured(entry) = haskey(RESOURCE_RANK_BY_FEATURE, entry.name)

function format_bytes(b)
    b < 1024        && return @sprintf("%d B", b)
    b < 1024^2      && return @sprintf("%.1f KiB", b / 1024)
    b < 1024^3      && return @sprintf("%.1f MiB", b / 1024^2)
    return @sprintf("%.2f GiB", b / 1024^3)
end

# ── Build a Distributions.jl object from the fitted prior params ──────────────
function make_prior(entry)
    fam = entry.prior_family
    p1, p2 = entry.param1_value, entry.param2_value
    (isnan(p1) || isnan(p2)) && return nothing
    fam == "Normal"    && return Normal(p1, p2)
    fam == "Gamma"     && return Gamma(p1, p2)       # (shape α, scale θ)
    fam == "Beta"      && return Beta(p1, p2)
    fam == "LogNormal" && return LogNormal(p1, p2)   # (μ, σ) of log
    return nothing
end

# ── Empirical column, cleaned ────────────────────────────────────────────────
function clean_column(df, name)
    name in names(df) || return Float64[]
    v = collect(skipmissing(df[!, name]))
    v = Float64.(v)
    filter(x -> isfinite(x), v)
end

summarystats_row(v) = (
    n      = length(v),
    med    = median(v),
    q05    = quantile(v, 0.05),
    q25    = quantile(v, 0.25),
    q75    = quantile(v, 0.75),
    q95    = quantile(v, 0.95),
    mean   = mean(v),
    std    = std(v),
)

# ── Render the "what does normal look like" figure ───────────────────────────
function render_figure(entry, v, prior, figpath; src = "pooled nsrdb+nsr2db, w360/s120")
    Plots.gr()
    s = summarystats_row(v)
    # clip long tails for display (0.5–99.5 pct) so the mode is visible
    lo, hi = quantile(v, 0.005), quantile(v, 0.995)
    unit = occursin("ms", lowercase(entry.definition)) ? "ms" : ""
    srcshort = first(split(src, ","))
    plt = Plots.histogram(
        v; bins = 60, normalize = :pdf, xlims = (lo, hi),
        label = "$srcshort windows (n=$(s.n))",
        color = Plots.RGBA(0.20, 0.45, 0.70, 0.55), linecolor = :white, linewidth = 0.3,
        xlabel = isempty(unit) ? entry.name : "$(entry.name) [$unit]",
        ylabel = "density",
        title  = "$(entry.name) — normative distribution ($src)",
        titlefontsize = 9, legend = :topright, legendfontsize = 7,
        grid = true, gridalpha = 0.15, size = (760, 440), dpi = 130,
    )
    if prior !== nothing
        xs = range(lo, hi; length = 400)
        Plots.plot!(plt, xs, pdf.(prior, xs);
            label = "fitted $(entry.prior_family) prior", color = :firebrick, linewidth = 2.5)
    end
    Plots.vline!(plt, [s.med]; label = "median", color = :black, linewidth = 1.6, linestyle = :solid)
    Plots.vline!(plt, [s.q05, s.q95]; label = "5–95%", color = :gray40, linewidth = 1.2, linestyle = :dash)
    Plots.savefig(plt, figpath)
    return s
end

# ── KS p-value rendering: 0.0 is float underflow, not a real zero p-value ─────
format_ksp(p) = p == 0.0 ? "< 1e-300" : @sprintf("= %.2g", p)

# ── Distribution-family reconciliation notes (declared vs. empirically-fitted
#    family diverge for a feature; render the empirical fit but explain why) ───
const FAMILY_RECONCILE_NOTE = Dict{String,String}(
    "hurst" => "Note: `hurst` is theoretically bounded to (0, 1) (`Beta`, as declared in the" *
               " `Features.jl` docstring), but the observed 360-beat-window values leave that" *
               " interval (see the 5–95% range below), so the empirical fit shown here is `Normal`.",
)

# ── Short-window degeneracy caveats: features whose 360-beat normative window
#    is too short to compute a meaningful value (need ≥5 min / multiple 5-min
#    segments) — the plotted distribution is dominated by degenerate windows
#    and is indicative only. See docs/src/zoo/index.md frequency-domain note. ──
const SHORT_WINDOW_CAVEAT = Dict{String,String}(
    "vlf" => "**VLF (0.003–0.04 Hz) is degenerate on 360-beat windows.** A 360-beat window" *
             " (~5–6 min) barely reaches the band's own lower edge, so Welch's frequency" *
             " resolution cannot resolve power inside it for most windows — the empirical" *
             " median/IQR collapse to 0 below. Treat the plot and normal-range table as" *
             " **indicative only**; a real VLF estimate needs much longer windows (≥5 min," *
             " ideally tens of minutes to hours) or a full-length recording.",
    "sdann" => "**SDANN is degenerate on 360-beat windows.** SDANN is the SD of *multiple*" *
               " non-overlapping 5-minute segment means; a single 360-beat window (~5–6 min)" *
               " usually spans only one segment, so most windows yield `NaN` (silently filtered" *
               " out of the summary below — see the reduced \"n windows\" count vs. the pooled" *
               " total). Treat the plot and normal-range table as **indicative only**; a real" *
               " SDANN needs ≥25–30 min (several 5-min blocks), ideally the full 24-h recording.",
)

# ── Emit the Documenter-markdown dex entry ───────────────────────────────────
function write_entry(entry, s, figrel, has_plot; src_label = "pooled nsrdb+nsr2db", win_desc = "360-beat windows, 120-beat stride")
    dom = entry.primary_domain
    res = resource_for(entry)
    measured = is_measured(entry)
    aliases = isempty(entry.aliases) ? "_none_" : join("`" .* entry.aliases .* "`", ", ")
    dombadge = join("`" .* entry.domains .* "`", " · ")
    prior_line = if entry.prior_status == "ok" && !isnan(entry.param1_value)
        @sprintf("**%s(%s = %.4g, %s = %.4g)**  —  KS p %s, n = %d",
            entry.prior_family, entry.param1_name, entry.param1_value,
            entry.param2_name, entry.param2_value, format_ksp(entry.ks_pvalue), entry.n_valid)
    else
        "_declared family: **$(entry.family)**; no fitted normative prior yet (see notes)_"
    end

    io = IOBuffer()
    println(io, "# `$(entry.name)`")
    println(io)
    println(io, "> **$(titlecase(replace(entry.definition, r"^Calculate the " => "")))**")
    println(io)
    println(io, "| | |")
    println(io, "|---|---|")
    println(io, "| **Aliases** | $aliases |")
    println(io, "| **Domain** | $dombadge |")
    println(io, "| **Distribution family** | `$(entry.family)` |")
    println(io, "| **Equation** | `$(entry.equation)` |")
    println(io, "| **Resource intensity** | $(res.rank) — _$(res.note)_ ($(measured ? "measured" : "placeholder"), see §Resources) |")
    println(io)
    println(io, "## Definition")
    println(io)
    defn = rstrip(entry.definition)
    endswith(defn, ".") || (defn *= ".")
    println(io, defn, isempty(entry.equation) ? "" : " Formally: `$(entry.equation)`.")
    println(io)

    println(io, "## What does *normal* look like?")
    println(io)
    println(io, "Fitted normative prior: $prior_line.")
    println(io)
    if haskey(FAMILY_RECONCILE_NOTE, entry.name)
        println(io, FAMILY_RECONCILE_NOTE[entry.name])
        println(io)
    end
    if haskey(SHORT_WINDOW_CAVEAT, entry.name)
        println(io, "!!! warning \"Degenerate on short (360-beat) windows — indicative only\"")
        for line in split(SHORT_WINDOW_CAVEAT[entry.name], "\n")
            println(io, "    ", line)
        end
        println(io)
    end
    if has_plot
        println(io, "![Normative distribution of $(entry.name)]($figrel)")
        println(io)
        println(io, "Empirical distribution over the **$(src_label)** normative windows ",
                    "($(win_desc)), overlaid with the fitted ",
                    "`$(entry.prior_family)` prior density. Vertical lines mark the median and the 5–95% range.")
        println(io)
        println(io, "### Normal-range summary ($(src_label))")
        println(io)
        println(io, "| statistic | value |")
        println(io, "|---|---|")
        println(io, @sprintf("| median | %.4g |", s.med))
        println(io, @sprintf("| IQR (25–75%%) | %.4g – %.4g |", s.q25, s.q75))
        println(io, @sprintf("| 5–95%% range | %.4g – %.4g |", s.q05, s.q95))
        println(io, @sprintf("| mean ± sd | %.4g ± %.4g |", s.mean, s.std))
        println(io, @sprintf("| n windows | %d |", s.n))
        println(io)
        println(io, "_n varies by feature only through per-window validity over the full pooled",
                    " nsrdb+nsr2db table (n up to 61 715; e.g. `sampen`/`mse` drop windows where the",
                    " statistic is undefined). `ulf` is the one exception: a 360-beat (~5 min) window",
                    " contains no ULF-band power, so it uses a long-window NSRDB-only extraction",
                    " (see its own page)._")
    else
        println(io, "!!! warning \"No normative plot yet\"")
        println(io, "    `$(entry.name)` is declared in `Features.jl` but was **not** included in the")
        println(io, "    windowed NSR2DB normative table and has **no fitted prior**, so its empirical")
        println(io, "    distribution cannot be shown here. It will populate automatically once the")
        println(io, "    normative-collection tool computes this column (see report §D-notes).")
    end
    println(io)

    println(io, "## Use cases")
    println(io)
    println(io, use_cases(entry))
    println(io)

    println(io, "## Applications by area")
    println(io)
    println(io, "*Evidence is reported at the measure-family level; a specific variant may not be the",
                " exact index measured in every cited study.*")
    println(io)
    println(io, "The three areas below are the application fields of the consolidated",
                " [HRV knowledge base](references.md) (clinical · sports & peak-performance ·",
                " contemplative practice); the fourth KB field, *methods & foundations*, is this",
                " measure's seminal lineage — see [§Citation](#Citation).")
    println(io)
    println(io, applications_block(entry))

    println(io, "## Resources")
    println(io)
    if measured
        println(io, "Resource-intensity rank **$(res.rank)** is **measured** — median wall-clock",
                    " time + allocations over a 360-beat window on synthetic realistic RR",
                    " (`docs/zoo_gen/bench_resources.jl`; full grid in `resource_bench.csv`).")
        println(io)
        println(io, "| metric (360-beat window) | value |")
        println(io, "|---|---|")
        println(io, @sprintf("| cold median wall-time | %.4g ms |", res.median_ms_360))
        println(io, @sprintf("| warm median wall-time | %.4g ms |", res.warm_ms_360))
        println(io, @sprintf("| allocations (cold) | %s |", format_bytes(res.allocs)))
        println(io)
        println(io, "*Cold* = fresh memoization caches (builds every shared representation from",
                    " scratch); *warm* = shared representations (`diff`, periodogram, Poincaré",
                    " coords, DFA fluctuation) already cached, so only this feature is recomputed.",
                    " The tier is derived from the cold cost; see `$(res.note)`")
    else
        println(io, "Resource-intensity rank **$(res.rank)** is a *placeholder* derived from the feature's")
        println(io, "depth in the computational graph (`docs/slides/computational-graph.mmd`). It will be")
        println(io, "replaced by measured wall-clock + allocation benchmarks (report §D7).")
    end
    println(io)

    println(io, "## Citation")
    println(io)
    println(io, citation_block(entry))
    println(io)
    println(io, "See the [References](references.md) page for the full bibliography.")

    open(joinpath(ZOO_DIR, "$(entry.name).md"), "w") do f
        write(f, String(take!(io)))
    end
end

# ── Minimal domain-based use-case blurbs (curated stubs; extend per feature) ──
function use_cases(entry)
    haskey(USE_CASES, entry.name) && return USE_CASES[entry.name]
    d = entry.primary_domain
    d == "time"      && return "- Short-term vagal / parasympathetic tone (esp. successive-difference measures).\n" *
                               "- Ultra-short and 5-min HRV screening; biofeedback targets.\n" *
                               "- Stress, recovery, and training-load monitoring."
    d == "frequency" && return "- Autonomic balance via spectral bands (LF/HF interpretation with care).\n" *
                               "- Baroreflex and respiratory-sinus-arrhythmia studies.\n" *
                               "- Longer recordings where spectral resolution is adequate."
    d == "geometric" && return "- Poincaré-plot geometry: short- vs long-term variability at a glance.\n" *
                               "- Robust-to-artifact summaries for noisy field recordings.\n" *
                               "- Sympatho-vagal indices (CSI/CVI) in clinical screening."
    return "- Signal complexity / regularity and fractal scaling.\n" *
           "- Discriminating pathology (AF, CHF) from healthy dynamics.\n" *
           "- Research into nonlinear cardiac control (use with adequate N)."
end

# ── Driver ───────────────────────────────────────────────────────────────────
function generate(name::AbstractString; df = nothing, extdf = nothing)
    haskey(INVENTORY_BY_NAME, name) || error("Unknown feature: $name")
    entry = INVENTORY_BY_NAME[name]
    figrel = "figs/$(name).png"

    # ── Extended-extraction fallback ─────────────────────────────────────────
    # Since the full 53-feature re-extraction (commit 472c970) the pooled
    # nsrdb+nsr2db tables + docs/normative_priors.csv cover every feature, so
    # this branch only fires when the pooled fit is NOT ok — in practice `ulf`,
    # whose 360-beat (~5 min) windows contain no ULF-band power and which is
    # therefore fitted from a long-window NSRDB-only extraction
    # (windowed_w360_s120_features_extended.csv + normative_priors_extended.csv).
    if haskey(EXT_PRIORS, name) && entry.prior_status != "ok"
        p = EXT_PRIORS[name]
        extdf === nothing && (extdf = CSV.read(EXTENDED, DataFrame))
        v = clean_column(extdf, name)
        entry = merge(entry, (
            in_windowed_csv = true, prior_status = "ok",
            prior_family = p.family, family = p.family,
            param1_name = p.p1n, param1_value = p.p1,
            param2_name = p.p2n, param2_value = p.p2,
            ks_pvalue = p.ksp, n_valid = p.n,
        ))
        has_plot = !isempty(v)
        s = nothing
        srclabel = uppercase(p.datasets)
        windesc  = "$(p.wsize)-beat windows, $(p.stride)-beat stride"
        if has_plot
            prior = make_prior(entry)
            s = render_figure(entry, v, prior, joinpath(FIG_DIR, "$(name).png");
                              src = "$srclabel, w$(p.wsize)/s$(p.stride)")
        end
        write_entry(entry, s, figrel, has_plot; src_label = srclabel, win_desc = windesc)
        @info "generated (extended)" feature=name plot=has_plot n=length(v) src=p.datasets
        return has_plot
    end

    df === nothing && (df = load_pooled_df())
    v = clean_column(df, name)
    has_plot = entry.in_windowed_csv && !isempty(v)
    s = nothing
    if has_plot
        prior = make_prior(entry)
        s = render_figure(entry, v, prior, joinpath(FIG_DIR, "$(name).png"))
    end
    write_entry(entry, s, figrel, has_plot)
    @info "generated" feature=name plot=has_plot md=joinpath("docs/src/zoo", "$(name).md")
    return has_plot
end

if abspath(PROGRAM_FILE) == @__FILE__
    mkpath(FIG_DIR)
    if isempty(ARGS)
        df    = load_pooled_df()
        extdf = isfile(EXTENDED) ? CSV.read(EXTENDED, DataFrame) : nothing
        for e in INVENTORY
            generate(e.name; df = df, extdf = extdf)
        end
    else
        for name in ARGS
            generate(name)
        end
    end
end
