using HeartRateLab
using Documenter

DocMeta.setdocmeta!(HeartRateLab, :DocTestSetup, :(using HeartRateLab); recursive=true)

makedocs(;
    modules=[HeartRateLab],
    authors="Alberto Barradas <abcsds@gmail.com> and contributors",
    sitename="HeartRateLab.jl",
    format=Documenter.HTML(;
        canonical="https://abcsds.github.io/HeartRateLab.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting_started.md",
        "Features" => "features.md",
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
        "Tutorials" => "tutorials.md",
    ],
)

deploydocs(;
    repo="github.com/abcsds/HeartRateLab.jl",
    devbranch="main",
)
