module TiledViews
using IndexFunArrays # needed for the default window function.
using NDTools # for linear_index

# using NDTools
export TiledView, get_num_tiles, TiledWindowView, tile_centers, get_window, tiled_processing
export get_num_tiles, eachtile, eachtilenumber, eachtilerelpos

tuple_len(::NTuple{N, Any}) where {N} = Val{N}()

 # T refers to the result type. N to the dimensions of the final array, and M to the dimensions of the raw array
struct TiledView{T, N, M, AA<:AbstractArray{T, M}} <: AbstractArray{T, N} 
    # stores the data. 
    parent::AA
    # output size of the array 
    tile_size::NTuple{M, Int}
    tile_period::NTuple{M, Int}
    tile_offset::NTuple{M, Int}  # the distance from the wrapping arrray to the start of stored data
    pad_value::T

    # Constructor function
    function TiledView{T, N, M}(data::AA; tile_size::NTuple{M,Int}, tile_period::NTuple{M,Int}, tile_offset::NTuple{M,Int}, pad_value=nothing) where {T,M,N,AA}
        if isnothing(pad_value)
            if T <: NTuple
                pad_value = T(Base.Iterators.repeated(0))
            # elseif T <: AbstractArray            
            else
                pad_value = convert(T,0)  # this may crash, but then the user should specify a valid pad_value
            end
        end
        return new{T, N, M, AA}(data, tile_size, tile_period, tile_offset, pad_value) 
    end
end

function center(data)
    return size(data) .÷ 2 .+1
end

"""
    TiledView(data::F, tile_size::NTuple{N,Int}, 
              tile_overlap::NTuple{N,Int} = tile_size .* 0, 
              tile_center::NTuple{M,Int} = (mod.(tile_size,2) .+ 1)
              ; pad_value::T, keep_center=true)

Creates an 2N dimensional view of the data by tiling the N-dimensional data as 
specified by tile_size, tile_overlap and optionally tile_center.

## Arguments
* `data`: the input data to decompose into a TiledView. No copies are made for the `TiledView` and the raw data can be accessed via `.parent`.
* `tile_size`: A Tuple describing the size of each tile. This size will form the first N dimensions of the result of `size(myview)`. The second N dimensions refer to N-dimensional tile numbering.
* `tile_overlap`: Tuple specifying the overlap between successive tiles in voxels. This implicitely defines the pitch between tiles as `(tile_size .- tile_overlap)`.

## Keyword Argument
* `pad_value`: Specifies the answer that is returned when get_index is applied to a position outside the source array.
* `keep_center`:  This boolean specifies whether the center of the parent `data` will be aligned with the center of the central tile. If `false`, the first tile starts at offset zero.
* `tile_center`:  Only used if `keep_center` is true. It defines the center position in the central tile. The default is `tile_size .÷ 2 .+1`.

# Examples
```jldoctest TiledView
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
"""
function TiledView(data::AbstractArray{T,M}, tile_size::NTuple{M,Int}, tile_overlap::NTuple{M,Int} = tile_size .* 0,
                   tile_center::NTuple{M,Int} = (tile_size .÷ 2 .+ 1); pad_value=nothing, keep_center=true) where {T, M}
    # Note that N refers to the original number of dimensions
    tile_period = tile_size .- tile_overlap
    tile_offset = let
        if keep_center
            data_center = center(data)
            tile_period .- mod.((data_center .- tile_center), tile_period)
        else
            tile_period .* 0
        end
    end
    N = 2*M
    return TiledView{T,N,M}(data; tile_size=tile_size, tile_period=tile_period, tile_offset=tile_offset, pad_value=pad_value)
end


"""
    get_num_tiles(data::TiledView)

Returns the number of tiles
"""
function get_num_tiles(data::TiledView)
    num_tiles = ((size(data.parent) .+ data.tile_offset .- 1) .÷ data.tile_period) .+ 1
    return num_tiles
end

