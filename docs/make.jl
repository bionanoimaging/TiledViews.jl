using IndexFunArrays, Documenter 

 # set seed fixed for documentation
DocMeta.setdocmeta!(IndexFunArrays, :DocTestSetup, :(using IndexFunArrays); recursive=true)
makedocs(modules = [IndexFunArrays], 
         sitename = "IndexFunArrays.jl", 
         pages = Any[
            "IndexFunArrays.jl" => "index.md",
            "Distance Functions" => "distance.md",
            "Window Functions" => "window.md",
         ]
        )

deploydocs(repo = "github.com/bionanoimaging/IndexFunArrays.jl.git", devbranch="master")
