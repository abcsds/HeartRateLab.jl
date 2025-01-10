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
    ],
)

deploydocs(;
    repo="github.com/abcsds/HeartRateLab.jl",
    devbranch="main",
)