# define AbstractArray function to allow to treat the generator as an array
# See https://docs.julialang.org/en/v1/manual/interfaces/#man-interface-array
"""
    Base.size(A::TiledView)

Returns the size of the `TiledView`.
See [`TiledView`](@ref) for how the size is determined.
"""
function Base.size(A::TiledView)
    return (A.tile_size..., (get_num_tiles(A))...)
end

"""
    zeros_like(A::TiledView, ::Type{T}=eltype(A.parent))

returns a new `TiledView` of the same size as `A` filled with zeros.

## Arguments:
* `A`: the `TiledView` to be used as a template for the new array.
* `T`: the element type of the new array. By default, it is the same as the type of the parent array of `A`.
"""
function zeros_like(A::TiledView, ::Type{T}=eltype(A.parent)) where {T}
    TiledView{T,ndims(A),length(A.tile_size)}(zeros(T, size(A.parent)); tile_size=A.tile_size, tile_period=A.tile_period, tile_offset=A.tile_offset, pad_value=A.pad_value) 
end

"""
    zeros_like(A::TiledView, reduced_size::NTuple, ::Type{T}=eltype(A.parent)) where {T}

returns a new `TiledView` of referring to a zero-array of  size `reduced_size` but with the same tile-layout as `A`.

## Arguments:
* `A`: the `TiledView` to be used as a template for the new array.
* `reduced_size`: the size of the new array. The first N dimensions are the tile size, the second N dimensions are the number of tiles.
* `T`: the element type of the new array. By default, it is the same as the type of the parent array of `A`.
"""
function zeros_like(A::TiledView, reduced_size::NTuple, ::Type{T}=eltype(A.parent)) where {T}
    @assert all(size(A.parent) .== reduced_size .|| (A.tile_size .== size(A.parent) .&& reduced_size .== 1)) "reduced_size must be 1 and the tile needs to span the array, or the same size as the parent array of A"
    tile_size = ntuple((d)-> (A.tile_size[d] == size(A.parent, d) && reduced_size[d] == 1) ? 1 : A.tile_size[d], ndims(A.parent))
    tile_period = ntuple((d)-> (A.tile_size[d] == size(A.parent, d) && reduced_size[d] == 1) ? 1 : A.tile_period[d], ndims(A.parent))
    tile_offset = ntuple((d)-> (A.tile_size[d] == size(A.parent, d) && reduced_size[d] == 1) ? 0 : A.tile_offset[d], ndims(A.parent))
    return TiledView{T,ndims(A),length(tile_size)}(zeros(T, reduced_size); tile_size=tile_size, tile_period = tile_period,
                tile_offset = tile_offset, pad_value = A.pad_value) 
end


"""
    ones_like(A::TiledView, ::Type{T}=eltype(A.parent))

returns a new `TiledView` of the same size as `A` filled with ones.

## Arguments:
* `A`: the `TiledView` to be used as a template for the new array.
* `T`: the element type of the new array. By default, it is the same as the type of the parent array of `A`.
"""
function ones_like(A::TiledView, ::Type{T}=eltype(A.parent)) where {T}
    TiledView{T,ndims(A),length(A.tile_size)}(ones(T, size(A.parent)); tile_size=A.tile_size, tile_period=A.tile_period, tile_offset=A.tile_offset, pad_value=A.pad_value) 
end

# Note that the similar function below will most of the times expand the overall required datasize
function Base.similar(A::TiledView, ::Type{T}=eltype(A.parent), dims::Dims=size(A)) where {T}
    # The first N coordinates are position within a tile, the second N coordinates are tile number
    #= N = length(A.tile_size)
    new_tile_sz = dims[1:N]
    new_num_tiles = dims[N + 1:end]
    new_tile_period = A.tile_period .+ new_tile_sz .- A.tile_size 
    new_core_sz = new_num_tiles .* new_tile_period .- A.tile_offset  # keep the overlap the same as before
    TiledView{T,ndims(A),length(A.tile_size)}(similar(A.parent, T, new_core_sz); tile_size=new_tile_sz, tile_period=new_tile_period, tile_offset=A.tile_offset, pad_value=A.pad_value) 
    =# 
    similar(A.parent, T, dims) # this returns an ordinary array, but this seems the only way to handle cases like: my_tiled_array[:,:,2,3] which expect a 2D array
