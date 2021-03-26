export Sca,ScaUnit,ScaNorm,ScaFT,ScaFTEdge
export Ctr,CtrCorner,CtrFFT,CtrFT,CtrMid,CtrEnd
export rr, rr2
export xx, yy, zz
export phiphi

# These are the type promotion rules, taken from float.jl but written in terms of types
# see also 
promote_type()
default_type(::Type{Bool}, def_T)    = def_T
default_type(::Type{Int8}, def_T)    = def_T
default_type(::Type{Int16}, def_T)   = def_T
default_type(::Type{Int32}, def_T)   = def_T
default_type(::Type{Int64}, def_T)   = def_T # LOSSY
default_type(::Type{Int128}, def_T)  = def_T # LOSSY
default_type(::Type{UInt8}, def_T)   = def_T
default_type(::Type{UInt16}, def_T)  = def_T
default_type(::Type{UInt32}, def_T)  = def_T
default_type(::Type{UInt64}, def_T)  = def_T # LOSSY
default_type(::Type{UInt128}, def_T) = def_T # LOSSY
default_type(::Type{T}, def_T) where{T} = T # all other types remain to be the same


# define types to specify where the center point is
abstract type Ctr end  # Center of the array
struct CtrCorner <: Ctr end  # corner voxel is zero
struct CtrFFT <: Ctr end # corresponding to FFTs
struct CtrFT <: Ctr end # corresponding to FTs  (meaning shifted FFTs)
struct CtrMid <: Ctr end # middle of the array
struct CtrEnd <: Ctr end # other corner voxel is zero

"""
    Ctr

Abstract type to specify the reference position
from which several other types subtype.

# Possible subtypes
* `CtrCorner`: Set the reference pixel in the corner
* `CtrFFT`: Set the reference pixel to the FFT center.
* `CtrMid`: Set the reference pixel to real mid. For uneven arrays it is the center pixel, for even arrays it is the centered around a half pixel.
* `CtrEnd` Set the reference to the end corner (last pixel)
"""
Ctr

get_offset(size, ::Type{CtrCorner}) = size.*0 .+ 1.0
get_offset(size, ::Type{CtrFT}) = size.÷2 .+ 1.0
get_offset(size, ::Type{CtrFFT}) = size.*0 .+ 1.0
get_offset(size, ::Type{CtrMid}) = (size.+1)./2.0
get_offset(size, ::Type{CtrEnd}) = size.+0.0
get_offset(size, t::NTuple) =  t



abstract type Sca end # scaling of the array
struct ScaUnit <: Sca end # pixel distance is one
struct ScaNorm <: Sca end # total size along each dimension normalized to 1.0
struct ScaFT <: Sca end # reciprocal Fourier coordinates
struct ScaFTEdge <: Sca end # such that the edge of the Fourier space is 1.0

"""
    Sca 

Abstract type to indicate a scaling from which several other types subtype.

# Possible subtypes
* `ScaUnit`: No scaling of the indices 
* `ScaNorm`: Total length along each dimension is normalized to 1
* `ScaFT`: Reciprocal Fourier coordinates
* `ScaFTEdge`: Such that the edge (in FFT sense) of the pixel is 1.0
"""
Sca

get_scale(size, ::Type{ScaUnit}) = ntuple(_ -> one(Int), length(size))
get_scale(size, ::Type{ScaNorm}) = 1 ./ (size .- 1)
get_scale(size, ::Type{ScaFT}) = 0.5 ./ (size .÷ 2)
get_scale(size, ::Type{ScaFTEdge}) = 1 ./ (size .÷ 2)  
get_scale(size, t::NTuple) = t 

# List of functions and names we want to predefine
function generate_functions_expr()
    # offset and scale is already wrapped in the generator function
    x_expr = :(scale .* (x .- offset))
    x_expr1 = :(scale[1] .* (x[1] .- offset[1]))
    x_expr2 = :(scale[2] .* (x[2] .- offset[2]))
    x_expr3 = :(scale[3] .* (x[3] .- offset[3]))

    functions = [
        (:(rr2), :(x -> T(sum(abs2.($x_expr))))),
        (:(rr),  :(x -> T(sqrt.(sum(abs2.($x_expr)))))),
        (:(xx),  :(x -> T($x_expr1))),
        (:(yy),  :(x -> T($x_expr2))),
        (:(zz),  :(x -> T($x_expr3))),
        (:(phiphi), :(x -> T(atan.($x_expr2, $x_expr1)))),  # this is the arcus tangens of y/x yielding a spiral phase ramp
    ]
    return functions
