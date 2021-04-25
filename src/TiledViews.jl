module TiledViews

export TiledView, get_num_tiles, TiledWindowView

# include("concrete_generators.jl")

 # T refers to the result type. N to the dimensions of the final array, and M to the dimensions of the raw array
struct TiledView{T, N, M, AA<:AbstractArray{T, M}} <: AbstractArray{T, N} 
    # stores the data. 
    parent::AA
    # output size of the array 
    tile_size::NTuple{M, Int}
    tile_period::NTuple{M, Int}
    tile_offset::NTuple{M, Int}

    # Constructor function
    function TiledView{T, N, M}(data::AA; tile_size::NTuple{M,Int}, tile_period::NTuple{M,Int}, tile_offset::NTuple{M,Int}) where {T,M,N,AA}
        return new{T, N, M, AA}(data, tile_size, tile_period, tile_offset) 
    end
end

function center(data)
    return size(data) .÷2 .+1
end

"""
    TiledView([T], data::F, tile_size::NTuple{N,Int}, tile_overlap::NTuple{N,Int}) where {N,F}

Creates an 2N dimensional view of the data by tiling the N-dimensional data as 
specified by tile_size, tile_overlap and optionally tile_center.

`data`. the inputdata to decompose into a TiledView. No copies are made for the TiledView and
the raw data can be accessed via myview.parent.

`tile_size`. A Tuple describing the size of each tile. This size will form the first N dimensions of the
result of size(myview). The second N dimensions refer to N-dimensional tile numbering.

`rel_overlap`. Tuple specifying the relative overlap between successive tiles in voxels. This implicitely
defines the pitch between tiles as (tile_size .- rel_overlap).

# Examples
```jldoctest
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
function TiledView(data::AbstractArray{T,M}, tile_size::NTuple{M,Int}, tile_overlap::NTuple{M,Int}=tile_size .* 0,
                   tile_center::NTuple{M,Int} = (mod.(tile_size,2) .+1)) where {T, M}
    # Note that N refers to the original number of dimensions
    tile_period = tile_size .- tile_overlap
    data_center = center(data)
    tile_offset = mod.((data_center .- tile_center), tile_period)
    N = 2*M
    return TiledView{T,N,M}(data; tile_size=tile_size, tile_period=tile_period, tile_offset=tile_offset)
end

function get_num_tiles(data::TiledView)
    num_tiles = ((size(data.parent) .+ data.tile_offset) .÷ data.tile_period) .+ 1  
    return num_tiles
end

# define AbstractArray function to allow to treat the generator as an array
# See https://docs.julialang.org/en/v1/manual/interfaces/#man-interface-array
function Base.size(A::TiledView)
    return (A.tile_size...,(get_num_tiles(A))...)
end

Base.similar(A::TiledView, ::Type{T}, size::Dims) where {T} = TiledView(A.parent, A.tile_size,  A.tile_period,  A.tile_offset)

# %24 = Base.getproperty(A, :parent)::AbstractMatrix{Float64}

# calculate the entry according to the index
# Base.getindex(A::IndexFunArray{T,N}, I::Vararg{B, N}) where {T,N, B} = return A.generator(I)

# calculate the entry according to the index
function Base.getindex(A::TiledView{T,N}, I::Vararg{Int, N}) where {T,N}
    @boundscheck checkbounds(A, I...)
    TilePos = I[1:N÷2]  # referring to the positon inside a tile
    TileNum = I[N÷2+1:end] # referring to the tile
    pos = TilePos .- A.tile_offset .+ (TileNum.-1) .* A.tile_period 
    if Base.checkbounds(Bool, A.parent, pos...)
        return Base.getindex(A.parent, pos... )
    else
        return convert(T,0)
    end
end

# not supported
Base.setindex!(A::TiledView{T,N}, v, I::Vararg{Int,N}) where {T,N} = begin 
    @boundscheck checkbounds(A, I...)
    TilePos = I[1:N÷2]
    TileNum = I[N÷2+1:end]
    pos = TilePos .- A.tile_offset .+ (TileNum.-1) .* A.tile_period 
    if Base.checkbounds(Bool, A.parent, pos...)
        return setindex!(A.parent, v, pos... )
    else
        return convert(T,0)
    end
end

## Some functions for generating useful tilings
using IndexFunArrays

"""
function TiledWindowView(data::AbstractArray{T,M}, tile_size::NTuple{M,Int};
    rel_overlap::NTuple{M,Float64}=tile_size .*0 .+ 1.0,
    window_function=window_hanning, get_norm=false, verbose=false) where {T, M}

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

