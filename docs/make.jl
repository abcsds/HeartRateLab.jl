using HeartRateLab
using Documenter
using DocumenterCitations

DocMeta.setdocmeta!(HeartRateLab, :DocTestSetup, :(using HeartRateLab); recursive=true)

# ── HRV Variable Zoo bibliography ─────────────────────────────────────────────
# Seminal-reference citations for the 53-feature "Pokédex". Each dex entry uses
# `[key](@cite)` links resolved against docs/references.bib; the References page
# (zoo/references.md) renders the full bibliography via an `@bibliography` block.
bib = CitationBibliography(joinpath(@__DIR__, "references.bib"); style=:authoryear)

# ── HRV Variable Zoo page list (grouped by domain, generated from the inventory)
include(joinpath(@__DIR__, "zoo_gen", "inventory.jl"))  # -> INVENTORY
const ZOO_DOMAINS = [
    ("time", "Time domain"), ("frequency", "Frequency domain"),
    ("geometric", "Geometric"), ("nonlinear", "Nonlinear"),
]
zoo_group(dom) = [e.name => "zoo/$(e.name).md"
                  for e in INVENTORY if e.primary_domain == dom]
zoo_pages = Any["Overview" => "zoo/index.md"]
for (dom, title) in ZOO_DOMAINS
    push!(zoo_pages, title => zoo_group(dom))
end
push!(zoo_pages, "References" => "zoo/references.md")

makedocs(;
    modules=[HeartRateLab],
    authors="Alberto Barradas <abcsds@gmail.com> and contributors",
    sitename="HeartRateLab.jl",
    checkdocs=:none,
    # A pre-existing docstring in the Models module carries a `[`forecast`](@ref)`
    # link with no target; it is spliced into models/dmd.md. Keep it non-fatal so
    # the site (incl. the HRV Variable Zoo) builds. All zoo `@cite` links resolve.
    warnonly=[:cross_references],
    plugins=[bib],
    format=Documenter.HTML(;
        canonical="https://abcsds.github.io/HeartRateLab.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Features" => "features.md",
        "HRV Variable Zoo" => zoo_pages,
        "Models" => [
            "Overview"     => "models/index.md",
            "Framework"    => "models/framework.md",
            "LIF"          => "models/lif.md",
            "Van der Pol"  => "models/vanderpol.md",
            "Lorenz"       => "models/lorenz.md",
            "DMD"          => "models/dmd.md",
            "Extending"    => "models/extending.md",
        ],
        "Visualization" => "visualization.md",
        "Use Cases" => [
            "Overview"                       => "usecases/index.md",
            "Is my data normal?"             => "usecases/normative.md",
            "Meditation & resonant breathing" => "usecases/meditation.md",
            "What do reported effects look like?" => "usecases/effect-distributions.md",
        ],
        "Tutorials" => "tutorials.md",
    ],
)

deploydocs(;
    repo="github.com/abcsds/HeartRateLab.jl",
    devbranch="main",
)