end
# Array{eltype(A)}(undef, size...) 

# %24 = Base.getproperty(A, :parent)::AbstractMatrix{Float64}

# calculate the entry according to the index
# Base.getindex(A::IndexFunArray{T,N}, I::Vararg{B, N}) where {T,N, B} = return A.generator(I)

function pos_from_tile(A::TiledView{T,N}, TilePos::NTuple{M,Int}, TileNum::NTuple{M,Int}) where {T,N,M}
    Tuple(TilePos[n] - A.tile_offset[n] + (TileNum[n]-1) * A.tile_period[n]  for n in 1:M)
end

# calculate the entry according to the index
Base.@propagate_inbounds function Base.getindex(A::TiledView{T,N,M,AA}, I::Vararg{Int, N})::T where {T,N,M,AA}
    @boundscheck checkbounds(A, I...)
    @inbounds pos = (I[n] - A.tile_offset[n] + (I[n+M].-1) * A.tile_period[n]  for n in 1:M)
    if Base.checkbounds(Bool, A.parent, pos...)
        return Base.getindex(A.parent, pos...)::T
    else
        return A.pad_value :: T; 
    end
end

Base.setindex!(A::TiledView{T,N,M,AA}, v, I::Vararg{Int,N}) where {T,N,M,AA} = begin 
    @boundscheck checkbounds(A, I...)
    @inbounds pos = (I[n] - A.tile_offset[n] + (I[n+M].-1) * A.tile_period[n]  for n in 1:M)
    # pos = TilePos .- A.tile_offset .+ (TileNum.-1) .* A.tile_period 
    if Base.checkbounds(Bool, A.parent, pos...)
        return setindex!(A.parent, v, pos... )
    else
        return convert(T,0)
    end
end

## Some functions for generating useful tilings

"""
    get_window(A::TiledView; window_function=window_hanning, get_norm=false, verbose=false, offset = CtrFT);

Calculates a window matching to the `TiledView`.

`window_function`. The window function as defined in IndexFunArrays to apply to the TiledView.
The result is currently not any longer a view as it is unclear how to wrap the multiplication into a view.
For this reason the TiledView without the window applied is also returned and can be used for assignments.
By default a von Hann window (window_hanning) is used. For even sizes the window is centered at the integer coordinate right of the middle position (`CtrFT`).

`get_norm`. An optional Boolean argument allowing to also obtain the normalization map for the boarder pixels, which
not necessarily undergo all required window operations. In a future version it may be possible
to automatically lay out the windowing such that this effect can be avoided.

`verbose`. If true, diagnostic information on the window layout is printed.

`offset`. defines where the center of the window is placed. See `IndexFunArrays.jl` for details.

# Returns
`matching_window`. a window that can be applied to the view via multiplication myview.*matching_window
This is intentionally not provided as a product to separate the features conceptually
when it comes to write access.

`normalized`. only returned for get_norm=true. Contains an array with the normalization information by
mapping the window back to the original data. This is useful for incomplete coverage of the tiles 
as well as using windows which do not sum up to one in the tiling process.

# Examples
```jldoctest
julia> data = ones(10,10).+0.0;

julia> myview = TiledView(data, (5, 5), (2,2));

julia> win = get_window(myview, verbose=true);
[ Info: Tiles with pitch (3, 3) overlap by (2, 2) pixels.
[ Info: Window starts at (0.5, 0.5) and ends at (2.5, 2.5).

julia> win
5×5 IndexFunArrays.IndexFunArray{Float64, 2, IndexFunArrays.var"#360#362"{Float64, Tuple{Int64, Int64}, Tuple{Int64, Int64}, Tuple{Float64, Float64}, Tuple{Float64, Float64}}}:
 0.0214466  0.125     0.146447  0.125     0.0214466
 0.125      0.728553  0.853553  0.728553  0.125
 0.146447   0.853553  1.0       0.853553  0.146447
 0.125      0.728553  0.853553  0.728553  0.125
 0.0214466  0.125     0.146447  0.125     0.0214466

```
see TiledWindowView() for more examples.
"""
function get_window(A::TiledView; window_function=window_hanning, get_norm=false, verbose=false, offset=CtrFT)
    # this is probably not type-stable, but it is not clear how to do this otherwise
    if isnothing(window_function)
        return 1;
    end
    tile_size = A.tile_size
    tile_pitch = A.tile_period
    tile_overlap = tile_size .- tile_pitch

    winend = (tile_size ./ 2.0)
    winstart = (winend .- tile_overlap)
    winend = winend .+ (tile_overlap .== 0) .* (64 .* eps(Float64)) # avoid zero size windows, which can cause NaNs

    if verbose
        @info("Tiles with pitch $tile_pitch overlap by $tile_overlap pixels.\n")
        @info("Window starts at $winstart and ends at $winend.\n")
    end
    if get_norm == false
        return window_function(tile_size; 
            scale=ScaUnit, offset=offset,
            border_in=winstart, border_out= winend)
    else
        my_view = ones_like(A)
        normalization = A.parent
        # normalization .= 0
        my_view .+= A .*window_function(tile_size;scale=ScaUnit, offset=offset, border_in=winstart, border_out= winend)        
        return (window_function(tile_size; 
            scale=ScaUnit, offset=offset,
            border_in=winstart, border_out= winend), normalization)
    end
