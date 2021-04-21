# TiledViews.jl
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

| **Documentation**                       | **Build Status**                          | **Code Coverage**               |
|:---------------------------------------:|:-----------------------------------------:|:-------------------------------:|
| [![][docs-stable-img]][docs-stable-url] [![][docs-dev-img]][docs-dev-url] | [![][CI-img]][CI-url] | [![][codecov-img]][codecov-url] |