`rel_overlap`. Tuple specifying the relative overlap between successive tiles in voxels. This implicitely
defines the pitch between tiles as (tile_size .- rel_overlap).

`window_function`. The window function as defined in IndexFunArrays to apply to the TiledView.
The result is currently not any longer a view as it is unclear how to wrap the multiplication into a view.
For this reason the TiledView without the window applied is also returned and can be used for assignments.
By default a von Hann window (window_hanning) is used.

`get_norm`. An optional Boolean argument allowing to also obtain the normalization map for the boarder pixels, which
not necessarily undergo all required window operations. In a future version it may be possible
to automatically lay out the windowing such that this effect can be avoided.

`verbose`. If true, diagnostic information on the window layout is printed.

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
julia> myview, matching_window = TiledWindowView(data, (5, 5);verbose=true);
Tiles with pitch (3, 3) overlap by (2, 2) pixels.
Window starts at (0.5, 0.5) and ends at (2.5, 2.5).
julia> size(myview)
(5, 5, 4, 4)
julia> matching_window
5×5 IndexFunArray{Float64, 2, IndexFunArrays.var"#199#200"{Float64, Tuple{Float64, Float64}, Tuple{Int64, Int64}, Tuple{Float64, Float64}, Tuple{Float64, Float64}}}:
 0.0214466  0.125     0.146447  0.125     0.0214466
 0.125      0.728553  0.853553  0.728553  0.125
 0.146447   0.853553  1.0       0.853553  0.146447
 0.125      0.728553  0.853553  0.728553  0.125
 0.0214466  0.125     0.146447  0.125     0.0214466
julia> windowed = collect(myview .* matching_window);
julia> myview[:,:,:,:].=0  # cleares the original array
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
julia> myview .+= windowed  # writes the windowed data back into the array
julia> data # lets see if the weigths correctly sum to one?
10×10 Matrix{Float64}:
 0.728553  0.853553  0.853553  0.853553  0.853553  0.853553  0.853553  0.853553  0.853553  0.853553
 0.853553  1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0
 0.853553  1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0
 0.853553  1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0
 0.853553  1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0
 0.853553  1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0
 0.853553  1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0
 0.853553  1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0
 0.853553  1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0
 0.853553  1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0       1.0
```
# This result may also be used for subsequent normalization but can also be directly obtained by
julia> myview, matching_window, normalized = TiledWindowView(rand(10,10).+0, (5, 5);get_norm=true);
"""
function TiledWindowView(data::AbstractArray{T,M}, tile_size::NTuple{M,Int};
                         rel_overlap::NTuple{M,Float64}=tile_size .*0 .+ 1.0,
                         window_function=window_hanning, get_norm=false, verbose=false) where {T, M}
    tile_overlap = round.(Int,tile_size./2.0 .* rel_overlap)
    tile_pitch = tile_size .- tile_overlap  
    winend = (tile_size ./ 2.0)
    winstart = (winend .- tile_overlap)
    if verbose
        print("Tiles with pitch $tile_pitch overlap by $tile_overlap pixels.\n")
        print("Window starts at $winstart and ends at $winend.\n")
    end
    changeable = TiledView(data,tile_size, tile_overlap);
    if get_norm == false
        return (changeable , window_function(tile_size; 
            scale=ScaUnit, offset=CtrMid,
            border_in=winstart, border_out= winend))
    else
        normalization = ones(Float32,size(data))
        my_view = TiledView(normalization,tile_size, tile_overlap)
        normalization .= 0
        my_view .+= changeable .*window_function(tile_size;scale=ScaUnit, offset=CtrMid, border_in=winstart, border_out= winend)        
        return (changeable, window_function(tile_size; 
            scale=ScaUnit, offset=CtrMid,
            border_in=winstart, border_out= winend), normalization)
    end
end

# ToDo: prevent set_index in windows or just pass it through

end # module
