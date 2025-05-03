using Documenter, TiledViews

# (b) if docs is not the current active environment, switch to it
# (from https://github.com/JuliaIO/HDF5.jl/pull/1020/) 
if Base.active_project() != joinpath(@__DIR__, "Project.toml")
    using Pkg
    Pkg.activate(@__DIR__)
    Pkg.develop(PackageSpec(; path=(@__DIR__) * "/../"))
    Pkg.resolve()
    Pkg.instantiate()
end

DocMeta.setdocmeta!(TiledViews, :DocTestSetup, :(using TiledViews); recursive=true)

makedocs(
    # options
    modules = [TiledViews],
    sitename = "TiledViews.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
    ),
    pages = Any[
        "Introduction" => "index.md",
        "API" => "api.md",
    ],
    # strict = true,
)

deploydocs(
repo = "github.com/bionanoimaging/TiledViews.jl.git",
branch = "gh-pages",  # Ensure this matches the GitHub Pages branch
devbranch = "main"    # Ensure this matches your development branch
)