end

"""
    function TiledWindowView(data::AbstractArray{T,M}, tile_size::NTuple{M,Int};
                             rel_overlap::NTuple{M,Float64}=tile_size .*0 .+ 1.0,
                             window_function=window_hanning, get_norm=false, verbose=false, offset=CtrFT) where {T, M}

Creates an 2N dimensional view of the data by tiling the N-dimensional data as 
specified by tile_size, tile_overlap and optionally tile_center.
Additionally a window is applied to this view. If the window_type as defined in
IndexFunArrays sums up to one,
which is the case for window_linear and window_hanning, a linear decomposition of the
data is obtained apart from possible border effects.
`data`. the inputdata to decompose into a TiledView. No copies are made for the TiledView and
the raw data can be accessed via myview.parent.

`tile_size`. A Tuple describing the size of each tile. This size will form the first N dimensions of the
result of size(myview). The second N dimensions refer to N-dimensional tile numbering.

`rel_overlap`. Tuple specifying the relative overlap between successive tiles. The absolute overlap is then calculated as `round.(Int,tile_size./2.0 .* rel_overlap)`.

`window_function`. The window function as defined in IndexFunArrays to apply to the TiledView.
The result is currently not any longer a view as it is unclear how to wrap the multiplication into a view.
For this reason the TiledView without the window applied is also returned and can be used for assignments.
By default a von Hann window (window_hanning) is used.

`get_norm`. An optional Boolean argument allowing to also obtain the normalization map for the boarder pixels, which
not necessarily undergo all required window operations. In a future version it may be possible
to automatically lay out the windowing such that this effect can be avoided.

`verbose`. If true, diagnostic information on the window layout is printed.

`offset`. defines where the center of the window is placed. See `IndexFunArrays.jl` for details.

# Returns
myview, matching_window = TiledWindowView ...
a Tuple of two or three (get_norm=true) with

`myview`. the TiledView of the data without the window which can also be written to.

`matching_window`. a window that can be applied to the view via multiplication myview.*matching_window
This is intentionally not provided as a product to separate the features conceptually
when it comes to write access.

`normalized`. only returned for get_norm=true. Contains an array with the normalization information by
mapping the window back to the original data. This is useful for incomplete coverage of the tiles 
as well as using windows which do not sum up to one in the tiling process.

Note that it may be dangerous to directly access the view via a simple .+= operation as
it is not entirely clear, whether it is always garanteed that there could not be any running
conditions with read-write operations, since some points in the referenced array are accessed
multiple times. To avoid such an effect, you can, for example, only acess every second tile along each dimension
in one call.
# Examples
```jldoctest
julia> data = ones(10,10).+0.0;

julia> myview, matching_window = TiledWindowView(data, (5, 5); verbose=true);
[ Info: Tiles with pitch (3, 3) overlap by (2, 2) pixels.
[ Info: Window starts at (0.5, 0.5) and ends at (2.5, 2.5).

julia> size(myview)
(5, 5, 5, 5)

julia> matching_window
5×5 IndexFunArrays.IndexFunArray{Float64, 2, IndexFunArrays.var"#360#362"{Float64, Tuple{Int64, Int64}, Tuple{Int64, Int64}, Tuple{Float64, Float64}, Tuple{Float64, Float64}}}:
 0.0214466  0.125     0.146447  0.125     0.0214466
 0.125      0.728553  0.853553  0.728553  0.125
 0.146447   0.853553  1.0       0.853553  0.146447
 0.125      0.728553  0.853553  0.728553  0.125
 0.0214466  0.125     0.146447  0.125     0.0214466

julia> windowed = collect(myview .* matching_window);

julia> myview[:,:,:,:].=0;  # cleares the original array

julia> myview.parent
10×10 Matrix{Float64}:
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0
 0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0  0.0

julia> myview .+= windowed;  # writes the windowed data back into the array

julia> data # lets see if the weigths correctly sum to one?
10×10 Matrix{Float64}:
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0
 1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0  1.0

julia> # This result may also be used for subsequent normalization but can also be directly obtained by
 
julia> myview, matching_window, normalized = TiledWindowView(rand(10,10).+0, (5, 5); get_norm=true);
```
"""
function TiledWindowView(data::AbstractArray{T,M}, tile_size::NTuple{M,Int};
                         rel_overlap::NTuple{M,Float64}=tile_size .*0 .+ 1.0,
                         window_function=window_hanning, get_norm=false, verbose=false, keep_center=true, offset=CtrFT) where {T, M}
    tile_overlap = round.(Int,tile_size./2.0 .* rel_overlap)
    changeable = TiledView(data,tile_size, tile_overlap, keep_center=keep_center);
    win = get_window(changeable, window_function= window_function, get_norm=get_norm, verbose=verbose, offset=offset)
    if get_norm
        return (changeable, win...)
    else
        return (changeable, win)
    end
