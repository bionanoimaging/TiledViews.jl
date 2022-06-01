# TiledViews.jl

[![codecov](https://codecov.io/gh/bionanoimaging/TiledViews.jl/branch/main/graph/badge.svg?token=910XO9N4NO)](https://codecov.io/gh/bionanoimaging/TiledViews.jl)
[![.github/workflows/ci.yml](https://github.com/bionanoimaging/TiledViews.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/bionanoimaging/TiledViews.jl/actions/workflows/ci.yml)


This package allows to view an N-dimensional array as an 2N-dimensional `TiledView` being separated in overlapping tiles.
The tiled view has read and write access. 
Via the `TiledWindowView` it is possible to imprint a weight-window onto the tiled view. By default the window is chosen such that
it sums up to one except in places very close to the border, where an insufficient number of contributions are generated.
However this can effect can easily be accounted for, since it optionally returns an overall weight distribution.

Example: 
```julia
julia> a = TiledView(reshape(1:49,(7,7)), (4, 4),(1, 1));

julia> size(a)
(4, 4, 3, 3)
```


The toolbox also offers support for iterators on the tiles via the functions `eachtile()`, `eachtilenumber()`, and `eachtilerelpos()`.
A very convenient way of processing all tiles with a user-supplied function and fusing the images automatically via window-based weighting is using
the function `tiled_processing()`.

## Installation
Type `]`in the REPL to get to the package manager and install it:
```julia
julia> ] add TiledViews
```
