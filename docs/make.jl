using Documenter, TiledViews

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