end

"""
    tile_centers(A, scale=nothing)


Returns the relative center coordinates of integer tile centers with respect to the integer center `1 .+ size(A) .÷ 2 ` 
The tuple `scale` is used to multiply the relative position with a physical pixelsize.
See also: `eachtilerelpos` for a corresponding iterator
"""
function tile_centers(A, scale=nothing)
    return collect(eachtilerelpos(A, scale))
end

"""
    eachtilerelpos(A, scale=nothing)
 
 
Returns a generator that iterates through the relative distance of each tile center `1 .+ size(A).÷2` to the 
center of the the untiled parent array `1 .+ size(parent).÷2` 
The tuple `scale` is used to multiply the relative position with a physical pixelsize.
"""
function eachtilerelpos(A, scale=nothing)
    nd = ndims(A)/2
    ctr_array = (size(A.parent) .÷ 2) .+ 1 # center of the parent array
    num_tiles = size(A)[end-nd+1:end]
    # ctr_tile = (num_tiles.÷2 .+1)
    tile_ctr = (size(A)[1:nd] .÷ 2) .+ 1
    if isnothing(scale)
        (pos_from_tile(A, tile_ctr, Tuple(idx)) .- ctr_array for idx in CartesianIndices(num_tiles))  # Only the "[" generate a 2D array
        # [(Tuple(idx).-1).* A.tile_period .+ ctr for idx in CartesianIndices(num_tiles)]
    else
        (scale .* (pos_from_tile(A, tile_ctr, Tuple(idx)) .- ctr_array) for idx in CartesianIndices(num_tiles))
    end
end

