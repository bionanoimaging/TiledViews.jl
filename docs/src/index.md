# TiledViews

Implementation of shifted arrays just like `ShiftedArrays.jl` but supporting mutation.

## Tiled Processing

The function `tiled_processing` takes an array of input data and dices it up into tiles via constructing a `TiledView` (see below), and processes each of the tiles (using the `eachtile` Iterator) with a function provided. The results are then reassembled into a final `TiledView` whos underlying `parent` corresponds to an array with the reassembled results. If the tiles are mutually overlapping, appropriate merging via the weights as provided by a `window_function` are used. This function has to adhere to the interface as defined by the package `IndexFunArrays`. By default a Hann Window is used.

```julia
julia> res = tiled_processing(ones(4,6), (a)->10*a, (2,2), (0,0)).parent
processing tile (1, 1) out of (2, 3), 0.0%
processing tile (2, 1) out of (2, 3), 17.0%
processing tile (1, 2) out of (2, 3), 33.0%
processing tile (2, 2) out of (2, 3), 50.0%
processing tile (1, 3) out of (2, 3), 67.0%
processing tile (2, 3) out of (2, 3), 83.0%
4×6 Matrix{Float64}:
 10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0
```

`tiled_processing` is especially useful, if the provided function casts the input into a `CuArray` from the `CUDA` toolbox and the result is collected back onto the CPU via the `Array` cast. This allows large arrays, too big for the GPU, to be processed efficiently.
For more details on the various ways to use `tiled_processing`, including functions that return multiple results, see the API of `tiled_processing`.

## TiledViews

A `TiledView` is a view into the data given upon its construction, which has twice as many dimensions as the original data.
The tile size as well as the mutula overlap can be specified. A `TiledView` works quite seamlessly with a spatial window function.

The number of tiles in a tiled array `ta = TiledView(ones(10, 10), (5, 5); keep_center=false)` can be accessed by calling `get_num_tiles(ta)` which in this case results in `(2, 2)`. The tile size (here `(5, 5)`) as provided upon its construction, can be obtained by the member `ta.tile_size`.

Here is a small example:
```julia
  julia> a = TiledView(reshape(1:49,(7,7)), (4, 4),(1, 1));
  julia> a.parent
  7×7 reshape(::UnitRange{Int64}, 7, 7) with eltype Int64:
   1   8  15  22  29  36  43
   2   9  16  23  30  37  44
   3  10  17  24  31  38  45
   4  11  18  25  32  39  46
   5  12  19  26  33  40  47
   6  13  20  27  34  41  48
   7  14  21  28  35  42  49
   julia> size(a)
  (4, 4, 3, 3)
```

Note that by default, the center of the central `TiledView` is forced to agree with the center of the original array. This often leads to more tiles than seemingly necessary. By using the named argument `keep_center=false`, this forced alignment can be turned off, such that instead the first pixels align.
For more details on the various ways to construct, see the API documentation.
