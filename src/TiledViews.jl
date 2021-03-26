module TiledViews

export TiledView, get_num_tiles, TiledWindowView

# include("concrete_generators.jl")

 # T refers to the result type. N to the dimensions of the final array, and M to the dimensions of the raw array
struct TiledView{T, N, M} <: AbstractArray{T, N} 
    # stores the data. 
    parent::AbstractArray{T, M}
    # output size of the array 
    tile_size::NTuple{M, Int}
    tile_period::NTuple{M, Int}
    tile_offset::NTuple{M, Int}

    # Constructor function
    function TiledView{T, N, M}(data::AbstractArray{T, M}; tile_size::NTuple{M,Int}, tile_period::NTuple{M,Int}, tile_offset::NTuple{M,Int}) where {T,M,N}
        return new{T, N, M}(data, tile_size, tile_period, tile_offset) 
    end
end

function center(data)
    return size(data) .÷2 .+1
end

"""
    TiledView([T], data::F, tile_size::NTuple{N,Int}, tile_overlap::NTuple{N,Int}) where {N,F}

Creates an 2N dimensional view of the data by tiling the N-dimensional data as 
specified by tile_size, tile_overlap and optionally tile_center.

# Examples
```julia-repl
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

Base.similar(A::TiledView) where {T} = TiledView(A.parent, A.tile_size,  A.tile_period,  A.tile_offset)

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
    TiledWindowView([T], data::F, tile_size::NTuple{N,Int}, tile_overlap::NTuple{N,Int}) where {N,F}

Creates an 2N dimensional view of the data by tiling the N-dimensional data as 
specified by tile_size, tile_overlap and optionally tile_center.

# Examples
```julia-repl
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
function TiledWindowView(data::AbstractArray{T,M}, tile_size::NTuple{M,Int}, rel_overlap::NTuple{M,Float64}=tile_size .*0 .+ 0.5) where {T, M}
    @show tile_overlap = round.(Int,tile_size./2.0 .* rel_overlap)
    @show winend = (tile_size .÷2 .+1)
    @show winstart = (winend .- tile_overlap)
    @show changeable = TiledView(data,tile_size, tile_overlap);
    return (changeable, changeable .*window_hanning(tile_size; scale=ScaUnit, border_in=winstart, border_out= winend))           
end

# ToDo: prevent set_index in windows or just pass it through


end # module