"""
    eachtile(tiled_view::TiledView)
 
Returns an iterator which iterates through all tiles. Depending on your application you may also want to use
`tiled_processing` for a convenient way to apply a function to each tile and join all tiles back together.
If you need simultaneous access to the tiles and tile numbers, you can also use `eachtilenumber`.
"""
function eachtile(tiled_view::TiledView)
    nd = ndims(tiled_view)÷2
    nz = ((size(tiled_view)[1:nd])..., prod(size(tiled_view)[nd+1:end]))
    reshaped = reshape(tiled_view, nz)
    return eachslice(reshaped, dims=nd+1)
end

"""
    eachtilenumber(tiled_view::TiledView)

Returns an iterator iterating though all the tile numbers. If you need access to the tiles themselves, use 
`eachtile`
"""
function eachtilenumber(tiled_view::TiledView)
    return (Tuple(tn) for tn in CartesianIndices(get_num_tiles(tiled_view)))
end

"""
    get_result_size(tiled_view::TiledView, res_tile::AbstractArray, arr)

returns a tuple of the size of the whole results arrey, considering the `tiled_view` of the input data
and the size of a single result tile `res_tile` obtained by processing the first tile of th input data. 
"""
function get_result_size(tiled_view::TiledView, res_tile::AbstractArray)
    sz = size(tiled_view.parent)
    return ntuple((d)-> (tiled_view.tile_size[d] == sz[d] && size(res_tile, d) == 1) ? 1 : sz[d], ndims(tiled_view.parent))
end

"""
    compatible_sizes(tiled_view, res_tile)

determinse whether a `tiled_view` is compatible with a processed result array of a tile `res_tile`.
"""
function compatible_sizes(tiled_view::TiledView, res_tile::AbstractArray)
    return all(tiled_view.tile_size .== size(res_tile) .|| (size(res_tile) .== 1))
end

"""
    alloc_zeros(tiled_view::TiledView, res_tile::AbstractArray, dtype=nothing)

a helper function to allocate a new array of zeros with the same size as the tile `res_tile`.
The function is used in the `tiled_processing` function to allocate the result array.
It dispatches for a tuple input type to allocate separately for each of the return types as stored in res_tile.
Allocation is only done for AbstractArrays, whereas other types are just kept in the tile-wise way as an Array of results of type Any.
"""
function alloc_zeros(tiled_view::TiledView, res_tile::AbstractArray, dtype=nothing)
    if !compatible_sizes(tiled_view, res_tile)
        s = get_num_tiles(tiled_view)
        # allocate an array of tile positions, each of which will store the corresponding result
        return Array{typeof(res_tile)}(undef, s...)
    end
    res_size = get_result_size(tiled_view, res_tile)
    if isnothing(dtype)
        dtype = eltype(res_tile)
    end
    return zeros_like(tiled_view, res_size, dtype);
end

function alloc_zeros(tiled_view::TiledView, res_tile, dtype=nothing)
# return an empty array of Any type of the size of the tiles.
    s = get_num_tiles(tiled_view)
    # allocate an array of tile positions, each of which will store the corresponding result
    return Array{typeof(res_tile)}(undef, s...)
end

# return an vector of various types, possibly with the large arrays as components
function alloc_zeros(tiled_view::TiledView, res_tile::Union{Tuple, Vector}, dtype=nothing)
    return collect(alloc_zeros(tiled_view, res_t, dtype) for res_t in res_tile)
end

function get_window(res::AbstractArray; window_function=window_function)
    return 1
end

function get_window(res::Vector; window_function=window_function)
    windows = []
    for r in res
        if isa(r, TiledView)
            push!(windows, get_window(r; window_function=window_function))
        else
            push!(windows, 1)
        end
    end
    return windows
end

"""
    add_to_member!(res::Vector, res_tile::Union{Tuple, Vector}, wins::Vector, n)

adds a plain array `res_tile` to a result Vector`res` at position `n`.
`res` is allocated to hold several results (such as TiledViews) as specified by the first call to the function when using the `tiled_processing` function.
"""
function add_to_member!(res::Vector, res_tile::Union{Tuple, Vector}, wins::Vector, n)
    @assert length(res) == length(res_tile) "res and res_tile must have the same length"
    for (sub_res, sub_res_tile, win) in zip(res, res_tile, wins)
        # @show typeof(sub_res) typeof(sub_res_tile) typeof(win)
        add_to_member!(sub_res, sub_res_tile, win, n)
    end
    return nothing