end

function generate_window_functions_expr()
    # x_exprW = :(clamp.(- border_in .+ abs.(scale .* (x .- offset))./(border_out-border_in),0,1))
    x_exprW = :(clamp.(1 .-(abs.(scale .* (x .- offset)).-border_in)./(border_out-border_in),0,1)) 
    x_exprRW = :(clamp.(1 .-(sqrt.(sum((scale .* (x .- offset)).^2)).-border_in)./(border_out-border_in),0,1)) 

    functions = [  # see https://en.wikipedia.org/wiki/Window_function 
        (:(window_linear),  :(x -> T(prod(($x_exprW))))),
        (:(window_edge),  :(x -> T(prod(($x_exprW).>0.5)))),
        (:(window_hanning),  :(x -> T(prod(sinpi.(0.5 .* ($x_exprW)).^2)))),
        (:(window_hamming),  :(x -> T(prod(0.54.-0.46.*cospi.(($x_exprW)))))),
        (:(window_blackman_harris),  :(x -> T(prod(0.35875-0.48829.*cospi.($x_exprW).+0.14128.*cospi.(2 .*$x_exprW).-0.01168.*cospi.(3 .*$x_exprW))))),
        (:(window_radial_linear),  :(x -> T($x_exprRW))),
        (:(window_radial_edge),  :(x -> T(($x_exprRW).>0.5))),
        (:(window_radial_hanning),  :(x -> T(sinpi.(0.5 .* ($x_exprRW)).^2))),
        (:(window_radial_hamming),  :(x -> T((0.54.-0.46.*cospi.(($x_exprRW)))))),
        (:(window_radial_blackman_harris),  :(x -> T((0.35875-0.48829.*cospi.($x_exprRW).+0.14128.*cospi.(2 .*$x_exprRW).-0.01168.*cospi.(3 .*$x_exprRW))))),
    ]
    return functions
end

# we automatically generate the functions for rr2, rr, ...
# We set the types for the arguments correctly in the default cases
for F in generate_functions_expr() 
    # fallback type of IndexFunArray
    default_T = Float64

    # default functions with certain offset and scaling behavior
    @eval function $(F[1])(::Type{T}, size::NTuple{N, Int};
                           offset=CtrFT,
                           scale=ScaUnit) where{N, T} 
        offset = get_offset(size, offset)
        scale = get_scale(size, scale)
        TiledView(T, $(F[2]), size) 
    end
    
    # change order of offset and scale
    @eval function $(F[1])(size::NTuple{N, Int}; 
                           offset=CtrFT, scale=ScaUnit) where {N}
        T = $default_T 
        $(F[1])(T, size, scale=scale, offset=offset) 
    end

    # convenient wrapper to provide an array as input
    @eval function $(F[1])(arr::AbstractArray{T, N}; 
                           offset=CtrFT, scale=ScaUnit) where {T, N}         
        $(F[1])(default_type(T, $default_T), size(arr), scale=scale, offset=offset)
    end

    @eval export $(F[1])
end 

# we automatically generate the functions for different windows like hanning 
for F in generate_window_functions_expr() 
    # fallback type of IndexFunArray
    default_T = Float64

    # default functions with certain offset and scaling behavior
    @eval function $(F[1])(::Type{T}, size::NTuple{N, Int};
                           offset=CtrFT,
                           scale=ScaFTEdge, border_in=0.8, border_out=1.0) where{N, T} 
        offset = get_offset(size, offset)
        scale = get_scale(size, scale)
        TiledView(T, $(F[2]), size) 
    end
    
    # change order of offset and scale
    @eval function $(F[1])(size::NTuple{N, Int}; 
                           offset=CtrFT, 
                           scale=ScaFTEdge, border_in=0.8, border_out=1.0) where{N} 
        T = $default_T 
        $(F[1])(T, size, scale=scale, offset=offset, border_in=border_in, border_out=border_out) 
    end

    # convenient wrapper to provide an array as input
    @eval function $(F[1])(arr::AbstractArray{T, N}; 
                           offset=CtrFT, 
                           scale=ScaFTEdge, border_in=0.8, border_out=1.0) where{N, T} 
        $(F[1])(default_type(T, $default_T), size(arr), scale=scale, offset=offset, border_in=border_in, border_out=border_out)
    end

    @eval export $(F[1])
end

# include docstrings
include("concrete_generators_docstrings.jl")
