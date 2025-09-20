using CDAWeb
using Documenter

DocMeta.setdocmeta!(CDAWeb, :DocTestSetup, :(using CDAWeb); recursive=true)

makedocs(;
    modules=[CDAWeb],
    authors="Beforerr <zzj956959688@gmail.com> and contributors",
    sitename="CDAWeb.jl",
    format=Documenter.HTML(;
        canonical="https://juliaspacephysics.github.io/CDAWeb.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/JuliaSpacePhysics/CDAWeb.jl",
    push_preview = true,
)