end

"""
    add_to_member!(res::Vector, res_tile::Union{Tuple, Vector}, wins::Vector, n)

adds a plain array `res_tile` to a TiledView result array `res` at position `n`.
"""
function add_to_member!(res::TiledView, res_tile::AbstractArray, win, n)
    # @show res.tile_size size(res_tile)
    @assert res.tile_size == size(res_tile) "res and res_tile must have the same size"
    eachtile(res)[n] .+= win .* res_tile
    return nothing
end

# no window applied to other types. Just store the results
"""
    add_to_member!(res, res_tile, win, n)

add any type of result to a result array `res` at position `n` of type any just storing the corresponding results of individual calls. Note that a windoe `win` is ignored here.
"""
function add_to_member!(res, res_tile, win, n)
    # @show typeof(res) typeof(res_tile) typeof(win)
    res[n] = res_tile
    return nothing
end

"""
    tiled_processing(tiled_view::TiledView, fct; verbose=true, dtype=eltype(tiled_view.parent), window_function=window_hanning)
 
Processes a raw dataset using tiled views by submitting each tile to the function `fct` and merging the results via the `window_function`.

Returns a TiledView of the result. The untiled result can be accessed via `.parent` member.

To be able to handle also functions that habe mutiple return values as a tuple, the accessor function can be used to extract the relevant value from the tuple.
The default is the identity function, which is used for functions that return a single value. If a tuple of accessor functions is provided,
each accessor function will be called and individual an return array for each element of the tuple is constructed and returned as a tuple.

## Arguments
* `tiled_view`: the input data to decompose into a TiledView. No copies are made for the TiledView and the raw data can be accessed via `.parent`.
* `fct`: the function to be applied to each tile. The function should accept a single argument, which is the tile data.
* `verbose`: If true, diagnostic information on the window layout is printed.
* `dtype`: The element type of the new array. By default, it is the same as the type of the parent array of `tiled_view`.
* `window_function`: The window function as defined in IndexFunArrays to apply to the TiledView. The result is currently not any longer a view as it is unclear how to wrap the multiplication into a view. For this reason the TiledView without the window applied is also returned and can be used for assignments. By default a Hanning window (window_hanning) is used.
* `accessor`: A function to access the data in the tile. By default, it is the identity function. 
"""
function tiled_processing(tiled_view::TiledView, fct; verbose=true, dtype=nothing, window_function=nothing)
    if (isnothing(window_function)  && !all(tiled_view.tile_size .== tiled_view.tile_period))
        window_function = window_hanning
    end
    arr = tiled_view.parent
    all_tiles = eachtile(tiled_view)
    first_tile = first(all_tiles)
    res_tile = fct(collect(first_tile))

    # find out if the fct projects along dimensions generating singlon result dimensions and calculate a corresponding result size.
    # Only if the tiling size is equal to the size of the parent array:
    res = alloc_zeros(tiled_view, res_tile, dtype)

    # res_size = ntuple((d)-> (tiled_view.tile_size[d] == size(arr, d) && size(res_tile, d) == 1) ? 1 : size(arr, d), ndims(arr))
    # if isnothing(dtype)
    #     dtype = eltype(res_tile)
    # end
    # res = zeros_like(tiled_view, res_size, dtype);

    win = get_window(res; window_function=window_function)
 
    ttn = get_num_tiles(tiled_view)
    n = 1
    for (src, tn) in zip(eachtile(tiled_view), eachtilenumber(tiled_view))
        if verbose
            perc = round(100 * (linear_index(tn, ttn)-1) ./ prod(ttn))
            print("processing tile $(tn) out of $(ttn), $(perc)%\n")
        end
        # since the first has already been calculated, we need to skip it
        if (n > 1)
            res_tile = fct(collect(src))
            # res_tiles[n] .+= win .* res_tile
        end
        add_to_member!(res, res_tile, win, n)
        n += 1
    end 
    return res
