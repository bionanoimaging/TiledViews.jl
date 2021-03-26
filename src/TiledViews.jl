module TiledViews

export TiledView

# include("concrete_generators.jl")

 # T refers to the result type
struct TiledView{T, N, M} <: AbstractArray{T, N} where {M}
    # stores the data. 
    parent::AbstractArray{T, M}
    # output size of the array 
    tile_size::NTuple{M, Int}
    tile_period::NTuple{M, Int}
    tile_offset::NTuple{M, Int}

    # Constructor function
    function TiledView(::Type{T}, data::AbstractArray{T, M}, tile_size::NTuple{M,Int}, tile_period::NTuple{M,Int}, tile_offset::NTuple{N,Int}) where {T,M,N,F}
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
julia> TiledView(reshape(1:49,(7,7)), (4, 4),(1, 1))
```
"""
function TiledView(data::AbstractArray{T,N}, tile_size::NTuple{N,Int}, tile_overlap::NTuple{N,Int}, tile_center::NTuple{N,Int} = (tile_size .÷2 +1)) where {T, N}
    # Note that N refers to the original number of dimensions
    tile_period = tile_size .- tile_offset
    data_center = center(data)
    tile_offset = (data_center - tile_center) .% tile_period
    return TiledView(T, data, tile_size, tile_period, tile_offset)
end

function get_num_tiles(data::TiledView) 
    return size(data + tile_offset) .÷ tile_period
end

# define AbstractArray function to allow to treat the generator as an array
# See https://docs.julialang.org/en/v1/manual/interfaces/#man-interface-array
function Base.size(A::TiledView)
    return (tile_size...,(A.tile_period .* get_num_tiles(A))...)
end

# similar requires to be "mutable".
# So we might remove this 
Base.similar(A::TiledView, ::Type{T}, size::Dims) where {T} = TiledView(A.parent, tile_size, tile_period, tile_offset)

# calculate the entry according to the index
function Base.getindex(A::TiledView{T,N}, I::Vararg{Int, M}) where {T,N, M}
    Idx = Tuple(I)
    TilePos = Idx[1:N]
    TileNum = Idx[N+1:end]
    pos = TilePos .- A.tile_offset .+ TileNum .* A.tile_period 
    return getindex(A.parent, pos... )
end

# not supported
Base.setindex!(A::TiledView{T,N}, v, I::Vararg{Int,N}) where {T,N} = begin 
    error("Attempt to assign entries to IndexFunArray which is immutable.")
end

end # module
