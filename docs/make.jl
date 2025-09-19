using CDAWeb
using Documenter

DocMeta.setdocmeta!(CDAWeb, :DocTestSetup, :(using CDAWeb); recursive=true)

makedocs(;
    modules=[CDAWeb],
    authors="Beforerr <zzj956959688@gmail.com> and contributors",
    sitename="CDAWeb.jl",
    format=Documenter.HTML(;
        canonical="https://Beforerr.github.io/CDAWeb.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/Beforerr/CDAWeb.jl",
    devbranch="main",
)