end

"""
    tiled_processing(data, fct, tile_size, tile_overlap = tile_size .* 0; verbose=true, dtype=eltype(data), keep_center=false, window_function=nothing)
 
Processes a raw dataset using tiled views by wrapping the `data` in a TiledView, and submitting each tile to the function `fct` and merging the results via the `window_function`.
Returns a TiledView of the result. The untiled result can be accessed via `.parent` member.
Note that this version with the `tile_size` adds a view conveniences: If the tile size specifies fewer dimensions than the data, the trailing dimensions are automatically expanded to match the full size of the data. 
The default `nothing` in the window_function assures that no window is applied if no overlap is used. With overlap this changes automatically to a Hanning window.
Furthermore, as opposed to the other version, the keep_center option has the default value of false, which is more convenient for most applications that just tile arrays in a matching way.

If the first processed tile returns an array with a size that is neither equal to the input tile size or a projection thereof, the result is a tuple of arrays of the same size as the input tile size,
an array of arrays one for each tile is returned.

## Arguments
* `data`: the input data to decompose into a TiledView. No copies are made for the TiledView and the raw data can be accessed via `.parent`.
* `fct`: the function to be applied to each tile. The function should accept a single argument, which is the tile data.
* `tile_size`: A Tuple describing the size of each tile. This size will form the first N dimensions of the result of `size(myview)`. The second N dimensions refer to N-dimensional tile numbering.
* `tile_overlap`: Tuple specifying the overlap between successive tiles in voxels. This implicitely defines the pitch between tiles as `(tile_size .- tile_overlap)`.
* `verbose`: If true, diagnostic information on the window layout is printed.
* `dtype`: The element type of the new array. By default, it is the same as the type of the parent array of `data`.
* `keep_center`: This boolean (default: false) specifies whether the center of the parent `data` will be aligned with the center of the central tile. If `false`, the first tile starts at offset zero.
* `window_function`: The window function as defined in IndexFunArrays to apply to the TiledView. The result is currently not any longer a view as it is unclear how to wrap the multiplication into a view. For this reason the TiledView without the window applied is also returned and can be used for assignments. By default a Hanning window (window_hanning) is used.

## Example
```jldoctest
julia> res = tiled_processing(ones(10,10), (a)->10*a, (2,2), (0,0), verbose=false).parent
10×10 Matrix{Float64}:
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0
 10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0  10.0

julia> tiled_processing(ones(10,20), (a)->sum(a, dims=2), (2,), verbose=false).parent
10×1 Matrix{Float64}:
 20.0
 20.0
 20.0
 20.0
 20.0
 20.0
 20.0
 20.0
 20.0
 20.0

julia> fct = (a)->[3 .*a, sum(a, dims=2), "result: \$(sum(a))"]; # a function that returns a tuple of three values of very different types

julia> tiled_processing(ones(5,6), fct, (2,), verbose=false)
3-element Vector{AbstractArray}:
 [3.0 3.0 … 3.0 3.0; 3.0 3.0 … 3.0 3.0;;; 3.0 3.0 … 3.0 3.0; 3.0 3.0 … 3.0 3.0;;; 3.0 3.0 … 3.0 3.0; 0.0 0.0 … 0.0 0.0;;;;]
 [6.0; 6.0;;; 6.0; 6.0;;; 6.0; 0.0;;;;]
 ["result: 12.0"; "result: 12.0"; "result: 6.0";;]
```
"""
function tiled_processing(data, fct, tile_size, tile_overlap =  expand_size(tile_size, size(data)) .* 0; verbose=true, dtype=eltype(data), keep_center=false, window_function=nothing)
    tile_size = expand_size(tile_size, size(data))
    tiled_view = TiledView(data, tile_size, tile_overlap; keep_center=keep_center);
    return tiled_processing(tiled_view, fct; verbose=verbose, dtype=dtype, window_function=window_function)
end

end # module
